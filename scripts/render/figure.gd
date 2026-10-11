extends RefCounted
## Placeholder pixel art, drawn in code. Each clothing and gear piece is its own
## layer, so a unit visibly looks like what it carries. Real sprites will
## replace these functions later; the callers (`_draw` methods) stay the same.
##
## Figures are drawn on a 12 x 18 "pixel" grid. `origin` is the point between
## the feet, `px` is the screen size of one grid pixel, and `facing` is 1
## (right) or -1 (left).

const AppearanceCatalog = preload("res://scripts/data/appearance_catalog.gd")

const GRID_W := 12.0
const GRID_H := 18.0

const WOOD := Color(0.48, 0.33, 0.19)
const STONE := Color(0.62, 0.60, 0.56)
const LEATHER := Color(0.42, 0.27, 0.15)
const BONE := Color(0.89, 0.85, 0.74)
const FUR := Color(0.48, 0.36, 0.24)
const EYE := Color(0.16, 0.11, 0.08)


## One grid rectangle, mirrored when facing left.
static func _r(ci: CanvasItem, origin: Vector2, px: float, facing: int, gx: float, gy: float, w: float, h: float, col: Color) -> void:
	var x := gx
	if facing < 0:
		x = GRID_W - gx - w
	ci.draw_rect(Rect2(origin + Vector2((x - GRID_W / 2.0) * px, (gy - GRID_H) * px), Vector2(w * px, h * px)), col)


static func _shadow(ci: CanvasItem, origin: Vector2, px: float, width: float) -> void:
	ci.draw_rect(Rect2(origin + Vector2(-width / 2.0 * px, -0.6 * px), Vector2(width * px, 1.2 * px)), Color(0, 0, 0, 0.25))


## A person: appearance (`look`) plus equipped `gear` (slot -> item id).
## `walk_t` > 0 animates the legs; `swing_t` > 0 animates an attack.
static func draw_human(ci: CanvasItem, origin: Vector2, px: float, look: Dictionary, gear: Dictionary,
		facing: int = 1, walk_t: float = 0.0, swing_t: float = 0.0) -> void:
	var skin := AppearanceCatalog.color_of("skin", str(look.get("skin", "skin3")))
	var skin_dark := skin.darkened(0.2)
	var hair := AppearanceCatalog.color_of("hair_color", str(look.get("hair_color", "black")))
	var tribe := AppearanceCatalog.color_of("tribe_color", str(look.get("tribe_color", "ochre")))
	var female := str(look.get("sex", "male")) == "female"
	var paint_id := str(look.get("paint", "none"))
	var paint := AppearanceCatalog.paint_color(paint_id)
	var body_id := str(gear.get("body", "none_body"))

	var step := 0
	if walk_t > 0.0:
		step = int(walk_t * 8.0) % 2
	_shadow(ci, origin, px, 8.0)
	var o := origin + Vector2(0, (-0.5 if step == 1 else 0.0) * px)

	# Cloak hangs behind everything else.
	if str(look.get("cloak", "none")) == "fur_cloak":
		_r(ci, o, px, facing, 2, 6, 5, 8, FUR)
		_r(ci, o, px, facing, 2, 6, 6, 1, FUR.lightened(0.2))

	# Back arm and legs.
	_r(ci, o, px, facing, 3, 7, 1, 4, skin_dark)
	_r(ci, o, px, facing, 4, 12, 2, 6.0 - (1.0 if step == 1 else 0.0), skin_dark)
	_r(ci, o, px, facing, 6, 12, 2, 6.0 - (1.0 if walk_t > 0.0 and step == 0 else 0.0), skin)

	# Lower garment.
	match str(look.get("lower", "loincloth")):
		"hide_skirt":
			_r(ci, o, px, facing, 3, 11, 6, 4, Color(0.61, 0.48, 0.33))
			_r(ci, o, px, facing, 3, 14, 6, 1, tribe)
		_:
			_r(ci, o, px, facing, 4, 11, 4, 2, tribe)
			_r(ci, o, px, facing, 5, 13, 2, 1, tribe.darkened(0.25))

	# Torso.
	_r(ci, o, px, facing, 4, 6, 4, 6, skin)
	if female and body_id == "none_body":
		_r(ci, o, px, facing, 4, 7, 4, 2, tribe)
	if paint_id != "none":
		_r(ci, o, px, facing, 5, 10, 2, 1, paint)

	# Body armor.
	match body_id:
		"hide_wrap":
			_r(ci, o, px, facing, 4, 7, 4, 4, Color(0.65, 0.52, 0.35))
			_r(ci, o, px, facing, 4, 7, 1, 4, Color(0.49, 0.37, 0.24))
		"leather_armor":
			_r(ci, o, px, facing, 3, 6, 6, 6, Color(0.48, 0.31, 0.16))
			_r(ci, o, px, facing, 3, 8, 6, 1, Color(0.35, 0.21, 0.10))
		"bone_hide":
			_r(ci, o, px, facing, 3, 6, 6, 6, Color(0.48, 0.35, 0.23))
			_r(ci, o, px, facing, 4, 7, 1, 1, BONE)
			_r(ci, o, px, facing, 6, 7, 1, 1, BONE)
			_r(ci, o, px, facing, 5, 9, 1, 1, BONE)
			_r(ci, o, px, facing, 7, 9, 1, 1, BONE)

	# Head.
	_r(ci, o, px, facing, 4, 1, 4, 5, skin)
	_r(ci, o, px, facing, 6, 3, 1, 1, EYE)
	if paint_id != "none":
		_r(ci, o, px, facing, 5, 4, 2, 1, paint)

	# Hair.
	match str(look.get("hair", "short")):
		"short":
			_r(ci, o, px, facing, 4, 0, 4, 2, hair)
			_r(ci, o, px, facing, 4, 2, 1, 1, hair)
		"long":
			_r(ci, o, px, facing, 4, 0, 4, 2, hair)
			_r(ci, o, px, facing, 3, 1, 2, 6, hair)
		"braids":
			_r(ci, o, px, facing, 4, 0, 4, 2, hair)
			_r(ci, o, px, facing, 3, 2, 1, 7, hair)
			_r(ci, o, px, facing, 3, 9, 1, 1, tribe)

	# Headwear.
	match str(look.get("headwear", "none")):
		"animal_hood":
			_r(ci, o, px, facing, 3, -1, 6, 3, FUR)
			_r(ci, o, px, facing, 3, -2, 1, 1, FUR)
			_r(ci, o, px, facing, 7, -2, 1, 1, FUR)
			_r(ci, o, px, facing, 8, 0, 2, 1, FUR.darkened(0.25))
			_r(ci, o, px, facing, 3, 2, 1, 4, FUR)
		"bone_headband":
			_r(ci, o, px, facing, 4, 2, 4, 1, BONE)

	# Off hand: shields are carried on the back arm's side.
	match str(gear.get("off_hand", "none_off")):
		"hide_shield":
			_r(ci, o, px, facing, 1, 7, 3, 5, Color(0.69, 0.54, 0.36))
			_r(ci, o, px, facing, 2, 8, 1, 3, tribe)
		"bone_shield":
			_r(ci, o, px, facing, 1, 6, 3, 7, BONE)
			_r(ci, o, px, facing, 2, 8, 1, 3, tribe)

	# Front arm.
	_r(ci, o, px, facing, 8, 7, 1, 4, skin)

	# Main hand weapon. During a swing its head moves forward.
	var sw := 0.0
	if swing_t > 0.0:
		sw = 2.0 if swing_t < 0.13 else 1.0
	match str(gear.get("main_hand", "fists")):
		"club":
			_r(ci, o, px, facing, 9, 6, 1, 6, WOOD)
			_r(ci, o, px, facing, 9 + sw, 3, 2, 4, WOOD.darkened(0.25))
		"spear":
			_r(ci, o, px, facing, 9 + sw, -2, 1, 15, WOOD)
			_r(ci, o, px, facing, 9 + sw, -4, 1, 2, STONE)
		"stone_axe":
			_r(ci, o, px, facing, 9, 4, 1, 8, WOOD)
			_r(ci, o, px, facing, 10 + sw, 4, 2, 3, STONE)
		"flail":
			_r(ci, o, px, facing, 9, 8, 1, 4, WOOD)
			_r(ci, o, px, facing, 9 + sw * 0.5, 6, 1, 2, LEATHER)
			_r(ci, o, px, facing, 9 + sw, 3, 2, 3, STONE)
		"sling":
			_r(ci, o, px, facing, 9, 9, 1, 3, LEATHER)
			_r(ci, o, px, facing, 10 + sw, 11, 1, 1, STONE)
	_r(ci, o, px, facing, 8, 10, 2, 1, skin)


## A wolf, used by the wilderness's wild animals.
static func draw_wolf(ci: CanvasItem, origin: Vector2, px: float, facing: int = 1, walk_t: float = 0.0, swing_t: float = 0.0) -> void:
	var fur := Color(0.47, 0.45, 0.42)
	var fur_dark := fur.darkened(0.25)
	var step := 0
	if walk_t > 0.0:
		step = int(walk_t * 10.0) % 2
	var lunge := 1.0 if swing_t > 0.0 else 0.0
	_shadow(ci, origin, px, 10.0)
	var o := origin
	_r(ci, o, px, facing, 0, 10, 2, 1, fur_dark)
	_r(ci, o, px, facing, 3, 14, 1, 4.0 - float(step), fur_dark)
	_r(ci, o, px, facing, 8, 14, 1, 4.0 - float(1 - step), fur_dark)
	_r(ci, o, px, facing, 2, 10, 8, 4, fur)
	_r(ci, o, px, facing, 4, 14, 1, 4.0 - float(1 - step), fur)
	_r(ci, o, px, facing, 9, 14, 1, 4.0 - float(step), fur)
	_r(ci, o, px, facing, 9 + lunge, 8, 3, 3, fur)
	_r(ci, o, px, facing, 10 + lunge, 7, 1, 1, fur_dark)
	_r(ci, o, px, facing, 10 + lunge, 9, 1, 1, Color(0.95, 0.80, 0.35))
	_r(ci, o, px, facing, 12 + lunge, 10, 1, 1, EYE)
