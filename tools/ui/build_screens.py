#!/usr/bin/env python3
"""Turn Luke's ChatGPT creator-screen mockups into the game's screen art.

    python3 tools/ui/build_screens.py      (needs opencv-contrib-python-headless)

The mockups (assets/source/ui_leader_mockup.png, ui_hut_mockup.png, ui_soldier_mockup.png) are full
screens with a sample leader / hut and sample options painted in. The game
keeps the painted frame, title, tabs and buttons, and draws everything that
changes on top, so this tool:
  - paints the sample leader / hut out of the scene (texture-aware inpainting),
  - clears the options panel and the view bar (refilled with the panel's slate),
  - turns the highlighted first tab (BODY / SHAPE) into a plain tab, since the
    game highlights whichever tab is open.
Output: assets/ui/leader_screen.png, assets/ui/hut_screen.png (same 1536 x 1024
layout as the mockups; scripts/ui/creator_screen.gd holds the coordinates).
"""
import os

import cv2
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
SRC = os.path.join(ROOT, "assets", "source")
OUT = os.path.join(ROOT, "assets", "ui")

SCREENS = {
    "leader": dict(
        stage=(320, 125, 905, 735),  # x0, y0, x1, y1 of the scene
        subject=(540, 230, 755, 662),  # where the sample figure is
        subject_kind="skin",
        clear=[(918, 105, 1498, 722), (400, 776, 1072, 922)],  # options panel, view strip
        slate=(965, 548, 1420, 655),  # an empty bit of panel to fill with
        tab=(45, 145, 302, 237), plain_tab=(45, 250, 302, 332),
        fill_bands=None,
    ),
    "hut": dict(
        stage=(312, 140, 990, 742),
        subject=(378, 228, 908, 640),
        subject_kind="hut",
        clear=[(1018, 48, 1492, 822), (262, 787, 900, 922)],
        slate=None,  # borrowed from the leader screen
        tab=(27, 143, 285, 237), plain_tab=(27, 250, 285, 340),
        fill_bands=[(400, 742), (140, 520)],  # ground first, then trees and river
    ),
    "soldier": dict(
        stage=(560, 125, 1062, 705),
        subject=None,
        subject_kind="boxes",
        # The sample soldier: spear, body, shield (x0, y0, x1, y1 boxes, rounded off).
        boxes=[(650, 160, 712, 625), (668, 285, 842, 655), (790, 360, 885, 535), (690, 600, 850, 660)],
        clear=[(220, 145, 553, 493), (1076, 108, 1500, 698), (234, 742, 692, 862), (709, 742, 1222, 862),
               (1244, 748, 1500, 860)],
        slate=None,
        tab=(38, 122, 198, 195), plain_tab=(38, 205, 198, 272),
        fill_bands=[(470, 705), (125, 520)],  # ground and stones first, then trees, lake and mountains
    ),
}


def subject_mask(img, box, kind, boxes=None):
    if kind == "boxes":
        m = np.zeros(img.shape[:2], np.uint8)
        for bx0, by0, bx1, by1 in boxes:
            cv2.rectangle(m, (bx0, by0), (bx1, by1), 255, -1)
        return cv2.dilate(m, np.ones((7, 7), np.uint8))
    x0, y0, x1, y1 = box
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    sub = hsv[y0:y1, x0:x1]
    if kind == "skin":
        sel = (sub[..., 0] >= 8) & (sub[..., 0] <= 24) & (sub[..., 1] > 90) & (sub[..., 2] > 120)
        close, grow = 15, 9
    else:
        green = (sub[..., 0] >= 30) & (sub[..., 0] <= 95) & (sub[..., 1] > 60)
        sel = ~green & (sub[..., 0] <= 95) & (sub[..., 1] > 40)
        close, grow = 21, 9
    m = np.zeros(img.shape[:2], np.uint8)
    m[y0:y1, x0:x1] = sel.astype(np.uint8) * 255
    n, lab, st, _ = cv2.connectedComponentsWithStats(m)
    m = (lab == 1 + np.argmax(st[1:, cv2.CC_STAT_AREA])).astype(np.uint8) * 255
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((close, close), np.uint8))
    m = cv2.dilate(m, np.ones((grow, grow), np.uint8))
    cnts, _ = cv2.findContours(m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    cv2.drawContours(m, cnts, -1, 255, -1)
    return m


def inpaint(img, mask, box, rows=None):
    """Shift-map inpainting at the art's pixel size, using only scene pixels from `box`."""
    x0, y0, x1, y1 = box
    c = img[y0:y1, x0:x1].copy()
    cm = mask[y0:y1, x0:x1].copy()
    if rows:
        keep = np.zeros_like(cm)
        keep[rows[0] - y0:rows[1] - y0] = 1
        cm = cm * keep
    h, w = cm.shape
    small = cv2.resize(c, (w // 2, h // 2), interpolation=cv2.INTER_AREA)
    ms = cv2.resize(cm, (w // 2, h // 2), interpolation=cv2.INTER_NEAREST)
    out = np.zeros_like(small)
    cv2.xphoto.inpaint(small, 255 - ms, out, cv2.xphoto.INPAINT_SHIFTMAP)
    big = cv2.resize(out, (w, h), interpolation=cv2.INTER_NEAREST)
    c[cm > 0] = big[cm > 0]
    img = img.copy()
    img[y0:y1, x0:x1] = c
    mask = mask.copy()
    mm = mask[y0:y1, x0:x1]
    mm[cm > 0] = 0
    mask[y0:y1, x0:x1] = mm
    return img, mask


def tile(img, box, patch):
    x0, y0, x1, y1 = box
    ph, pw = patch.shape[:2]
    for y in range(y0, y1, ph):
        for x in range(x0, x1, pw):
            h, w = min(ph, y1 - y), min(pw, x1 - x)
            img[y:y + h, x:x + w] = patch[:h, :w]


def plain_tab(img, tab, plain):
    """The highlighted tab redrawn as a plain one: its icon and label keep their
    shape but turn bone-white, and the gold plate becomes the plain tabs' slate."""
    x0, y0, x1, y1 = tab
    px0, py0, px1, py1 = plain
    sel = img[y0:y1, x0:x1].astype(float)
    ref = img[py0:py1, px0:px1]
    hsv = cv2.cvtColor(img[y0:y1, x0:x1], cv2.COLOR_BGR2HSV).astype(float)
    bright = (hsv[..., 2] > 170) & (hsv[..., 1] > 60)  # the gold icon and letters
    # Slate plate: the plain tab's own pixels where it has no icon/letters, stretched to size.
    plate = cv2.resize(ref, (x1 - x0, y1 - y0), interpolation=cv2.INTER_NEAREST).astype(float)
    ref_hsv = cv2.cvtColor(plate.astype(np.uint8), cv2.COLOR_BGR2HSV)
    ref_ink = ref_hsv[..., 2] > 150
    lum = sel.mean(axis=2, keepdims=True)
    slate = np.median(plate[~ref_ink], axis=0)
    base = slate * np.clip(lum / max(np.median(lum[~bright]), 1), 0.5, 1.6)
    out = np.where(ref_ink[..., None], slate, plate) * 0.6 + base * 0.4
    bone = np.array([196, 214, 226], float)  # BGR
    out[bright] = bone * np.clip(hsv[..., 2][bright] / 230.0, 0.6, 1.1)[:, None]
    # The gold border becomes the plain tabs' dark border.
    ring = np.ones(out.shape[:2], bool)
    ring[7:-7, 7:-7] = False
    out[ring] = plate[ring]
    img[y0:y1, x0:x1] = np.clip(out, 0, 255).astype(np.uint8)


def main():
    leader_src = cv2.imread(os.path.join(SRC, "ui_leader_mockup.png"))
    s = SCREENS["leader"]
    sx0, sy0, sx1, sy1 = s["slate"]
    slate_patch = leader_src[sy0:sy1, sx0:sx1].copy()
    for name, s in SCREENS.items():
        img = cv2.imread(os.path.join(SRC, "ui_%s_mockup.png" % name))
        mask = subject_mask(img, s["subject"], s["subject_kind"], s.get("boxes"))
        if s["fill_bands"]:
            for band in s["fill_bands"]:
                x0, _, x1, _ = s["stage"]
                img, mask = inpaint(img, mask, (x0, band[0], x1, band[1]), band)
        else:
            img, mask = inpaint(img, mask, s["stage"])
        for box in s["clear"]:
            tile(img, box, slate_patch)
        plain_tab(img, s["tab"], s["plain_tab"])
        cv2.imwrite(os.path.join(OUT, "%s_screen.png" % name), img)
        print("wrote assets/ui/%s_screen.png" % name)


if __name__ == "__main__":
    main()
