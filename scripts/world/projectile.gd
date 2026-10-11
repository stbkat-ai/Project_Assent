extends Node2D
## A thrown or slung stone. Flies at its target and applies the hit on arrival,
## where a shield's block chance can stop it.

const SPEED := 420.0

var target = null  # creature
var source = null  # creature that fired it
var damage := 1
var damage_type := "pierce"


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
	position += to.normalized() * SPEED * delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2(-2, -2), Vector2(4, 4)), Color(0.55, 0.54, 0.51))
