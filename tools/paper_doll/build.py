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

ROOT = os.path.join(HERE, '..', '..')
SPRITES = os.path.join(ROOT, 'assets', 'sprites')
PAD = 70

# Landmarks on each bald body, in sheet pixels of the body's own crop:
# head (center x, top y, width), torso (center x, top y, width), waist y, hip y (legs start),
# main / off hand (x, y).
BODIES = {
    'male': dict(sheet='male2', scale=1.8, waist=50, hip=62, L={
        's':  dict(head=(27, 0, 21), torso=(27, 24, 34), main=(47, 62), off=(7, 62)),
        'se': dict(head=(28, 0, 21), torso=(26, 25, 32), main=(45, 62), off=(6, 62)),
        'e':  dict(head=(16, 0, 21), torso=(15, 24, 22), main=(10, 62), off=(22, 55)),
        'ne': dict(head=(21, 0, 20), torso=(24, 26, 34), main=(45, 62), off=(3, 60)),
        'n':  dict(head=(27, 0, 21), torso=(27, 26, 36), main=(47, 62), off=(6, 62)),
    }),
    'female': dict(sheet='female', scale=3.0, waist=70, hip=88, L={
        's':  dict(head=(31, 0, 22), torso=(31, 34, 42), main=(55, 80), off=(8, 80)),
        'se': dict(head=(30, 0, 22), torso=(28, 34, 38), main=(51, 77), off=(6, 82)),
        'e':  dict(head=(21, 0, 22), torso=(17, 34, 24), main=(14, 82), off=(26, 70)),
        'ne': dict(head=(27, 0, 22), torso=(29, 36, 42), main=(50, 80), off=(5, 80)),
        'n':  dict(head=(30, 0, 22), torso=(30, 36, 44), main=(54, 82), off=(6, 82)),
    }),
}

# (category, id): {sex: (sheet, row, pick)}, anchor, size factor, extra
def both(src):
    return {'male': src, 'female': src}

PIECES = [
    (('hair', 'long'), {'male': ('male2', 'hair_long', 'all'), 'female': ('female', 'hair_long', 'all')}, 'head', 1.25, dict(dy=-2)),
    (('hair', 'braids'), {'male': ('male2', 'hair_braids', 'all'), 'female': ('female', 'hair_braids', 'all')}, 'head', 1.30, dict(dy=-2)),
    (('hair', 'short'), {'male': ('male2', 'hair_short', 'all'), 'female': ('female', 'hair_short', 'all')}, 'head', 1.20, dict(dy=-2)),
    (('gear', 'hide_wrap'), {'male': ('male2', 'armor_hide', 'all'), 'female': ('female', 'armor_hide', 'all')}, 'torso', 1.05, dict(dy=-1)),
    (('gear', 'leather_armor'), {'male': ('male2', 'armor_leather', 'all'), 'female': ('female', 'armor_leather', 'all')}, 'torso', 1.05, dict(dy=-1)),
    (('gear', 'bone_hide'), both(('male2', 'armor_bone', 'all')), 'torso', 1.10, dict(dy=-2)),
    (('clothing', 'fur_cloak'), {'male': ('male2', 'cloak_fur', 'all'), 'female': ('female', 'cloak_fur', 'all')}, 'torso', 1.30, dict(dy=-5)),
    (('clothing', 'hide_skirt'), {'male': ('male2', 'skirt_hide', 'all'), 'female': ('female', 'skirt_hide', 'all')}, 'waist', 0.95, dict(dy=-2)),
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


def fit(piece, anchor, factor, extra, lm, body_h, shape, ox, oy, waist, view):
    ph, pw = piece.shape[:2]
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
            body = cut(b['sheet'], 'body', v)
            bh, bw = body.shape[:2]
            shape = (bh + PAD, bw + 2 * PAD, 4)
            canvas = np.zeros(shape, np.uint8)
            ox, oy = PAD, PAD
            canvas[oy:oy + bh, ox:ox + bw] = body
            lm = b['L'][v]
            layers = {}
            for key, sources, anchor, factor, extra in PIECES:
                if sex not in sources:
                    continue
                sheet, row, pick = sources[sex]
                piece = cut(sheet, row, v, pick)
                if piece is not None:
                    layers[key] = fit(piece, anchor, factor, extra, lm, bh, shape, ox, oy, b['waist'], v)
            # One crop for every layer of this view: symmetric about the body, bottom at the feet.
            union = canvas[..., 3] > 0
            for arr in layers.values():
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
            rig[sex][v] = dict(main=rel(ox + lm['main'][0], oy + lm['main'][1]),
                               off=rel(ox + lm['off'][0], oy + lm['off'][1]),
                               hip=round((oy + b['hip'] - feet) / sc, 1))
            sm = skin_mask(canvas)
            for skin, color in SKINS.items():
                save(finish(recolor(canvas, sm, color, 0.85)), 'bodies', 'body_%s__%s' % (sex, skin), v)
            for (category, pid), arr in layers.items():
                if category == 'hair':
                    clear = arr.copy()
                    clear[skin_mask(arr)] = 0  # let the body's own face show through
                    for hair, color in HAIRS.items():
                        save(finish(recolor(clear, hair_mask(clear), color)), 'hair', '%s_%s__%s' % (sex, pid, hair), v)
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
    print('built paper-doll sprites for', ', '.join(BODIES))


if __name__ == '__main__':
    main()
