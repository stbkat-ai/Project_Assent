#!/usr/bin/env python3
"""Put sliced sprites into the game's asset folder, lined up consistently.

    python3 tools/place_sprite.py CATEGORY PIECE s=a.png se=b.png e=c.png ne=d.png n=e.png
                                  [--anim walk --frame 0] [--canvas 32x48] [--flip VIEW ...]

Every view is placed on the same canvas size with its feet at the bottom
center, which is how the game anchors sprites. The canvas defaults to the
largest view (rounded up to an even size).

Output: assets/sprites/CATEGORY/PIECE/<view>.png, or <view>_<anim>_<frame>.png
with --anim. Categories the game reads: bodies, clothing, hair, gear, beasts,
scenery (see assets/README.md).
"""
import argparse
import os
import sys

from PIL import Image

VIEWS = ("s", "se", "e", "ne", "n")
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("category")
    ap.add_argument("piece")
    ap.add_argument("views", nargs="+", help="view=path pairs, e.g. s=out/piece_03.png")
    ap.add_argument("--anim", default="")
    ap.add_argument("--frame", type=int, default=0)
    ap.add_argument("--canvas", help="WxH, e.g. 32x48")
    ap.add_argument("--flip", nargs="*", default=[], help="views to mirror (if the sheet drew them facing the wrong way)")
    args = ap.parse_args()

    images = {}
    for pair in args.views:
        view, _, path = pair.partition("=")
        if view not in VIEWS:
            sys.exit("unknown view %r (use %s)" % (view, ", ".join(VIEWS)))
        img = Image.open(path).convert("RGBA")
        box = img.getbbox()
        if box:
            img = img.crop(box)
        if view in args.flip:
            img = img.transpose(Image.FLIP_LEFT_RIGHT)
        images[view] = img

    if args.canvas:
        cw, ch = (int(v) for v in args.canvas.lower().split("x"))
    else:
        cw = max(i.width for i in images.values())
        ch = max(i.height for i in images.values())
        cw += cw % 2
        ch += ch % 2

    out_dir = os.path.normpath(os.path.join(ROOT, args.category, args.piece))
    os.makedirs(out_dir, exist_ok=True)
    for view, img in images.items():
        if img.width > cw or img.height > ch:
            sys.exit("%s view is %dx%d, larger than the %dx%d canvas" % (view, img.width, img.height, cw, ch))
        canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        canvas.alpha_composite(img, ((cw - img.width) // 2, ch - img.height))
        name = view if not args.anim else "%s_%s_%d" % (view, args.anim, args.frame)
        path = os.path.join(out_dir, name + ".png")
        canvas.save(path)
        print("wrote", os.path.relpath(path))


if __name__ == "__main__":
    sys.exit(main())
