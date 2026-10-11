extends Control
## Prototype A (opening phase 1): design the tribal leader, the player's first
## hero. Appearance and gear are edited separately: looks are cosmetic, gear
## sets the stats.

signal done(action: String)  # "wilderness" or "menu"

const GameState = preload("res://scripts/game_state.gd")
const AppearanceCatalog = preload("res://scripts/data/appearance_catalog.gd")
const GearCatalog = preload("res://scripts/data/gear_catalog.gd")
const UnitStats = preload("res://scripts/data/unit_stats.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")
const FigureArt = preload("res://scripts/render/figure.gd")


## Big live preview of the leader.
class Preview extends Control:
	const Figure = preload("res://scripts/render/figure.gd")
	const Directions = preload("res://scripts/render/directions.gd")
	var look: Dictionary = {}
	var gear: Dictionary = {}
	var dir := Directions.SE
	var walking := false
	var attacking := false
	var _t := 0.0

	func _process(delta: float) -> void:
		if walking or attacking:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.20, 0.27, 0.15))
		var px := 2.4 * minf(size.x / 72.0, size.y / 58.0)
		var origin := Vector2(size.x / 2.0, size.y * 0.92)
		var swing := 0.0
		if attacking:
			swing = maxf(0.0, Figure.ATTACK_TIME - fmod(_t, Figure.ATTACK_TIME + 0.4))
		Figure.draw_human(self, origin, px, look, gear, dir, _t if walking else 0.0, swing)


var state: GameState
var _preview: Preview
var _stats_label: Label
var _desc_label: Label
var _refreshers: Array = []
var _rng := RandomNumberGenerator.new()


func setup(game_state: GameState) -> void:
	state = game_state
	if not state.has_leader():
		state.new_leader()


func _ready() -> void:
	theme = UiStyle.make_theme()
	UiStyle.full_rect(self)
	_rng.randomize()

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
	outer.add_child(UiStyle.label("Your leader: the founder of your people", 26, UiStyle.GOLD))

	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 16)
	outer.add_child(main)

	# Left: preview and stats.
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.8
	main.add_child(left)
	_preview = Preview.new()
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.custom_minimum_size = Vector2(200, 180)
	left.add_child(_preview)
	var turn_row := HBoxContainer.new()
	turn_row.add_theme_constant_override("separation", 8)
	left.add_child(turn_row)
	var turn_left := UiStyle.button("<", 56)
	turn_left.pressed.connect(func() -> void:
		_preview.dir = posmod(_preview.dir - 1, 8)
		_preview.queue_redraw())
	turn_row.add_child(turn_left)
	var walk := UiStyle.button("Walk", 80)
	walk.toggle_mode = true
	walk.toggled.connect(func(on: bool) -> void:
		_preview.walking = on
		_preview.queue_redraw())
	turn_row.add_child(walk)
	var attack := UiStyle.button("Attack", 100)
	attack.toggle_mode = true
	attack.toggled.connect(func(on: bool) -> void:
		_preview.attacking = on
		_preview.queue_redraw())
	turn_row.add_child(attack)
	var turn_right := UiStyle.button(">", 56)
	turn_right.pressed.connect(func() -> void:
		_preview.dir = posmod(_preview.dir + 1, 8)
		_preview.queue_redraw())
	turn_row.add_child(turn_right)
	_stats_label = UiStyle.label("", 18)
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_stats_label)

	# Right: scrolling list of choices.
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	var name_row := HBoxContainer.new()
	var name_label := UiStyle.label("Name")
	name_label.custom_minimum_size = Vector2(150, 0)
	name_row.add_child(name_label)
	var name_edit := LineEdit.new()
	name_edit.text = str(state.leader["name"])
	name_edit.max_length = 20
	name_edit.custom_minimum_size = Vector2(0, UiStyle.BUTTON_HEIGHT)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(t: String) -> void:
		state.leader["name"] = t.strip_edges() if t.strip_edges() != "" else "Nameless")
	name_row.add_child(name_edit)
	list.add_child(name_row)

	list.add_child(UiStyle.label("Appearance (cosmetic only)", 20, UiStyle.GOLD))
	var look: Dictionary = state.leader["look"]
	for field in AppearanceCatalog.fields():
		_add_choice_row(list, str(field["label"]), look, str(field["key"]), field["options"])

	list.add_child(UiStyle.label("Gear (sets the stats)", 20, UiStyle.GOLD))
	var gear: Dictionary = state.leader["gear"]
	for slot_pair in GearCatalog.slots():
		_add_choice_row(list, str(slot_pair[1]), gear, str(slot_pair[0]),
			GearCatalog.unlocked_options_for_slot(str(slot_pair[0]), state.unlocked))
	list.add_child(UiStyle.label("* no art for this yet: it still counts, but isn't drawn on the leader", 16, UiStyle.MUTED))
	_desc_label = UiStyle.label("", 18, UiStyle.MUTED)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(_desc_label)

	# Bottom buttons.
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	outer.add_child(buttons)
	var back := UiStyle.button("Back", 120)
	back.pressed.connect(func() -> void:
		state.save_game()
		done.emit("menu"))
	buttons.add_child(back)
	var random := UiStyle.button("Random look", 180)
	random.pressed.connect(_randomize_look)
	buttons.add_child(random)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(spacer)
	var go := UiStyle.button("Enter the wilderness  >", 280)
	go.pressed.connect(func() -> void:
		state.save_game()
		done.emit("wilderness"))
	buttons.add_child(go)

	_changed()


func _add_choice_row(parent: Control, label_text: String, target: Dictionary, key: String, options: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var lab := UiStyle.label(label_text, 20)
	lab.custom_minimum_size = Vector2(150, 0)
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
		var id := str(target.get(key, ""))
		if key == "off_hand" and GearCatalog.is_two_handed(str(target.get("main_hand", ""))):
			value.text = "Hands full (two-handed weapon)"
			return
		value.text = _option_name(options, id) + ("" if _art_ok(key, id) else "  *")
	_refreshers.append(refresh)
	prev.pressed.connect(func() -> void:
		_cycle(target, key, options, -1)
		refresh.call()
		_changed())
	next.pressed.connect(func() -> void:
		_cycle(target, key, options, 1)
		refresh.call()
		_changed())
	refresh.call()


## False when a choice has no art yet for the current body (shown with a *).
func _art_ok(key: String, id: String) -> bool:
	var look: Dictionary = state.leader["look"]
	if key == "sex":
		var trial := look.duplicate()
		trial["sex"] = id
		return FigureArt.has_body_art(trial)
	if not FigureArt.has_body_art(look):
		return true  # placeholder figure: everything is drawn
	return FigureArt.option_has_art(key, id, look)


func _cycle(target: Dictionary, key: String, options: Array, direction: int) -> void:
	if key == "off_hand" and GearCatalog.is_two_handed(str(target.get("main_hand", ""))):
		return  # both hands are on the weapon
	var index := 0
	var current := str(target.get(key, ""))
	for i in options.size():
		if str(options[i][0]) == current:
			index = i
			break
	index = posmod(index + direction, options.size())
	target[key] = str(options[index][0])
	if key == "main_hand" and GearCatalog.is_two_handed(str(target[key])):
		target["off_hand"] = "none_off"


func _option_name(options: Array, id: String) -> String:
	for option in options:
		if str(option[0]) == id:
			return str(option[1])
	return "?"


func _randomize_look() -> void:
	var look: Dictionary = state.leader["look"]
	var fresh := AppearanceCatalog.random_look(_rng)
	for key in fresh:
		look[key] = fresh[key]
	for refresh in _refreshers:
		refresh.call()
	_changed()


func _changed() -> void:
	var gear: Dictionary = state.leader["gear"]
	for refresh in _refreshers:
		refresh.call()
	_preview.look = state.leader["look"]
	_preview.gear = gear
	_preview.queue_redraw()

	var hero := UnitStats.compute(gear, true)
	var soldier := UnitStats.compute(gear, false)
	var attack_kind := "ranged" if hero["ranged"] else "melee"
	_stats_label.text = "HP %d   Armor %d   Speed %d\nAttack %d %s (%s), every %.1fs\nBlocks %d%% of stones" % [
		hero["hp"], hero["armor"], int(hero["speed"]),
		hero["damage"], hero["damage_type"], attack_kind, hero["interval"],
		int(round(float(hero["block"]) * 100.0)),
	]
	_stats_label.text += "\nAs a soldier blueprint: cost %d, squads of %d" % [soldier["cost"], soldier["squad_size"]]

	var descs := PackedStringArray()
	for slot_pair in GearCatalog.slots():
		var item := GearCatalog.get_item(str(gear.get(slot_pair[0], "")))
		if not item.is_empty() and int(item.get("cost", 0)) > 0:
			descs.append("%s: %s" % [item["name"], item["desc"]])
	_desc_label.text = "\n".join(descs)
