extends Node2D
## A tree or rock on a battle map. Scenery sits in the same depth-sorted layer
## as units, so in 3/4 view a unit walking behind a tree is hidden by it.
## Uses a sprite from assets/sprites/scenery/<kind>/s.png when one exists.

const SpriteLibrary = preload("res://scripts/render/sprite_library.gd")

var kind := "tree"  # "tree" or "rock"
var size := 24.0


func _draw() -> void:
	var tex = SpriteLibrary.frame_at("scenery", kind, "s", "", 0.0)
	if tex != null:
		SpriteLibrary.draw(self, tex, Vector2.ZERO, SpriteLibrary.SPRITE_SCALE, false)
		return
	# Shadow on the ground.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, size * (1.0 if kind == "tree" else 1.1), Color(0, 0, 0, 0.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if kind == "tree":
		draw_rect(Rect2(Vector2(-3, -size * 0.9), Vector2(6, size * 0.9)), Color(0.36, 0.25, 0.15))
		draw_circle(Vector2(0, -size * 1.3), size, Color(0.17, 0.33, 0.15))
		draw_circle(Vector2(-size * 0.3, -size * 1.5), size * 0.6, Color(0.22, 0.40, 0.18))
	else:
		draw_circle(Vector2(0, -size * 0.4), size, Color(0.45, 0.44, 0.41))
		draw_circle(Vector2(-size * 0.25, -size * 0.6), size * 0.6, Color(0.55, 0.54, 0.50))
