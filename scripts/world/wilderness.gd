extends Node2D
## Prototype B (opening phase 2): the leader alone in an untamed wilderness.
## Goal: reach the marked clearing and make it safe, so the tribe can settle.
## Every creature defeated on the way scores points; the score sets how many Huts
## the village can raise at first (wildlife_catalog.gd).
##
## Controls (phone): tap the ground to walk, tap an enemy to attack,
## drag to pan, pinch to zoom, tap the leader's card to re-center.
## Desktop: the same with the mouse, and the wheel to zoom.

signal finished(action: String)  # "menu", "retry" or "village"

const GameState = preload("res://scripts/game_state.gd")
const Creature = preload("res://scripts/world/creature.gd")
const UnitStats = preload("res://scripts/data/unit_stats.gd")
const GearCatalog = preload("res://scripts/data/gear_catalog.gd")
const AppearanceCatalog = preload("res://scripts/data/appearance_catalog.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")
const Scenery = preload("res://scripts/world/scenery.gd")
const SceneryCatalog = preload("res://scripts/data/scenery_catalog.gd")
const WildlifeCatalog = preload("res://scripts/data/wildlife_catalog.gd")

const WildernessMap = preload("res://scripts/data/wilderness_map.gd")
const MapGrid = preload("res://scripts/world/map_grid.gd")
const Cache = preload("res://scripts/world/cache.gd")
const GROUND_ART := "res://assets/maps/wilderness_ground.jpg"

const SITE_RADIUS := 130.0
const SITE_GUARD_RADIUS := 480.0
const TAP_SLOP := 14.0
const MIN_ZOOM := 0.6
const MAX_ZOOM := 2.4

## In 3/4 top-down view, circles on the ground look squashed vertically.
const GROUND_SQUASH := 0.6

const GROUND_DARK := Color(0.24, 0.34, 0.17)

## The map (tools/map/build_wilderness.py): a grid of person-sized squares with solid
## walls and obstacles, terrain that slows or blocks, the camp and the clearing.
var grid: MapGrid
var WORLD := Rect2()
var START := Vector2.ZERO
var SITE := Vector2.ZERO
var _caches: Array = []  # Cache nodes not yet found
var _toast: Label
var _toast_t := 0.0

var state: GameState
var hero: Creature
var _units: Node2D
var _camera: Camera2D
var _follow := true
var _over := false
var _score := 0
var _kills := {}  # species id -> count

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
var _score_label: Label
var _hero_card: Button
var _overlay: Control


func setup(game_state: GameState) -> void:
	state = game_state
	grid = MapGrid.new()
	grid.setup(WildernessMap)
	WORLD = Rect2(Vector2.ZERO, grid.world_size())
	START = grid.center_of(WildernessMap.start())
	SITE = grid.center_of(WildernessMap.site())


func _ready() -> void:
	# The painted ground (terrain, the inner forests and rock walls) lies under everything.
	if ResourceLoader.exists(GROUND_ART):
		var ground := Sprite2D.new()
		ground.texture = load(GROUND_ART)
		ground.centered = false
		ground.scale = WORLD.size / ground.texture.get_size()
		ground.z_index = -10
		add_child(ground)
	var beyond := ColorRect.new()  # beyond the map's edge
	beyond.color = GROUND_DARK.darkened(0.3)
	beyond.position = WORLD.position - Vector2(600, 600)
	beyond.size = WORLD.size + Vector2(1200, 1200)
	beyond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	beyond.z_index = -20
	add_child(beyond)

	_units = Node2D.new()
	_units.y_sort_enabled = true
	add_child(_units)
	# Solid objects (trees, rocks, bushes, stumps, the fronts of the walls), sorted with units.
	for obj in WildernessMap.objects():
		_add_scenery(str(obj[1]), Vector2(float(obj[2]), float(obj[3])), str(obj[0]), 24.0, bool(obj[4]))
	for c in WildernessMap.caches():
		var cache := Cache.new()
		cache.setup(c)
		cache.position = grid.center_of(Vector2i(int(c[2]), int(c[3])))
		_units.add_child(cache)
		_caches.append(cache)

	hero = _spawn_human(START, "player", state.leader["look"], state.leader["gear"], true)
	hero.display_name = str(state.leader["name"])
	hero.selected = true

	for spawn in WildernessMap.spawns():
		var pos := grid.center_of(Vector2i(int(spawn[1]), int(spawn[2])))
		if str(spawn[0]) == "caveman":
			_spawn_caveman(pos, bool(spawn[3]))
		else:
			_spawn_beast(str(spawn[0]), pos, bool(spawn[3]))

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
	c.grid = grid
	c.apply_stats(UnitStats.compute(gear, is_hero))
	c.died.connect(_on_creature_died)
	_units.add_child(c)
	return c


func _add_scenery(kind: String, pos: Vector2, piece: String, size: float, mirrored: bool) -> void:
	var s := Scenery.new()
	s.kind = kind
	s.piece = piece
	s.size = size
	s.mirrored = mirrored
	s.position = pos
	_units.add_child(s)


func _spawn_caveman(pos: Vector2, guards_site: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pos.x * 31 + pos.y)
	var look := AppearanceCatalog.random_look(rng)
	look["tribe_color"] = "ash"
	look["headwear"] = "bone_headband"
	var c := _spawn_human(pos, "wild", look, {"body": "none_body", "main_hand": "spear", "off_hand": "none_off"}, false)
	c.display_name = "Hostile caveman"
	c.species_id = "caveman"
	c.sprite_category = "units"
	c.sprite_piece = "caveman_spear"
	c.max_hp = 30
	c.hp = 30
	c.aggro_radius = 170.0
	if guards_site:
		c.add_to_group("site_guards")


func _spawn_wolf(pos: Vector2, guards_site: bool) -> void:
	_spawn_beast("wolf", pos, guards_site)


func _spawn_beast(species_id: String, pos: Vector2, guards_site: bool) -> void:
	var info := WildlifeCatalog.get_species(species_id)
	var c := Creature.new()
	c.position = pos
	c.team = "wild"
	c.kind = "wolf"  # the code-drawn fallback if a sprite is missing
	c.species_id = species_id
	c.temper = str(info.get("temper", "aggressive"))
	c.display_name = str(info.get("name", species_id))
	c.sprite_category = "beasts"
	c.grid = grid
	c.scale = Vector2.ONE * float(info.get("scale", 1.0))
	var pieces: Array = info.get("pieces", [species_id])
	c.sprite_piece = str(pieces[int(pos.x + pos.y) % pieces.size()])
	c.bounds = WORLD
	c.apply_stats(WildlifeCatalog.stats(species_id))
	c.aggro_radius = float(info.get("aggro", 0.0))
	c.died.connect(_on_creature_died)
	if guards_site:
		c.add_to_group("site_guards")
	_units.add_child(c)


# --- Frame update ------------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta
	_marker_t = maxf(0.0, _marker_t - delta)
	if _follow and is_instance_valid(hero):
		_camera.position = _camera.position.lerp(hero.position, minf(1.0, delta * 6.0))
	if is_instance_valid(hero) and hero.is_alive():
		_hero_card.text = "%s   HP %d/%d" % [hero.display_name, hero.hp, hero.max_hp]
		_update_objective()
		_check_caches()
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.visible = _toast_t > 0.0
	queue_redraw()


## Off the beaten path: walking onto a cache picks up its reward.
func _check_caches() -> void:
	for cache in _caches.duplicate():
		if hero.position.distance_to(cache.position) > 26.0:
			continue
		_caches.erase(cache)
		var text := "Found: %s" % cache.cache_name
		if cache.reward == "unlock":
			var item_name := str(GearCatalog.get_item(cache.value).get("name", cache.value))
			if state.unlocked.has(cache.value):
				text += "  (%s already unlocked: +25 points)" % item_name
				_add_points(25)
			else:
				state.unlocked.append(cache.value)
				state.save_game()
				text += "  -  %s unlocked for your leader and soldiers!" % item_name
		else:
			_add_points(int(cache.value))
			text += "  -  +%s points" % cache.value
		cache.queue_free()
		_show_toast(text)


func _add_points(points: int) -> void:
	_score += points
	_score_label.text = _score_text()


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.visible = true
	_toast_t = 4.0


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
		state.site_claimed = true
		state.wilderness_score = _score
		state.save_game()
		var huts := WildlifeCatalog.huts_for_score(_score)
		_show_overlay("Your people have a home",
			"%s has claimed the clearing.\n\nScore: %d%s\n\nYour people can raise %d Huts at first (%d soldiers). Now design your huts and found the village."
				% [hero.display_name, _score, _kill_summary(), huts, huts * 4],
			[["Found the village", "village"], ["Main menu", "menu"]])


func _kill_summary() -> String:
	if _kills.is_empty():
		return ""
	var parts: Array = []
	for id in _kills:
		var kind_name := "Hostile caveman" if str(id) == "caveman" else str(WildlifeCatalog.get_species(str(id)).get("name", id))
		parts.append("%s x%d" % [kind_name, _kills[id]])
	return "  (" + ", ".join(parts) + ")"


func _score_text() -> String:
	var huts := WildlifeCatalog.huts_for_score(_score)
	var next := WildlifeCatalog.points_to_next_hut(_score)
	var tail := "  (%d more for another)" % next if next > 0 else "  (the most for now)"
	return "Score %d   -   Huts for your village: %d%s" % [_score, huts, tail]


func _on_creature_died(c: Node2D) -> void:
	if c != hero and not _over:
		var dead = c
		if dead.team != "player" and dead.species_id != "":
			_score += WildlifeCatalog.points(dead.species_id)
			_kills[dead.species_id] = int(_kills.get(dead.species_id, 0)) + 1
			_score_label.text = _score_text()
		return
	if c == hero:
		_show_overlay("%s has fallen" % hero.display_name,
			"The wilderness is not kind. Try different gear, or pick your fights more carefully.",
			[["Try again", "retry"], ["Main menu", "menu"]])


# --- Drawing -----------------------------------------------------------------

func _draw() -> void:

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
	var top_box := VBoxContainer.new()
	top.add_child(top_box)
	_objective = UiStyle.label("", 20)
	top_box.add_child(_objective)
	_score_label = UiStyle.label(_score_text(), 17, UiStyle.GOLD)
	top_box.add_child(_score_label)

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

	_toast = UiStyle.label("", 22, UiStyle.GOLD)
	var toast_box := StyleBoxFlat.new()
	toast_box.bg_color = Color(0.08, 0.07, 0.06, 0.8)
	toast_box.set_content_margin_all(10)
	_toast.add_theme_stylebox_override("normal", toast_box)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = 90
	_toast.visible = false
	root.add_child(_toast)

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
