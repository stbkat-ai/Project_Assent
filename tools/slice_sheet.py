#!/usr/bin/env python3
"""Slice a pixel-art concept sheet (e.g. from ChatGPT) into separate sprites.

    python3 tools/slice_sheet.py SHEET.png OUT_DIR [--bg ff00ff] [--tol 70]
                                 [--scale auto|N] [--merge 3] [--min-size 12]

What it does:
  1. Makes the flat background color transparent (default: the most common
     color along the sheet's border, usually magenta #FF00FF).
  2. Finds each separate item on the sheet. Parts of one item that are close
     together (within --merge art pixels) are kept together.
  3. Shrinks each item to its true pixel grid: AI "pixel art" is usually drawn
     with each art pixel as a block of N x N screen pixels. --scale auto
     detects N; pass a number to force it.
  4. Writes piece_00.png, piece_01.png, ... plus _index.png, a contact sheet
     with each piece's number, to check what was found.

Text labels come out as pieces too; just ignore those numbers.
Needs Pillow and numpy.
"""
import argparse
import collections
import os
import sys

import numpy as np
from PIL import Image, ImageDraw


def parse_hex(text):
    text = text.lstrip("#")
    return tuple(int(text[i:i + 2], 16) for i in (0, 2, 4))


def border_color(rgb):
    border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    counts = collections.Counter(map(tuple, border))
    return counts.most_common(1)[0][0]


def background_mask(img, bg, tol):
    arr = np.asarray(img).astype(np.int32)
    rgb, alpha = arr[..., :3], arr[..., 3]
    dist = np.sqrt(((rgb - np.array(bg)) ** 2).sum(axis=-1))
    return (dist < tol) | (alpha < 16)


def components(fg, block):
    """Bounding boxes of foreground blobs, found on a coarse grid of block x block cells."""
    h, w = fg.shape
    gh, gw = (h + block - 1) // block, (w + block - 1) // block
    padded = np.zeros((gh * block, gw * block), dtype=bool)
    padded[:h, :w] = fg
    grid = padded.reshape(gh, block, gw, block).any(axis=(1, 3))
    # Grow each occupied cell by one so nearby parts of the same item join up.
    grown = grid.copy()
    grown[1:] |= grid[:-1]
    grown[:-1] |= grid[1:]
    grown[:, 1:] |= grid[:, :-1]
    grown[:, :-1] |= grid[:, 1:]
    labels = np.full(grid.shape, -1, dtype=np.int32)
    boxes = []
    for sy, sx in zip(*np.nonzero(grown)):
        if labels[sy, sx] != -1:
            continue
        idx = len(boxes)
        stack = [(sy, sx)]
        labels[sy, sx] = idx
        y0 = y1 = sy
        x0 = x1 = sx
        while stack:
            y, x = stack.pop()
            y0, y1, x0, x1 = min(y0, y), max(y1, y), min(x0, x), max(x1, x)
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < gh and 0 <= nx < gw and grown[ny, nx] and labels[ny, nx] == -1:
                        labels[ny, nx] = idx
                        stack.append((ny, nx))
        boxes.append((x0 * block, y0 * block, min((x1 + 1) * block, w), min((y1 + 1) * block, h)))
    # Shrink each box to the real foreground pixels inside it.
    tight = []
    for x0, y0, x1, y1 in boxes:
        ys, xs = np.nonzero(fg[y0:y1, x0:x1])
        if len(xs):
            tight.append((x0 + xs.min(), y0 + ys.min(), x0 + xs.max() + 1, y0 + ys.max() + 1))
    # Top-to-bottom rows, then left to right.
    row_h = max(8, int(np.median([b[3] - b[1] for b in tight])) // 2) if tight else 8
    tight.sort(key=lambda b: (b[1] // row_h, b[0]))
    return tight


def detect_scale(arr):
    """Most common run length of identical colors, i.e. the size of one art pixel."""
    runs = collections.Counter()
    for line in list(arr) + list(arr.transpose(1, 0, 2)):
        run = 1
        for a, b in zip(line[:-1], line[1:]):
            if a[3] > 0 and np.array_equal(a, b):
                run += 1
            else:
                if run >= 2:
                    runs[run] += 1
                run = 1
    if not runs:
        return 1
    candidates = [n for n in range(2, 17) if sum(c for r, c in runs.items() if r % n == 0) > 0]
    if not candidates:
        return 1
    # Prefer the largest block size that most runs are a multiple of.
    total = sum(runs.values())
    best = 1
    for n in candidates:
        share = sum(c for r, c in runs.items() if r % n == 0) / total
        if share >= 0.6:
            best = n
    return best


def white_mask(arr):
    rgb = arr[..., :3].astype(np.int32)
    return (arr[..., 3] > 0) & (rgb.min(axis=-1) > 205) & (rgb.max(axis=-1) - rgb.min(axis=-1) < 45)


def is_text(arr):
    """True for a piece that is just a caption (mostly white letters)."""
    opaque = (arr[..., 3] > 0).sum()
    return opaque > 0 and white_mask(arr).sum() / opaque > 0.3


def strip_bottom_label(arr):
    """Cut a caption printed just under an item off the bottom of its crop."""
    h = arr.shape[0]
    counts = white_mask(arr).sum(axis=1)
    label_rows = counts >= 6
    y = h - 1
    while y >= max(0, h - 90) and not label_rows[y]:
        y -= 1
    if y < max(0, h - 90) or not label_rows[y]:
        return arr
    top, gap = y, 0
    while y > 0 and gap <= 12:
        y -= 1
        if label_rows[y]:
            top, gap = y, 0
        else:
            gap += 1
    cut = max(1, top - 3)
    out = arr[:cut].copy()
    ys, xs = np.nonzero(out[..., 3] > 0)
    if not len(xs):
        return arr
    return out[: ys.max() + 1, xs.min(): xs.max() + 1]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("sheet")
    ap.add_argument("out_dir")
    ap.add_argument("--bg", help="background color as hex, e.g. ff00ff (default: border color)")
    ap.add_argument("--tol", type=float, default=70.0, help="how far a color may be from the background and still count as background")
    ap.add_argument("--scale", default="auto", help="screen pixels per art pixel, or 'auto'")
    ap.add_argument("--merge", type=int, default=6, help="join parts closer than this many sheet pixels")
    ap.add_argument("--min-size", type=int, default=12, help="ignore specks smaller than this many sheet pixels")
    ap.add_argument("--keep-labels", action="store_true", help="keep text captions instead of removing them")
    args = ap.parse_args()

    img = Image.open(args.sheet).convert("RGBA")
    rgb = np.asarray(img)[..., :3]
    bg = parse_hex(args.bg) if args.bg else border_color(rgb)
    bgmask = background_mask(img, bg, args.tol)
    if bg[0] > 200 and bg[2] > 200 and bg[1] < 80:
        # Magenta key: also drop the pink fringe that soft edges blend into it.
        c = rgb.astype(np.int32)
        bgmask |= (c[..., 0] - c[..., 1] > 70) & (c[..., 2] - c[..., 1] > 70)
    arr = np.asarray(img).copy()
    arr[bgmask] = (0, 0, 0, 0)
    keyed = Image.fromarray(arr)

    boxes = [b for b in components(~bgmask, max(2, args.merge))
             if b[2] - b[0] >= args.min_size or b[3] - b[1] >= args.min_size]
    os.makedirs(args.out_dir, exist_ok=True)
    thumbs = []
    i = -1
    for x0, y0, x1, y1 in boxes:
        piece = keyed.crop((x0, y0, x1, y1))
        if not args.keep_labels:
            arr_piece = np.asarray(piece)
            if is_text(arr_piece):
                continue
            arr_piece = strip_bottom_label(arr_piece)
            if is_text(arr_piece) or min(arr_piece.shape[:2]) < 4:
                continue
            piece = Image.fromarray(arr_piece)
        scale = detect_scale(np.asarray(piece)) if args.scale == "auto" else int(args.scale)
        i += 1
        if scale > 1:
            piece = piece.resize((max(1, piece.width // scale), max(1, piece.height // scale)), Image.NEAREST)
        path = os.path.join(args.out_dir, "piece_%02d.png" % i)
        piece.save(path)
        thumbs.append((i, piece, scale, (x0, y0, x1, y1)))
        print("piece_%02d  %3dx%-3d  (scale %d, sheet box %d,%d-%d,%d)" % (i, piece.width, piece.height, scale, x0, y0, x1, y1))

    # Contact sheet: every piece at 4x with its number, on a grey checker.
    cell = 160
    cols = 6
    rows = max(1, (len(thumbs) + cols - 1) // cols)
    sheet = Image.new("RGBA", (cols * cell, rows * cell), (60, 60, 60, 255))
    draw = ImageDraw.Draw(sheet)
    for n, (i, piece, _, _) in enumerate(thumbs):
        cx, cy = (n % cols) * cell, (n // cols) * cell
        for yy in range(cy, cy + cell, 16):
            for xx in range(cx, cx + cell, 16):
                if (xx // 16 + yy // 16) % 2:
                    draw.rectangle((xx, yy, xx + 15, yy + 15), fill=(75, 75, 75, 255))
        zoom = max(1, min(4, (cell - 30) // max(piece.width, piece.height, 1)))
        big = piece.resize((piece.width * zoom, piece.height * zoom), Image.NEAREST)
        sheet.alpha_composite(big, (cx + (cell - big.width) // 2, cy + 20 + (cell - 20 - big.height) // 2))
        draw.text((cx + 4, cy + 4), "%02d" % i, fill=(255, 220, 120, 255))
    sheet.save(os.path.join(args.out_dir, "_index.png"))
    print("%d pieces -> %s (background %s)" % (len(thumbs), args.out_dir, "#%02x%02x%02x" % tuple(bg)))


if __name__ == "__main__":
    sys.exit(main())
