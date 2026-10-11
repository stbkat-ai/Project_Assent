extends Node
## Screen manager: the main menu, the leader editor (Prototype A) and the
## wilderness (Prototype B). Screens are built in code and swapped in here.

const GameState = preload("res://scripts/game_state.gd")
const LeaderEditor = preload("res://scripts/ui/leader_editor.gd")
const Wilderness = preload("res://scripts/world/wilderness.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")
const TitleScreen = preload("res://scripts/ui/title_screen.gd")
const BuildingEditor = preload("res://scripts/ui/building_editor.gd")
const Village = preload("res://scripts/world/village.gd")
const SoldierEditor = preload("res://scripts/ui/soldier_editor.gd")

const VERSION := "0.12.0 - soldiers and squads"

var state: GameState
var _current: Node = null


func _ready() -> void:
	state = GameState.new()
	state.load_game()
	show_menu()


func _swap(screen: Node) -> void:
	if _current != null:
		_current.queue_free()
	_current = screen
	add_child(screen)


func show_menu() -> void:
	var root := Control.new()
	root.theme = UiStyle.make_theme()
	UiStyle.full_rect(root)
	var title := TitleScreen.new()
	root.add_child(title)
	var version := UiStyle.label(VERSION, 14, Color(1, 1, 1, 0.6))
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.offset_left = 10
	version.offset_bottom = -6
	root.add_child(version)
	title.chosen.connect(func(action: String) -> void: _on_title_choice(root, action))
	_swap(root)


func _on_title_choice(root: Control, action: String) -> void:
	match action:
		"new":
			var start_new := func() -> void:
				state.new_leader()
				show_leader_editor()
			if state.has_leader():
				_panel(root, "Start a new game?", "This replaces %s, your current leader." % state.leader["name"],
					[["Start new", start_new], ["Cancel", null]])
			else:
				state.new_leader()
				show_leader_editor()
		"load":
			if state.has_leader() and state.site_claimed:
				_panel(root, "Continue as %s" % state.leader["name"], "Your people are waiting in the clearing.",
					[["To the village", show_village], ["Edit leader", show_leader_editor], ["Back", null]])
			elif state.has_leader():
				_panel(root, "Continue as %s" % state.leader["name"], "Your leader is waiting at the edge of the wilderness.",
					[["Into the wilderness", show_wilderness], ["Edit leader", show_leader_editor], ["Back", null]])
			else:
				_panel(root, "No saved game yet", "Tap New Game to create your leader.", [["OK", null]])
		"settings":
			_panel(root, "Settings", "Settings are coming in a later build.", [["OK", null]])
		"credits":
			_panel(root, "Credits", "Project Ascent, created by Luke.\nArt made with ChatGPT. Code by Claude.\nBuilt with the Godot Engine.", [["OK", null]])
		"exit":
			if OS.has_feature("web"):
				_panel(root, "Exit", "Close the browser tab to leave the game.", [["OK", null]])
			else:
				get_tree().quit()


## A small dialog over the menu. Each button is [label, Callable or null]; null just closes it.
func _panel(root: Control, heading: String, body: String, buttons: Array) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	root.add_child(UiStyle.full_rect(shade))
	var center := CenterContainer.new()
	shade.add_child(UiStyle.full_rect(center))
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(UiStyle.label(heading, 28, UiStyle.GOLD))
	var text := UiStyle.label(body, 20)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(420, 0)
	box.add_child(text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	for entry in buttons:
		var b := UiStyle.button(str(entry[0]), 120)
		var action = entry[1]
		b.pressed.connect(func() -> void:
			shade.queue_free()
			if action != null:
				action.call())
		row.add_child(b)


func show_leader_editor() -> void:
	var editor := LeaderEditor.new()
	editor.setup(state)
	editor.done.connect(func(action: String) -> void:
		if action == "wilderness":
			show_wilderness()
		else:
			show_menu())
	_swap(editor)


func show_wilderness() -> void:
	if not state.has_leader():
		state.new_leader()
	var world := Wilderness.new()
	world.setup(state)
	world.finished.connect(func(action: String) -> void:
		if action == "retry":
			show_wilderness()
		elif action == "village":
			show_village()
		else:
			show_menu())
	_swap(world)


## Opening phase 3: design the Chief's Hut and the Hut (first time only), then the village.
func show_village() -> void:
	for type_id in ["chief_hut", "hut"]:
		if not state.building_designs.has(type_id):
			show_building_editor(type_id)
			return
	var village := Village.new()
	village.setup(state)
	village.finished.connect(func(action: String) -> void:
		if action.begins_with("redesign:"):
			show_building_editor(action.get_slice(":", 1))
		elif action.begins_with("soldier:"):
			show_soldier_editor(action.get_slice(":", 1), false)
		elif action.begins_with("soldier_new:"):
			show_soldier_editor(action.get_slice(":", 1), true)
		else:
			show_menu())
	_swap(village)


func show_building_editor(type_id: String) -> void:
	var editor := BuildingEditor.new()
	editor.setup(state, type_id)
	editor.done.connect(func(action: String) -> void:
		if action == "next":
			show_village()
		else:
			show_menu())
	_swap(editor)


## Opening phase 4: design a soldier (a squad blueprint), then back to the village.
func show_soldier_editor(blueprint_id: String, is_new: bool) -> void:
	if state.get_blueprint(blueprint_id).is_empty():
		show_village()
		return
	var editor := SoldierEditor.new()
	editor.setup(state, blueprint_id, is_new)
	editor.done.connect(func(action: String) -> void:
		if action == "confirm":
			state.refit_squads(blueprint_id)
			state.save_game()
		show_village())
	_swap(editor)
