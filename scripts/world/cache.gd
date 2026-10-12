extends Node2D
## A reward off the beaten path: a cache to walk onto (a weapon to unlock, or points).
## Drawn as one of the huts' yard props, with a glint so it catches the eye.

const SpriteLibrary = preload("res://scripts/render/sprite_library.gd")

var cache_id := ""
var cache_name := ""
var reward := "points"  # "unlock" (value = gear id) or "points" (value = how many)
var value := ""
var look := ""
var _t := 0.0
static var _used := {}


## `data` = [id, name, square x, square y, reward, value, look sprite] (wilderness_map.gd caches()).
func setup(data: Array) -> void:
	cache_id = str(data[0])
	cache_name = str(data[1])
	reward = str(data[4])
	value = str(data[5])
	look = str(data[6])


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var tex = SpriteLibrary.frame_at("buildings", look, "s", "", 0.0)
	if tex != null:
		var region := _used_rect(tex)
		var zoom := 1.6
		draw_texture_rect_region(tex, Rect2(Vector2(-region.size.x * zoom / 2.0, -region.size.y * zoom), region.size * zoom), region)
	else:
		draw_rect(Rect2(-8, -14, 16, 14), Color(0.55, 0.38, 0.2))
	# A pulsing glint.
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	var at := Vector2(6, -26)
	var col := Color(1.0, 0.92, 0.55, 0.4 + 0.5 * pulse)
	draw_line(at + Vector2(-5 - 3 * pulse, 0), at + Vector2(5 + 3 * pulse, 0), col, 2.0)
	draw_line(at + Vector2(0, -5 - 3 * pulse), at + Vector2(0, 5 + 3 * pulse), col, 2.0)


func _used_rect(tex: Texture2D) -> Rect2:
	var key := tex.resource_path
	if not _used.has(key):
		var r := Rect2(Vector2.ZERO, tex.get_size())
		var img := tex.get_image()
		if img != null:
			var u := img.get_used_rect()
			if u.size.x > 0:
				r = Rect2(u)
		_used[key] = r
	return _used[key]
