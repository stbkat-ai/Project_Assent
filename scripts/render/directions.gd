extends RefCounted
## The 8 facing directions of a 3/4 top-down unit, numbered clockwise from
## east (screen y points down):
##   0 E, 1 SE, 2 S, 3 SW, 4 W, 5 NW, 6 N, 7 NE
##
## Like the original StarCraft, only 5 views are drawn (s, se, e, ne, n).
## SW, W and NW reuse SE, E and NE flipped left-to-right.

const E := 0
const SE := 1
const S := 2
const SW := 3
const W := 4
const NW := 5
const N := 6
const NE := 7

const NAMES := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
## The drawn views, in the order an art sheet should show them.
const VIEWS := ["s", "se", "e", "ne", "n"]


## The direction closest to vector `v`.
static func from_vector(v: Vector2) -> int:
	return posmod(int(round(v.angle() / (PI / 4.0))), 8)


## The drawn view used for `dir`.
static func view_of(dir: int) -> String:
	match posmod(dir, 8):
		E, W:
			return "e"
		SE, SW:
			return "se"
		S:
			return "s"
		N:
			return "n"
		_:
			return "ne"


## True when `dir` is drawn as a mirrored copy of its view.
static func is_mirrored(dir: int) -> bool:
	var d := posmod(dir, 8)
	return d == SW or d == W or d == NW


## True for views where the unit faces away, so held items go behind the body.
static func is_back_view(view: String) -> bool:
	return view == "n" or view == "ne"


static func turn(dir: int, steps: int) -> int:
	return posmod(dir + steps, 8)
