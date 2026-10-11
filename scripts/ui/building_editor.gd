extends Control
## Opening phase 3: design a building type (the Chief's Hut, then the Hut) on
## Luke's "Create hut" screen (creator_screen.gd); both huts use the same
## screen. Like the leader creator: a base shape with interchangeable parts.

signal done(action: String)  # "next" or "back"

const GameState = preload("res://scripts/game_state.gd")
const BuildingCatalog = preload("res://scripts/data/building_catalog.gd")
const PartDraw = preload("res://scripts/render/building_draw.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")
const CreatorScreen = preload("res://scripts/ui/creator_screen.gd")

## Where things sit on the hut screen art (assets/ui/hut_screen.png), in art pixels.
const LAYOUT := {
	"tabs": [Rect2(27, 143, 258, 94), Rect2(27, 250, 258, 90), Rect2(27, 352, 258, 91), Rect2(27, 455, 258, 93),
		Rect2(27, 560, 258, 95)],
	"randomize": Rect2(28, 910, 300, 85),
	"confirm": Rect2(1075, 905, 215, 90),
	"cancel": Rect2(1305, 910, 200, 85),
	"stage": Rect2(312, 120, 683, 630),
	"panel": Rect2(1018, 48, 474, 774),
	"viewbar": Rect2(262, 787, 638, 135),
}
## Tab -> [header, slot] rows it shows.
const TABS := [
	[["Shape", "shape"]],
	[["Roof", "roof"]],
	[["Walls", "walls"]],
	[["Doorway", "door"]],
	[["Roof crest", "crest"], ["Hanging", "hang"], ["Yard", "yard"]],
]
const SHAPE_TILE := Vector2(210, 190)
const PART_TILE := Vector2(140, 150)


## The building standing in the middle of the stage.
class Preview extends Control:
	const BuildingDraw = preload("res://scripts/render/building_draw.gd")
	var type_id := "hut"
	var design: Dictionary = {}

	func _draw() -> void:
		var width := minf(size.x * 0.5, size.y * 0.55)
		BuildingDraw.draw_building(self, type_id, design, Vector2(size.x * 0.5, size.y * 0.84), width)


var state: GameState
var type_id := "hut"
var _design: Dictionary = {}
var _screen: CreatorScreen
var _preview: Preview
var _front_tile = null
var _groups: Array = []  # {"slot", "tiles"}
var _rng := RandomNumberGenerator.new()
static var _used_rects := {}


func setup(game_state: GameState, building_type: String) -> void:
	state = game_state
	type_id = building_type
	if not state.building_designs.has(type_id):
		state.building_designs[type_id] = BuildingCatalog.default_design(type_id)
	_design = BuildingCatalog.normalized(type_id, state.building_designs[type_id])
	state.building_designs[type_id] = _design


func _ready() -> void:
	UiStyle.full_rect(self)
	_rng.randomize()
	_screen = CreatorScreen.new()
	_screen.configure("res://assets/ui/hut_screen.png", LAYOUT)
	add_child(_screen)

	_preview = Preview.new()
	_preview.type_id = type_id
	_preview.size = Rect2(LAYOUT["stage"]).size
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.stage.add_child(_preview)
	var info := BuildingCatalog.get_type(type_id)
	var title := UiStyle.label("%s\n%s" % [info.get("name", "Building"), info.get("desc", "")], 24)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(420, 0)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.07, 0.06, 0.72)
	box.set_content_margin_all(10)
	box.set_corner_radius_all(4)
	title.add_theme_stylebox_override("normal", box)
	title.position = Vector2(12, 12)
	_screen.stage.add_child(title)

	# Only the front view has art so far.
	var front := CreatorScreen.Tile.new()
	front.custom_minimum_size = Vector2(120, 118)
	front.caption = "Front"
	front.chosen = true
	front.draw_fn = func(ci: CanvasItem, r: Rect2) -> void:
		PartDraw.draw_building(ci, type_id, _design, Vector2(r.get_center().x, r.end.y - r.size.y * 0.12), r.size.x * 0.48)
	_screen.viewbar.add_child(front)
	_front_tile = front
	var note := UiStyle.label("Other views (right, back, left)\narrive with more hut art.", 22, UiStyle.MUTED)
	_screen.viewbar.add_child(note)

	_screen.tab_selected.connect(_show_tab)
	_screen.action.connect(_on_action)
	_screen.select_tab(0)
	_changed()


func _shape() -> String:
	return str(_design.get("shape", "round"))


func _show_tab(index: int) -> void:
	_screen.clear_panel()
	_groups.clear()
	for row in TABS[index]:
		var slot: String = row[1]
		_screen.add_header(str(row[0]))
		var options := BuildingCatalog.options(slot, _shape(), type_id)
		var tile_size := SHAPE_TILE if slot == "shape" else PART_TILE
		var draw_tile := func(ci: CanvasItem, r: Rect2, id: String) -> void: _draw_option(ci, r, slot, id)
		var pick := func(id: String) -> void: _pick(slot, id)
		var tiles := _screen.add_tiles(options, str(_design.get(slot, "")), tile_size, draw_tile, pick)
		_groups.append({"slot": slot, "tiles": tiles})
	if index == 1 and type_id == "chief_hut":
		_screen.add_note("The decorated chieftain roofs are only for the Chief's Hut.")
	_refresh_tiles()


## A shape tile shows the whole hut in that shape; a part tile shows just the part.
func _draw_option(ci: CanvasItem, r: Rect2, slot: String, id: String) -> void:
	if slot == "shape":
		var trial := _design.duplicate()
		trial["shape"] = id
		PartDraw.draw_building(ci, type_id, BuildingCatalog.normalized(type_id, trial),
			Vector2(r.get_center().x, r.end.y - r.size.y * 0.1), r.size.x * 0.42)
		return
	if id == "none":
		var c := r.get_center()
		var rad := minf(r.size.x, r.size.y) * 0.28
		var col := CreatorScreen.HEADER.darkened(0.3)
		ci.draw_arc(c, rad, 0.0, TAU, 32, col, 5.0)
		ci.draw_line(c + Vector2(-rad, rad) * 0.7, c + Vector2(rad, -rad) * 0.7, col, 5.0)
		return
	var tex = PartDraw.part_texture(_shape(), slot, id)
	if tex == null:
		return
	var used := _used_rect(tex)
	var zoom := minf(r.size.x / used.size.x, r.size.y / used.size.y) * 0.95
	var dest := Rect2(r.get_center() - used.size * zoom / 2.0, used.size * zoom)
	ci.draw_texture_rect_region(tex, dest, used)


## The part's drawn pixels within its shared canvas (cached).
func _used_rect(tex: Texture2D) -> Rect2:
	var key := tex.resource_path
	if not _used_rects.has(key):
		var r := Rect2(Vector2.ZERO, tex.get_size())
		var img := tex.get_image()
		if img != null:
			var used := img.get_used_rect()
			if used.size.x > 0 and used.size.y > 0:
				r = Rect2(used)
		_used_rects[key] = r
	return _used_rects[key]


func _pick(slot: String, id: String) -> void:
	_design[slot] = id
	# A new shape has its own walls, roofs, doorways and crests.
	var fixed := BuildingCatalog.normalized(type_id, _design)
	for k in fixed:
		_design[k] = fixed[k]
	if slot == "shape":
		_show_tab(_screen.current_tab)
	_changed()


func _randomize() -> void:
	for slot_pair in BuildingCatalog.part_slots():
		var slot: String = slot_pair[0]
		var options := BuildingCatalog.options(slot, _shape(), type_id)
		_design[slot] = str(options[_rng.randi_range(0, options.size() - 1)][0])
		var fixed := BuildingCatalog.normalized(type_id, _design)
		for k in fixed:
			_design[k] = fixed[k]
	_show_tab(_screen.current_tab)
	_changed()


func _refresh_tiles() -> void:
	for group in _groups:
		var current := str(_design.get(group["slot"], ""))
		var tiles: Dictionary = group["tiles"]
		for id in tiles:
			var tile = tiles[id]
			tile.chosen = str(id) == current
			tile.queue_redraw()


func _changed() -> void:
	_refresh_tiles()
	_preview.design = _design
	_preview.queue_redraw()
	if _front_tile != null:
		_front_tile.queue_redraw()


func _on_action(act: String) -> void:
	match act:
		"randomize":
			_randomize()
		"confirm":
			state.save_game()
			done.emit("next")
		"cancel":
			state.save_game()
			done.emit("back")
