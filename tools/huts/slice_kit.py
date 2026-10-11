#!/usr/bin/env python3
"""Cut a ChatGPT building-kit sheet (rows of parts, round huts on the left half,
long huts on the right) into separate pieces.

    python3 tools/huts/slice_kit.py SHEET.png OUT_DIR name:top:bottom:left_count:right_count ...

Pieces in one row often touch, so each half of a row is split into the given
number of pieces at the emptiest columns between them. Output:
OUT_DIR/<name>_<side>_<n>.png (side = round | long) at art scale (sheet / 2),
plus _index.png to check them.
"""
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

SCALE = 2


def keyed(path):
    img = Image.open(path).convert("RGBA")
    a = np.asarray(img).copy()
    rgb = a[..., :3].astype(np.int32)
    bg = (rgb[..., 0] - rgb[..., 1] > 60) & (rgb[..., 2] - rgb[..., 1] > 60)
    a[bg] = 0
    mid = a.shape[1] // 2
    a[:, mid - 4:mid + 4] = 0  # the divider line between the two halves
    return a


def split(fg, count):
    """Column ranges of `count` pieces in a band. Pieces are first separated at
    empty columns; the closest neighbours are joined (an item made of loose
    parts) or the widest piece is cut at its emptiest column (touching items)
    until there are `count`."""
    cols = fg.sum(axis=0).astype(float)
    segs = []
    start = None
    for x, c in enumerate(cols):
        if c > 0 and start is None:
            start = x
        elif c == 0 and start is not None:
            segs.append([start, x])
            start = None
    if start is not None:
        segs.append([start, len(cols)])
    segs = [s for s in segs if s[1] - s[0] >= 2 or cols[s[0]:s[1]].sum() > 3]
    smooth = np.convolve(cols, np.ones(5) / 5, mode="same")
    while len(segs) > count:
        gaps = [segs[i + 1][0] - segs[i][1] for i in range(len(segs) - 1)]
        i = int(np.argmin(gaps))
        segs[i:i + 2] = [[segs[i][0], segs[i + 1][1]]]
    while len(segs) < count:
        widths = [s[1] - s[0] for s in segs]
        i = int(np.argmax(widths))
        a, b = segs[i]
        lo, hi = a + (b - a) // 4, b - (b - a) // 4
        c = lo + int(np.argmin(smooth[lo:hi]))
        segs[i:i + 1] = [[a, c], [c, b]]
    return [tuple(s) for s in segs]


def main():
    sheet, out = sys.argv[1], sys.argv[2]
    a = keyed(sheet)
    w = a.shape[1]
    os.makedirs(out, exist_ok=True)
    rows = []
    for spec in sys.argv[3:]:
        name, top, bottom, nl, nr = spec.split(":")
        top, bottom = int(top), int(bottom)
        for side, (sx0, sx1), n in (("round", (0, w // 2), int(nl)), ("long", (w // 2, w), int(nr))):
            if n == 0:
                continue
            band = a[top:bottom, sx0:sx1]
            fg = band[..., 3] > 0
            paths = []
            for i, (c0, c1) in enumerate(split(fg, n)):
                piece = band[:, c0:c1].copy()
                # Keep only pixels of this piece (drop slivers of neighbours at the edges).
                im = Image.fromarray(piece)
                box = im.getbbox()
                if box is None:
                    continue
                im = im.crop(box)
                im = im.resize((max(1, im.width // SCALE), max(1, im.height // SCALE)), Image.NEAREST)
                path = os.path.join(out, "%s_%s_%d.png" % (name, side, i))
                im.save(path)
                paths.append(path)
            rows.append(("%s %s" % (name, side), paths))
    cell = 96
    cols = max(len(p) for _, p in rows)
    index = Image.new("RGBA", (cols * cell, len(rows) * cell), (60, 60, 60, 255))
    d = ImageDraw.Draw(index)
    for r, (label, paths) in enumerate(rows):
        for c, p in enumerate(paths):
            im = Image.open(p)
            z = min(1.0, (cell - 14) / max(im.width, im.height))
            im = im.resize((max(1, int(im.width * z)), max(1, int(im.height * z))), Image.NEAREST)
            index.alpha_composite(im, (c * cell + (cell - im.width) // 2, r * cell + cell - 2 - im.height))
            d.text((c * cell + 2, r * cell + 1), ("%s " % label if c == 0 else "") + str(c), fill=(255, 220, 120, 255))
    index.save(os.path.join(out, "_index.png"))
    print("wrote", sum(len(p) for _, p in rows), "pieces")


if __name__ == "__main__":
    main()
