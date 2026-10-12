#!/usr/bin/env python3
"""Build the leader's paper-doll sprites from the ChatGPT sheets in assets/source/.

    python3 tools/paper_doll/build.py

ChatGPT draws every piece centered in its own cell at its own scale, so pieces
don't stack by themselves. Each piece is fitted to landmarks on the bald body
it belongs to (head, torso, waist, hands per view), all layers of one view go on
a shared canvas with the feet at the bottom center, and everything is shrunk to
game size. Skin, hair and paint are recolored into variants. Also writes
scripts/data/rig.gd (hand and hip positions per sex and view) for animation.

Output ids (assets/sprites/<category>/<id>/<view>.png):
  bodies/body_<sex>__<skin>            hair/<sex>_<style>__<hair color>
  gear/<sex>_<gear id>                 clothing/<sex>_<clothing id>
  (war paint: tools/paper_doll/build_paint.py, run after this)
"""
import os
import shutil
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from sheets import cut, VIEWS  # noqa: E402
from template_body import LANDMARKS, body_frame, head_center  # noqa: E402

ROOT = os.path.join(HERE, '..', '..')
SPRITES = os.path.join(ROOT, 'assets', 'sprites')
PAD = 70

# Landmarks on each bald body, in sheet pixels of the body's own crop:
# head (center x, top y, width), torso (center x, top y, width), waist y, hip y (legs start),
# main / off hand (x, y).
# The bodies come from Luke's animation template (template_body.py): idle + 4 walk
# frames per view, in the template's sheet pixels (2 sheet pixels per art pixel).
BODIES = {
    sex: dict(sheet='template', scale=2.0, waist=lm['waist'], hip=lm['hip'], L=lm['L'])
    for sex, lm in LANDMARKS.items()
}
WALK_FRAMES = 4

# (category, id): {sex: (sheet, row, pick)}, anchor, size factor, extra
def both(src):
    return {'male': src, 'female': src}

PIECES = [
    (('hair', 'long'), {'male': ('male2', 'hair_long', 'all'), 'female': ('female', 'hair_long', 'all')}, 'hair', 1.0, {}),
    (('hair', 'braids'), {'male': ('male2', 'hair_braids', 'all'), 'female': ('female', 'hair_braids', 'all')}, 'hair', 1.0, {}),
    (('hair', 'short'), {'male': ('male2', 'hair_short', 'all'), 'female': ('female', 'hair_short', 'all')}, 'hair', 1.0, {}),
    (('gear', 'hide_wrap'), {'male': ('male2', 'armor_hide', 'all'), 'female': ('female', 'armor_hide', 'all')}, 'span', 1.0,
     dict(top=('torso', -3), bottom=('chest', 0), clip=2)),
    (('gear', 'leather_armor'), {'male': ('male2', 'armor_leather', 'all'), 'female': ('female', 'armor_leather', 'all')}, 'span', 1.0,
     dict(top=('torso', -3), bottom=('waist', 3), clip=2)),
    (('gear', 'bone_hide'), both(('male2', 'armor_bone', 'all')), 'span', 1.0,
     dict(top=('torso', -4), bottom=('hip', 8), clip=3)),
    (('clothing', 'fur_cloak'), {'male': ('male2', 'cloak_fur', 'all'), 'female': ('female', 'cloak_fur', 'all')}, 'torso', 1.30, dict(dy=-5)),
    (('clothing', 'hide_skirt'), {'male': ('male2', 'skirt_hide', 'all'), 'female': ('female', 'skirt_hide', 'all')}, 'span', 1.0,
     dict(top=('waist', -2), bottom=('hip', 14), clip=3)),
    (('clothing', 'bone_headband'), {'male': ('male2', 'headband_bone', 'all'), 'female': ('female', 'headband_bone', 'all')}, 'head', 1.12, dict(dy=-1)),
    (('clothing', 'animal_hood'), {'male': ('male1', 'hood_wolf', 'all'), 'female': ('female', 'hood_wolf', 'all')}, 'head', 1.55, dict(dy=-6)),
    (('clothing', 'antler_skull'), {'male': ('male1', 'helm_antler', 'all'), 'female': ('female', 'helm_antler', 'all')}, 'head', 1.85, dict(dy=-12)),
    (('gear', 'spear'), both(('weapons', 'spear_stone', 'all')), 'main', 0.95, dict(grip=0.18)),
    (('gear', 'bone_spear'), both(('weapons', 'spear_bone', 'all')), 'main', 1.0, dict(grip=0.18)),
    (('gear', 'club'), both(('weapons', 'club_spiked', 'all')), 'main', 0.58, dict(grip=0.12)),
    (('gear', 'stone_axe'), both(('weapons', 'axe_stone', 'all')), 'main', 0.58, dict(grip=0.12)),
    (('gear', 'flail'), both(('male2', 'flail', 'left')), 'main', 0.60, dict(grip=0.10)),
    (('gear', 'sling'), both(('male2', 'sling', 'left')), 'main', 0.45, dict(grip=0.10)),
    (('gear', 'hide_shield'), {'male': ('male1', 'shield_wood', 'all'), 'female': ('female', 'weapons_row', 'right')}, 'off', 0.40, dict(dy=-4)),
    (('gear', 'bone_shield'), both(('male1', 'shield_bone', 'all')), 'off', 0.44, dict(dy=-4)),
]

# Degrees a held weapon leans forward per view (counter-clockwise positive, as in PIL).
HELD_TILT = {'e': -40, 'se': -10}

SKINS = {'skin1': (0.95, 0.82, 0.71), 'skin2': (0.88, 0.70, 0.56), 'skin3': (0.76, 0.57, 0.42),
         'skin4': (0.60, 0.42, 0.29), 'skin5': (0.44, 0.30, 0.20), 'skin6': (0.31, 0.21, 0.15)}
HAIRS = {'black': (0.16, 0.13, 0.12), 'brown': (0.40, 0.26, 0.16), 'auburn': (0.60, 0.28, 0.14),
         'blond': (0.88, 0.74, 0.44), 'grey': (0.66, 0.64, 0.61)}


def hsv(a):
    f = a[..., :3].astype(float) / 255
    mx, mn = f.max(axis=-1), f.min(axis=-1)
    d = np.maximum(mx - mn, 1e-6)
    r, g, b = f[..., 0], f[..., 1], f[..., 2]
    h = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    return h, s, mx


def skin_mask(a):
    h, s, v = hsv(a)
    return (a[..., 3] > 0) & (v >= 0.42) & (s > 0.28) & (h >= 14) & (h <= 48)


def hair_mask(a):
    h, s, v = hsv(a)
    return (a[..., 3] > 0) & (v < 0.42) & (v > 0.12) & ~skin_mask(a)


def dyeable(a):
    """Every strand of a hairstyle (light or dark), but not its white bone beads."""
    _, s, v = hsv(a)
    return (a[..., 3] > 0) & ~((s < 0.25) & (v > 0.6))


def recolor(a, mask, target, strength=1.0):
    """Give masked pixels the target color, keeping their light and shade."""
    if not mask.any():
        return a
    out = a.astype(float)
    _, _, v = hsv(a)
    base = v[mask].mean()
    t = np.array(target) * 255
    for ch in range(3):
        new = np.clip(t[ch] * (v[mask] / base), 0, 255)
        out[..., ch][mask] = a[..., ch][mask] * (1 - strength) + new * strength
    return out.astype(np.uint8)


def paste(shape, piece, x, y, s):
    im = Image.fromarray(piece)
    im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.NEAREST)
    out = Image.new('RGBA', (shape[1], shape[0]), (0, 0, 0, 0))
    out.alpha_composite(im, (int(round(x)), int(round(y))))
    return np.asarray(out)


def grip_point(piece, frac):
    """Where a hand holds a weapon: `frac` of its length up from the handle end (its lowest point)."""
    ys, xs = np.nonzero(piece[..., 3] > 0)
    bottom = ys.max()
    bx = xs[ys >= bottom - 2].mean()
    top = ys.min()
    tx = xs[ys <= top + 2].mean()
    return bx + (tx - bx) * frac, bottom + (top - bottom) * frac


def pink_mask(a, hair=False):
    """The sheet's magenta key bleeding into a piece's edges (and, in hair, the pink-tinted faces)."""
    h, s, v = hsv(a)
    m = (a[..., 3] > 0) & (s > 0.25) & (h >= 285) & (h <= 345)
    if hair:
        m |= (a[..., 3] > 0) & (s > 0.25) & (v > 0.45) & ((h > 345) | (h < 14))
    return m


def drop_specks(a, min_px):
    """Remove little islands left behind (a face's eyes and mouth once the skin is gone)."""
    from sheets import _blobs
    lab, sizes = _blobs(a[..., 3] > 0)
    out = a.copy()
    for k, n in enumerate(sizes):
        if n < min_px:
            out[lab == k] = 0
    return out


def clean_piece(piece, category):
    """A worn piece without the sheet's own skin (bare arms, faces): the body shows through
    instead, in the chosen skin tone. Hair and headwear ('head') also lose the face drawn
    inside them."""
    a = piece.copy()
    hair = category in ('hair', 'head')
    # The magenta key tints the dark outline purple: keep it as a plain dark outline.
    _, _, v = hsv(a)
    pink = pink_mask(a, hair)
    a[pink & (v < 0.5), :3] = (44, 28, 22)
    a[pink & (v >= 0.5)] = 0
    if category == 'hair':
        a[skin_mask(a)] = 0
    else:  # fur, bone and leather can look skin-ish: only clear bright bare skin
        a[bare_skin_mask(a)] = 0
    if hair:
        a = drop_specks(a, 18)
    return a


def bare_skin_mask(a):
    """Bare arms drawn into an armor piece: large, bright, orange-tan areas (and the skin-toned
    shading around them). Leather that only looks skin-ish is darker or scattered, and stays."""
    from sheets import _blobs
    h, s, v = hsv(a)
    core = (a[..., 3] > 0) & (h >= 14) & (h <= 29) & (s > 0.5) & (v > 0.72)
    lab, sizes = _blobs(core)
    big = np.isin(lab, [k for k, n in enumerate(sizes) if n >= 20])
    return big | (skin_mask(a) & dilate(big, 2))


def hair_fit(piece_s):
    """Measure a hairstyle on its front view, in the piece's own pixels: the hairline row and
    the width (at the cheeks) and center of the face opening (specks in the hair filled in first)."""
    m = piece_s[..., 3] > 0
    m = ~dilate(~dilate(m, 2), 2)  # close: fill little holes inside the hair
    h, w = m.shape
    cols = np.nonzero(m.any(axis=0))[0]
    cx = int(round((cols.min() + cols.max()) / 2))
    y = int(np.nonzero(m[:, cx])[0].min())
    while y < h and m[y, cx]:
        y += 1
    hairline = y
    runs = []
    mid = hairline + (h - hairline) // 2  # cheek level: halfway from the hairline to the chin
    for fy in range(mid - 3, min(h, mid + 4)):
        left = cx
        while left > 0 and not m[fy, left - 1]:
            left -= 1
        right = cx
        while right < w - 1 and not m[fy, right + 1]:
            right += 1
        if left > 0 and right < w - 1:  # bounded by hair on both sides
            runs.append((right - left + 1, (left + right) / 2))
    if not runs:
        return hairline, w * 0.5, cx
    runs.sort()
    width, center = runs[len(runs) // 2]
    return hairline, width, center


# Where a hairstyle's crown starts, in sheet pixels from the top of the bald head.
HAIR_TOP = -3


def hair_face_width(sex):
    """One face width per sex: every hairstyle on a sheet is drawn around the same head, so
    the middle measurement of the styles is used for all of them (bangs fool a single one)."""
    widths = []
    for key, sources, anchor, _, _ in PIECES:
        if anchor == 'hair' and sex in sources:
            sheet, row, pick = sources[sex]
            widths.append(hair_fit(clean_piece(cut(sheet, row, 's', pick), 'hair'))[1])
    return sorted(widths)[len(widths) // 2]


def paste_xy(shape, piece, x, y, sx, sy):
    im = Image.fromarray(piece)
    im = im.resize((max(1, round(im.width * sx)), max(1, round(im.height * sy))), Image.NEAREST)
    out = Image.new('RGBA', (shape[1], shape[0]), (0, 0, 0, 0))
    out.alpha_composite(im, (int(round(x)), int(round(y))))
    return np.asarray(out)


def dilate(mask, r):
    out = mask.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            out |= np.roll(np.roll(mask, dy, 0), dx, 1)
    return out


def fit(piece, anchor, factor, extra, lm, body_h, shape, ox, oy, waist, view, body=None, refs=None, hair_ref=None, eye=0):
    ph, pw = piece.shape[:2]
    if anchor == 'span':
        # Stretch the piece over the body's own outline between two landmarks (the full width
        # of the body there, arms included), then trim whatever sticks out past the body.
        top = refs[extra['top'][0]] + extra['top'][1]
        bottom = refs[extra['bottom'][0]] + extra['bottom'][1]
        rows = body[max(0, oy + top):oy + bottom]
        cols = np.nonzero(rows.any(axis=0))[0]
        x0, x1 = cols.min(), cols.max() + 1
        layer = paste_xy(shape, piece, x0, oy + top, (x1 - x0) / pw, (bottom - top) / ph)
        keep = dilate(body, extra['clip'])
        layer = layer.copy()
        layer[~keep] = 0
        return layer
    if anchor == 'hair':
        # Same scale as the front view, where the face opening fits the body's face; the
        # crown sits over the body's head.
        scale, top_off, face_dx = hair_ref
        hcx = lm['head'][0]
        if view == 's':
            x = ox + hcx - face_dx * scale
        elif view in ('se', 'e'):
            # Facing right: the hair's front edge stops at the forehead, the mass hangs behind.
            hm = piece[..., 3] > 0
            front = np.nonzero(hm[:max(2, int(ph * 0.35))].any(axis=0))[0].max()
            x = ox + hcx + lm['head'][2] / 2 - 1 - front * scale
        else:
            hm = piece[..., 3] > 0
            ys, xs = np.nonzero(hm[:max(2, ph // 4)])
            x = ox + hcx - xs.mean() * scale
        layer = paste_xy(shape, piece, x, oy + top_off, scale, scale).copy()
        if view in ('s', 'se'):
            # Keep the face clear: no strands across the eyes, cheeks or mouth.
            fx = ox + hcx + (3 if view == 'se' else 0)
            fy = oy + eye + 3
            rx, ry = lm['head'][2] * 0.34, 6.5
            yy, xx = np.mgrid[0:shape[0], 0:shape[1]]
            layer[((xx - fx) / rx) ** 2 + ((yy - fy) / ry) ** 2 <= 1.0] = 0
        return layer
    if anchor in ('head', 'torso'):
        cx, top, width = lm[anchor]
        s = width * factor / pw
        return paste(shape, piece, ox + cx - pw * s / 2, oy + top + extra.get('dy', 0), s)
    if anchor == 'waist':
        cx, _, width = lm['torso']
        s = width * factor / pw
        return paste(shape, piece, ox + cx - pw * s / 2, oy + waist + extra.get('dy', 0), s)
    if anchor == 'main':
        s = body_h * factor / ph
        gx, gy = grip_point(piece, extra['grip'])
        hx, hy = lm['main']
        layer = paste(shape, piece, ox + hx - gx * s, oy + hy - gy * s, s)
        tilt = HELD_TILT.get(view, 0)
        if tilt:
            # Carry the weapon leaning forward instead of straight up in front of the face.
            layer = np.asarray(Image.fromarray(layer).rotate(tilt, center=(ox + hx, oy + hy), resample=Image.NEAREST))
        return layer
    s = body_h * factor / ph  # shield, centered on the off hand
    hx, hy = lm['off']
    return paste(shape, piece, ox + hx - pw * s / 2, oy + hy + extra.get('dy', 0) - ph * s / 2, s)


def save(arr, category, piece, view):
    d = os.path.join(SPRITES, category, piece)
    os.makedirs(d, exist_ok=True)
    Image.fromarray(arr).save(os.path.join(d, view + '.png'))


def main():
    for category in ('bodies', 'hair', 'gear', 'clothing'):
        shutil.rmtree(os.path.join(SPRITES, category), ignore_errors=True)
    rig = {}
    for sex, b in BODIES.items():
        rig[sex] = {}
        sc = b['scale']
        for v in VIEWS:
            body = body_frame(sex, v, 0)
            bh, bw = body.shape[:2]
            shape = (bh + PAD, bw + 2 * PAD, 4)
            canvas = np.zeros(shape, np.uint8)
            ox, oy = PAD, PAD
            canvas[oy:oy + bh, ox:ox + bw] = body
            lm = b['L'][v]
            body_mask = canvas[..., 3] > 0
            refs = dict(torso=lm['torso'][1], waist=b['waist'], hip=b['hip'],
                        chest=lm['torso'][1] + int(0.6 * (b['waist'] - lm['torso'][1])))
            layers = {}
            for key, sources, anchor, factor, extra in PIECES:
                if sex not in sources:
                    continue
                sheet, row, pick = sources[sex]
                piece = cut(sheet, row, v, pick)
                if piece is None:
                    continue
                piece = clean_piece(piece, 'head' if anchor == 'head' and key[0] == 'clothing' else key[0])
                hair_ref = None
                if anchor == 'hair':
                    _, face_w, face_cx = hair_fit(clean_piece(cut(sheet, row, 's', pick), 'hair'))
                    scale = 0.72 * b['L']['s']['head'][2] / hair_face_width(sex)
                    hair_ref = (scale, HAIR_TOP, face_cx)
                layers[key] = fit(piece, anchor, factor, extra, lm, bh, shape, ox, oy, b['waist'], v,
                                  body=body_mask, refs=refs, hair_ref=hair_ref, eye=LANDMARKS[sex]['eye'])
            # Walk frames: feet on the same ground line, heads lined up over the idle head.
            walks = []
            idle_head = head_center(body)
            for n in range(WALK_FRAMES):
                f = body_frame(sex, v, n + 1)
                fh, fw = f.shape[:2]
                fx = int(round(ox + idle_head - head_center(f)))
                fy = oy + bh - fh
                frame_canvas = np.zeros(shape, np.uint8)
                frame_canvas[fy:fy + fh, fx:fx + fw] = f
                walks.append((frame_canvas, fh, fw))
            # One crop for every layer of this view: symmetric about the body, bottom at the feet.
            union = canvas[..., 3] > 0
            for arr in layers.values():
                union |= arr[..., 3] > 0
            for arr, _, _ in walks:
                union |= arr[..., 3] > 0
            ys, xs = np.nonzero(union)
            feet, cx = oy + bh, ox + bw / 2
            half = int(np.ceil(max(cx - xs.min(), xs.max() + 1 - cx)))
            box = (int(cx - half), int(ys.min()), int(cx + half), int(feet))
            out_w = max(2, round((box[2] - box[0]) / sc))
            out_h = max(2, round((box[3] - box[1]) / sc))

            def finish(arr):
                return np.asarray(Image.fromarray(arr).crop(box).resize((out_w, out_h), Image.NEAREST))

            def rel(x, y):
                return [round((x - cx) / sc, 1), round((y - feet) / sc, 1)]
            # How far the head (and everything worn above the legs) moves in each walk frame,
            # and the widest stride (the lunge of an attack).
            offsets = [[0.0, round((bh - fh) / sc, 1)] for _, fh, _ in walks]
            lunge = int(np.argmax([fw for _, _, fw in walks]))
            rig[sex][v] = dict(main=rel(ox + lm['main'][0], oy + lm['main'][1]),
                               off=rel(ox + lm['off'][0], oy + lm['off'][1]),
                               hip=round((oy + b['hip'] - feet) / sc, 1), walk=offsets, lunge=lunge)
            sm = skin_mask(canvas)
            for skin, color in SKINS.items():
                save(finish(recolor(canvas, sm, color, 0.85)), 'bodies', 'body_%s__%s' % (sex, skin), v)
                for n, (arr, _, _) in enumerate(walks):
                    save(finish(recolor(arr, skin_mask(arr), color, 0.85)), 'bodies', 'body_%s__%s' % (sex, skin),
                         '%s_walk_%d' % (v, n))
            for (category, pid), arr in layers.items():
                if category == 'hair':
                    clear = arr.copy()
                    clear[skin_mask(arr)] = 0  # let the body's own face show through
                    for hair, color in HAIRS.items():
                        save(finish(recolor(clear, dyeable(clear), color)), 'hair', '%s_%s__%s' % (sex, pid, hair), v)
                elif pid.startswith('paint_'):
                    for skin, color in SKINS.items():
                        save(finish(recolor(arr, skin_mask(arr), color, 0.85)), category, '%s_%s__%s' % (sex, pid, skin), v)
                else:
                    save(finish(arr), category, '%s_%s' % (sex, pid), v)
    with open(os.path.join(ROOT, 'scripts', 'data', 'rig.gd'), 'w') as f:
        f.write('extends RefCounted\n## Generated by tools/paper_doll/build.py - do not edit by hand.\n')
        f.write('## Per sex and view, in art pixels from the feet (bottom-center of the sprite):\n')
        f.write('## main_hand / off_hand = where the hands are, hip = where the legs start (negative = up).\n\n')
        f.write('const BODIES := {\n')
        for sex, views in rig.items():
            f.write('\t"%s": {\n' % sex)
            for v, r in views.items():
                f.write('\t\t"%s": {"main_hand": Vector2(%s, %s), "off_hand": Vector2(%s, %s), "hip": %s},\n' % (
                    v, r['main'][0], r['main'][1], r['off'][0], r['off'][1], r['hip']))
            f.write('\t},\n')
        f.write('}\n\n\nstatic func bodies() -> Dictionary:\n\treturn BODIES\n')
    with open(os.path.join(ROOT, 'scripts', 'data', 'walk_rig.gd'), 'w') as f:
        f.write('extends RefCounted\n## Generated by tools/paper_doll/build.py - do not edit by hand.\n')
        f.write('## Per sex and view: walk = how far everything worn above the legs moves (art pixels) in each\n')
        f.write('## walk frame (bodies/body_<sex>__<skin>/<view>_walk_<n>.png), lunge = the walk frame with the\n')
        f.write('## widest stride, used while striking.\n\nconst WALK := {\n')
        for sex, views in rig.items():
            f.write('\t"%s": {\n' % sex)
            for v, r in views.items():
                offs = ', '.join('Vector2(%s, %s)' % (o[0], o[1]) for o in r['walk'])
                f.write('\t\t"%s": {"offsets": [%s], "lunge": %d},\n' % (v, offs, r['lunge']))
            f.write('\t},\n')
        f.write('}\n\n\nstatic func walk() -> Dictionary:\n\treturn WALK\n')
    print('built paper-doll sprites for', ', '.join(BODIES))


if __name__ == '__main__':
    main()
