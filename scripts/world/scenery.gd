extends Node2D
## A tree, bush, rock or plant on a battle map. Scenery sits in the same
## depth-sorted layer as units, so in 3/4 view a unit walking behind a tree is
## hidden by it. Draws assets/sprites/scenery/<piece>/s.png when it exists,
## otherwise a placeholder for its kind.

const SpriteLibrary = preload("res://scripts/render/sprite_library.gd")

var kind := "tree"  # "tree", "bush", "rock" or "plant"
var piece := ""  # sprite id from scenery_catalog.gd
var mirrored := false
var size := 24.0  # placeholder size


func _draw() -> void:
	var tex = SpriteLibrary.frame_at("scenery", piece, "s", "", 0.0)
	if tex != null:
		SpriteLibrary.draw(self, tex, Vector2.ZERO, SpriteLibrary.SPRITE_SCALE, mirrored)
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, size, Color(0, 0, 0, 0.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	match kind:
		"tree":
			draw_rect(Rect2(Vector2(-3, -size * 0.9), Vector2(6, size * 0.9)), Color(0.36, 0.25, 0.15))
			draw_circle(Vector2(0, -size * 1.3), size, Color(0.17, 0.33, 0.15))
			draw_circle(Vector2(-size * 0.3, -size * 1.5), size * 0.6, Color(0.22, 0.40, 0.18))
		"rock":
			draw_circle(Vector2(0, -size * 0.4), size, Color(0.45, 0.44, 0.41))
			draw_circle(Vector2(-size * 0.25, -size * 0.6), size * 0.6, Color(0.55, 0.54, 0.50))
		_:
			draw_circle(Vector2(0, -size * 0.5), size * 0.6, Color(0.22, 0.42, 0.18))
