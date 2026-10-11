extends Node2D
## Anything that walks and fights on a battle map: the leader hero, wild
## animals, hostile cavemen. Later, squad members reuse this.
##
## Player units follow commands (move_target / target). Wild units run a small
## AI: wander near home, chase anything hostile that comes close, give up and
## go home if pulled too far away.

signal died(creature: Node2D)

const Figure = preload("res://scripts/render/figure.gd")
const Directions = preload("res://scripts/render/directions.gd")
const UnitStats = preload("res://scripts/data/unit_stats.gd")
const Projectile = preload("res://scripts/world/projectile.gd")

const PX := 2.4  # screen size of one placeholder pixel at zoom 1 (matches sprite art)
const BODY_CENTER := Vector2(0, -20)
const Corpse = preload("res://scripts/world/corpse.gd")
const HIT_RADIUS := 26.0
const HERO_REST_DELAY := 4.0  # seconds without being hit before healing starts
const HERO_REGEN_PER_SEC := 0.08  # share of max HP healed per second

var team := "wild"  # "player" or "wild"
var kind := "human"  # "human" or "wolf"
var display_name := ""
var is_hero := false
## Whole-body sprite for units drawn from one image per view, e.g.
## "units" / "caveman_spear" or "beasts" / "wolf_gray". Empty = layered figure.
var sprite_category := ""
var sprite_piece := ""
var look: Dictionary = {}
var gear: Dictionary = {}

var max_hp := 40
var hp := 40
var damage := 2
var damage_type := "blunt"
var attack_interval := 1.0
var attack_range := 22.0
var ranged := false
var armor := 0
var block := 0.0
var speed := 80.0

var aggro_radius := 230.0
var leash_radius := 520.0
var bounds := Rect2(0, 0, 3000, 2000)
var home := Vector2.ZERO

var move_target = null  # Vector2 or null
var target = null  # creature or null
var dir := Directions.S  # facing, 0-7 (see directions.gd)
var selected := false

var _cooldown := 0.0
var _walk_t := 0.0
var _swing_t := 0.0
var _hurt_t := 0.0
var _wander_t := 0.0
var _returning := false
var _since_hit := 99.0
var _regen := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("creatures")
	_rng.randomize()
	home = position


## Copy stats worked out by UnitStats.compute().
func apply_stats(stats: Dictionary) -> void:
	max_hp = int(stats["hp"])
	hp = max_hp
	damage = int(stats["damage"])
	damage_type = str(stats["damage_type"])
	attack_interval = float(stats["interval"])
	attack_range = float(stats["range"])
	ranged = bool(stats["ranged"])
	armor = int(stats["armor"])
	block = float(stats["block"])
	speed = float(stats["speed"])


func is_alive() -> bool:
	return hp > 0


func order_move(point: Vector2) -> void:
	target = null
	move_target = point


func order_attack(enemy) -> void:
	move_target = null
	target = enemy


func _process(delta: float) -> void:
	if hp <= 0:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_swing_t = maxf(0.0, _swing_t - delta)
	_hurt_t = maxf(0.0, _hurt_t - delta)
	modulate = Color(1.0, 0.55, 0.5) if _hurt_t > 0.0 else Color.WHITE
	_since_hit += delta
	if is_hero:
		_heal_out_of_combat(delta)

	if target != null and (not is_instance_valid(target) or not target.is_alive()):
		target = null
	if team == "wild":
		_think(delta)
	elif target == null and move_target == null:
		var nearby = _nearest_enemy(70.0)
		if nearby != null:
			target = nearby

	var moving := false
	if target != null:
		var dist := position.distance_to(target.position)
		if dist > attack_range:
			moving = _step_toward(target.position, delta)
		else:
			_face(target.position)
			if _cooldown <= 0.0:
				_attack(target)
	elif move_target != null:
		if position.distance_to(move_target) < 4.0:
			move_target = null
			_returning = false
		else:
			moving = _step_toward(move_target, delta)

	_separate(delta)
	_walk_t = _walk_t + delta if moving else 0.0
	queue_redraw()


## Heroes recover when they haven't been hit for a few seconds.
func _heal_out_of_combat(delta: float) -> void:
	if _since_hit < HERO_REST_DELAY or hp >= max_hp:
		_regen = 0.0
		return
	_regen += max_hp * HERO_REGEN_PER_SEC * delta
	if _regen >= 1.0:
		var amount := int(_regen)
		_regen -= amount
		hp = mini(max_hp, hp + amount)


func _think(delta: float) -> void:
	if _returning:
		hp = mini(max_hp, hp + int(ceil(max_hp * 0.5 * delta)))
		return
	if target != null and position.distance_to(home) > leash_radius:
		target = null
		move_target = home
		_returning = true
		return
	if target == null:
		var enemy = _nearest_enemy(aggro_radius)
		if enemy != null:
			target = enemy
			move_target = null
			return
		if move_target == null:
			_wander_t -= delta
			if _wander_t <= 0.0:
				_wander_t = _rng.randf_range(2.0, 5.0)
				move_target = home + Vector2(_rng.randf_range(-90, 90), _rng.randf_range(-90, 90))


func _nearest_enemy(radius: float):
	var best = null
	var best_dist := radius
	for node in get_tree().get_nodes_in_group("creatures"):
		var other = node
		if other == self or other.team == team or not other.is_alive():
			continue
		var d: float = position.distance_to(other.position)
		if d < best_dist:
			best_dist = d
			best = other
	return best


func _step_toward(point: Vector2, delta: float) -> bool:
	var to := point - position
	var dist := to.length()
	if dist < 0.5:
		return false
	position += to / dist * minf(speed * delta, dist)
	position = position.clamp(bounds.position, bounds.end)
	_face(point)
	return true


func _face(point: Vector2) -> void:
	var to := point - position
	if to.length() > 2.0:
		dir = Directions.from_vector(to)


## Gently push apart units that stand on top of each other.
func _separate(delta: float) -> void:
	for node in get_tree().get_nodes_in_group("creatures"):
		var other = node
		if other == self or not other.is_alive():
			continue
		var away: Vector2 = position - other.position
		var d := away.length()
		if d < 18.0:
			if d < 0.01:
				away = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
				d = maxf(away.length(), 0.01)
			position += away / d * (18.0 - d) * 4.0 * delta


func _attack(enemy) -> void:
	_cooldown = attack_interval
	_swing_t = 0.25
	if ranged:
		var shot := Projectile.new()
		shot.position = position + BODY_CENTER
		shot.target = enemy
		shot.source = self
		shot.damage = damage
		shot.damage_type = damage_type
		get_parent().add_child(shot)
	else:
		enemy.take_hit(damage, damage_type, false, self)


func take_hit(amount: int, dtype: String, from_range: bool, attacker) -> void:
	if hp <= 0:
		return
	var dealt := UnitStats.resolve_damage(amount, dtype, armor, from_range, block, _rng.randf())
	if dealt <= 0:
		return
	hp -= dealt
	_hurt_t = 0.15
	_since_hit = 0.0
	if attacker != null and is_instance_valid(attacker) and target == null:
		if team == "wild" and not _returning:
			target = attacker
			move_target = null
		elif team == "player" and move_target == null:
			target = attacker
	if hp <= 0:
		hp = 0
		died.emit(self)
		_leave_corpse()
		queue_free()


func _draw() -> void:
	if selected:
		# A ring lying flat on the ground (an ellipse in 3/4 view).
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 32, Color(0.95, 0.80, 0.30, 0.9), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var drawn := false
	if sprite_piece != "":
		drawn = Figure.draw_whole(self, Vector2.ZERO, PX, sprite_category, sprite_piece, dir, _walk_t, _swing_t)
	if not drawn:
		if kind == "wolf":
			Figure.draw_wolf(self, Vector2.ZERO, PX, dir, _walk_t, _swing_t)
		else:
			Figure.draw_human(self, Vector2.ZERO, PX, look, gear, dir, _walk_t, _swing_t)
	if hp < max_hp or is_hero:
		var w := 30.0
		var top := -56.0
		draw_rect(Rect2(Vector2(-w / 2.0, top), Vector2(w, 4)), Color(0, 0, 0, 0.6))
		var bar_col := Color(0.35, 0.80, 0.35) if team == "player" else Color(0.85, 0.30, 0.25)
		draw_rect(Rect2(Vector2(-w / 2.0, top), Vector2(w * float(hp) / float(max_hp), 4)), bar_col)


func _leave_corpse() -> void:
	if sprite_piece == "" or get_parent() == null:
		return
	var tex = Figure.death_frame(sprite_category, sprite_piece)
	if tex == null:
		return
	var body := Corpse.new()
	body.tex = tex
	body.mirrored = dir == Directions.SW or dir == Directions.W or dir == Directions.NW
	body.scale_factor = PX / Figure.REF_PX
	body.position = position
	get_parent().add_child(body)
