extends Node
## Screen manager: the main menu, the leader editor (Prototype A) and the
## wilderness (Prototype B). Screens are built in code and swapped in here.

const GameState = preload("res://scripts/game_state.gd")
const LeaderEditor = preload("res://scripts/ui/leader_editor.gd")
const Wilderness = preload("res://scripts/world/wilderness.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")

const VERSION := "0.2.0 - 3/4 view, 8 directions"

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
	var bg := ColorRect.new()
	bg.color = UiStyle.BG
	root.add_child(UiStyle.full_rect(bg))

	var center := CenterContainer.new()
	root.add_child(UiStyle.full_rect(center))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := UiStyle.label("PROJECT ASCENT", 52, UiStyle.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle := UiStyle.label("From the Stone Age to the stars", 22, UiStyle.MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	box.add_child(Control.new())

	if state.has_leader():
		var cont := UiStyle.button("Continue as %s" % state.leader["name"], 360)
		cont.pressed.connect(show_wilderness)
		box.add_child(cont)
		var edit := UiStyle.button("Edit your leader", 360)
		edit.pressed.connect(show_leader_editor)
		box.add_child(edit)
	var fresh := UiStyle.button("New leader", 360)
	fresh.pressed.connect(func() -> void:
		state.new_leader()
		show_leader_editor())
	box.add_child(fresh)

	var version := UiStyle.label(VERSION, 16, UiStyle.MUTED)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(version)
	_swap(root)


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
		else:
			show_menu())
	_swap(world)
