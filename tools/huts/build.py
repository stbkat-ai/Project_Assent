#!/usr/bin/env python3
"""Build the hut kit: cut Luke's ChatGPT hut sheets into parts, line every part
up on one shared canvas per hut shape, and write the sprites plus
scripts/data/building_parts.gd (the option lists the designer shows).

    python3 tools/huts/build.py

Like the leader's paper doll, every part of a shape is drawn on the same canvas
(CANVAS, anchored at the bottom center), so the game just stacks the layers:
walls, roof, door, hanging decoration, roof crest, yard prop. The canvas point
ANCHOR is the center of the building's footprint on the ground.

Sheets (assets/source/): sheet_huts_1.png, sheet_huts_2.png. Each row holds
round-hut parts on the left half and longhouse parts on the right half.
"""
import os
import re
import shutil
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
from slice_kit import keyed, split  # noqa: E402

SCALE = 2  # sheet pixels per art pixel
CANVAS = (120, 150)
ANCHOR = (60, 128)  # footprint center on the canvas
WALL_W = 64  # every wall is scaled to this width
WALL_BOTTOM = 143  # the front of the walls' ground ring
WALL_H = 40  # reference wall height the roof sits on
ROOF_W = WALL_W * 1.12
ROOF_SINK = 0.55  # the roof's lower edge covers this share of the wall height
DOOR_W = {"round": WALL_W * 0.46, "long": WALL_W * 0.5}
CREST_W = WALL_W * 0.42
HANG_W = WALL_W * 0.2
YARD_W = WALL_W * 0.36

# Row bands per sheet: name -> (top, bottom, pieces on the left, pieces on the right).
BANDS = {
    "sheet_huts_1.png": {"roof": (168, 320, 5, 5), "chiefroof": (323, 493, 5, 5), "walls": (496, 612, 6, 6),
                         "door": (615, 726, 6, 6), "crest": (728, 818, 6, 7)},
    "sheet_huts_2.png": {"roof": (169, 335, 5, 5), "walls": (338, 457, 6, 6), "crest": (587, 686, 7, 6),
                         "hang": (689, 790, 9, 8), "rack": (793, 900, 8, 8), "prop": (903, 1022, 10, 10)},
}

# (sheet, band, half, index) -> (shape, slot, name, chief_only). shape "any" = both shapes.
S1, S2 = "sheet_huts_1.png", "sheet_huts_2.png"
PARTS = []


def add(sheet, band, half, shape, slot, names, chief_only=False):
    for i, name in enumerate(names):
        if name:
            PARTS.append((sheet, band, half, i, shape, slot, name, chief_only))


add(S1, "walls", "round", "round", "walls", ["Painted palisade", "Hide wrap", "Hide and posts", "Log ring", "Stone ring", "Leaf ring"])
add(S2, "walls", "round", "round", "walls", ["Post ring", "Woven wattle", "Hide over posts", "Stone and logs", "Fieldstone", "Leafy wattle"])
add(S1, "walls", "long", "long", "walls", ["Plank walls", "Hide walls", "Patched hide walls", "Stone walls", "Post walls", "Wattle walls"])
add(S2, "walls", "long", "long", "walls", ["Log box", "Wattle box", "Hide box", "Fieldstone box", "Heavy posts", "Fine wattle"])
add(S1, "roof", "round", "round", "roof", ["Thick thatch", "Peaked thatch", "Patched hide", "Green leaf", "Brush and poles"])
add(S2, "roof", "round", "round", "roof", ["Shaggy thatch", "Patchwork hide", "Reed thatch", "Spotted hide", "Bundled sticks"])
add(S1, "chiefroof", "round", "round", "roof", ["Antler crown", "Skull and hide", "Red hide mantle", "Bone crown", "Banner lodge"], True)
add(S1, "roof", "long", "long", "roof", ["Thatched gable", "Hide gable", "Leaf gable", "Moss gable", "Poled thatch gable"])
add(S2, "roof", "long", "long", "roof", ["Reed gable", "Patchwork gable", "Grass gable", "Plank and hide gable", "Stick gable"])
add(S1, "chiefroof", "long", "long", "roof", ["Antler hall", "Painted hide hall", "Red-striped hall", "Hide hall", "Banner hall"], True)
add(S1, "door", "round", "round", "door", ["Hide flap", "Antler skull", "Skull and hides", "Fur curtain", "Log frame curtain", "Stone arch"])
add(S1, "door", "long", "long", "door", ["Pole tent door", "Hide curtain", "Skull gate", "Banner frame", "Stone arch", "Spear frame"])
add(S1, "crest", "round", "round", "crest", ["Pole bundle", "Antlers", "Bull skull", "Small skull", "Crossed poles", "Feathered poles"])
add(S2, "crest", "round", "round", "crest", ["Red poles", "Thatch tuft", "Skull poles", "Crossed sticks", "Antler skull", "Feather poles", "Blue feathers"])
add(S1, "crest", "long", "long", "crest", ["Crossed beams", "Antler skull", "Bull skull", "Lashed beams", "Red banner", "Hide banner", "Feathered beams"])
add(S2, "crest", "long", "long", "crest", ["Gable poles", "Ram skull", "Lashed bundle", "Crossed rafters", "Hide shield", "Red-tied beams"])
add(S2, "hang", "round", "any", "hang", ["Hide banner", "Red hide", "Woven net", "Antler skull", "White pennant", "Horned mask", "Bone pennant", "Blue banner", "Bull skull"])
add(S2, "hang", "long", "any", "hang", ["Clan banner", "Twin banners", "Hide drape", "Small bull skull", "Painted pennant", "Blue standard", "Hide standard", "Blue clan banner"])
add(S2, "prop", "round", "any", "yard", ["Spear cairn", "Fire pit", "Wood pile", "Bone heap", "Clay pots", "Skull post", "Trophy pile", "Rune stone", "Baskets", "Bull skull"])
add(S2, "rack", "round", "any", "yard", ["Spear totem", "Drying rack", "Skull totem", "Spear rack", "Spear stand", "Tool rack", "Spear bundle", "Mask totem"])

SLOTS = ["walls", "roof", "door", "hang", "crest", "yard"]


def slug(name):
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")


def cut_all():
    """{(sheet, band, half): [Image, ...]} at art scale."""
    out = {}
    for sheet, bands in BANDS.items():
        a = keyed(os.path.join(ROOT, "assets", "source", sheet))
        w = a.shape[1]
        for band, (top, bottom, nl, nr) in bands.items():
            for half, (x0, x1), n in (("round", (0, w // 2), nl), ("long", (w // 2, w), nr)):
                sub = a[top:bottom, x0:x1]
                pieces = []
                for c0, c1 in split(sub[..., 3] > 0, n):
                    im = Image.fromarray(sub[:, c0:c1].copy())
                    im = im.crop(im.getbbox())
                    im = im.resize((max(1, im.width // SCALE), max(1, im.height // SCALE)), Image.NEAREST)
                    pieces.append(im)
                out[(sheet, band, half)] = pieces
    return out


def scaled(im, width):
    s = width / im.width
    return im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.NEAREST)


def apex(roof_canvas):
    """Canvas y of the top of the roof near its middle (where a crest sits)."""
    a = np.asarray(roof_canvas)[..., 3] > 0
    mid = CANVAS[0] // 2
    rows = np.nonzero(a[:, mid - 6:mid + 6].any(axis=1))[0]
    return int(rows.min()) if len(rows) else 40


# Parts whose red is not cloth (flames).
NO_TINT = {"fire_pit"}


def _label(mask):
    """4-connected blobs: (count, label image)."""
    labels = np.zeros(mask.shape, np.int32)
    n = 0
    for y, x in zip(*np.nonzero(mask)):
        if labels[y, x]:
            continue
        n += 1
        stack = [(y, x)]
        labels[y, x] = n
        while stack:
            cy, cx = stack.pop()
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = cy + dy, cx + dx
                if 0 <= ny < mask.shape[0] and 0 <= nx < mask.shape[1] and mask[ny, nx] and not labels[ny, nx]:
                    labels[ny, nx] = n
                    stack.append((ny, nx))
    return n, labels


REF_APEX = 40  # crests are drawn for a roof whose top is here; the game shifts them per roof


def split_tribal(canvas):
    """Separate a part's dyed cloth (the sheets paint banners red or blue) into a
    grey "tint" layer the game colors with the tribe's color. Returns (base, tint or None)."""
    a = np.asarray(canvas).astype(float)
    rgb = a[..., :3] / 255.0
    mx, mn = rgb.max(axis=-1), rgb.min(axis=-1)
    d = np.maximum(mx - mn, 1e-6)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hue = np.where(mx == r, ((g - b) / d) % 6, np.where(mx == g, (b - r) / d + 2, (r - g) / d + 4)) * 60
    sat = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0)
    opaque = a[..., 3] > 0
    red = ((hue <= 16) | (hue >= 340)) & (sat > 0.42) & (mx > 0.28)
    blue = (hue >= 195) & (hue <= 250) & (sat > 0.30) & (mx > 0.22)
    cloth = opaque & (red | blue)
    # Only patches of cloth, not stray reddish outline pixels.
    n, labels = _label(cloth)
    for i in range(1, n + 1):
        if (labels == i).sum() < 8:
            cloth[labels == i] = False
    if cloth.sum() < 6:
        return canvas, None
    shade = np.clip(mx / max(np.percentile(mx[cloth], 95), 1e-3), 0.35, 1.0)
    tint = np.zeros_like(a)
    tint[..., 0] = tint[..., 1] = tint[..., 2] = shade * 255
    tint[..., 3] = np.where(cloth, a[..., 3], 0)
    base = a.copy()
    base[cloth] = 0
    return Image.fromarray(base.astype(np.uint8)), Image.fromarray(tint.astype(np.uint8))


def place(slot, shape, im):
    """The part on its shape's canvas."""
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    cx = ANCHOR[0]
    if slot == "walls":
        p = scaled(im, WALL_W)
        canvas.alpha_composite(p, (cx - p.width // 2, WALL_BOTTOM - p.height))
    elif slot == "roof":
        p = scaled(im, ROOF_W)
        bottom = int(WALL_BOTTOM - WALL_H + WALL_H * ROOF_SINK)
        canvas.alpha_composite(p, (cx - p.width // 2, bottom - p.height))
    elif slot == "door":
        p = scaled(im, DOOR_W[shape])
        canvas.alpha_composite(p, (cx - p.width // 2, WALL_BOTTOM + 1 - p.height))
    elif slot == "crest":
        p = scaled(im, CREST_W)
        canvas.alpha_composite(p, (cx - p.width // 2, REF_APEX + int(p.height * 0.45) - p.height))
    elif slot == "hang":
        p = scaled(im, HANG_W)
        x = int(cx - WALL_W * 0.34)
        canvas.alpha_composite(p, (x - p.width // 2, WALL_BOTTOM - 4 - p.height))
    elif slot == "yard":
        p = scaled(im, YARD_W)
        x = int(cx + WALL_W * 0.62)
        canvas.alpha_composite(p, (x - p.width // 2, CANVAS[1] - 2 - p.height))
    return canvas


def main():
    cut = cut_all()
    tinted = 0
    options = {}  # (shape, slot) -> [[id, name, chief_only]]
    apexes = {}  # (shape, roof id) -> y
    out_root = os.path.join(ROOT, "assets", "sprites", "buildings")
    for sheet, band, half, i, shape, slot, name, chief_only in PARTS:
        pieces = cut[(sheet, band, half)]
        if i >= len(pieces):
            sys.exit("missing piece %s %s %s %d" % (sheet, band, half, i))
        pid = slug(name)
        canvas = place(slot, half if shape == "any" else shape, pieces[i])
        folder = os.path.join(out_root, "%s_%s_%s" % (shape, slot, pid))
        os.makedirs(folder, exist_ok=True)
        base, tint = (canvas, None) if pid in NO_TINT or slot == "walls" else split_tribal(canvas)
        base.save(os.path.join(folder, "s.png"))
        tint_folder = folder + "__tint"
        if tint is not None:
            os.makedirs(tint_folder, exist_ok=True)
            tint.save(os.path.join(tint_folder, "s.png"))
            tinted += 1
        elif os.path.isdir(tint_folder):
            shutil.rmtree(tint_folder)
        options.setdefault((shape, slot), [])
        if any(o[0] == pid for o in options[(shape, slot)]):
            sys.exit("duplicate id %s %s %s" % (shape, slot, pid))
        options[(shape, slot)].append([pid, name, chief_only])
        if slot == "roof":
            apexes[(shape, pid)] = apex(canvas)
    write_gd(options, apexes)
    print("wrote %d parts (%d with tribal-color cloth)" % (len(PARTS), tinted))


def write_gd(options, apexes):
    lines = [
        "extends RefCounted",
        "## Generated by tools/huts/build.py from Luke's hut sheets. Do not edit by hand.",
        "## Hut parts per shape and slot, as [id, name, chief_only]. Art for a part is",
        "## assets/sprites/buildings/<shape>_<slot>_<id>/s.png (shape \"any\" = both shapes), every part",
        "## on the same canvas, so the layers simply stack.",
        "",
        "",
        "## Canvas size in art pixels, the footprint center on it, and the wall width parts are scaled to.",
        "static func canvas() -> Vector2:",
        "\treturn Vector2(%d, %d)" % CANVAS,
        "",
        "",
        "static func anchor() -> Vector2:",
        "\treturn Vector2(%d, %d)" % ANCHOR,
        "",
        "",
        "static func wall_width() -> float:",
        "\treturn %.1f" % WALL_W,
        "",
        "",
        "## Crests are drawn for a roof whose top is at this canvas y; shift them by roof_apex() - this.",
        "static func crest_apex() -> float:",
        "\treturn %.1f" % REF_APEX,
        "",
        "",
        "static func options() -> Dictionary:",
        "\treturn {",
    ]
    for (shape, slot), opts in sorted(options.items()):
        rows = ", ".join('["%s", "%s", %s]' % (o[0], o[1], "true" if o[2] else "false") for o in opts)
        lines.append('\t\t"%s/%s": [%s],' % (shape, slot, rows))
    lines += ["\t}", "", "", "static func roof_apexes() -> Dictionary:", "\treturn {"]
    for (shape, pid), y in sorted(apexes.items()):
        lines.append('\t\t"%s/%s": %d.0,' % (shape, pid, y))
    lines += ["\t}", ""]
    path = os.path.join(ROOT, "scripts", "data", "building_parts.gd")
    with open(path, "w") as f:
        f.write("\n".join(lines))


if __name__ == "__main__":
    main()
