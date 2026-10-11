extends RefCounted
## Draws people and beasts in 3/4 top-down view, facing any of 8 directions.
##
## A person is a stack of layers: body, lower garment, armor, hair, headwear,
## cloak, shield, weapon. For each layer, if a sprite exists in assets/sprites
## (see sprite_library.gd) it is drawn; otherwise a placeholder is drawn in
## code. So real art can replace the placeholders one piece at a time.
##
## Placeholders use a 12 x 18 "pixel" grid. `origin` is the point between the
## feet and `px` is the screen size of one grid pixel. Only the views s, se, e,
## ne and n are drawn; the other three directions are mirror images.

const AppearanceCatalog = preload("res://scripts/data/appearance_catalog.gd")
const Directions = preload("res://scripts/render/directions.gd")
const SpriteLibrary = preload("res://scripts/render/sprite_library.gd")

const GRID_W := 12.0
const GRID_H := 18.0

const WOOD := Color(0.48, 0.33, 0.19)
const STONE := Color(0.62, 0.60, 0.56)
const LEATHER := Color(0.42, 0.27, 0.15)
const BONE := Color(0.89, 0.85, 0.74)
const FUR := Color(0.48, 0.36, 0.24)
const EYE := Color(0.16, 0.11, 0.08)

## Layer order for views facing the viewer, and for views facing away
## (held items and the cloak swap sides of the body).
const FRONT_ORDER := ["cloak", "body", "lower", "armor", "hair", "headwear", "shield", "weapon"]
const BACK_ORDER := ["shield", "weapon", "body", "lower", "armor", "hair", "headwear", "cloak"]


## Everything a draw call needs, gathered once per frame.
class Ctx:
	var ci: CanvasItem
	var o: Vector2
	var px: float
	var mirrored: bool
	var view: String
	var walk_t: float
	var swing_t: float

	## One placeholder grid rectangle, mirrored when needed.
	func r(gx: float, gy: float, w: float, h: float, col: Color) -> void:
		var x := gx
		if mirrored:
			x = 12.0 - gx - w
		ci.draw_rect(Rect2(o + Vector2((x - 6.0) * px, (gy - 18.0) * px), Vector2(w * px, h * px)), col)

	func front() -> bool:
		return view == "s" or view == "se"

	func back() -> bool:
		return view == "n" or view == "ne"


static func _shadow(ci: CanvasItem, origin: Vector2, px: float, width: float) -> void:
	ci.draw_rect(Rect2(origin + Vector2(-width / 2.0 * px, -1.0 * px), Vector2(width * px, 2.0 * px)), Color(0, 0, 0, 0.22))


## The sprite piece shown on each layer for this look and gear: layer -> [category, piece id, tint].
## An empty piece id means the layer is not drawn.
static func pieces(look: Dictionary, gear: Dictionary) -> Dictionary:
	var skin := AppearanceCatalog.color_of("skin", str(look.get("skin", "skin3")))
	var hair := AppearanceCatalog.color_of("hair_color", str(look.get("hair_color", "black")))
	var hair_id := str(look.get("hair", "short"))
	var body_gear := str(gear.get("body", "none_body"))
	var off := str(gear.get("off_hand", "none_off"))
	var main := str(gear.get("main_hand", "fists"))
	return {
		"body": ["bodies", "body_" + str(look.get("sex", "male")), skin],
		"lower": ["clothing", str(look.get("lower", "loincloth")), Color.WHITE],
		"armor": ["gear", "" if body_gear == "none_body" else body_gear, Color.WHITE],
		"hair": ["hair", "" if hair_id == "bald" else hair_id, hair],
		"headwear": ["clothing", "" if str(look.get("headwear", "none")) == "none" else str(look["headwear"]), Color.WHITE],
		"cloak": ["clothing", "" if str(look.get("cloak", "none")) == "none" else str(look["cloak"]), Color.WHITE],
		"shield": ["gear", "" if off == "none_off" else off, Color.WHITE],
		"weapon": ["gear", "" if main == "fists" else main, Color.WHITE],
	}


## A person facing `dir` (0-7, see directions.gd).
static func draw_human(ci: CanvasItem, origin: Vector2, px: float, look: Dictionary, gear: Dictionary,
		dir: int = Directions.S, walk_t: float = 0.0, swing_t: float = 0.0) -> void:
	var c := Ctx.new()
	c.ci = ci
	c.px = px
	c.view = Directions.view_of(dir)
	c.mirrored = Directions.is_mirrored(dir)
	c.walk_t = walk_t
	c.swing_t = swing_t
	var bob := 0.0
	if walk_t > 0.0 and int(walk_t * 8.0) % 2 == 1:
		bob = -0.5
	c.o = origin + Vector2(0, bob * px)
	_shadow(ci, origin, px, 9.0)

	var layer_pieces := pieces(look, gear)
	var anim := "walk" if walk_t > 0.0 else ""
	var order: Array = BACK_ORDER if Directions.is_back_view(c.view) else FRONT_ORDER
	for layer in order:
		var piece: Array = layer_pieces[layer]
		if str(piece[1]) == "":
			continue
		var tex = SpriteLibrary.frame_at(str(piece[0]), str(piece[1]), c.view, anim, walk_t)
		if tex != null:
			SpriteLibrary.draw(ci, tex, origin, px * 0.5 * SpriteLibrary.SPRITE_SCALE, c.mirrored, piece[2])
		else:
			_placeholder(c, str(layer), str(piece[1]), look)


static func _placeholder(c: Ctx, layer: String, piece: String, look: Dictionary) -> void:
	match layer:
		"body":
			_body(c, look)
		"lower":
			_lower(c, piece, look)
		"armor":
			_armor(c, piece)
		"hair":
			_hair(c, piece, look)
		"headwear":
			_headwear(c, piece)
		"cloak":
			_cloak(c)
		"shield":
			_shield(c, piece, look)
		"weapon":
			_weapon(c, piece)


static func _body(c: Ctx, look: Dictionary) -> void:
	var skin := AppearanceCatalog.color_of("skin", str(look.get("skin", "skin3")))
	var dark := skin.darkened(0.2)
	var tribe := AppearanceCatalog.color_of("tribe_color", str(look.get("tribe_color", "ochre")))
	var step := int(c.walk_t * 8.0) % 2 if c.walk_t > 0.0 else -1
	# Legs (alternate lifting while walking).
	c.r(4, 12, 2, 6.0 - (1.0 if step == 1 else 0.0), dark if c.view == "e" else skin)
	c.r(6, 12, 2, 6.0 - (1.0 if step == 0 else 0.0), skin)
	# Arms: the far arm is shaded in side views.
	c.r(3, 7, 1, 4, dark if c.view == "e" or c.view == "se" else skin)
	c.r(8, 7, 1, 4, skin)
	# Torso and head.
	c.r(4, 6, 4, 6, skin)
	c.r(4, 1, 4, 5, skin)
	if str(look.get("sex", "male")) == "female" and c.view != "n":
		c.r(4, 7, 4, 2, tribe)
	# Face.
	match c.view:
		"s":
			c.r(5, 3, 1, 1, EYE)
			c.r(6, 3, 1, 1, EYE)
		"se":
			c.r(6, 3, 1, 1, EYE)
			c.r(7, 3, 1, 1, EYE)
		"e":
			c.r(6, 3, 1, 1, EYE)
			c.r(8, 3, 1, 1, skin)
	var paint_id := str(look.get("paint", "none"))
	if paint_id != "none" and not c.back():
		var paint := AppearanceCatalog.paint_color(paint_id)
		c.r(5, 4, 2, 1, paint)
		c.r(5, 10, 2, 1, paint)


static func _lower(c: Ctx, piece: String, look: Dictionary) -> void:
	var tribe := AppearanceCatalog.color_of("tribe_color", str(look.get("tribe_color", "ochre")))
	if piece == "hide_skirt":
		c.r(3, 11, 6, 4, Color(0.61, 0.48, 0.33))
		c.r(3, 14, 6, 1, tribe)
	else:
		c.r(4, 11, 4, 2, tribe)
		c.r(5, 13, 2, 1, tribe.darkened(0.25))


static func _armor(c: Ctx, piece: String) -> void:
	match piece:
		"hide_wrap":
			c.r(4, 7, 4, 4, Color(0.65, 0.52, 0.35))
			c.r(4, 7, 1, 4, Color(0.49, 0.37, 0.24))
		"leather_armor":
			c.r(3, 6, 6, 6, Color(0.48, 0.31, 0.16))
			c.r(3, 8, 6, 1, Color(0.35, 0.21, 0.10))
		"bone_hide":
			c.r(3, 6, 6, 6, Color(0.48, 0.35, 0.23))
			if not c.back():
				c.r(4, 7, 1, 1, BONE)
				c.r(6, 7, 1, 1, BONE)
				c.r(5, 9, 1, 1, BONE)
				c.r(7, 9, 1, 1, BONE)


static func _hair(c: Ctx, piece: String, look: Dictionary) -> void:
	var hair := AppearanceCatalog.color_of("hair_color", str(look.get("hair_color", "black")))
	var tribe := AppearanceCatalog.color_of("tribe_color", str(look.get("tribe_color", "ochre")))
	if c.back():
		# Seen from behind, hair covers the head.
		c.r(4, 0, 4, 5 if c.view == "n" else 4, hair)
		if piece == "long":
			c.r(4, 5, 4, 3, hair)
		elif piece == "braids":
			c.r(4, 5, 1, 5, hair)
			c.r(7, 5, 1, 5, hair)
		return
	c.r(4, 0, 4, 2, hair)
	match piece:
		"short":
			if c.view != "s":
				c.r(4, 2, 1, 1, hair)
		"long":
			if c.view == "s":
				c.r(3, 1, 1, 6, hair)
				c.r(8, 1, 1, 6, hair)
			else:
				c.r(3, 1, 2, 6, hair)
		"braids":
			if c.view == "s":
				c.r(3, 2, 1, 7, hair)
				c.r(8, 2, 1, 7, hair)
				c.r(8, 9, 1, 1, tribe)
			else:
				c.r(3, 2, 1, 7, hair)
			c.r(3, 9, 1, 1, tribe)


static func _headwear(c: Ctx, piece: String) -> void:
	match piece:
		"animal_hood":
			c.r(3, -1, 6, 3, FUR)
			c.r(3, -2, 1, 1, FUR)
			c.r(8, -2, 1, 1, FUR)
			match c.view:
				"s":
					c.r(5, 1, 2, 1, FUR.darkened(0.3))
				"se":
					c.r(7, 1, 2, 1, FUR.darkened(0.3))
				"e":
					c.r(8, 0, 2, 1, FUR.darkened(0.3))
				"n":
					c.r(3, 2, 6, 3, FUR)
			if not c.back():
				c.r(3, 2, 1, 4, FUR)
		"bone_headband":
			c.r(4, 2, 4, 1, BONE)


static func _cloak(c: Ctx) -> void:
	match c.view:
		"s":
			c.r(2, 6, 8, 8, FUR)
		"n":
			c.r(3, 6, 6, 8, FUR)
			c.r(3, 6, 6, 1, FUR.lightened(0.2))
		"ne":
			c.r(3, 6, 5, 8, FUR)
			c.r(3, 6, 5, 1, FUR.lightened(0.2))
		_:
			c.r(2, 6, 5, 8, FUR)
			c.r(2, 6, 6, 1, FUR.lightened(0.2))


static func _shield(c: Ctx, piece: String, look: Dictionary) -> void:
	var tribe := AppearanceCatalog.color_of("tribe_color", str(look.get("tribe_color", "ochre")))
	var face := Color(0.69, 0.54, 0.36) if piece == "hide_shield" else BONE
	var tall := 5.0 if piece == "hide_shield" else 7.0
	var top := 7.0 if piece == "hide_shield" else 6.0
	if c.back():
		# From behind we see the shield's back: plain frame, no emblem.
		c.r(1, top, 3, tall, face.darkened(0.3))
	else:
		c.r(1, top, 3, tall, face)
		c.r(2, top + 1.0, 1, tall - 2.0, tribe)


static func _weapon(c: Ctx, piece: String) -> void:
	var sw := 0.0
	if c.swing_t > 0.0:
		sw = 2.0 if c.swing_t < 0.13 else 1.0
	match piece:
		"club":
			c.r(9, 6, 1, 6, WOOD)
			c.r(9 + sw, 3, 2, 4, WOOD.darkened(0.25))
		"spear":
			c.r(9 + sw, -2, 1, 15, WOOD)
			c.r(9 + sw, -4, 1, 2, STONE)
		"stone_axe":
			c.r(9, 4, 1, 8, WOOD)
			c.r(10 + sw, 4, 2, 3, STONE)
		"flail":
			c.r(9, 8, 1, 4, WOOD)
			c.r(9 + sw * 0.5, 6, 1, 2, LEATHER)
			c.r(9 + sw, 3, 2, 3, STONE)
		"sling":
			c.r(9, 9, 1, 3, LEATHER)
			c.r(10 + sw, 11, 1, 1, STONE)


## A wolf facing `dir`.
static func draw_wolf(ci: CanvasItem, origin: Vector2, px: float, dir: int = Directions.S, walk_t: float = 0.0, swing_t: float = 0.0) -> void:
	var view := Directions.view_of(dir)
	var mirrored := Directions.is_mirrored(dir)
	_shadow(ci, origin, px, 11.0)
	var tex = SpriteLibrary.frame_at("beasts", "wolf", view, "walk" if walk_t > 0.0 else "", walk_t)
	if tex != null:
		SpriteLibrary.draw(ci, tex, origin, px * 0.5 * SpriteLibrary.SPRITE_SCALE, mirrored)
		return
	var c := Ctx.new()
	c.ci = ci
	c.o = origin
	c.px = px
	c.view = view
	c.mirrored = mirrored
	var fur := Color(0.47, 0.45, 0.42)
	var fur_dark := fur.darkened(0.25)
	var step := int(walk_t * 10.0) % 2 if walk_t > 0.0 else 0
	var lunge := 1.0 if swing_t > 0.0 else 0.0
	match view:
		"s":
			c.r(3, 10, 6, 4, fur_dark)
			c.r(4, 14, 1, 4.0 - float(step), fur_dark)
			c.r(7, 14, 1, 4.0 - float(1 - step), fur_dark)
			c.r(4, 7 + lunge, 4, 4, fur)
			c.r(4, 6 + lunge, 1, 1, fur_dark)
			c.r(7, 6 + lunge, 1, 1, fur_dark)
			c.r(5, 8 + lunge, 1, 1, Color(0.95, 0.80, 0.35))
			c.r(6, 8 + lunge, 1, 1, Color(0.95, 0.80, 0.35))
			c.r(5, 10 + lunge, 2, 1, EYE)
		"n":
			c.r(4, 14, 1, 4.0 - float(step), fur_dark)
			c.r(7, 14, 1, 4.0 - float(1 - step), fur_dark)
			c.r(3, 9, 6, 5, fur)
			c.r(4, 6, 4, 3, fur_dark)
			c.r(4, 5, 1, 1, fur_dark)
			c.r(7, 5, 1, 1, fur_dark)
			c.r(5, 13, 2, 3, fur_dark)
		_:
			var head_y := 7.0 if view == "ne" else 9.0 if view == "se" else 8.0
			c.r(0, 10, 2, 1, fur_dark)
			c.r(3, 14, 1, 4.0 - float(step), fur_dark)
			c.r(8, 14, 1, 4.0 - float(1 - step), fur_dark)
			c.r(2, 10, 8, 4, fur)
			c.r(4, 14, 1, 4.0 - float(1 - step), fur)
			c.r(9, 14, 1, 4.0 - float(step), fur)
			c.r(9 + lunge, head_y, 3, 3, fur)
			c.r(10 + lunge, head_y - 1.0, 1, 1, fur_dark)
			if view != "ne":
				c.r(10 + lunge, head_y + 1.0, 1, 1, Color(0.95, 0.80, 0.35))
				c.r(12 + lunge, head_y + 2.0, 1, 1, EYE)
