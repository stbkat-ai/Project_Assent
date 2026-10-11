#!/usr/bin/env python3
"""Render outfit previews from the built sprites: python3 tools/paper_doll/preview.py OUT.png"""
import os
import sys
from PIL import Image

A = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'assets', 'sprites')
VIEWS = ['s', 'se', 'e', 'ne', 'n']
ROWS = [
    ('male', 'skin3', ['hair/male_short__brown', 'gear/male_hide_wrap', 'gear/male_spear', 'gear/male_hide_shield']),
    ('male', 'skin5', ['clothing/male_paint_red__skin5', 'gear/male_leather_armor', 'clothing/male_fur_cloak', 'hair/male_long__black', 'gear/male_club']),
    ('male', 'skin1', ['clothing/male_hide_skirt', 'gear/male_bone_hide', 'clothing/male_antler_skull', 'gear/male_stone_axe', 'gear/male_bone_shield']),
    ('female', 'skin2', ['hair/female_long__auburn', 'gear/female_hide_wrap', 'gear/female_spear', 'gear/female_hide_shield']),
    ('female', 'skin4', ['clothing/female_hide_skirt', 'gear/female_leather_armor', 'hair/female_braids__black', 'clothing/female_bone_headband', 'gear/female_club']),
    ('female', 'skin6', ['gear/female_hide_wrap', 'clothing/female_fur_cloak', 'clothing/female_animal_hood', 'gear/female_stone_axe', 'gear/female_bone_shield']),
]
HELD = ('spear', 'shield', 'club', 'axe', 'flail', 'sling')
sheet = Image.new('RGBA', (5 * 130, len(ROWS) * 110), (74, 102, 51, 255))
for r, (sex, skin, layers) in enumerate(ROWS):
    for c, v in enumerate(VIEWS):
        base = Image.open(f'{A}/bodies/body_{sex}__{skin}/{v}.png')
        held = [l for l in layers if any(h in l for h in HELD)]
        worn = [l for l in layers if l not in held]
        order = (held + ['BODY'] + worn) if v in ('n', 'ne') else (['BODY'] + worn + held)
        im = Image.new('RGBA', base.size, (0, 0, 0, 0))
        for l in order:
            im.alpha_composite(base if l == 'BODY' else Image.open(f'{A}/{l}/{v}.png'))
        im = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
        sheet.alpha_composite(im, (c * 130 + (130 - im.width) // 2, r * 110 + 106 - im.height))
sheet.save(sys.argv[1] if len(sys.argv) > 1 else 'preview.png')
