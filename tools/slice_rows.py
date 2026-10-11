#!/usr/bin/env python3
"""Slice a sheet laid out in rows (one character or animal per row, its views
and poses left to right), e.g. ChatGPT's "N NE E SE S SW W NW | Idle Walk ..." sheets.

    python3 tools/slice_rows.py SHEET.png OUT_DIR --band wolf:5:148 --band bear:712:858
                                [--x-min 105] [--scale 2] [--merge 2]

Each --band is name:top:bottom in sheet pixels. Captions are dropped, the
magenta background is keyed out, and items are numbered left to right:
OUT_DIR/<name>_00.png, <name>_01.png, ... plus _rows.png to check them.

ChatGPT's direction labels are often wrong (e.g. "N" drawn facing the viewer),
so always check _rows.png and map views by what they show:
s = facing the viewer, se = down-right, e = right, ne = up-right, n = away.
"""
import argparse
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from slice_sheet import background_mask, components, is_text  # noqa: E402


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("sheet")
    ap.add_argument("out_dir")
    ap.add_argument("--band", action="append", required=True, help="name:top:bottom")
    ap.add_argument("--x-min", type=int, default=0, help="skip this many pixels on the left (row titles)")
    ap.add_argument("--scale", type=int, default=2, help="sheet pixels per art pixel")
    ap.add_argument("--merge", type=int, default=2)
    ap.add_argument("--min-size", type=int, default=14)
    args = ap.parse_args()

    img = Image.open(args.sheet).convert("RGBA")
    rgb = np.asarray(img)[..., :3].astype(np.int32)
    bg = background_mask(img, (255, 0, 255), 70)
    bg |= (rgb[..., 0] - rgb[..., 1] > 70) & (rgb[..., 2] - rgb[..., 1] > 70)
    arr = np.asarray(img).copy()
    arr[bg] = 0
    os.makedirs(args.out_dir, exist_ok=True)

    rows = []
    for band in args.band:
        name, y0, y1 = band.split(":")
        sub = arr[int(y0):int(y1), args.x_min:]
        items = []
        for bx0, by0, bx1, by1 in components(sub[..., 3] > 0, args.merge):
            piece = sub[by0:by1, bx0:bx1]
            if not is_text(piece) and max(bx1 - bx0, by1 - by0) >= args.min_size:
                items.append([bx0, by0, bx1, by1])
        items.sort()
        merged = []
        for b in items:
            if merged and b[0] < merged[-1][2] - 2:
                m = merged[-1]
                merged[-1] = [min(m[0], b[0]), min(m[1], b[1]), max(m[2], b[2]), max(m[3], b[3])]
            else:
                merged.append(b)
        paths = []
        for i, (bx0, by0, bx1, by1) in enumerate(merged):
            im = Image.fromarray(sub[by0:by1, bx0:bx1].copy())
            if args.scale > 1:
                im = im.resize((max(1, im.width // args.scale), max(1, im.height // args.scale)), Image.NEAREST)
            path = os.path.join(args.out_dir, "%s_%02d.png" % (name, i))
            im.save(path)
            paths.append(path)
        rows.append((name, paths))
        print("%-12s %d items" % (name, len(paths)))

    cell = 90
    cols = max(len(p) for _, p in rows)
    sheet = Image.new("RGBA", (cols * cell, len(rows) * cell), (60, 60, 60, 255))
    draw = ImageDraw.Draw(sheet)
    for r, (name, paths) in enumerate(rows):
        for c, path in enumerate(paths):
            im = Image.open(path)
            z = max(1, min(2, (cell - 16) // max(im.width, im.height, 1)))
            im = im.resize((im.width * z, im.height * z), Image.NEAREST)
            sheet.alpha_composite(im, (c * cell + (cell - im.width) // 2, r * cell + cell - 2 - im.height))
            draw.text((c * cell + 2, r * cell + 1), "%s %d" % (name if c == 0 else "", c), fill=(255, 220, 120, 255))
    sheet.save(os.path.join(args.out_dir, "_rows.png"))


if __name__ == "__main__":
    sys.exit(main())
