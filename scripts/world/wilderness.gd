extends Node2D
## Prototype B (opening phase 2): the leader alone in an untamed wilderness.
## Goal: reach the marked clearing and make it safe, so the tribe can settle.
##
## Controls (phone): tap the ground to walk, tap an enemy to attack,
## drag to pan, pinch to zoom, tap the leader's card to re-center.
## Desktop: the same with the mouse, and the wheel to zoom.

signal finished(action: String)  # "menu" or "retry"

const GameState = preload("res://scripts/game_state.gd")
const Creature = preload("res://scripts/world/creature.gd")
const UnitStats = preload("res://scripts/data/unit_stats.gd")
const AppearanceCatalog = preload("res://scripts/data/appearance_catalog.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")
const Scenery = preload("res://scripts/world/scenery.gd")

const WORLD := Rect2(0, 0, 3000, 2000)
const START := Vector2(320, 1600)
const SITE := Vector2(2550, 520)
const SITE_RADIUS := 130.0
const SITE_GUARD_RADIUS := 480.0
const TAP_SLOP := 14.0
const MIN_ZOOM := 0.6
const MAX_ZOOM := 2.4

## In 3/4 top-down view, circles on the ground look squashed vertically.
const GROUND_SQUASH := 0.6

const GROUND := Color(0.29, 0.40, 0.20)
const GROUND_DARK := Color(0.24, 0.34, 0.17)

var state: GameState
var hero: Creature
var _units: Node2D
var _camera: Camera2D
var _follow := true
var _over := false

var _trees: Array = []  # [position, size]
var _rocks: Array = []  # [position, size]
var _tufts: Array = []  # positions
var _marker_pos := Vector2.ZERO
var _marker_t := 0.0
var _time := 0.0

# Input tracking.
var _press_pos = null  # Vector2 while the primary pointer is down
var _dragged := false
var _touches := {}  # touch index -> position
var _pinch_dist := 0.0
var _gestured := false

# UI.
var _objective: Label
var _hero_card: Button
var _overlay: Control


func setup(game_state: GameState) -> void:
	state = game_state


func _ready() -> void:
	_generate_scenery()

	_units = Node2D.new()
	_units.y_sort_enabled = true
	add_child(_units)
	for t in _trees:
		_add_scenery("tree", t[0], t[1])
	for r in _rocks:
		_add_scenery("rock", r[0], r[1])

	hero = _spawn_human(START, "player", state.leader["look"], state.leader["gear"], true)
	hero.display_name = str(state.leader["name"])
	hero.selected = true

	# Two wolf packs on the way, cavemen holding the clearing.
	for p in [Vector2(1050, 1300), Vector2(1120, 1370)]:
		_spawn_wolf(p, false)
	_spawn_wolf(Vector2(1850, 930), false)
	for p in [Vector2(2380, 430), Vector2(2700, 640)]:
		_spawn_caveman(p, true)
	_spawn_wolf(Vector2(2520, 760), true)

	_camera = Camera2D.new()
	_camera.position = hero.position
	_camera.zoom = Vector2(1.3, 1.3)
	_camera.limit_left = int(WORLD.position.x) - 200
	_camera.limit_top = int(WORLD.position.y) - 200
	_camera.limit_right = int(WORLD.end.x) + 200
	_camera.limit_bottom = int(WORLD.end.y) + 200
	add_child(_camera)
	_camera.make_current()

	_build_ui()


# --- Spawning --------------------------------------------------------------

func _spawn_human(pos: Vector2, team: String, look: Dictionary, gear: Dictionary, is_hero: bool) -> Creature:
	var c := Creature.new()
	c.position = pos
	c.team = team
	c.kind = "human"
	c.look = look
	c.gear = gear
	c.is_hero = is_hero
	c.bounds = WORLD
	c.apply_stats(UnitStats.compute(gear, is_hero))
	c.died.connect(_on_creature_died)
	_units.add_child(c)
	return c


func _add_scenery(kind: String, pos: Vector2, size: float) -> void:
	var s := Scenery.new()
	s.kind = kind
	s.size = size
	s.position = pos
	_units.add_child(s)


func _spawn_caveman(pos: Vector2, guards_site: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 31 + pos.y)
	var look := AppearanceCatalog.random_look(rng)
	look["tribe_color"] = "ash"
	look["headwear"] = "bone_headband"
	var c := _spawn_human(pos, "wild", look, {"body": "hide_wrap", "main_hand": "club", "off_hand": "none_off"}, false)
	c.display_name = "Hostile caveman"
	c.max_hp = 30
	c.hp = 30
	c.aggro_radius = 170.0
	if guards_site:
		c.add_to_group("site_guards")


func _spawn_wolf(pos: Vector2, guards_site: bool) -> void:
	var c := Creature.new()
	c.position = pos
	c.team = "wild"
	c.kind = "wolf"
	c.display_name = "Wolf"
	c.bounds = WORLD
	c.apply_stats({"hp": 20, "damage": 3, "damage_type": "slash", "interval": 1.0, "range": 22.0,
		"ranged": false, "armor": 0, "block": 0.0, "speed": 100.0})
	c.aggro_radius = 190.0
	c.died.connect(_on_creature_died)
	if guards_site:
		c.add_to_group("site_guards")
	_units.add_child(c)


func _generate_scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	while _trees.size() < 140:
		var p := Vector2(rng.randf_range(0, WORLD.size.x), rng.randf_range(0, WORLD.size.y))
		if p.distance_to(START) < 220 or p.distance_to(SITE) < SITE_RADIUS + 60:
			continue
		_trees.append([p, rng.randf_range(18, 30)])
	for i in 60:
		_rocks.append([Vector2(rng.randf_range(0, WORLD.size.x), rng.randf_range(0, WORLD.size.y)), rng.randf_range(6, 14)])
	for i in 500:
		_tufts.append(Vector2(rng.randf_range(0, WORLD.size.x), rng.randf_range(0, WORLD.size.y)))


# --- Frame update ------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	_marker_t = maxf(0.0, _marker_t - delta)
	if _follow and is_instance_valid(hero):
		_camera.position = _camera.position.lerp(hero.position, minf(1.0, delta * 6.0))
	if is_instance_valid(hero) and hero.is_alive():
		_hero_card.text = "%s   HP %d/%d" % [hero.display_name, hero.hp, hero.max_hp]
		_update_objective()
	queue_redraw()


func _guards_left() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group("site_guards"):
		var guard = node
		if guard.is_alive():
			count += 1
	return count


func _update_objective() -> void:
	if _over:
		return
	var offset := hero.position - SITE
	var at_site := Vector2(offset.x, offset.y / GROUND_SQUASH).length() <= SITE_RADIUS
	var guards := _guards_left()
	if guards > 0:
		if at_site or hero.position.distance_to(SITE) < SITE_GUARD_RADIUS:
			_objective.text = "Drive off the creatures holding the clearing (%d left)" % guards
		else:
			_objective.text = "Find a home for your people: reach the clearing to the northeast"
	elif not at_site:
		_objective.text = "The clearing is safe. Walk into it to claim it"
	else:
		_show_overlay("Your people have a home",
			"%s has claimed the clearing. Next: designing and building the village (Prototype C)." % hero.display_name,
			[["Play again", "retry"], ["Main menu", "menu"]])


func _on_creature_died(c: Node2D) -> void:
	if c == hero:
		_show_overlay("%s has fallen" % hero.display_name,
			"The wilderness is not kind. Try different gear, or pick your fights more carefully.",
			[["Try again", "retry"], ["Main menu", "menu"]])


# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(WORLD.position - Vector2(600, 600), WORLD.size + Vector2(1200, 1200)), GROUND_DARK.darkened(0.3))
	draw_rect(WORLD, GROUND)
	for p in _tufts:
		draw_rect(Rect2(p, Vector2(3, 5)), GROUND_DARK)

	# The clearing: a circle lying on the ground.
	var pulse := 0.5 + 0.5 * sin(_time * 3.0)
	draw_set_transform(SITE, 0.0, Vector2(1.0, GROUND_SQUASH))
	draw_circle(Vector2.ZERO, SITE_RADIUS, Color(0.42, 0.50, 0.27))
	draw_arc(Vector2.ZERO, SITE_RADIUS, 0.0, TAU, 64, Color(0.95, 0.80, 0.30, 0.4 + 0.4 * pulse), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(SITE + Vector2(-2, -60), Vector2(4, 60)), Color(0.45, 0.31, 0.18))
	draw_colored_polygon(PackedVector2Array([SITE + Vector2(2, -60), SITE + Vector2(34, -50), SITE + Vector2(2, -40)]),
		Color(0.85, 0.64, 0.25))

	if _marker_t > 0.0:
		var r := 8.0 + (1.0 - _marker_t) * 12.0
		draw_set_transform(_marker_pos, 0.0, Vector2(1.0, GROUND_SQUASH))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(1, 1, 1, _marker_t), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Input -------------------------------------------------------------------

func _unhandled_input(input_event: InputEvent) -> void:
	if _over:
		return
	var event = input_event  # untyped: fields differ per event class
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		if _touches.size() >= 2:
			_gestured = true
			_pinch_dist = _two_finger_distance()
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			var d := _two_finger_distance()
			if _pinch_dist > 0.0 and d > 0.0:
				_set_zoom(_camera.zoom.x * d / _pinch_dist)
			_pinch_dist = d
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_set_zoom(_camera.zoom.x * 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_set_zoom(_camera.zoom.x / 1.1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_pos = event.position
				_dragged = false
				if _touches.size() <= 1:
					_gestured = false
			else:
				if _press_pos != null and not _dragged and not _gestured:
					_tap(event.position)
				_press_pos = null
	elif event is InputEventMouseMotion:
		if _press_pos != null and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if not _dragged and event.position.distance_to(_press_pos) > TAP_SLOP:
				_dragged = true
			if _dragged and not _gestured and _touches.size() < 2:
				_follow = false
				_camera.position -= event.relative / _camera.zoom.x
				_camera.position = _camera.position.clamp(WORLD.position, WORLD.end)


func _two_finger_distance() -> float:
	var points := _touches.values()
	if points.size() < 2:
		return 0.0
	var a: Vector2 = points[0]
	var b: Vector2 = points[1]
	return a.distance_to(b)


func _set_zoom(z: float) -> void:
	var clamped := clampf(z, MIN_ZOOM, MAX_ZOOM)
	_camera.zoom = Vector2(clamped, clamped)


func _tap(screen_pos: Vector2) -> void:
	if not is_instance_valid(hero) or not hero.is_alive():
		return
	var world_pos: Vector2 = get_canvas_transform().affine_inverse() * screen_pos
	var enemy = _enemy_at(world_pos)
	if enemy != null:
		hero.order_attack(enemy)
		_marker_pos = enemy.position
	else:
		var dest := world_pos.clamp(WORLD.position, WORLD.end)
		hero.order_move(dest)
		_marker_pos = dest
	_marker_t = 1.0


func _enemy_at(world_pos: Vector2):
	var best = null
	var best_dist := Creature.HIT_RADIUS / maxf(_camera.zoom.x, 0.5) + 14.0
	for node in get_tree().get_nodes_in_group("creatures"):
		var c = node
		if c.team == "player" or not c.is_alive():
			continue
		var d: float = world_pos.distance_to(c.position + Creature.BODY_CENTER)
		if d < best_dist:
			best_dist = d
			best = c
	return best


# --- UI ----------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.theme = UiStyle.make_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(UiStyle.full_rect(root))

	var top := PanelContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.position = Vector2(12, 12)
	root.add_child(top)
	_objective = UiStyle.label("", 20)
	top.add_child(_objective)

	var menu := UiStyle.button("Menu", 110)
	menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	menu.offset_left = -122
	menu.offset_right = -12
	menu.offset_top = 12
	menu.offset_bottom = 12 + UiStyle.BUTTON_HEIGHT
	menu.pressed.connect(func() -> void: finished.emit("menu"))
	root.add_child(menu)

	# The leader's card: the first card of what becomes the squad card bar.
	_hero_card = UiStyle.button("", 300)
	_hero_card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_hero_card.offset_left = 12
	_hero_card.offset_right = 312
	_hero_card.offset_top = -12 - 64
	_hero_card.offset_bottom = -12
	_hero_card.pressed.connect(func() -> void: _follow = true)
	root.add_child(_hero_card)

	var hint := UiStyle.label("Tap to move  -  tap an enemy to attack  -  drag to look  -  pinch to zoom  -  rest to heal", 16, UiStyle.MUTED)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_right = -12
	hint.offset_bottom = -12
	root.add_child(hint)

	_overlay = CenterContainer.new()
	_overlay.visible = false
	root.add_child(UiStyle.full_rect(_overlay))


func _show_overlay(title: String, body: String, actions: Array) -> void:
	if _over:
		return
	_over = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	_overlay.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(UiStyle.label(title, 30, UiStyle.GOLD))
	var text := UiStyle.label(body, 20)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(480, 0)
	box.add_child(text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	for action in actions:
		var b := UiStyle.button(str(action[0]), 200)
		var action_id := str(action[1])
		b.pressed.connect(func() -> void: finished.emit(action_id))
		row.add_child(b)
	_overlay.visible = true
