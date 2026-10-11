extends Control
## Opening phase 3: design a building type (the Chief's Hut, then the Hut).
## Works like the leader creator: a base model with interchangeable parts.

signal done(action: String)  # "next" or "back"

const GameState = preload("res://scripts/game_state.gd")
const BuildingCatalog = preload("res://scripts/data/building_catalog.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")


class Preview extends Control:
	const BuildingDraw = preload("res://scripts/render/building_draw.gd")
	var type_id := "hut"
	var design: Dictionary = {}

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.42, 0.50, 0.27))
		var width := minf(size.x * 0.62, size.y * 0.75)
		BuildingDraw.draw_building(self, type_id, design, Vector2(size.x * 0.48, size.y * 0.78), width)


var state: GameState
var type_id := "hut"
var _design: Dictionary = {}
var _preview: Preview
var _refreshers: Array = []


func setup(game_state: GameState, building_type: String) -> void:
	state = game_state
	type_id = building_type
	if not state.building_designs.has(type_id):
		state.building_designs[type_id] = BuildingCatalog.default_design(type_id)
	_design = state.building_designs[type_id]


func _ready() -> void:
	theme = UiStyle.make_theme()
	UiStyle.full_rect(self)
	var info := BuildingCatalog.get_type(type_id)

	var bg := ColorRect.new()
	bg.color = UiStyle.BG
	add_child(UiStyle.full_rect(bg))
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(UiStyle.full_rect(margin))
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	margin.add_child(outer)
	outer.add_child(UiStyle.label("Design your %s" % info.get("name", "building"), 26, UiStyle.GOLD))
	var desc := UiStyle.label(str(info.get("desc", "")), 18, UiStyle.MUTED)
	outer.add_child(desc)

	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 16)
	outer.add_child(main)
	_preview = Preview.new()
	_preview.type_id = type_id
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.custom_minimum_size = Vector2(240, 200)
	main.add_child(_preview)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	main.add_child(list)
	list.add_child(UiStyle.label("Parts (cosmetic: every %s you build will look like this)" % str(info.get("name", "")).to_lower(), 18, UiStyle.MUTED))
	for slot_pair in BuildingCatalog.part_slots():
		_add_choice_row(list, str(slot_pair[1]), str(slot_pair[0]), BuildingCatalog.option_pairs(str(slot_pair[0])))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	outer.add_child(buttons)
	var back := UiStyle.button("Back", 120)
	back.pressed.connect(func() -> void:
		state.save_game()
		done.emit("back"))
	buttons.add_child(back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	var next := UiStyle.button("Done  >", 200)
	next.pressed.connect(func() -> void:
		state.save_game()
		done.emit("next"))
	buttons.add_child(next)
	_changed()


func _add_choice_row(parent: Control, label_text: String, key: String, options: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var lab := UiStyle.label(label_text, 20)
	lab.custom_minimum_size = Vector2(130, 0)
	row.add_child(lab)
	var prev := UiStyle.button("<")
	var value := UiStyle.label("", 20)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.clip_text = true
	var next := UiStyle.button(">")
	row.add_child(prev)
	row.add_child(value)
	row.add_child(next)
	parent.add_child(row)
	var refresh := func() -> void:
		var id := str(_design.get(key, ""))
		value.text = "?"
		for option in options:
			if str(option[0]) == id:
				value.text = str(option[1])
	_refreshers.append(refresh)
	prev.pressed.connect(func() -> void:
		_cycle(key, options, -1)
		_changed())
	next.pressed.connect(func() -> void:
		_cycle(key, options, 1)
		_changed())


func _cycle(key: String, options: Array, direction: int) -> void:
	var index := 0
	for i in options.size():
		if str(options[i][0]) == str(_design.get(key, "")):
			index = i
	_design[key] = str(options[posmod(index + direction, options.size())][0])


func _changed() -> void:
	for refresh in _refreshers:
		refresh.call()
	_preview.design = _design
	_preview.queue_redraw()
