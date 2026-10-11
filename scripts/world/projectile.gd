extends Node2D
## A thrown or slung stone, or an arrow. Flies at its target and applies the hit
## on arrival, where a shield's block chance can stop it. Drawn from
## assets/sprites/projectiles/<piece>/e.png (art points right; turned to its flight).

const SpriteLibrary = preload("res://scripts/render/sprite_library.gd")
const SPEED := 420.0

var target = null  # creature
var source = null  # creature that fired it
var damage := 1
var damage_type := "pierce"
var piece := "sling_stone"
var _heading := Vector2.RIGHT


## The projectile art for a weapon.
static func piece_for(weapon_id: String) -> String:
	if weapon_id.ends_with("bow"):
		return "arrow"
	if weapon_id.ends_with("knife"):
		return "knife"
	if weapon_id == "throwing_spear":
		return "throwing_spear"
	return "sling_stone"


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target) or not target.is_alive():
		queue_free()
		return
	var aim: Vector2 = target.position + Vector2(0, -18)
	var to := aim - position
	if to.length() <= SPEED * delta:
		var attacker = source if is_instance_valid(source) else null
		target.take_hit(damage, damage_type, true, attacker)
		queue_free()
		return
	_heading = to.normalized()
	position += _heading * SPEED * delta
	queue_redraw()


func _draw() -> void:
	var tex = SpriteLibrary.frame_at("projectiles", piece, "e", "", 0.0)
	if tex == null:
		draw_rect(Rect2(Vector2(-2, -2), Vector2(4, 4)), Color(0.55, 0.54, 0.51))
		return
	var size: Vector2 = tex.get_size()
	draw_set_transform(Vector2.ZERO, _heading.angle(), Vector2.ONE)
	draw_texture(tex, -size / 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
