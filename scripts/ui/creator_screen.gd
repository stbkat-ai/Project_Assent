extends Control
## The shared frame of the creator screens (leader and huts), from Luke's
## mockups: the painted screen art (assets/ui/*_screen.png, built by
## tools/ui/build_screens.py) fills the screen, its painted tabs and buttons are
## tap zones, and the parts that change are drawn live on top:
##   stage    - the big preview in the middle (the owner draws into it)
##   panel    - the options panel on the right (sections of option tiles)
##   viewbar  - the strip under the preview (view tiles, info)
## Everything inside `canvas` is laid out in the art's own pixels (1536 x 1024);
## the canvas is scaled to fit the screen, so the layout matches the art exactly.

signal tab_selected(index: int)
signal action(name: String)  # "randomize", "confirm" or "cancel"

const ART_SIZE := Vector2(1536, 1024)
const UiStyle = preload("res://scripts/ui/ui_style.gd")

## Colors sampled from the mockups.
const HEADER := Color(0.91, 0.87, 0.78)
const SELECT := Color(0.93, 0.74, 0.32)


## One option in the panel: a framed square showing a live drawing of the
## option (via `draw_fn(tile, rect)`), gold-framed when selected.
class Tile extends Button:
	var draw_fn: Callable
	var caption := ""
	var chosen := false
	var dimmed := false

	const C_BG := Color(0.17, 0.17, 0.16)
	const C_EDGE := Color(0.30, 0.29, 0.27)
	const C_SELECT := Color(0.93, 0.74, 0.32)
	const C_TEXT := Color(0.91, 0.87, 0.78)

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, C_BG)
		var art := Rect2(Vector2(6, 6), size - Vector2(12, 12 + (26.0 if caption != "" else 0.0)))
		if draw_fn.is_valid():
			draw_fn.call(self, art)
		if dimmed:
			draw_rect(r, Color(0, 0, 0, 0.55))
		if caption != "":
			var font := get_theme_default_font()
			var fs := 18
			var w := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var x := maxf(4.0, (size.x - w) / 2.0)
			draw_string(font, Vector2(x, size.y - 9), caption, HORIZONTAL_ALIGNMENT_LEFT, size.x - 8, fs,
				C_SELECT if chosen else C_TEXT)
		draw_rect(r.grow(-1), C_SELECT if chosen else C_EDGE, false, 4.0 if chosen else 2.0)


var canvas: Control
var stage: Control
var panel: VBoxContainer
var viewbar: HBoxContainer
var current_tab := 0

var _tex: Texture2D = null
var _layout: Dictionary = {}
var _flash := ""
var _flash_t := 0.0
var _overlay: Control


## `layout` (art pixels): tabs: Array[Rect2], randomize / confirm / cancel / stage / panel / viewbar: Rect2.
func configure(art_path: String, layout: Dictionary) -> void:
	_layout = layout
	if ResourceLoader.exists(art_path):
		_tex = load(art_path)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiStyle.make_theme()
	canvas = Control.new()
	canvas.size = ART_SIZE
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)

	stage = Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(stage, _layout["stage"])
	canvas.add_child(stage)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_place(scroll, Rect2(_layout["panel"]).grow(-14))
	canvas.add_child(scroll)
	panel = VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 12)
	scroll.add_child(panel)

	viewbar = HBoxContainer.new()
	viewbar.alignment = BoxContainer.ALIGNMENT_CENTER
	viewbar.add_theme_constant_override("separation", 14)
	_place(viewbar, Rect2(_layout["viewbar"]).grow(-10))
	canvas.add_child(viewbar)

	# Painted tabs and buttons: invisible buttons over the art.
	var tabs: Array = _layout["tabs"]
	for i in tabs.size():
		var index := i
		_zone(tabs[i], func() -> void: select_tab(index))
	for key in ["randomize", "confirm", "cancel"]:
		var act := str(key)
		_zone(_layout[key], func() -> void:
			_flash = act
			_flash_t = 0.2
			action.emit(act))

	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.size = ART_SIZE
	_overlay.draw.connect(_draw_overlay)
	canvas.add_child(_overlay)

	resized.connect(_fit)
	_fit()


func _place(c: Control, r: Rect2) -> void:
	c.position = r.position
	c.size = r.size


func _zone(r: Rect2, on_press: Callable) -> void:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	var empty := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(s, empty)
	_place(b, r)
	b.pressed.connect(on_press)
	canvas.add_child(b)


## Scale the art to fit the screen (letterboxed, never cropped: the tabs and buttons sit at the edges).
func _fit() -> void:
	var s := minf(size.x / ART_SIZE.x, size.y / ART_SIZE.y)
	canvas.scale = Vector2(s, s)
	canvas.position = ((size - ART_SIZE * s) / 2.0).floor()
	queue_redraw()


func select_tab(index: int) -> void:
	current_tab = index
	_overlay.queue_redraw()
	tab_selected.emit(index)


func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash = ""
		_overlay.queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.05))
	if _tex != null:
		var s := canvas.scale.x
		draw_texture_rect(_tex, Rect2(canvas.position, ART_SIZE * s), false)


## The open tab gets the mockup's gold frame; a tapped button flashes.
func _draw_overlay() -> void:
	var tabs: Array = _layout.get("tabs", [])
	if current_tab >= 0 and current_tab < tabs.size():
		var r: Rect2 = tabs[current_tab]
		_overlay.draw_rect(r, Color(0.85, 0.62, 0.22, 0.22))
		_overlay.draw_rect(r.grow(-3), SELECT, false, 4.0)
	if _flash != "":
		_overlay.draw_rect(_layout[_flash], Color(1.0, 0.9, 0.6, 0.25))


# --- Panel helpers ---------------------------------------------------------------

func clear_panel() -> void:
	for child in panel.get_children():
		panel.remove_child(child)
		child.queue_free()


func clear_viewbar() -> void:
	for child in viewbar.get_children():
		viewbar.remove_child(child)
		child.queue_free()


## A section header like the mockup's "BODY TYPE".
func add_header(text: String) -> void:
	var l := UiStyle.label(text.to_upper(), 30, HEADER)
	panel.add_child(l)


func add_note(text: String) -> Label:
	var l := UiStyle.label(text, 22, UiStyle.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(Rect2(_layout["panel"]).size.x - 50, 0)
	panel.add_child(l)
	return l


## A row of option tiles. `options` = [[id, caption], ...]; `draw_fn(tile, rect, id)` draws one.
## `on_pick(id)` is called when one is tapped. Returns the tiles (by id) so the caller can refresh them.
func add_tiles(options: Array, selected: String, tile_size: Vector2, draw_fn: Callable, on_pick: Callable,
		show_captions: bool = true) -> Dictionary:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 12)
	panel.add_child(flow)
	var tiles := {}
	for option in options:
		var id := str(option[0])
		var t := Tile.new()
		t.custom_minimum_size = tile_size
		t.caption = str(option[1]) if show_captions else ""
		t.tooltip_text = str(option[1])
		t.chosen = id == selected
		t.draw_fn = func(ci: CanvasItem, r: Rect2) -> void: draw_fn.call(ci, r, id)
		t.pressed.connect(func() -> void: on_pick.call(id))
		flow.add_child(t)
		tiles[id] = t
	return tiles
