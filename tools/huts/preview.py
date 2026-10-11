#!/usr/bin/env python3
"""Render sample huts from the built kit, stacked the way the game stacks them.

    python3 tools/huts/preview.py OUT.png [--random N]
"""
import os
import random
import re
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
ART = os.path.join(ROOT, "assets", "sprites", "buildings")
ORDER = ["walls", "roof", "door", "hang", "crest", "yard"]


def parts():
    text = open(os.path.join(ROOT, "scripts", "data", "building_parts.gd")).read()
    opts = {}
    for key, body in re.findall(r'"(\w+/\w+)": \[(.*)\],', text):
        opts[key] = re.findall(r'\["(\w+)", "([^"]+)", (true|false)\]', body)
    apex = {k: float(v) for k, v in re.findall(r'"(\w+/\w+)": ([\d.]+),', text)}
    ref = float(re.search(r"crest_apex\(\) -> float:\n\treturn ([\d.]+)", text).group(1))
    return opts, apex, ref


def render(design, opts, apex, ref):
    shape = design["shape"]
    out = Image.new("RGBA", (120, 150), (0, 0, 0, 0))
    for slot in ORDER:
        pid = design.get(slot, "none")
        if pid == "none":
            continue
        owner = "any" if slot in ("hang", "yard") else shape
        im = Image.open(os.path.join(ART, "%s_%s_%s" % (owner, slot, pid), "s.png"))
        dy = 0
        if slot == "crest":
            dy = int(apex["%s/%s" % (shape, design["roof"])] - ref)
        out.alpha_composite(im, (0, dy))
    return out


def main():
    opts, apex, ref = parts()
    rng = random.Random(3)
    designs = []
    for shape in ("round", "long"):
        for i in range(6):
            d = {"shape": shape}
            for slot in ORDER:
                owner = "any" if slot in ("hang", "yard") else shape
                choices = [o[0] for o in opts["%s/%s" % (owner, slot)]]
                d[slot] = rng.choice(choices + (["none"] if slot in ("hang", "crest", "yard") else []))
            designs.append(d)
    cell = (130, 160)
    sheet = Image.new("RGBA", (cell[0] * 6, cell[1] * 2), (74, 96, 52, 255))
    for i, d in enumerate(designs):
        im = render(d, opts, apex, ref)
        sheet.alpha_composite(im, ((i % 6) * cell[0] + 5, (i // 6) * cell[1] + 5))
    sheet = sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
    sheet.save(sys.argv[1])


if __name__ == "__main__":
    main()
