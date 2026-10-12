#!/usr/bin/env python3
"""Build the wilderness map: a grid of 32 px squares (one square = one person, like
the original Warcraft), its terrain, its walls of trees and rock, and its scattered
solid obstacles.

    python3 tools/map/build_wilderness.py      (needs opencv-python-headless or -contrib)

The layout is drawn here in code (river with fords, pond, forest walls, rock ridge
with a pass, a path from the camp to the clearing, tall-grass meadows). Outputs:
  assets/maps/wilderness_ground.jpg - the painted ground (terrain from Luke's terrain
      sheet, soft noisy edges between terrains, foam along the water) with the deep
      parts of forests and rock walls and the small ground plants baked in.
  scripts/data/wilderness_map.gd - the grid for the game: terrain per square, which
      squares are blocked, the solid objects to place (trees, rocks, bushes, stumps,
      logs, and the wall trees/rocks along the walls' south edges, so units can walk
      behind them), the camp, the clearing and the creature spawns.

Terrain rules (scripts/world/map_grid.gd): deep water blocks; shallow water, tall
grass and rocky ground slow you down; the path is quicker.
"""
import os
import sys

import cv2
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
SHEET = os.path.join(ROOT, "assets", "source", "sheet_terrain.png")
SCENERY = os.path.join(ROOT, "assets", "sprites", "scenery")

W, H = 96, 64
TILE = 32
SEED = 21

# Terrain: char -> (sheet sample box, speed multiplier). Walls and obstacles are separate.
TERRAIN = {
    ".": ((14, 42, 182, 178), 1.0),      # grass (basic)
    ":": ((204, 42, 374, 178), 0.7),     # tall grass (dense) - slow
    ",": ((399, 42, 566, 178), 1.0),     # dark grass (forest floor)
    "d": ((770, 42, 938, 178), 1.0),     # patchy dirt
    "c": ((587, 42, 744, 178), 1.0),     # bare dirt (the clearing)
    "p": ((964, 42, 1110, 178), 1.2),    # trampled path - quick
    "r": ((1164, 42, 1332, 178), 0.8),   # rocky ground - slow
    "s": ((1356, 42, 1524, 178), 0.9),   # sand
    "~": ((193, 540, 340, 650), 0.55),   # shallow water - slow
    "W": ((15, 540, 164, 650), 0.0),     # deep water - blocked
}
WALL_TREES = ["oak_large", "oak_medium", "pine_large", "pine_medium", "pine_small", "birch_medium", "oak_small"]
WALL_ROCKS = ["rock_large", "rock_tall", "boulder_mossy", "rock_medium", "rock_mossy_small"]
LONE = {
    "tree": ["oak_large", "oak_medium", "oak_small", "pine_medium", "pine_small", "birch_medium", "birch_small", "dead_tree"],
    "bush": ["bush_dense", "bush_sparse", "bush_sparse_small", "bush_berry_orange", "bush_berry_small", "bush_blueberry",
             "bush_raspberry"],
    "rock": ["rock_large", "rock_tall", "rock_medium", "rock_small", "rock_flat", "rock_mossy_small", "boulder_mossy"],
    "plant": ["stump_small", "stump_large", "log", "roots_large"],
}
DECOR = ["grass_small", "grass_medium", "grass_large", "grass_thin", "fern_small", "fern_large", "flowers_white",
         "flowers_yellow", "mushrooms_small", "mushrooms_large", "roots_small"]

START = (10, 51)
SITE = (80, 15)
# Creatures: species -> rough squares (snapped to the nearest open square).
WILDLIFE = [
    ("rabbit", 18, 46), ("rabbit", 25, 57), ("rabbit", 40, 54), ("rabbit", 56, 40), ("rabbit", 68, 54), ("rabbit", 28, 34),
    ("squirrel", 15, 38), ("squirrel", 38, 30), ("squirrel", 60, 56), ("squirrel", 74, 34), ("squirrel", 22, 20),
    ("turkey", 32, 50), ("turkey", 50, 26), ("turkey", 66, 40), ("turkey", 12, 28),
    ("doe", 40, 16), ("doe", 42, 18), ("doe", 62, 48), ("doe", 84, 42),
    ("stag", 38, 13), ("stag", 86, 45),
    ("fox", 27, 42), ("fox", 54, 18), ("fox", 72, 58),
    ("boar", 50, 47), ("boar", 70, 28), ("boar", 20, 12),
    ("bear", 86, 56),
    ("wolf", 33, 42), ("wolf", 35, 44), ("wolf", 58, 30),
]
GUARDS = [("caveman", 75, 13), ("caveman", 84, 19), ("wolf", 79, 23)]

# Off the beaten path: hidden pockets in the woods, each reached by a narrow gap, with a
# reward (a cache to pick up) and whatever guards it.
# (name, pocket center, pocket radii, gap from, gap to, terrain inside)
SECRETS = [
    ("glade", (20, 21), (3.5, 3.0), (20, 24), (20, 31), ","),
    ("beach", (7, 8), (3.0, 2.5), (9, 10), (13, 15), "s"),
    ("den", (87, 34), (3.0, 2.2), (86, 36), (85, 40), "d"),
    ("bear", (87, 56), (3.5, 3.0), (84, 56), (78, 53), "r"),
]
# Caches: [id, name, square x, y, reward kind ("unlock" gear id / "points"), value, look]
CACHES = [
    ["flint_cache", "Flint cache", 20, 20, "unlock", "flint_axe", "any_yard_trophy_pile"],
    ["sling_cache", "Sling and stones", 6, 7, "unlock", "sling", "any_yard_baskets"],
    ["bone_cache", "Bone cache", 88, 33, "unlock", "bone_spear", "any_yard_bone_heap"],
    ["honey_cache", "Honey and hides", 89, 57, "points", "60", "any_yard_clay_pots"],
]
WILDLIFE += [("alpha_wolf", 21, 22), ("wolf", 18, 21), ("wolf", 22, 19), ("boar", 8, 9),
             ("alpha_wolf", 86, 33), ("wolf", 88, 35), ("wolf", 85, 34)]


def smooth_noise(rng, shape, scale):
    """Smooth random field in [-1, 1] (blurred white noise)."""
    small = rng.standard_normal((shape[0] // scale + 3, shape[1] // scale + 3)).astype(np.float32)
    big = cv2.resize(small, (shape[1] + 3 * scale, shape[0] + 3 * scale), interpolation=cv2.INTER_CUBIC)
    big = big[scale:scale + shape[0], scale:scale + shape[1]]
    return big / (np.abs(big).max() + 1e-6)


# --- Layout -----------------------------------------------------------------------

def disk(grid, cx, cy, rx, ry, ch, only=None):
    for y in range(max(0, int(cy - ry - 1)), min(H, int(cy + ry + 2))):
        for x in range(max(0, int(cx - rx - 1)), min(W, int(cx + rx + 2))):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0 and (only is None or grid[y, x] in only):
                grid[y, x] = ch


def line(grid, pts, width, ch, only=None):
    """A thick polyline through `pts` (square coordinates)."""
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
        for i in range(n + 1):
            t = i / n
            disk(grid, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, width / 2, width / 2, ch, only)


def layout():
    rng = np.random.default_rng(SEED)
    terrain = np.full((H, W), ".", dtype="<U1")
    wall = np.zeros((H, W), dtype="<U1")  # "T" forest, "R" rock wall, "" open
    ys, xs = np.mgrid[0:H, 0:W]

    # Tall-grass meadows and darker grass from smooth noise.
    n1 = smooth_noise(rng, (H, W), 6)
    terrain[n1 > 0.35] = ":"
    n2 = smooth_noise(rng, (H, W), 8)
    terrain[(n2 > 0.45) & (terrain == ".")] = ","

    # Forest walls: the map's edge (noisy, 2-5 deep) and three inner woods.
    edge = np.minimum(np.minimum(xs, W - 1 - xs), np.minimum(ys, H - 1 - ys))
    depth = 3 + 1.5 * smooth_noise(rng, (H, W), 5)
    wall[edge < depth] = "T"
    woods = smooth_noise(rng, (H, W), 7)
    for (cx, cy, rx, ry) in [(20, 22, 7, 8), (30, 8, 8, 4), (82, 34, 9, 4), (66, 60, 7, 3), (12, 38, 4, 3)]:
        inside = ((xs - cx) / rx) ** 2 + ((ys - cy) / ry) ** 2 <= 1.0 + 0.35 * woods
        wall[inside] = "T"

    # Secret pockets carved into the woods, each with one narrow way in.
    for name, (cx, cy), (rx, ry), a, b, ch in SECRETS:
        disk(wall, cx, cy, rx, ry, "")
        disk(terrain, cx, cy, rx, ry, ch)
        line(wall, [a, b], 1.4, "")

    # The river: deep in the middle, shallow banks, sandy beaches; two fords.
    river = [(35, -2), (38, 8), (42, 18), (45, 28), (50, 38), (51, 47), (48, 56), (50, 66)]
    line(terrain, river, 9, "s")
    line(terrain, river, 6, "~")
    line(terrain, river, 3.2, "W")
    for fy in (12, 43):  # fords: shallow all the way across
        for y in range(fy - 2, fy + 3):
            for x in range(W):
                if terrain[y, x] == "W":
                    terrain[y, x] = "~"
    wall[(terrain == "W") | (terrain == "~") | (terrain == "s")] = ""

    # The pond in the south-east, with a sandy shore.
    disk(terrain, 70, 47, 6.5, 5, "s")
    disk(terrain, 70, 47, 5, 3.8, "~")
    disk(terrain, 70, 47, 3.5, 2.6, "W")
    wall[((xs - 70) / 6.5) ** 2 + ((ys - 47) / 5) ** 2 <= 1.0] = ""

    # The rock ridge north of the clearing's approach, with a pass; rocky ground around it.
    ridge = [(58, 3), (60, 10), (63, 17), (66, 24), (70, 28), (76, 29), (86, 28)]
    line(terrain, ridge, 6, "r")
    rock = np.zeros((H, W), bool)
    tmp = np.full((H, W), "", dtype="<U1")
    line(tmp, ridge, 3, "R")
    rock = tmp == "R"
    wall[rock] = "R"
    for (px, py) in [(64, 20), (65, 21), (78, 29), (79, 29)]:  # two passes through the ridge
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                if 0 <= py + dy < H and 0 <= px + dx < W and wall[py + dy, px + dx] == "R":
                    wall[py + dy, px + dx] = ""

    # The path from the camp, over the southern ford, up to the pass and the clearing.
    path = [START, (22, 50), (32, 47), (42, 44), (50, 43), (56, 40), (60, 33), (63, 26), (65, 21), (70, 18), SITE]
    line(terrain, path, 2.2, "p", only=set(".:,drs"))
    line(wall, path, 2.6, "")
    # The clearing (the goal) and the camp.
    disk(terrain, SITE[0], SITE[1], 6, 5, "c")
    disk(wall, SITE[0], SITE[1], 7, 6, "")
    disk(terrain, START[0], START[1], 3.5, 3, "d")
    disk(wall, START[0], START[1], 5, 4, "")
    # Never leave deep water under a wall, or walls on the path.
    return terrain, wall, rng


def place_objects(terrain, wall, rng):
    """Lone solid objects on open ground: [(kind, piece, x, y)] in square coordinates."""
    objects = []
    keep_clear = np.zeros((H, W), bool)
    for (cx, cy, r) in [(START[0], START[1], 6), (SITE[0], SITE[1], 7)]:
        ys, xs = np.mgrid[0:H, 0:W]
        keep_clear |= (xs - cx) ** 2 + (ys - cy) ** 2 <= r * r
    for name, sx, sy in WILDLIFE + GUARDS:
        keep_clear[max(0, sy - 1):sy + 2, max(0, sx - 1):sx + 2] = True
    for c in CACHES:
        keep_clear[max(0, c[3] - 1):c[3] + 2, max(0, c[2] - 1):c[2] + 2] = True
    taken = np.zeros((H, W), bool)
    chances = [("tree", 0.035), ("bush", 0.03), ("rock", 0.015), ("plant", 0.012)]
    for y in range(2, H - 2):
        for x in range(2, W - 2):
            t = terrain[y, x]
            if wall[y, x] or keep_clear[y, x] or taken[y, x] or t in "pWc~s":
                continue
            roll = rng.random()
            acc = 0.0
            for kind, chance in chances:
                acc += chance
                if roll < acc:
                    piece = LONE[kind][rng.integers(len(LONE[kind]))]
                    objects.append((kind, piece, x, y))
                    taken[y, x] = True
                    break
    return objects


def footprint(piece, x, y):
    """The squares an object blocks: its base, one square deep, wide objects two squares."""
    w = Image.open(os.path.join(SCENERY, piece, "s.png")).size[0]
    if w >= 76 and x + 1 < W:
        return [(x, y), (x + 1, y)]
    return [(x, y)]


def snap(blocked, terrain, x, y):
    """The open square nearest (x, y)."""
    best = None
    for r in range(0, 12):
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and not blocked[ny, nx] and terrain[ny, nx] != "W":
                    d = dx * dx + dy * dy
                    if best is None or d < best[0]:
                        best = (d, nx, ny)
        if best:
            return best[1], best[2]
    return x, y


# --- Painting ---------------------------------------------------------------------

def texture(box, shape, rng):
    """A terrain sample, mirror-tiled over the whole map at art scale."""
    sheet = np.asarray(Image.open(SHEET).convert("RGB"))
    x0, y0, x1, y1 = box
    sample = sheet[y0:y1, x0:x1]
    sample = cv2.resize(sample, ((x1 - x0) // 2, (y1 - y0) // 2), interpolation=cv2.INTER_NEAREST)
    block = np.concatenate([np.concatenate([sample, sample[:, ::-1]], 1),
                            np.concatenate([sample[::-1], sample[::-1, ::-1]], 1)], 0)
    reps = (shape[0] // block.shape[0] + 2, shape[1] // block.shape[1] + 2, 1)
    tiled = np.tile(block, reps)
    oy, ox = rng.integers(block.shape[0]), rng.integers(block.shape[1])
    return tiled[oy:oy + shape[0], ox:ox + shape[1]].astype(np.float32)


def paint(terrain, rng):
    shape = (H * TILE, W * TILE)
    edge_noise = smooth_noise(rng, shape, 24) * 0.22 + smooth_noise(rng, shape, 6) * 0.08
    comp = np.zeros(shape + (3,), np.float32)
    wsum = np.zeros(shape, np.float32)
    water = np.zeros(shape, np.float32)
    for ch, (box, _) in TERRAIN.items():
        mask = (terrain == ch).astype(np.float32)
        if not mask.any():
            continue
        m = cv2.resize(mask, (shape[1], shape[0]), interpolation=cv2.INTER_NEAREST)
        m = cv2.GaussianBlur(m, (0, 0), 9)
        w = np.clip((m + edge_noise - 0.38) / 0.24, 0.0, 1.0)
        w = w * w * (3 - 2 * w)
        if ch in "~W":
            water += m
        tex = texture(box, shape, rng)
        if ch == ":":
            tex *= np.array([1.06, 1.04, 0.78], np.float32)  # tall grass reads drier and yellower: slow ground
        comp += w[..., None] * tex
        wsum += w
    comp /= np.maximum(wsum, 1e-3)[..., None]
    # Light and shade over large areas, so repeats don't show.
    comp *= (1.0 + 0.07 * smooth_noise(rng, shape, 90))[..., None]
    # Foam where water meets land.
    foam = np.clip(1.0 - np.abs(water + edge_noise * 0.5 - 0.42) / 0.07, 0, 1) * 0.55
    comp = comp * (1 - foam[..., None]) + np.array([226, 236, 232], np.float32) * foam[..., None]
    return Image.fromarray(np.clip(comp, 0, 255).astype(np.uint8)).convert("RGBA")


def stamp(img, piece, px, py, mirrored=False):
    """Draw a scenery sprite with its bottom center at (px, py)."""
    spr = Image.open(os.path.join(SCENERY, piece, "s.png")).convert("RGBA")
    if mirrored:
        spr = spr.transpose(Image.FLIP_LEFT_RIGHT)
    img.alpha_composite(spr, (int(px - spr.width / 2), int(py - spr.height)))


def main():
    terrain, wall, rng = layout()
    objects = place_objects(terrain, wall, rng)
    blocked = (wall != "") | (terrain == "W")
    nodes = []  # solid objects the game places (y-sorted with units): [piece, kind, world x, world y, mirrored]
    for kind, piece, x, y in objects:
        for fx, fy in footprint(piece, x, y):
            blocked[fy, fx] = True
        nodes.append([piece, kind, x * TILE + TILE // 2 + int(rng.integers(-4, 5)), y * TILE + TILE - 4, bool(rng.random() < 0.5)])

    img = paint(terrain, rng)
    # Small ground plants (not solid): baked into the ground.
    for y in range(H):
        for x in range(W):
            if not blocked[y, x] and terrain[y, x] in ".:," and rng.random() < (0.05 if terrain[y, x] == ":" else 0.025):
                stamp(img, DECOR[rng.integers(len(DECOR))], x * TILE + rng.integers(4, 28), y * TILE + rng.integers(16, 32),
                      rng.random() < 0.5)
    # Walls: every wall square gets a tree or a rock, top to bottom. A wall square with open
    # ground just below it is the wall's visible front: placed as a game object so units
    # walking behind it are hidden; the rest is baked into the ground.
    for y in range(H):
        for x in range(W):
            if not wall[y, x]:
                continue
            pool = WALL_TREES if wall[y, x] == "T" else WALL_ROCKS
            piece = pool[rng.integers(len(pool))]
            px = x * TILE + TILE // 2 + int(rng.integers(-6, 7))
            py = y * TILE + TILE - int(rng.integers(0, 6))
            mirrored = bool(rng.random() < 0.5)
            front = any(y + k < H and not wall[y + k, x] for k in (1, 2, 3))
            if front:
                nodes.append([piece, "tree" if wall[y, x] == "T" else "rock", px, py, mirrored])
            else:
                stamp(img, piece, px, py, mirrored)

    out_dir = os.path.join(ROOT, "assets", "maps")
    os.makedirs(out_dir, exist_ok=True)
    img.convert("RGB").save(os.path.join(out_dir, "wilderness_ground.jpg"), quality=90)

    spawns = []
    for name, sx, sy in WILDLIFE + GUARDS:
        x, y = snap(blocked, terrain, sx, sy)
        blocked_here = False
        spawns.append([name, x, y, (name, sx, sy) in GUARDS])
        del blocked_here
    caches = []
    for cid, name, cx, cy, kind, value, look in CACHES:
        x, y = snap(blocked, terrain, cx, cy)
        caches.append([cid, name, x, y, kind, value, look])
    write_gd(terrain, blocked, nodes, spawns, caches)
    print("map %dx%d squares: %d blocked, %d objects, %d spawns" % (W, H, int(blocked.sum()), len(nodes), len(spawns)))


def write_gd(terrain, blocked, nodes, spawns, caches):
    speeds = ", ".join('"%s": %s' % (ch, sp) for ch, (_, sp) in TERRAIN.items())
    rows = ",\n\t\t".join('"%s"' % "".join(terrain[y]) for y in range(H))
    solid = ",\n\t\t".join('"%s"' % "".join("#" if blocked[y, x] else "." for x in range(W)) for y in range(H))
    objs = ",\n\t\t".join('["%s", "%s", %d, %d, %s]' % (p, k, x, y, "true" if m else "false") for p, k, x, y, m in nodes)
    sp = ",\n\t\t".join('["%s", %d, %d, %s]' % (n, x, y, "true" if g else "false") for n, x, y, g in spawns)
    ca = ",\n\t\t".join('["%s", "%s", %d, %d, "%s", "%s", "%s"]' % tuple(c) for c in caches)
    text = """extends RefCounted
## Generated by tools/map/build_wilderness.py - do not edit by hand.
## The wilderness grid: %d x %d squares of %d px. Terrain letters: . grass, : tall grass,
## , dark grass, d dirt, c the clearing, p path, r rocky ground, s sand, ~ shallow water,
## W deep water. Solid squares (walls, deep water, obstacles) are "#" in solid().


static func tile() -> int:
\treturn %d


static func size() -> Vector2i:
\treturn Vector2i(%d, %d)


static func start() -> Vector2i:
\treturn Vector2i(%d, %d)


static func site() -> Vector2i:
\treturn Vector2i(%d, %d)


## Movement speed on each terrain (0 = impassable).
static func speeds() -> Dictionary:
\treturn {%s}


static func terrain() -> Array:
\treturn [
\t\t%s,
\t]


static func solid() -> Array:
\treturn [
\t\t%s,
\t]


## Solid objects placed in the world: [sprite, kind, x, y (world px, base), mirrored].
static func objects() -> Array:
\treturn [
\t\t%s,
\t]


## Creatures: [species, square x, square y, guards the clearing].
static func spawns() -> Array:
\treturn [
\t\t%s,
\t]


## Rewards off the beaten path: [id, name, square x, y, "unlock" (gear id) or "points", value, look sprite].
static func caches() -> Array:
\treturn [
\t\t%s,
\t]
""" % (W, H, TILE, TILE, W, H, START[0], START[1], SITE[0], SITE[1], speeds, rows, solid, objs, sp, ca)
    with open(os.path.join(ROOT, "scripts", "data", "wilderness_map.gd"), "w") as f:
        f.write(text)


if __name__ == "__main__":
    sys.exit(main())
