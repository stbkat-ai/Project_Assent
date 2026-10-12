#!/usr/bin/env python3
"""Render the whole wilderness map as the game shows it (ground, solid objects,
caches, camp and clearing), optionally with blocked squares tinted.

    python3 tools/map/preview.py OUT.png [--blocked] [--scale 0.4]
"""
import os
import re
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))


def main():
    out = sys.argv[1]
    show_blocked = "--blocked" in sys.argv
    scale = float(sys.argv[sys.argv.index("--scale") + 1]) if "--scale" in sys.argv else 0.4
    text = open(os.path.join(ROOT, "scripts", "data", "wilderness_map.gd")).read()
    img = Image.open(os.path.join(ROOT, "assets", "maps", "wilderness_ground.jpg")).convert("RGBA")
    objs = re.findall(r'\["([\w]+)", "(tree|rock|bush|plant)", (\d+), (\d+), (true|false)\]', text)
    for piece, kind, x, y, m in sorted(objs, key=lambda o: int(o[3])):
        spr = Image.open(os.path.join(ROOT, "assets", "sprites", "scenery", piece, "s.png")).convert("RGBA")
        if m == "true":
            spr = spr.transpose(Image.FLIP_LEFT_RIGHT)
        img.alpha_composite(spr, (int(x) - spr.width // 2, int(y) - spr.height))
    d = ImageDraw.Draw(img)
    if show_blocked:
        solid = re.search(r"static func solid\(\) -> Array:\n\treturn \[(.*?)\]", text, re.S).group(1)
        rows = re.findall(r'"([#.]+)"', solid)
        overlay = Image.new("RGBA", img.size)
        od = ImageDraw.Draw(overlay)
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch == "#":
                    od.rectangle([x * 32, y * 32, x * 32 + 31, y * 32 + 31], fill=(255, 0, 0, 70))
        img.alpha_composite(overlay)
    for cid, name, x, y, kind, value, look in re.findall(r'\["(\w+)", "([^"]+)", (\d+), (\d+), "(\w+)", "(\w+)", "(\w+)"\]', text):
        d.ellipse([int(x) * 32 + 4, int(y) * 32 + 4, int(x) * 32 + 28, int(y) * 32 + 28], outline=(255, 215, 0), width=4)
    for name, x, y, guard in re.findall(r'\["(\w+)", (\d+), (\d+), (true|false)\]', text):
        col = (255, 60, 60) if name in ("wolf", "alpha_wolf", "boar", "bear", "caveman") else (90, 160, 255)
        d.ellipse([int(x) * 32 + 10, int(y) * 32 + 10, int(x) * 32 + 22, int(y) * 32 + 22], fill=col)
    img = img.resize((int(img.width * scale), int(img.height * scale)), Image.LANCZOS)
    img.convert("RGB").save(out)


if __name__ == "__main__":
    main()
