#!/usr/bin/env python3
"""Animated preview (GIF) of the leader walking and attacking, drawn the way
scripts/render/figure.gd draws it (whole-body walk frames + attack keyframes).

    python3 tools/anim/preview.py OUT.gif
"""
import math
import os
import re
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
SP = os.path.join(ROOT, "assets", "sprites")
FORWARD = {"s": (0, 0.6), "se": (0.8, 0.4), "e": (1, 0), "ne": (0.8, -0.4), "n": (0, -0.6)}


def read_poses():
    text = open(os.path.join(ROOT, "scripts", "render", "figure.gd")).read()
    block = text[text.index("const ATTACK_POSES"):text.index("## The attacks a weapon kind")]
    poses = {}
    for name, body in re.findall(r'"(\w+)": \[(.*?)\],\n\t(?:#|\})', block + "\n\t}", re.S):
        poses[name] = [[float(x) for x in k.split(",")] for k in re.findall(r"\[([-\d., ]+)\]", body)]
    return poses


def rig():
    text = open(os.path.join(ROOT, "scripts", "data", "rig.gd")).read()
    out = {}
    for sex, body in re.findall(r'"(male|female)": \{(.*?)\n\t\}', text, re.S):
        out[sex] = {v: (float(x), float(y)) for v, x, y in re.findall(r'"(\w+)": \{"main_hand": Vector2\(([-\d.]+), ([-\d.]+)\)', body)}
    text = open(os.path.join(ROOT, "scripts", "data", "walk_rig.gd")).read()
    legs = {}
    for sex, body in re.findall(r'"(male|female)": \{(.*?)\n\t\}', text, re.S):
        legs[sex] = {v: int(l) for v, l in re.findall(r'"(\w+)": \{"offsets": \[.*?\], "lunge": (\d+)\}', body)}
    return out, legs


def pose_at(keys, t):
    for i in range(1, len(keys)):
        if t <= keys[i][0]:
            a, b = keys[i - 1], keys[i]
            k = (t - a[0]) / max(b[0] - a[0], 1e-4)
            k = k * k * (3 - 2 * k)
            return [a[j] + (b[j] - a[j]) * k for j in range(1, 6)]
    return [0, 0, 0, 0, 0]


def draw(sex, skin, view, weapon, walk_phase=None, attack=None, t=0.0, poses=None, hands=None, legs=None):
    W, H = 110, 90
    feet = (W // 2, H - 8)
    canvas = Image.new("RGBA", (W, H), (52, 70, 40, 255))
    body = Image.open(os.path.join(SP, "bodies", "body_%s__%s" % (sex, skin), view + ".png"))
    fw = FORWARD[view]
    angle = push = lean = dip = lift = 0.0
    if attack:
        angle, push, lean, dip, lift = pose_at(poses[attack], t)
        angle *= 0.35 + 0.65 * abs(fw[0])
    lunge = legs[sex][view]
    frames = [os.path.join(SP, "bodies", "body_%s__%s" % (sex, skin), "%s_walk_%d.png" % (view, n)) for n in range(4)]
    if attack and attack != "shoot" and 0.45 <= t <= 0.85:
        body = Image.open(frames[lunge])
    elif walk_phase is not None:
        body = Image.open(frames[int(walk_phase / (math.pi / 2)) % 4])
    up = (fw[0] * lean, fw[1] * lean + dip)

    def place(img, shift=(0, 0)):
        x = feet[0] - img.width // 2 + round(shift[0])
        y = feet[1] - img.height + round(shift[1])
        canvas.alpha_composite(img, (x, y))

    place(body, up)
    wpath = os.path.join(SP, "gear", "%s_%s" % (sex, weapon), view + ".png")
    w = Image.open(wpath)
    hx, hy = hands[sex][view]
    # Pivot in weapon image coords: sprite drawn bottom-center at feet.
    px, py = w.width / 2 + hx, w.height + hy
    rot = w.rotate(-math.degrees(angle), center=(px, py), resample=Image.NEAREST)
    place(rot, (up[0] + fw[0] * push, up[1] + fw[1] * push - lift))
    return canvas


def main():
    poses = read_poses()
    hands, legs = rig()
    frames = []
    scenes = [("male", "skin3", "e", "club", "swing"), ("male", "skin3", "se", "spear", "thrust"),
              ("female", "skin2", "e", "stone_axe", "swing"), ("female", "skin2", "s", "spear", "thrust")]
    for t_i in range(24):
        row = []
        for sex, skin, view, weapon, kind in scenes:
            row.append(draw(sex, skin, view, weapon, walk_phase=t_i * 0.42, poses=poses, hands=hands, legs=legs))
        for sex, skin, view, weapon, kind in scenes:
            t = (t_i % 12) / 11.0
            row.append(draw(sex, skin, view, weapon, attack=kind, t=t, poses=poses, hands=hands, legs=legs))
        sheet = Image.new("RGBA", (110 * 4, 90 * 2))
        for i, im in enumerate(row):
            sheet.alpha_composite(im, ((i % 4) * 110, (i // 4) * 90))
        frames.append(sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).convert("RGB"))
    frames[0].save(sys.argv[1], save_all=True, append_images=frames[1:], duration=60, loop=0)


if __name__ == "__main__":
    main()
