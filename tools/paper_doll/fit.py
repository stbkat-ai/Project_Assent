import sys
sys.path.insert(0, ''+__import__('os').path.dirname(__import__('os').path.abspath(__file__))+'')
import numpy as np
from PIL import Image
from cut import cell, VIEWS

# Landmarks on each body view (sheet pixels, body crop coords):
# head: (center x, top y, width); torso: (center x, top y, width); main hand / off hand: (x, y)
L = {
    's':  dict(head=(39, 0, 30), torso=(39, 40, 44), main=(66, 82), off=(12, 82)),
    'se': dict(head=(45, 0, 30), torso=(40, 40, 42), main=(64, 72), off=(12, 84)),
    'e':  dict(head=(30, 0, 28), torso=(30, 40, 36), main=(48, 68), off=(14, 64)),
    'ne': dict(head=(36, 0, 30), torso=(36, 40, 46), main=(68, 78), off=(8, 74)),
    'n':  dict(head=(38, 0, 30), torso=(38, 40, 50), main=(70, 82), off=(6, 82)),
}
# How each sheet row is fitted onto the body: (anchor kind, width factor, extra params)
FIT = {
    'armor_hide':    ('torso', 1.20, dict(dy=-4)),
    'armor_leather': ('torso', 1.10, dict(dy=-3)),
    'cloak_fur':     ('torso', 1.35, dict(dy=-7)),
    'hair_long':     ('head', 1.30, dict(dy=-2)),
    'hair_braids':   ('head', 1.25, dict(dy=-2)),
    'hood_wolf':     ('head', 1.55, dict(dy=-7)),
    'helm_antler':   ('head', 1.90, dict(dy=-14)),
    'spear':         ('main', 1.00, dict(length=1.05)),
    'spear_bone':    ('main', 1.00, dict(length=1.05)),
    'shield_wood':   ('off', 1.00, dict(height=0.40, dy=-6)),
    'shield_bone':   ('off', 1.00, dict(height=0.44, dy=-6)),
}
PAD = 60  # room around the body for spears, antlers, shields


def body_canvas(view):
    b = cell('body', view)
    h, w = b.shape[:2]
    canvas = np.zeros((h + PAD, w + 2 * PAD, 4), np.uint8)
    canvas[PAD:PAD + h, PAD:PAD + w] = b
    return canvas, (PAD, PAD), (w, h)


def place(canvas_shape, piece, x, y, scale):
    """Scale `piece` (nearest) and paste its top-left at (x, y) on an empty canvas."""
    im = Image.fromarray(piece)
    im = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.NEAREST)
    out = Image.new('RGBA', (canvas_shape[1], canvas_shape[0]), (0, 0, 0, 0))
    out.alpha_composite(im, (int(round(x)), int(round(y))))
    return np.asarray(out)


def fit_layer(name, view):
    canvas, (ox, oy), (bw, bh) = body_canvas(view)
    lm = L[view]
    kind, factor, p = FIT[name]
    piece = cell(name, view)
    ph, pw = piece.shape[:2]
    if kind in ('torso', 'head'):
        cx, top, width = lm[kind]
        s = width * factor / pw
        x = ox + cx - pw * s / 2
        y = oy + top + p.get('dy', 0)
        if kind == 'head':
            y = oy + top + p.get('dy', 0)
    elif kind == 'main':
        s = bh * p['length'] / np.hypot(pw, ph)
        hx, hy = lm['main']
        x = ox + hx - pw * s / 2
        y = oy + hy - ph * s / 2
    else:
        s = bh * p['height'] / ph
        hx, hy = lm['off']
        x = ox + hx - pw * s / 2
        y = oy + hy + p.get('dy', 0) - ph * s / 2
    return place(canvas.shape, piece, x, y, s)


def stack(view, names):
    canvas, _, _ = body_canvas(view)
    out = Image.fromarray(canvas)
    for n in names:
        out.alpha_composite(Image.fromarray(fit_layer(n, view)))
    return out
