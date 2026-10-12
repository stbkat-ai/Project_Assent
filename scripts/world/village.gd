extends Node2D
## Prototype C (opening phase 3): found the village in the claimed clearing.
## Place the Chief's Hut first, then Huts. Buildings snap to an invisible grid
## and can go anywhere in the clearing as long as they don't overlap. Each Hut
## houses a family of four: four soldiers you can field.
##
## Opening phase 4 lives here too: the Army panel designs soldiers and raises
## squads from the village's free people; squads stand in formation, and tapping
## a soldier selects the squad (tap the ground to march it).
##
## Controls: pick a building on the bottom bar, then tap the ground to place it.
## Tap a building to select it (move or remove). Tap the ground with nothing
## picked to walk your leader there. Drag to pan, pinch to zoom.

signal finished(action: String)  # "menu", "redesign:<type>", "soldier:<blueprint id>" or "soldier_new:<blueprint id>"

const GameState = preload("res://scripts/game_state.gd")
const AppearanceCatalog = preload("res://scripts/data/appearance_catalog.gd")
const WildlifeCatalog = preload("res://scripts/data/wildlife_catalog.gd")
const BuildingCatalog = preload("res://scripts/data/building_catalog.gd")
const VillageLayout = preload("res://scripts/data/village_layout.gd")
const SceneryCatalog = preload("res://scripts/data/scenery_catalog.gd")
const Building = preload("res://scripts/world/building.gd")
const Scenery = preload("res://scripts/world/scenery.gd")
const Creature = preload("res://scripts/world/creature.gd")
const MapControls = preload("res://scripts/world/map_controls.gd")
const UnitStats = preload("res://scripts/data/unit_stats.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")

const WORLD := Rect2(0, 0, 1600, 1080)
const GROUND := Color(0.36, 0.45, 0.24)
const GROUND_EDGE := Color(0.27, 0.37, 0.19)

var state: GameState
var _units: Node2D
var _camera: Camera2D
var _controls
var _hero: Creature
var _buildings: Array = []  # Building nodes
var _placing := ""  # building type being placed, or ""
var _moving = null  # the Building being moved, if any
var _ghost: Building
var _selected = null
var _soldiers: Array = []  # Creature nodes of every squad
var _selected_squad := ""  # squad id, or "" when the leader is selected
var _ui_root: Control
var _army: Control = null

var _status: Label
var _hint: Label
var _bar: HBoxContainer
var _selection_bar: HBoxContainer


func setup(game_state: GameState) -> void:
	state = game_state


func _ready() -> void:
	_units = Node2D.new()
	_units.y_sort_enabled = true
	add_child(_units)
	_add_forest_edge()

	for b in state.village:
		_spawn_building(str(b["type"]), Rect2i(int(b["x"]), int(b["y"]), 0, 0))

	var area_center := VillageLayout.center_of(VillageLayout.AREA)
	_hero = Creature.new()
	_hero.team = "player"
	_hero.kind = "human"
	_hero.is_hero = true
	_hero.look = state.leader["look"]
	_hero.gear = state.leader["gear"]
	_hero.display_name = str(state.leader["name"])
	_hero.bounds = WORLD
	_hero.apply_stats(UnitStats.compute(_hero.gear, true))
	_hero.position = area_center + Vector2(0, 140)
	_hero.selected = true
	_units.add_child(_hero)

	_camera = Camera2D.new()
	_camera.position = area_center
	_camera.zoom = Vector2(1.0, 1.0)
	add_child(_camera)
	_camera.make_current()
	_controls = MapControls.new()
	_controls.camera = _camera
	_controls.bounds = WORLD
	_controls.min_zoom = 0.5
	_controls.tapped.connect(_on_tap)
	add_child(_controls)

	_ghost = Building.new()
	_ghost.tribe = _tribe()
	_ghost.ghost = true
	_ghost.visible = false
	_units.add_child(_ghost)

	_spawn_squads()
	_build_ui()
	if not state.has_chief_hut():
		_start_placing("chief_hut")
	_refresh_ui()


func _add_forest_edge() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var area := Rect2(Vector2(VillageLayout.AREA.position) * VillageLayout.CELL, Vector2(VillageLayout.AREA.size) * VillageLayout.CELL)
	var trees := SceneryCatalog.trees()
	var placed := 0
	while placed < 90:
		var p := Vector2(rng.randf_range(0, WORLD.size.x), rng.randf_range(0, WORLD.size.y))
		if area.grow(30).has_point(p):
			continue
		var s := Scenery.new()
		s.kind = "tree"
		s.piece = trees[rng.randi_range(0, trees.size() - 1)]
		s.mirrored = rng.randf() < 0.5
		s.position = p
		_units.add_child(s)
		placed += 1


# --- Buildings -----------------------------------------------------------------

func _taken(except = null) -> Array:
	var out: Array = []
	for b in _buildings:
		if b != except:
			out.append(b.rect)
	return out


## `rect` with size 0 means "use the type's footprint at this corner cell".
func _spawn_building(type_id: String, rect: Rect2i) -> Building:
	if rect.size == Vector2i.ZERO:
		var size: Vector2i = BuildingCatalog.get_type(type_id).get("footprint", Vector2i(3, 3))
		rect = Rect2i(rect.position, size)
	var b := Building.new()
	b.tribe = _tribe()
	b.setup(type_id, _design(type_id), rect)
	_units.add_child(b)
	_buildings.append(b)
	return b


func _design(type_id: String) -> Dictionary:
	if not state.building_designs.has(type_id):
		state.building_designs[type_id] = BuildingCatalog.default_design(type_id)
	return state.building_designs[type_id]


func _hut_count() -> int:
	var huts := 0
	for b in _buildings:
		if b.type_id == "hut":
			huts += 1
	return huts


## How many Huts the people can raise for now (set by the wilderness score).
func _hut_limit() -> int:
	return WildlifeCatalog.huts_for_score(state.wilderness_score)


func _save_village() -> void:
	state.village = []
	for b in _buildings:
		state.village.append({"type": b.type_id, "x": b.rect.position.x, "y": b.rect.position.y})
	state.save_game()


func _start_placing(type_id: String, moving = null) -> void:
	_placing = type_id
	_moving = moving
	_select(null)
	_ghost.setup(type_id, _design(type_id), VillageLayout.footprint_at(type_id, _camera.position))
	_ghost.valid = VillageLayout.can_place(_ghost.rect, _taken(_moving))
	_ghost.visible = true
	if _moving != null:
		_moving.visible = false
	_refresh_ui()


func _stop_placing() -> void:
	if _moving != null:
		_moving.visible = true
	_placing = ""
	_moving = null
	_ghost.visible = false
	_refresh_ui()


func _on_tap(world: Vector2) -> void:
	if _placing != "":
		var rect := VillageLayout.footprint_at(_placing, world)
		var ok := VillageLayout.can_place(rect, _taken(_moving))
		if _ghost.visible and _ghost.rect == rect and ok:
			# Second tap on the same spot confirms.
			_place(rect)
			return
		_ghost.setup(_placing, _design(_placing), rect)
		_ghost.valid = ok
		_ghost.queue_redraw()
		_refresh_ui()
		return
	var unit = _unit_at(world)
	if unit != null:
		_select_unit(unit)
		return
	var hit = _building_at(world)
	if hit != null:
		_select(hit)
		return
	_select(null)
	if _selected_squad != "":
		_march(world)
	else:
		_hero.order_move(world.clamp(WORLD.position, WORLD.end))


func _place(rect: Rect2i) -> void:
	if _moving != null:
		_moving.setup(_moving.type_id, _moving.design, rect)
		_moving.visible = true
	else:
		_spawn_building(_placing, rect)
	var was := _placing
	_moving = null
	_placing = ""
	_ghost.visible = false
	_save_village()
	# Keep placing huts until the player stops; the Chief's Hut is placed once.
	if was == "hut" and _hut_count() < _hut_limit():
		_start_placing("hut")
	else:
		_refresh_ui()


func _building_at(world: Vector2):
	for b in _buildings:
		var r: Rect2i = b.rect
		var area := Rect2(Vector2(r.position) * VillageLayout.CELL, Vector2(r.size) * VillageLayout.CELL)
		# Include the roof, which rises above the footprint.
		area = area.grow_individual(0, area.size.y * 1.2, 0, 0)
		if area.has_point(world):
			return b
	return null


func _select(b) -> void:
	if _selected != null and is_instance_valid(_selected):
		_selected.selected = false
		_selected.queue_redraw()
	_selected = b
	if b != null:
		b.selected = true
		b.queue_redraw()
	_refresh_ui()


func _remove_selected() -> void:
	if _selected == null or _selected.type_id == "chief_hut":
		return
	_buildings.erase(_selected)
	_selected.queue_free()
	_selected = null
	_save_village()
	_refresh_ui()


# --- UI ------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	_ui_root = root
	root.theme = UiStyle.make_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(UiStyle.full_rect(root))

	var top := PanelContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.position = Vector2(12, 12)
	root.add_child(top)
	var top_box := VBoxContainer.new()
	top.add_child(top_box)
	_status = UiStyle.label("", 20, UiStyle.GOLD)
	top_box.add_child(_status)
	_hint = UiStyle.label("", 17, UiStyle.MUTED)
	top_box.add_child(_hint)

	var menu := UiStyle.button("Menu", 110)
	menu.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	menu.offset_left = -122
	menu.offset_right = -12
	menu.offset_top = 12
	menu.offset_bottom = 12 + UiStyle.BUTTON_HEIGHT
	menu.pressed.connect(func() -> void:
		_save_village()
		finished.emit("menu"))
	root.add_child(menu)

	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 10)
	_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bar.offset_left = 12
	_bar.offset_bottom = -12
	root.add_child(_bar)

	_selection_bar = HBoxContainer.new()
	_selection_bar.add_theme_constant_override("separation", 10)
	_selection_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_selection_bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_selection_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_selection_bar.offset_right = -12
	_selection_bar.offset_bottom = -12
	root.add_child(_selection_bar)


func _refresh_ui() -> void:
	if _status == null:
		return
	var huts := _hut_count()
	var placed: Array = []
	for b in _buildings:
		placed.append({"type": b.type_id})
	var pop := VillageLayout.population(placed)
	_status.text = "Population %d   (Huts %d of %d)   -   in squads %d, free %d" % [pop, huts, _hut_limit(),
		state.soldiers_in_squads(), state.free_population()]

	if _placing == "chief_hut":
		_hint.text = "Tap where your Chief's Hut should stand, then tap again to build it."
	elif _placing != "":
		_hint.text = "Tap to choose a spot, tap again to build. Each Hut houses a family of four."
		if _ghost.visible and not _ghost.valid:
			_hint.text = "Can't build there: it overlaps another building or the forest."
	elif _selected != null:
		_hint.text = "%s selected." % BuildingCatalog.get_type(_selected.type_id).get("name", "Building")
	elif huts >= _hut_limit():
		_hint.text = "Your people have raised every Hut they can for now (score %d in the wilderness)." % state.wilderness_score
	else:
		if _selected_squad != "":
			_hint.text = "%s selected: tap the ground to march them, or tap %s." % [_squad_name(_selected_squad), _hero.display_name]
		elif state.blueprints.is_empty():
			_hint.text = "Open Army to design your first soldier."
		else:
			_hint.text = "Tap a soldier to select their squad, or tap the ground to walk %s around." % _hero.display_name

	for child in _bar.get_children():
		child.queue_free()
	for child in _selection_bar.get_children():
		child.queue_free()
	if _placing != "":
		if state.has_chief_hut() or _moving != null:
			var cancel := UiStyle.button("Done placing", 200)
			cancel.pressed.connect(_stop_placing)
			_bar.add_child(cancel)
		return
	if not state.has_chief_hut():
		var chief := UiStyle.button("Chief's Hut", 180)
		chief.pressed.connect(func() -> void: _start_placing("chief_hut"))
		_bar.add_child(chief)
		return
	var hut := UiStyle.button("Build Hut", 170)
	hut.pressed.connect(func() -> void: _start_placing("hut"))
	hut.disabled = huts >= _hut_limit()
	_bar.add_child(hut)
	var redesign_hut := UiStyle.button("Redesign Hut", 190)
	redesign_hut.pressed.connect(func() -> void:
		_save_village()
		finished.emit("redesign:hut"))
	_bar.add_child(redesign_hut)
	var redesign_chief := UiStyle.button("Redesign Chief's Hut", 260)
	redesign_chief.pressed.connect(func() -> void:
		_save_village()
		finished.emit("redesign:chief_hut"))
	_bar.add_child(redesign_chief)
	var army := UiStyle.button("Army", 130)
	army.pressed.connect(_open_army)
	_bar.add_child(army)
	if _selected != null:
		var move := UiStyle.button("Move", 110)
		var target = _selected
		move.pressed.connect(func() -> void: _start_placing(target.type_id, target))
		_selection_bar.add_child(move)
		if _selected.type_id != "chief_hut":
			var remove := UiStyle.button("Remove", 120)
			remove.pressed.connect(_remove_selected)
			_selection_bar.add_child(remove)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(WORLD.position - Vector2(400, 400), WORLD.size + Vector2(800, 800)), GROUND_EDGE.darkened(0.3))
	draw_rect(WORLD, GROUND_EDGE)
	var area := Rect2(Vector2(VillageLayout.AREA.position) * VillageLayout.CELL, Vector2(VillageLayout.AREA.size) * VillageLayout.CELL)
	# The clearing: a soft oval of lighter ground.
	draw_set_transform(area.get_center(), 0.0, Vector2(1.0, area.size.y / area.size.x))
	draw_circle(Vector2.ZERO, area.size.x * 0.62, GROUND)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Squads ------------------------------------------------------------------------

## Soldiers stand in rows of four.
func _formation_offset(index: int) -> Vector2:
	return Vector2((index % 4 - 1.5) * 26.0, floorf(index / 4.0) * 22.0)


func _spawn_squads() -> void:
	for s in _soldiers:
		if is_instance_valid(s):
			s.queue_free()
	_soldiers.clear()
	var center := VillageLayout.center_of(VillageLayout.AREA)
	for i in state.squads.size():
		var q: Dictionary = state.squads[i]
		var bp := state.get_blueprint(str(q["blueprint"]))
		if bp.is_empty():
			continue
		var base := center + Vector2(-255.0 + (i % 4) * 170.0, 230.0 + floorf(i / 4.0) * 120.0)
		for m in int(q["size"]):
			var c := Creature.new()
			c.team = "player"
			c.kind = "human"
			c.look = bp["look"]
			c.gear = bp["gear"]
			c.display_name = str(bp["name"])
			c.bounds = WORLD
			c.apply_stats(UnitStats.compute(c.gear, false))
			c.squad_id = str(q["id"])
			c.squad_leader = m == 0
			c.selected = c.squad_id == _selected_squad
			c.position = (base + _formation_offset(m)).clamp(WORLD.position, WORLD.end)
			_units.add_child(c)
			_soldiers.append(c)


func _squad_name(squad_id: String) -> String:
	for q in state.squads:
		if str(q["id"]) == squad_id:
			return str(state.get_blueprint(str(q["blueprint"])).get("name", "Squad"))
	return "Squad"


## The leader or a soldier under a tap, if any.
func _unit_at(world: Vector2):
	var best = null
	var best_dist := 24.0
	for c in [_hero] + _soldiers:
		if not is_instance_valid(c):
			continue
		var d: float = world.distance_to(c.position + Creature.BODY_CENTER)
		if d < best_dist:
			best_dist = d
			best = c
	return best


func _select_unit(unit) -> void:
	_select(null)
	_selected_squad = "" if unit == _hero else str(unit.squad_id)
	_hero.selected = _selected_squad == ""
	_hero.queue_redraw()
	for c in _soldiers:
		c.selected = c.squad_id == _selected_squad
		c.queue_redraw()
	_refresh_ui()


## Move the selected squad to `world`, keeping its formation.
func _march(world: Vector2) -> void:
	var index := 0
	for c in _soldiers:
		if c.squad_id == _selected_squad:
			c.order_move((world + _formation_offset(index) - Vector2(39, 0)).clamp(WORLD.position, WORLD.end))
			index += 1


# --- Army panel ----------------------------------------------------------------------

func _open_army() -> void:
	_close_army()
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	_ui_root.add_child(UiStyle.full_rect(shade))
	_army = shade
	var center := CenterContainer.new()
	shade.add_child(UiStyle.full_rect(center))
	var panel := PanelContainer.new()
	center.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(680, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)

	box.add_child(UiStyle.label("Army", 28, UiStyle.GOLD))
	box.add_child(UiStyle.label("People %d   -   in squads %d   -   free to serve %d   (each Hut houses 4)" % [
		state.population(), state.soldiers_in_squads(), state.free_population()], 18, UiStyle.MUTED))

	box.add_child(UiStyle.label("Soldier designs", 22, UiStyle.GOLD))
	if state.blueprints.is_empty():
		box.add_child(UiStyle.label("None yet. A design sets the look and gear every soldier of a squad shares.", 18, UiStyle.MUTED))
	for bp in state.blueprints:
		var id := str(bp["id"])
		var stats := UnitStats.compute(bp["gear"], false)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var title := UiStyle.label("%s   (squads of %d, cost %d)" % [bp["name"], stats["squad_size"], stats["cost"]], 18)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.clip_text = true
		row.add_child(title)
		var edit := UiStyle.button("Edit", 90)
		edit.pressed.connect(func() -> void:
			_save_village()
			finished.emit("soldier:" + id))
		row.add_child(edit)
		var raise := UiStyle.button("Raise squad", 160)
		raise.disabled = not state.can_raise_squad(id)
		raise.pressed.connect(func() -> void:
			state.raise_squad(id)
			state.save_game()
			_spawn_squads()
			_refresh_ui()
			_open_army())
		row.add_child(raise)
		box.add_child(row)
	var new_design := UiStyle.button("+  New soldier design", 280)
	new_design.pressed.connect(func() -> void:
		var bp := state.new_blueprint()
		_save_village()
		finished.emit("soldier_new:" + str(bp["id"])))
	box.add_child(new_design)

	box.add_child(UiStyle.label("Squads", 22, UiStyle.GOLD))
	if state.squads.is_empty():
		box.add_child(UiStyle.label("None yet. Raise one from a design: it takes people from the village.", 18, UiStyle.MUTED))
	for q in state.squads:
		var qid := str(q["id"])
		var row := HBoxContainer.new()
		var label := UiStyle.label("%s  x%d" % [_squad_name(qid), int(q["size"])], 18)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var disband := UiStyle.button("Disband", 130)
		disband.pressed.connect(func() -> void:
			state.disband_squad(qid)
			if _selected_squad == qid:
				_select_unit(_hero)
			state.save_game()
			_spawn_squads()
			_refresh_ui()
			_open_army())
		row.add_child(disband)
		box.add_child(row)

	var close := UiStyle.button("Close", 140)
	close.pressed.connect(_close_army)
	box.add_child(close)


func _close_army() -> void:
	if _army != null and is_instance_valid(_army):
		_army.queue_free()
	_army = null


func _tribe() -> Color:
	return AppearanceCatalog.color_of("tribe_color", state.tribe_color())
