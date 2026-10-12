"""The leader's bodies, taken from Luke's animation template sheet
(assets/source/sheet_anim_template.png): idle and 4 walk frames in 5 views for
both bodies, in sheet pixels. The template is a faceless, unclothed mannequin, so
this adds simple eyes, a loincloth and (female) a chest wrap, and cleans a few
stray dark pixels the sheet has on the female body.

Landmarks are measured on the idle frames (sheet pixels, top of the head = 0):
head (center x, top y, width), torso (center x, shoulder y, width), main / off
hand (x, y), waist y (loincloth band), hip y.
"""
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "anim"))
from template import frame  # noqa: E402

# ChatGPT's "UP-RIGHT" column faces down-right, so the up-right view uses the back view.
SOURCE_VIEW = {"s": "s", "se": "se", "e": "e", "ne": "n", "n": "n"}

LANDMARKS = {
    "male": dict(waist=50, hip=62, eye=13, L={
        "s": dict(head=(29, 0, 20), torso=(29, 22, 50), main=(53, 58), off=(5, 58)),
        "se": dict(head=(34, 0, 22), torso=(30, 22, 44), main=(52, 52), off=(8, 62)),
        "e": dict(head=(23, 0, 20), torso=(20, 22, 26), main=(40, 50), off=(12, 60)),
        "ne": dict(head=(31, 0, 20), torso=(30, 22, 52), main=(55, 60), off=(6, 60)),
        "n": dict(head=(31, 0, 20), torso=(30, 22, 52), main=(55, 60), off=(6, 60)),
    }),
    "female": dict(waist=52, hip=58, eye=12, chest=(31, 38), L={
        "s": dict(head=(28, 0, 19), torso=(27, 24, 40), main=(52, 58), off=(6, 60)),
        "se": dict(head=(34, 0, 20), torso=(30, 25, 36), main=(54, 50), off=(8, 60)),
        "e": dict(head=(20, 0, 19), torso=(17, 24, 22), main=(37, 50), off=(12, 58)),
        "ne": dict(head=(28, 0, 20), torso=(29, 26, 44), main=(53, 60), off=(5, 60)),
        "n": dict(head=(28, 0, 20), torso=(29, 26, 44), main=(53, 60), off=(5, 60)),
    }),
}

CLOTH = np.array([196, 184, 160], float)
CLOTH_DARK = np.array([122, 104, 84], float)
EYE = np.array([46, 28, 22], float)


def _value(a):
    return a[..., :3].astype(float).max(axis=-1) / 255.0


def head_center(a):
    """Center x of the head (the top rows of the figure)."""
    ys, xs = np.nonzero(a[..., 3] > 0)
    top = ys.min()
    sel = ys < top + 14
    return float(xs[sel].mean())


def _clean(a):
    """Stray dark pixels inside the body (sheet artifacts) take their neighbours' color."""
    out = a.copy()
    v = _value(a)
    opaque = a[..., 3] > 0
    h, w = v.shape
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            r, g, b = a[y, x, 0], a[y, x, 1], a[y, x, 2]
            stray_red = r > 150 and g < 80 and b < 90  # a few magenta-tinted specks
            if opaque[y, x] and (v[y, x] < 0.35 or stray_red):
                nb = a[y - 1:y + 2, x - 1:x + 2].reshape(-1, 4)
                bright = nb[(_value(nb[None])[0] > 0.5) & (nb[:, 3] > 0)]
                if len(bright) >= 7:
                    out[y, x, :3] = bright[:, :3].mean(axis=0)
    return out


def _paint_rows(a, y0, y1, x0, x1, color, dark):
    """Cloth over the body's own pixels in rows y0..y1 and columns x0..x1, shaded, with a dark edge."""
    h, w = a.shape[:2]
    y0, y1 = max(0, y0), min(h, y1)
    x0, x1 = max(0, x0), min(w, x1)
    body = a[..., 3] > 0
    v = _value(a)
    for y in range(y0, y1):
        xs = [x for x in range(x0, x1) if body[y, x] and v[y, x] > 0.25]
        if not xs:
            continue
        for x in xs:
            edge = y in (y0, y1 - 1) or x in (xs[0], xs[-1])
            shade = 0.82 + 0.25 * v[y, x]
            a[y, x, :3] = np.clip((dark if edge else color * shade), 0, 255)


def body_frame(sex, view, row):
    """A body frame (row 0 = idle, 1-4 = walk) in sheet pixels, with eyes and cloth.
    The template draws its walk frames a little smaller than the idle pose, so they
    are scaled up to the idle height first."""
    lm = LANDMARKS[sex]
    raw = frame(sex, SOURCE_VIEW[view], row, scale=1)
    if row:
        idle_h = frame(sex, SOURCE_VIEW[view], 0, scale=1).shape[0]
        k = idle_h / raw.shape[0]
        raw = np.asarray(Image.fromarray(raw).resize((max(1, round(raw.shape[1] * k)), idle_h), Image.NEAREST))
    a = _clean(raw.copy()).astype(float)
    a = a.copy()
    dx = head_center(a) - lm["L"][view]["head"][0] if row else 0.0
    tcx, _, tw = lm["L"][view]["torso"]
    cx = int(round(tcx + dx))
    half = tw // 2
    # Loincloth: a band at the waist and a flap hanging in front (or behind, from the back).
    waist = lm["waist"]
    _paint_rows(a, waist - 1, waist + 3, cx - half, cx + half, CLOTH, CLOTH_DARK)
    flap = 6 if view != "e" else 5
    for i, y in enumerate(range(waist + 3, waist + 15)):
        width = max(2, flap - i // 4)
        fx = cx + (4 if view == "e" else 0)
        _paint_rows(a, y, y + 1, fx - width, fx + width, CLOTH, CLOTH_DARK)
    if sex == "female":
        c0, c1 = lm["chest"]
        _paint_rows(a, c0, c1, cx - half + 2, cx + half - 2, CLOTH, CLOTH_DARK)
    # Eyes (the template's faces are blank).
    hcx = int(round(lm["L"][view]["head"][0] + dx))
    ey = lm["eye"]
    eyes = {"s": [hcx - 5, hcx + 2], "se": [hcx, hcx + 6], "e": [hcx + 5]}.get(view, [])
    for ex in eyes:
        a[ey:ey + 3, ex:ex + 2, :3] = EYE
    return np.clip(a, 0, 255).astype(np.uint8)
