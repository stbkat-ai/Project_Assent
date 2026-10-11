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
