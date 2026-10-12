extends RefCounted
## Finds real sprite images when they exist, so art can replace the
## placeholder drawings one piece at a time. See assets/README.md for the
## folder layout and naming rules.
##
##   res://assets/sprites/<category>/<piece>/<view>.png            still frame
##   res://assets/sprites/<category>/<piece>/<view>_<anim>_<n>.png  animation frames (n = 0, 1, 2, ...)
##
## <view> is one of s, se, e, ne, n. Sprites stand with their feet at the
## bottom-center of the image and are drawn at SPRITE_SCALE screen pixels per
## art pixel at zoom 1.

const ROOT := "res://assets/sprites/"
## Screen pixels per art pixel at zoom 1 (matches the placeholder figures).
const SPRITE_SCALE := 1.0

static var _cache := {}


## All frames of an animation ("walk", "attack", ...), falling back to the
## still frame. Empty when there is no art for this piece and view.
static func frames(category: String, piece: String, view: String, anim: String = "") -> Array:
	var key := "%s/%s/%s/%s" % [category, piece, view, anim]
	if _cache.has(key):
		return _cache[key]
	var found: Array = []
	var base := ROOT + category + "/" + piece + "/" + view
	if anim != "":
		var i := 0
		while ResourceLoader.exists("%s_%s_%d.png" % [base, anim, i]):
			found.append(load("%s_%s_%d.png" % [base, anim, i]))
			i += 1
	if found.is_empty() and ResourceLoader.exists(base + ".png"):
		found.append(load(base + ".png"))
	_cache[key] = found
	return found


## The frame to show at time `t` (seconds) for an animation at `fps`, or null.
static func frame_at(category: String, piece: String, view: String, anim: String, t: float, fps: float = 8.0):
	var list := frames(category, piece, view, anim)
	if list.is_empty():
		return null
	return list[int(t * fps) % list.size()]


## Draw `tex` standing at `origin`, optionally mirrored and tinted.
## `scale` is screen pixels per art pixel.
static func draw(ci: CanvasItem, tex: Texture2D, origin: Vector2, scale: float, mirrored: bool, tint: Color = Color.WHITE) -> void:
	var size := tex.get_size()
	ci.draw_set_transform(origin, 0.0, Vector2(-scale if mirrored else scale, scale))
	ci.draw_texture(tex, Vector2(-size.x / 2.0, -size.y), tint)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Draw only `region` of `tex` (texture pixels), moved by `shift` art pixels.
## Used to animate parts of one sprite, e.g. lifting one leg while walking.
static func draw_region(ci: CanvasItem, tex: Texture2D, origin: Vector2, scale: float, mirrored: bool,
		region: Rect2, shift: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE) -> void:
	var size := tex.get_size()
	ci.draw_set_transform(origin, 0.0, Vector2(-scale if mirrored else scale, scale))
	ci.draw_texture_rect_region(tex, Rect2(Vector2(-size.x / 2.0, -size.y) + region.position + shift, region.size), region, tint)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Draw `tex` turned by `angle` (radians) around `pivot`, then moved by `shift`.
## `pivot` and `shift` are in art pixels from the feet (e.g. a hand holding a weapon).
static func draw_rotated(ci: CanvasItem, tex: Texture2D, origin: Vector2, scale: float, mirrored: bool,
		pivot: Vector2, angle: float, shift: Vector2 = Vector2.ZERO) -> void:
	var size := tex.get_size()
	var xf := Transform2D(0.0, Vector2(-scale if mirrored else scale, scale), 0.0, origin)
	xf = xf * Transform2D(0.0, pivot + shift) * Transform2D(angle, Vector2.ZERO) * Transform2D(0.0, -pivot)
	ci.draw_set_transform_matrix(xf)
	ci.draw_texture(tex, Vector2(-size.x / 2.0, -size.y))
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Draw a standing sprite with its legs stepping: the part below `hip` (art
## pixels above the feet) is split into left and right halves that lift in turn,
## and the upper body bobs. `phase` advances while walking.
static func draw_walking(ci: CanvasItem, tex: Texture2D, origin: Vector2, scale: float, mirrored: bool,
		hip: float, phase: float, upper_shift: Vector2 = Vector2.ZERO) -> void:
	var size := tex.get_size()
	var leg_top := clampf(size.y - hip, 0.0, size.y)
	var lift_a := maxf(0.0, sin(phase)) * 2.5
	var lift_b := maxf(0.0, -sin(phase)) * 2.5
	var half := floorf(size.x / 2.0)
	draw_region(ci, tex, origin, scale, mirrored, Rect2(0, leg_top, half, size.y - leg_top), Vector2(0, -lift_a))
	draw_region(ci, tex, origin, scale, mirrored, Rect2(half, leg_top, size.x - half, size.y - leg_top), Vector2(0, -lift_b))
	# Upper body (overlapping the legs by 2 px so the bob never opens a gap).
	draw_region(ci, tex, origin, scale, mirrored, Rect2(0, 0, size.x, minf(size.y, leg_top + 2.0)), upper_shift)


## How far the upper body rises during a walk cycle at `phase`.
static func walk_bob(phase: float) -> float:
	return absf(sin(phase)) * 1.0
