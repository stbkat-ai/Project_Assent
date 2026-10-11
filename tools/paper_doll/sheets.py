"""Cell layouts of the paper-doll sheets, and a cutter that pulls one piece out of a cell.

Each sheet maps a piece name to its rows/columns. Columns are always the 5 views
in order s, se, e, ne, n ("front", "front-3/4", "side", "back-3/4", "back").
"""
import os
import sys
from collections import deque

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))
from slice_sheet import background_mask  # noqa: E402

SOURCE = os.path.join(HERE, '..', '..', 'assets', 'source')
VIEWS = ['s', 'se', 'e', 'ne', 'n']

SHEETS = {
    # First male sheet (13 x 5 grid); used here for the shields and the two helmets.
    'male1': dict(file='sheet_paper_doll_male.png',
                  cols=[(0, 263), (263, 525), (525, 786), (786, 1048), (1048, 1311)],
                  rows={'helm_antler': (647, 740), 'hood_wolf': (740, 821), 'shield_wood': (980, 1073),
                        'shield_bone': (1073, 1197)}),
    # Second male sheet: a labeled table, bald body.
    'male2': dict(file='sheet_paper_doll_male_2.png',
                  cols=[(296, 536), (539, 776), (778, 1010), (1012, 1271), (1274, 1534)],
                  rows={'body': (41, 123), 'hair_long': (125, 183), 'hair_braids': (185, 244),
                        'hair_short': (247, 305), 'armor_hide': (359, 411), 'armor_leather': (413, 470),
                        'cloak_fur': (472, 535), 'armor_bone': (537, 608), 'skirt_hide': (610, 664),
                        'headband_bone': (666, 714), 'paint_red': (716, 769), 'club_spiked': (771, 824),
                        'axe_small': (826, 881), 'flail': (883, 947), 'sling': (949, 1022)}),
    # Female sheet: no grid lines; rows found by the gaps between pieces.
    'female': dict(file='sheet_paper_doll_female.png',
                   cols=[(270, 485), (485, 690), (690, 880), (880, 1062), (1062, 1270)],
                   rows={'body': (12, 147), 'hair_long': (150, 226), 'hair_braids': (226, 301),
                         'hair_short': (301, 369), 'armor_hide': (416, 484), 'armor_leather': (484, 555),
                         'cloak_fur': (556, 633), 'skirt_hide': (633, 702), 'headband_bone': (702, 752),
                         'hood_wolf': (752, 831), 'helm_antler': (831, 913), 'weapons_row': (913, 1018)}),
    # Standalone weapons, drawn upright for each view.
    'weapons': dict(file='sheet_weapons.png',
                    cols=[(100, 300), (400, 620), (690, 880), (930, 1120), (1260, 1430)],
                    rows={'spear_stone': (10, 246), 'spear_bone': (246, 502), 'club_spiked': (505, 745),
                          'axe_stone': (750, 1000)}),
}

_cache = {}


def sheet_array(name):
    if name not in _cache:
        img = Image.open(os.path.join(SOURCE, SHEETS[name]['file'])).convert('RGBA')
        a = np.asarray(img).copy()
        rgb = a[..., :3].astype(int)
        bg = background_mask(img, (255, 0, 255), 80) | ((rgb[..., 0] - rgb[..., 1] > 70) & (rgb[..., 2] - rgb[..., 1] > 70))
        dark_line = (rgb.max(axis=-1) < 40)  # table borders
        a[bg] = 0
        _cache[name] = (a, dark_line)
    return _cache[name][0]


def _blobs(mask):
    lab = np.full(mask.shape, -1)
    sizes = []
    for y, x in zip(*np.nonzero(mask)):
        if lab[y, x] != -1:
            continue
        k = len(sizes)
        q = deque([(y, x)])
        lab[y, x] = k
        n = 0
        while q:
            cy, cx = q.popleft()
            n += 1
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < mask.shape[0] and 0 <= nx < mask.shape[1] and mask[ny, nx] and lab[ny, nx] == -1:
                        lab[ny, nx] = k
                        q.append((ny, nx))
        sizes.append(n)
    return lab, sizes


def cut(sheet, piece, view, pick='all', inset=3):
    """The piece in one cell, keyed and trimmed. pick: 'all' keeps every sizeable
    blob; 'left' / 'right' keeps the left- or right-most large item (cells with two drawings)."""
    s = SHEETS[sheet]
    a = sheet_array(sheet)
    x0, x1 = s['cols'][VIEWS.index(view)]
    y0, y1 = s['rows'][piece]
    cell = a[y0 + inset:y1 - inset, x0 + inset:x1 - inset].copy()
    mask = cell[..., 3] > 0
    lab, sizes = _blobs(mask)
    if not sizes:
        return None
    big = max(sizes)
    keep_ids = [k for k, n in enumerate(sizes) if n >= max(25, big * 0.03)]
    if pick in ('left', 'right'):
        large = [k for k in keep_ids if sizes[k] >= big * 0.3]
        cx = {k: np.nonzero(lab == k)[1].mean() for k in large}
        chosen = min(cx, key=cx.get) if pick == 'left' else max(cx, key=cx.get)
        keep_ids = [chosen]
    keep = np.isin(lab, keep_ids)
    cell[~keep] = 0
    ys, xs = np.nonzero(keep)
    return cell[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
