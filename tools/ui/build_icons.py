#!/usr/bin/env python3
"""Cut the weapon icons and projectiles out of Luke's soldier weapon sheet
(assets/source/sheet_soldier_weapons_anim.png, top row).

    python3 tools/ui/build_icons.py

Icons -> assets/ui/icons/weapon_<name>.png (used on the soldier designer's tiles).
Projectiles -> assets/sprites/projectiles/<name>/e.png, turned to point right (+x)
so the game can rotate them to their flight direction.
"""
import math
import os

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
SHEET = os.path.join(ROOT, "assets", "source", "sheet_soldier_weapons_anim.png")

ICONS = {  # name: (x0, y0, x1, y1) inside the icon's cell, above its caption
    "spear": (15, 33, 152, 98), "club": (158, 33, 282, 98), "axe": (286, 33, 412, 98),
    "bow": (420, 33, 543, 98), "throwing_spear": (551, 33, 668, 98), "sling": (675, 33, 800, 98),
    "knife": (806, 33, 918, 98), "long_knife": (925, 33, 1045, 98),
}
PROJECTILES = {
    "arrow": (1064, 62, 1185, 120), "throwing_spear": (1190, 62, 1300, 120),
    "sling_stone": (1305, 62, 1408, 120), "knife": (1413, 62, 1528, 120),
}
SCALE = 2  # sheet pixels per art pixel


def cut(box):
    """The item in `box` with the dark cell background made transparent."""
    a = np.asarray(Image.open(SHEET).convert("RGBA").crop(box)).copy()
    rgb = a[..., :3].astype(int)
    bg = np.median(np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]]), axis=0)
    near = np.abs(rgb - bg).sum(axis=-1) < 40
    a[near] = 0
    im = Image.fromarray(a)
    # Drop stray specks: keep pixels with enough opaque neighbours.
    alpha = np.asarray(im)[..., 3] > 0
    pad = np.pad(alpha, 1)
    count = sum(np.roll(np.roll(pad, dy, 0), dx, 1) for dy in (-1, 0, 1) for dx in (-1, 0, 1))[1:-1, 1:-1]
    a = np.asarray(im).copy()
    a[count < 3] = 0
    # Keep the item itself: the biggest connected blob (drops cell-border slivers).
    alpha = (a[..., 3] > 0).astype(np.uint8)
    n, labels = _label(alpha)
    if n > 1:
        sizes = [(labels == i).sum() for i in range(1, n + 1)]
        biggest = 1 + int(np.argmax(sizes))
        keep = labels == biggest
        # Also keep nearby parts of the same item (e.g. a sling's cord and stone).
        ys, xs = np.nonzero(keep)
        y0, y1, x0, x1 = ys.min() - 6, ys.max() + 6, xs.min() - 6, xs.max() + 6
        for i in range(1, n + 1):
            yy, xx = np.nonzero(labels == i)
            if yy.min() >= y0 and yy.max() <= y1 and xx.min() >= x0 and xx.max() <= x1 and (xx.max() - xx.min() > 2):
                keep |= labels == i
        a[~keep] = 0
    im = Image.fromarray(a)
    return im.crop(im.getbbox())


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


def point_right(im):
    """Rotate a long item so its long axis is level and its tip (the upper-right end) points right."""
    ys, xs = np.nonzero(np.asarray(im)[..., 3] > 0)
    if len(xs) < 4:
        return im
    cx, cy = xs.mean(), ys.mean()
    cov = np.cov(np.vstack([xs - cx, ys - cy]))
    vals, vecs = np.linalg.eigh(cov)
    if vals[1] < vals[0] * 2.0:
        return im  # round (a sling stone)
    vx, vy = vecs[:, 1]
    if vx < 0:
        vx, vy = -vx, -vy
    angle = math.degrees(math.atan2(vy, vx))  # image y points down
    out = im.rotate(angle, resample=Image.NEAREST, expand=True)
    return out.crop(out.getbbox())


def shrink(im):
    return im.resize((max(1, im.width // SCALE), max(1, im.height // SCALE)), Image.NEAREST)


def main():
    icon_dir = os.path.join(ROOT, "assets", "ui", "icons")
    os.makedirs(icon_dir, exist_ok=True)
    for name, box in ICONS.items():
        cut(box).save(os.path.join(icon_dir, "weapon_%s.png" % name))
    for name, box in PROJECTILES.items():
        folder = os.path.join(ROOT, "assets", "sprites", "projectiles", name)
        os.makedirs(folder, exist_ok=True)
        shrink(point_right(cut(box))).save(os.path.join(folder, "e.png"))
    print("wrote %d icons, %d projectiles" % (len(ICONS), len(PROJECTILES)))


if __name__ == "__main__":
    main()
