"""Cut Luke's animation template sheet (assets/source/sheet_anim_template.png):
male and female base bodies, idle + 4 walk frames in 5 views, and three
7-frame attack sequences (spear, club, axe) per sex."""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
from slice_sheet import components  # noqa: E402

SHEET = os.path.join(ROOT, "assets", "source", "sheet_anim_template.png")
VIEWS = ["s", "se", "e", "ne", "n"]  # FRONT, DOWN-RIGHT, RIGHT, UP-RIGHT, BACK (labelled correctly)
COLS = [(80, 182), (182, 288), (288, 392), (392, 497), (497, 603)]
ROWS = {
    "male": [(40, 145), (145, 232), (232, 322), (322, 413), (413, 503)],
    "female": [(555, 660), (660, 745), (745, 830), (830, 920), (920, 1012)],
}
SCALE = 2  # sheet pixels per art pixel

_cache = {}


def keyed():
    if "a" not in _cache:
        a = np.asarray(Image.open(SHEET).convert("RGBA")).copy()
        rgb = a[..., :3].astype(np.int32)
        bg = (rgb[..., 0] - rgb[..., 1] > 60) & (rgb[..., 2] - rgb[..., 1] > 60)
        # Labels and grid lines are white/pale pink; the bodies are tan with dark outlines.
        pale = (rgb.min(axis=-1) > 200)
        a[bg | pale] = 0
        _cache["a"] = a
    return _cache["a"]


def largest(sub):
    """The biggest blob in a cell (drops label letters and line scraps)."""
    boxes = components(sub[..., 3] > 0, 2)
    if not boxes:
        return None
    x0, y0, x1, y1 = max(boxes, key=lambda b: (b[2] - b[0]) * (b[3] - b[1]))
    return sub[y0:y1, x0:x1]


def frame(sex, view, row):
    """row 0 = idle, 1-4 = walk frames. Returns an RGBA array at art scale."""
    a = keyed()
    (y0, y1), (x0, x1) = ROWS[sex][row], COLS[VIEWS.index(view)]
    piece = largest(a[y0 + 3:y1 - 2, x0 + 3:x1 - 2])
    im = Image.fromarray(piece)
    im = im.resize((max(1, im.width // SCALE), max(1, im.height // SCALE)), Image.NEAREST)
    return np.asarray(im)
