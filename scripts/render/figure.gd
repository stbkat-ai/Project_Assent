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
const Rig = preload("res://scripts/data/rig.gd")
const GearCatalog = preload("res://scripts/data/gear_catalog.gd")
const WalkRig = preload("res://scripts/data/walk_rig.gd")

## How long an attack takes to play, in seconds.
const ATTACK_TIME := 0.45
## Attack keyframes, timed from the poses in Luke's animation template sheet:
## [time 0-1, weapon turn (radians, + = forward/down), weapon push forward,
## body lean forward, crouch] (pushes and leans in art pixels).
const ATTACK_POSES := {
	# Spear: draw back low, lunge with the spear level, recover.
	"thrust": [[0.0, 0.0, 0.0, 0.0, 0.0], [0.3, -0.3, -2.0, -0.5, 1.0], [0.55, 0.4, 6.0, 2.0, 0.0],
		[0.8, 0.3, 4.0, 1.5, 0.0], [1.0, 0.0, 0.0, 0.0, 0.0]],
	# Club and axe: raise it back overhead, crouch, swing down and forward, follow through.
	"swing": [[0.0, 0.0, 0.0, 0.0, 0.0], [0.35, -1.4, -1.0, -0.8, 1.0], [0.6, 0.55, 3.0, 2.5, 0.5],
		[0.8, 0.75, 2.0, 1.5, 0.5], [1.0, 0.0, 0.0, 0.0, 0.0]],
	# Spear sweep and overhead stab (the soldier weapon sheet's attacks 2 and 3).
	"sweep_thrust": [[0.0, 0.0, 0.0, 0.0, 0.0], [0.3, -0.9, -1.0, -0.5, 0.5], [0.6, 0.9, 3.0, 1.5, 0.0],
		[0.8, 1.1, 2.0, 1.0, 0.0], [1.0, 0.0, 0.0, 0.0, 0.0]],
	"overhead_thrust": [[0.0, 0.0, 0.0, 0.0, 0.0], [0.35, -0.8, 0.0, -0.6, -1.0], [0.6, 0.7, 5.0, 2.0, 1.0],
		[0.8, 0.5, 3.0, 1.5, 0.5], [1.0, 0.0, 0.0, 0.0, 0.0]],
	# Club and axe: a big overhead smash, and a low sideways sweep.
	"overhead": [[0.0, 0.0, 0.0, 0.0, 0.0], [0.4, -2.0, -1.5, -1.0, -0.5], [0.65, 1.0, 3.0, 3.0, 1.5],
		[0.85, 1.0, 2.0, 2.0, 1.0], [1.0, 0.0, 0.0, 0.0, 0.0]],
	"sweep": [[0.0, 0.0, 0.0, 0.0, 0.0], [0.3, -0.6, -2.0, 0.0, 0.5], [0.6, 1.2, 4.0, 1.5, 0.5],
		[0.8, 1.4, 3.0, 1.0, 0.0], [1.0, 0.0, 0.0, 0.0, 0.0]],
	# Sling and bow: pull back and release.
	"shoot": [[0.0, 0.0, 0.0, 0.0, 0.0], [0.4, 0.0, -2.0, 0.0, 0.0], [0.6, 0.0, -2.5, 0.0, 0.0], [1.0, 0.0, 0.0, 0.0, 0.0]],
}
## The attacks a weapon kind mixes between (each swing picks one).
const ATTACK_VARIANTS := {
	"thrust": ["thrust", "sweep_thrust", "overhead_thrust"],
	"swing": ["swing", "overhead", "sweep"],
	"shoot": ["shoot"],
	"punch": ["thrust"],
}
## Share of the attack spent in the lunge stance (widest walk stride).
const LUNGE_FROM := 0.45
const LUNGE_TO := 0.85

## The direction a figure faces, in each drawn view's own art space (used to
## lean and thrust forward when attacking).
const FORWARD := {"s": Vector2(0, 0.6), "se": Vector2(0.8, 0.4), "e": Vector2(1, 0), "ne": Vector2(0.8, -0.4), "n": Vector2(0, -0.6)}
const WALK_SPEED := 10.0  # walk-cycle radians per second

const GRID_W := 12.0
const GRID_H := 18.0
## Placeholder pixel size that matches sprite art at 1:1. Sprites are drawn at
## px / REF_PX, so art and placeholders stay the same size at any zoom.
const REF_PX := 2.4

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
## Layer order when drawn with real art (the fur mantle is worn over the body;
## war paint is a painted head drawn over the body's head).
const ART_FRONT_ORDER := ["body", "lower", "paint", "armor", "cloak", "hair", "headwear", "shield", "weapon"]
const ART_BACK_ORDER := ["shield", "weapon", "body", "lower", "paint", "armor", "cloak", "hair", "headwear"]


## What each layer shows for this look and gear: layer -> [category, art id, base id].
## The base id is the gear / clothing id ("" = layer not drawn); the art id is the
## sprite to use, which is per body (sex) and pre-colored for skin and hair:
## body_female__skin3, male_long__blond, female_leather_armor, male_paint_red__skin5.
static func pieces(look: Dictionary, gear: Dictionary) -> Dictionary:
	var sex := str(look.get("sex", "male"))
	var skin := str(look.get("skin", "skin3"))
	var hair_id := str(look.get("hair", "short"))
	var hair_color := str(look.get("hair_color", "black"))
	var body_gear := str(gear.get("body", "none_body"))
	var off := str(gear.get("off_hand", "none_off"))
	var main := str(gear.get("main_hand", "fists"))
	var headwear := str(look.get("headwear", "none"))
	var cloak := str(look.get("cloak", "none"))
	var paint := str(look.get("paint", "none"))
	var lower := str(look.get("lower", "loincloth"))
	var out := {
		"body": ["bodies", "body_%s__%s" % [sex, skin], "body_" + sex],
		"lower": ["clothing", "", "" if lower == "loincloth" else lower],
		"paint": ["clothing", "", "" if paint == "none" else paint],
		"armor": ["gear", "", "" if body_gear == "none_body" else body_gear],
		"hair": ["hair", "", "" if hair_id == "bald" else hair_id],
		"headwear": ["clothing", "", "" if headwear == "none" else headwear],
		"cloak": ["clothing", "", "" if cloak == "none" else cloak],
		"shield": ["gear", "", "" if off == "none_off" or GearCatalog.is_two_handed(main) else off],
		"weapon": ["gear", "", "" if main == "fists" else main],
	}
	for layer in out:
		var entry: Array = out[layer]
		var base := str(entry[2])
		if layer == "body" or base == "":
			continue
		match str(layer):
			"hair":
				entry[1] = "%s_%s__%s" % [sex, base, hair_color]
			"paint":
				entry[1] = "%s_paint_%s__%s" % [sex, base, skin]
			_:
				entry[1] = "%s_%s" % [sex, base]
	return out


## True when this look has body art, so the figure is drawn from sprites.
static func has_body_art(look: Dictionary) -> bool:
	var body: Array = pieces(look, {})["body"]
	return not SpriteLibrary.frames(str(body[0]), str(body[1]), "s").is_empty()


## True when choosing `id` for editor field `key` shows up in the art for this look
## (used to flag choices that have no art yet).
static func option_has_art(key: String, id: String, look: Dictionary) -> bool:
	var trial := look.duplicate()
	var gear := {}
	var layer := ""
	match key:
		"hair":
			trial["hair"] = id
			layer = "hair"
		"headwear", "cloak", "paint", "lower":
			trial[key] = id
			layer = {"headwear": "headwear", "cloak": "cloak", "paint": "paint", "lower": "lower"}[key]
		"body":
			gear["body"] = id
			layer = "armor"
		"main_hand":
			gear["main_hand"] = id
			layer = "weapon"
		"off_hand":
			gear["off_hand"] = id
			layer = "shield"
		_:
			return true
	var entry: Array = pieces(trial, gear)[layer]
	if str(entry[2]) == "":
		return true  # "none" draws nothing, and bald just shows the bald body
	return not SpriteLibrary.frames(str(entry[0]), str(entry[1]), "s").is_empty()


## A person facing `dir` (0-7, see directions.gd). With body art, every layer
## that has art is drawn from sprites and layers without art are left out (mixing
## code-drawn pieces onto painted bodies would not line up). Without body art the
## whole figure is the code-drawn placeholder.
static func draw_human(ci: CanvasItem, origin: Vector2, px: float, look: Dictionary, gear: Dictionary,
		dir: int = Directions.S, walk_t: float = 0.0, swing_t: float = 0.0, variant: int = 0) -> void:
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
	var back := Directions.is_back_view(c.view)
	if has_body_art(look):
		_draw_art_layers(ci, origin, px, c.view, c.mirrored, back, layer_pieces, walk_t, swing_t, str(look.get("sex", "male")),
			attack_name(GearCatalog.attack_kind(str(gear.get("main_hand", "fists"))), variant))
		return
	for layer in (BACK_ORDER if back else FRONT_ORDER):
		var piece: Array = layer_pieces[layer]
		var id := str(piece[2])
		if layer == "lower" and id == "":
			id = "loincloth"  # drawn as part of the body in the art, but not in the placeholder
		if id == "":
			continue
		_placeholder(c, str(layer), id, look)


## The art version of a person, animated in code from its layers:
## walking lifts the legs in turn and bobs the upper body; attacking leans the
## body forward and thrusts the weapon out from the hand.
static func _draw_art_layers(ci: CanvasItem, origin: Vector2, px: float, view: String, mirrored: bool, back: bool,
		layer_pieces: Dictionary, walk_t: float, swing_t: float, sex: String = "male", attack: String = "thrust") -> void:
	var s := px / REF_PX * SpriteLibrary.SPRITE_SCALE
	var rig_views: Dictionary = Rig.BODIES.get(sex, Rig.BODIES["male"])
	var rig: Dictionary = rig_views.get(view, {})
	var hip := -float(rig.get("hip", -13.0))
	var hand: Vector2 = rig.get("main_hand", Vector2(8, -16))
	var walking := walk_t > 0.0
	var phase := walk_t * WALK_SPEED if walking else 0.0
	var up := Vector2(0, -SpriteLibrary.walk_bob(phase)) if walking else Vector2.ZERO
	var attacking := swing_t > 0.0
	var t := clampf(1.0 - swing_t / ATTACK_TIME, 0.0, 1.0) if attacking else 0.0
	var fwd: Vector2 = FORWARD.get(view, Vector2(1, 0))
	var pose := attack_pose(attack, t) if attacking else [0.0, 0.0, 0.0, 0.0]
	# Facing the viewer or away, a forward swing turns the weapon less on screen.
	var w_angle := float(pose[0]) * (0.35 + 0.65 * absf(fwd.x))
	var w_shift := fwd * float(pose[1])
	var lean := fwd * float(pose[2]) + Vector2(0, float(pose[3]))
	# Walk-cycle legs from the animation template replace the body's own legs
	# while walking and in the lunge of an attack.
	var leg_frames: Array = []
	var legs_h := 0.0
	var legs_rig: Dictionary = WalkRig.legs().get(sex, {}).get(view, {})
	if not legs_rig.is_empty():
		var body_id := str(layer_pieces["body"][1])
		leg_frames = SpriteLibrary.frames("bodies", body_id.replace("body_", "legs_"), view, "walk")
		legs_h = float(legs_rig["legs"])
	var leg_tex = null
	if leg_frames.size() >= 4:
		if attacking and attack != "shoot" and t >= LUNGE_FROM and t <= LUNGE_TO:
			leg_tex = leg_frames[int(legs_rig["lunge"]) % leg_frames.size()]
		elif walking:
			leg_tex = leg_frames[int(phase / (TAU / 4.0)) % 4]
	for layer in (ART_BACK_ORDER if back else ART_FRONT_ORDER):
		var piece: Array = layer_pieces[layer]
		if str(piece[1]) == "":
			continue
		var tex = SpriteLibrary.frame_at(str(piece[0]), str(piece[1]), view, "", 0.0)
		if tex == null:
			continue
		match str(layer):
			"body":
				if leg_tex != null:
					var size: Vector2 = tex.get_size()
					SpriteLibrary.draw(ci, leg_tex, origin, s, mirrored)
					# Upper body overlaps the new legs by 2 px so the bob never opens a gap.
					SpriteLibrary.draw_region(ci, tex, origin, s, mirrored,
						Rect2(0, 0, size.x, minf(size.y, size.y - legs_h + 2.0)), up + lean)
				elif walking:
					SpriteLibrary.draw_walking(ci, tex, origin, s, mirrored, hip, phase, up + lean)
				else:
					SpriteLibrary.draw_region(ci, tex, origin, s, mirrored, Rect2(Vector2.ZERO, tex.get_size()), up + lean)
			"weapon":
				SpriteLibrary.draw_rotated(ci, tex, origin, s, mirrored, hand, w_angle, up + lean + w_shift)
			_:
				SpriteLibrary.draw_region(ci, tex, origin, s, mirrored, Rect2(Vector2.ZERO, tex.get_size()), up + lean)


## Which attack (a key of ATTACK_POSES) variant `variant` of a weapon kind plays.
static func attack_name(kind: String, variant: int) -> String:
	var list: Array = ATTACK_VARIANTS.get(kind, ["thrust"])
	return str(list[posmod(variant, list.size())])


## [weapon turn, weapon push, body lean, crouch] at `t` (0-1) through an attack,
## blended between the keyframes in ATTACK_POSES.
static func attack_pose(attack: String, t: float) -> Array:
	var keys: Array = ATTACK_POSES.get(attack, ATTACK_POSES["thrust"])
	for i in range(1, keys.size()):
		var b: Array = keys[i]
		if t <= float(b[0]):
			var a: Array = keys[i - 1]
			var span := maxf(float(b[0]) - float(a[0]), 0.0001)
			var k := smoothstep(0.0, 1.0, (t - float(a[0])) / span)
			var out: Array = []
			for j in range(1, 5):
				out.append(lerpf(float(a[j]), float(b[j]), k))
			return out
	return [0.0, 0.0, 0.0, 0.0]


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
	match str(GearCatalog.get_item(piece).get("shape", "")):
		"knife":
			c.r(9, 9, 1, 3, WOOD)
			c.r(9 + sw, 6, 1, 3, BONE if piece == "bone_knife" else STONE)
		"club":
			c.r(9, 6, 1, 6, WOOD)
			c.r(9 + sw, 3, 2, 4, BONE if piece == "bone_club" else STONE if piece == "stone_club" else WOOD.darkened(0.25))
		"mace":
			c.r(9, 6, 1, 6, WOOD)
			c.r(8 + sw, 2, 3, 4, STONE)
		"great_club":
			c.r(9, 3, 1, 10, WOOD)
			c.r(8 + sw, -1, 3, 5, WOOD.darkened(0.3))
		"spear":
			var extra := 4.0 if piece == "war_spear" else 0.0
			c.r(9 + sw, -2 - extra, 1, 15 + extra, WOOD)
			c.r(9 + sw, -4 - extra, 1, 2, BONE if piece == "bone_spear" else STONE)
		"halberd":
			c.r(9 + sw, -3, 1, 16, WOOD)
			c.r(10 + sw, -3, 2, 4, STONE)
		"axe":
			c.r(9, 4, 1, 8, WOOD)
			c.r(10 + sw, 4, 2, 3, STONE.darkened(0.2) if piece == "flint_axe" else STONE)
		"flail":
			c.r(9, 8, 1, 4, WOOD)
			c.r(9 + sw * 0.5, 6, 1, 2, LEATHER)
			c.r(9 + sw, 3, 2, 3, STONE)
		"sling":
			c.r(9, 9, 1, 3, LEATHER)
			c.r(10 + sw, 11, 1, 1, STONE)
		"bow":
			c.r(10, 3, 1, 10, WOOD if piece == "bow" else WOOD.darkened(0.3))
			c.r(9, 2, 1, 1, WOOD)
			c.r(9, 13, 1, 1, WOOD)
			c.r(9, 3, 1, 10, BONE.darkened(0.2))


## A wolf facing `dir`.
static func draw_wolf(ci: CanvasItem, origin: Vector2, px: float, dir: int = Directions.S, walk_t: float = 0.0, swing_t: float = 0.0) -> void:
	var view := Directions.view_of(dir)
	var mirrored := Directions.is_mirrored(dir)
	_shadow(ci, origin, px, 11.0)
	var tex = SpriteLibrary.frame_at("beasts", "wolf", view, "walk" if walk_t > 0.0 else "", walk_t)
	if tex != null:
		SpriteLibrary.draw(ci, tex, origin, px / REF_PX * SpriteLibrary.SPRITE_SCALE, mirrored)
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


## A unit drawn from one whole sprite per view (e.g. a hostile caveman or a
## wolf), with a small bob while walking and a lunge while attacking.
## Returns false if there is no art for it, so the caller can draw a placeholder.
static func draw_whole(ci: CanvasItem, origin: Vector2, px: float, category: String, piece: String,
		dir: int, walk_t: float = 0.0, swing_t: float = 0.0) -> bool:
	var view := Directions.view_of(dir)
	var tex = SpriteLibrary.frame_at(category, piece, view, "walk" if walk_t > 0.0 else "", walk_t)
	if tex == null:
		return false
	var o := origin
	if swing_t > 0.0:
		o += Vector2.from_angle(dir * PI / 4.0) * px * 2.0 * sin(PI * clampf(1.0 - swing_t / ATTACK_TIME, 0.0, 1.0))
	_shadow(ci, origin, px, 10.0)
	var s := px / REF_PX * SpriteLibrary.SPRITE_SCALE
	var phase := walk_t * WALK_SPEED
	var up := Vector2(0, -SpriteLibrary.walk_bob(phase)) if walk_t > 0.0 else Vector2.ZERO
	# Legs: roughly the bottom third of a whole-body sprite.
	SpriteLibrary.draw_walking(ci, tex, o, s, Directions.is_mirrored(dir), tex.get_size().y * 0.32,
		phase if walk_t > 0.0 else 0.0, up)
	return true


## The death sprite for a whole-sprite unit, or null.
static func death_frame(category: String, piece: String):
	return SpriteLibrary.frame_at(category, piece, "e", "death", 0.0)
