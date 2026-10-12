#!/usr/bin/env python3
"""Build the tribal war paint layers: a stripe across the eyes, a band across
the chest and bands on the upper arms, following each body's own skin, in all
5 views for both bodies. The layer is grey (keeping the skin's light and shade)
and the game draws it in the tribe's color, so paint always matches the tribe.

    python3 tools/paper_doll/build_paint.py      (after tools/paper_doll/build.py)

Output: assets/sprites/clothing/<sex>_paint_tribal/<view>.png on the body's canvas.
"""
import os
import shutil
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from build import hsv, skin_mask  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
SPRITES = os.path.join(ROOT, "assets", "sprites")
VIEWS = ["s", "se", "e", "ne", "n"]
# Bands as (top, bottom) shares of the body's height from the top of the head.
FACE = {"male": (0.13, 0.18), "female": (0.12, 0.16)}
CHEST = {"male": (0.38, 0.43), "female": (0.40, 0.44)}
ARMS = {"male": (0.47, 0.52), "female": (0.48, 0.52)}


def rows(box, band):
    top, bottom = box[1], box[3]
    h = bottom - top
    return int(round(top + band[0] * h)), max(int(round(top + band[1] * h)), int(round(top + band[0] * h)) + 1)


def paint_layer(sex, view, name=None):
    """The paint for one body frame (`name` = file name without .png, default the still view)."""
    body = np.asarray(Image.open(os.path.join(SPRITES, "bodies", "body_%s__skin3" % sex, (name or view) + ".png")))
    skin = skin_mask(body)
    _, _, v = hsv(body)
    box = Image.fromarray(body).getbbox()
    mask = np.zeros(skin.shape, bool)
    if view != "n":  # the face is turned away in the back view
        y0, y1 = rows(box, FACE[sex])
        mask[y0:y1] |= skin[y0:y1]
    y0, y1 = rows(box, CHEST[sex])
    mask[y0:y1] |= skin[y0:y1]
    if view != "e":  # in side view the arm is in front of the chest band already
        y0, y1 = rows(box, ARMS[sex])
        for y in range(y0, y1):
            xs = np.nonzero(skin[y])[0]
            if len(xs) == 0:
                continue
            # The outermost skin on each side of the row is the upper arm.
            mask[y, xs.min():xs.min() + 3] |= skin[y, xs.min():xs.min() + 3]
            mask[y, xs.max() - 2:xs.max() + 1] |= skin[y, xs.max() - 2:xs.max() + 1]
    out = np.zeros(body.shape, np.uint8)
    shade = np.clip(v / max(np.percentile(v[skin], 90), 1e-3), 0.45, 1.0) * 255
    for ch in range(3):
        out[..., ch] = shade.astype(np.uint8)
    out[..., 3] = np.where(mask, 235, 0)
    return out


def main():
    for old in ("male_paint_red", "female_paint_red"):
        for skin in range(1, 7):
            shutil.rmtree(os.path.join(SPRITES, "clothing", "%s__skin%d" % (old, skin)), ignore_errors=True)
    for sex in ("male", "female"):
        folder = os.path.join(SPRITES, "clothing", "%s_paint_tribal" % sex)
        os.makedirs(folder, exist_ok=True)
        for view in VIEWS:
            Image.fromarray(paint_layer(sex, view)).save(os.path.join(folder, view + ".png"))
            for n in range(4):  # the walk frames, so the paint moves with the body
                name = "%s_walk_%d" % (view, n)
                Image.fromarray(paint_layer(sex, view, name)).save(os.path.join(folder, name + ".png"))
    print("built tribal war paint for male, female")


if __name__ == "__main__":
    main()
