extends Control
## Prototype A (opening phase 1): design the tribal leader, the player's first
## hero, on Luke's "Create your leader" screen (creator_screen.gd). Tabs on the
## left pick a category, the panel on the right shows its options as tiles,
## the stage shows the leader and the view strip turns them. Looks are
## cosmetic; gear (clothing armor, weapons) sets the stats.

signal done(action: String)  # "wilderness" or "menu"

const GameState = preload("res://scripts/game_state.gd")
const AppearanceCatalog = preload("res://scripts/data/appearance_catalog.gd")
const GearCatalog = preload("res://scripts/data/gear_catalog.gd")
const UnitStats = preload("res://scripts/data/unit_stats.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")
const FigureArt = preload("res://scripts/render/figure.gd")
const Dirs = preload("res://scripts/render/directions.gd")
const CreatorScreen = preload("res://scripts/ui/creator_screen.gd")

## Where things sit on the leader screen art (assets/ui/leader_screen.png), in art pixels.
const LAYOUT := {
	"tabs": [Rect2(45, 145, 257, 92), Rect2(45, 250, 257, 82), Rect2(45, 340, 257, 82), Rect2(45, 432, 257, 81),
		Rect2(45, 522, 257, 83), Rect2(45, 615, 257, 85), Rect2(45, 710, 257, 85)],
	"randomize": Rect2(28, 905, 307, 92),
	"confirm": Rect2(1105, 902, 215, 93),
	"cancel": Rect2(1332, 905, 173, 90),
	"stage": Rect2(320, 125, 585, 610),
	"panel": Rect2(918, 105, 580, 617),
	"viewbar": Rect2(400, 776, 672, 146),
}
const FIGURE_TILE := Vector2(122, 176)
const SWATCH_TILE := Vector2(60, 60)
const VIEW_TILE := Vector2(92, 122)
const VIEWS := [["s", "Front", 2], ["se", "Down-right", 1], ["e", "Right", 0], ["ne", "Up-right", 7], ["n", "Back", 6]]


## The leader standing in the middle of the stage.
class Preview extends Control:
	const Figure = preload("res://scripts/render/figure.gd")
	var look: Dictionary = {}
	var gear: Dictionary = {}
	var dir := 1  # Directions.SE
	var walking := false
	var attacking := false
	var _t := 0.0

	func _process(delta: float) -> void:
		if walking or attacking:
			_t += delta
			queue_redraw()

	func _draw() -> void:
		# Feet on the stone circle; the leader is drawn about 7 times art size.
		var zoom := minf(size.x / 84.0, size.y / 87.0)
		var origin := Vector2(size.x * 0.556, size.y * 0.845)
		var swing := 0.0
		if attacking:
			swing = maxf(0.0, Figure.ATTACK_TIME - fmod(_t, Figure.ATTACK_TIME + 0.4))
		Figure.draw_human(self, origin, Figure.REF_PX * zoom, look, gear, dir, _t if walking else 0.0, swing)


var state: GameState
var _screen: CreatorScreen
var _preview: Preview
var _stats: Label
var _groups: Array = []  # {"key", "target", "tiles"} for every tile row on the open tab
var _view_tiles: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func setup(game_state: GameState) -> void:
	state = game_state
	if not state.has_leader():
		state.new_leader()


func _ready() -> void:
	UiStyle.full_rect(self)
	_rng.randomize()
	_screen = CreatorScreen.new()
	_screen.configure("res://assets/ui/leader_screen.png", LAYOUT)
	add_child(_screen)

	_preview = Preview.new()
	_preview.size = Rect2(LAYOUT["stage"]).size
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.stage.add_child(_preview)
	_stats = UiStyle.label("", 22)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.07, 0.06, 0.72)
	box.set_content_margin_all(10)
	box.set_corner_radius_all(4)
	_stats.add_theme_stylebox_override("normal", box)
	_stats.position = Vector2(12, 12)
	_screen.stage.add_child(_stats)

	_screen.tab_selected.connect(_show_tab)
	_screen.action.connect(_on_action)
	_build_viewbar()
	_screen.select_tab(0)
	_changed()



func _on_action(act: String) -> void:
	match act:
		"randomize":
			_randomize_look()
		"confirm":
			state.save_game()
			done.emit("wilderness")
		"cancel":
			state.save_game()
			done.emit("menu")

# --- Tabs ------------------------------------------------------------------------

func _look() -> Dictionary:
	return state.leader["look"]


func _gear() -> Dictionary:
	return state.leader["gear"]


func _show_tab(index: int) -> void:
	_screen.clear_panel()
	_groups.clear()
	var look := _look()
	var gear := _gear()
	match index:
		0:
			_screen.add_header("Name")
			var name_edit := LineEdit.new()
			name_edit.text = str(state.leader["name"])
			name_edit.max_length = 20
			name_edit.custom_minimum_size = Vector2(0, 60)
			name_edit.add_theme_font_size_override("font_size", 30)
			name_edit.text_changed.connect(func(t: String) -> void:
				state.leader["name"] = t.strip_edges() if t.strip_edges() != "" else "Nameless"
				_changed())
			_screen.panel.add_child(name_edit)
			_figure_row("Body type", look, "sex", _field_options("sex"))
			_swatch_row("Skin tone", look, "skin", AppearanceCatalog.skin_tones())
			_swatch_row("Tribe color", look, "tribe_color", AppearanceCatalog.tribe_colors())
		1:
			_figure_row("Hair style", look, "hair", _field_options("hair"))
			_swatch_row("Hair color", look, "hair_color", AppearanceCatalog.hair_colors())
		2:
			_screen.add_header("Facial hair")
			_screen.add_note("No beards yet: a ChatGPT sheet of beards (drawn like the hair pieces) will add them here.")
		3:
			_figure_row("War paint", look, "paint", _field_options("paint"))
		4:
			_figure_row("Lower", look, "lower", _field_options("lower"))
			_figure_row("Cloak", look, "cloak", _field_options("cloak"))
			_figure_row("Armor (sets the stats)", gear, "body", GearCatalog.unlocked_options_for_slot("body", state.unlocked))
		5:
			_figure_row("Headwear", look, "headwear", _field_options("headwear"))
		6:
			_figure_row("Main hand", gear, "main_hand", GearCatalog.unlocked_options_for_slot("main_hand", state.unlocked))
			_figure_row("Off hand", gear, "off_hand", GearCatalog.unlocked_options_for_slot("off_hand", state.unlocked))
			if GearCatalog.is_two_handed(str(gear.get("main_hand", ""))):
				_screen.add_note("Hands full: a two-handed weapon leaves no hand for a shield.")
			var descs := PackedStringArray()
			for slot_pair in GearCatalog.slots():
				var item := GearCatalog.get_item(str(gear.get(slot_pair[0], "")))
				if not item.is_empty() and int(item.get("cost", 0)) > 0:
					descs.append("%s: %s" % [item["name"], item["desc"]])
			if not descs.is_empty():
				_screen.add_note("\n".join(descs))
	if index != 2:
		_screen.add_note("* no art for this yet: it still counts, but isn't drawn on the leader")
	_refresh_tiles()


func _field_options(key: String) -> Array:
	for field in AppearanceCatalog.fields():
		if field["key"] == key:
			return field["options"]
	return []


## A row of tiles that each show the leader wearing that option.
func _figure_row(title: String, target: Dictionary, key: String, options: Array) -> void:
	_screen.add_header(title)
	var labelled: Array = []
	for option in options:
		var id := str(option[0])
		labelled.append([id, str(option[1]).get_slice(" (", 0) + ("" if _art_ok(key, id) else " *")])
	var tiles := _screen.add_tiles(labelled, str(target.get(key, "")), FIGURE_TILE,
		func(ci: CanvasItem, r: Rect2, id: String) -> void: _draw_trial(ci, r, target, key, id),
		func(id: String) -> void: _pick(target, key, id))
	_groups.append({"key": key, "target": target, "tiles": tiles})


## A row of color swatches.
func _swatch_row(title: String, target: Dictionary, key: String, colors: Array) -> void:
	_screen.add_header(title)
	var options: Array = []
	for row in colors:
		options.append([row[0], row[1]])
	var draw_swatch := func(ci: CanvasItem, r: Rect2, id: String) -> void:
		for row in colors:
			if row[0] == id:
				ci.draw_rect(r.grow(-2), row[2])
	var pick := func(id: String) -> void: _pick(target, key, id)
	var tiles := _screen.add_tiles(options, str(target.get(key, "")), SWATCH_TILE, draw_swatch, pick, false)
	_groups.append({"key": key, "target": target, "tiles": tiles})


func _draw_trial(ci: CanvasItem, r: Rect2, target: Dictionary, key: String, id: String) -> void:
	var look := _look().duplicate()
	var gear := _gear().duplicate()
	if is_same(target, _gear()):
		gear[key] = id
		if key == "main_hand" and GearCatalog.is_two_handed(id):
			gear["off_hand"] = "none_off"
	else:
		look[key] = id
	var zoom := minf(r.size.x / 62.0, r.size.y / 56.0)
	FigureArt.draw_human(ci, Vector2(r.get_center().x, r.end.y - 4), FigureArt.REF_PX * zoom, look, gear, Dirs.SE)


func _pick(target: Dictionary, key: String, id: String) -> void:
	if key == "off_hand" and GearCatalog.is_two_handed(str(target.get("main_hand", ""))):
		return  # both hands are on the weapon
	target[key] = id
	if key == "main_hand" and GearCatalog.is_two_handed(id):
		target["off_hand"] = "none_off"
	if key == "main_hand" or key == "body" or key == "off_hand":
		_show_tab(_screen.current_tab)  # the item notes depend on the gear
	if key == "sex":
		_show_tab(_screen.current_tab)  # the "*" marks depend on the body
	_changed()


## False when a choice has no art yet for the current body (shown with a *).
func _art_ok(key: String, id: String) -> bool:
	var look := _look()
	if key == "sex":
		var trial := look.duplicate()
		trial["sex"] = id
		return FigureArt.has_body_art(trial)
	if not FigureArt.has_body_art(look):
		return true  # placeholder figure: everything is drawn
	return FigureArt.option_has_art(key, id, look)


func _refresh_tiles() -> void:
	var hands_full := GearCatalog.is_two_handed(str(_gear().get("main_hand", "")))
	for group in _groups:
		var target: Dictionary = group["target"]
		var current := str(target.get(group["key"], ""))
		var tiles: Dictionary = group["tiles"]
		for id in tiles:
			var tile = tiles[id]
			tile.chosen = str(id) == current
			tile.dimmed = group["key"] == "off_hand" and hands_full
			tile.queue_redraw()
	for id in _view_tiles:
		_view_tiles[id].queue_redraw()


# --- View strip --------------------------------------------------------------------

func _build_viewbar() -> void:
	_screen.clear_viewbar()
	for v in VIEWS:
		var t := CreatorScreen.Tile.new()
		t.custom_minimum_size = VIEW_TILE
		t.caption = str(v[1])
		var dir: int = v[2]
		t.draw_fn = func(ci: CanvasItem, r: Rect2) -> void:
			var zoom := minf(r.size.x / 60.0, r.size.y / 52.0)
			FigureArt.draw_human(ci, Vector2(r.get_center().x, r.end.y - 2), FigureArt.REF_PX * zoom, _look(), _gear(), dir)
		t.pressed.connect(func() -> void:
			_preview.dir = dir
			_preview.queue_redraw()
			_refresh_view_tiles())
		_screen.viewbar.add_child(t)
		_view_tiles[str(v[0])] = t
	_toggle_tile("Walk", func(on: bool) -> void: _preview.walking = on)
	_toggle_tile("Attack", func(on: bool) -> void: _preview.attacking = on)
	_refresh_view_tiles()


func _toggle_tile(caption: String, on_toggle: Callable) -> void:
	var t := CreatorScreen.Tile.new()
	t.custom_minimum_size = Vector2(84, VIEW_TILE.y)
	t.caption = caption
	t.draw_fn = func(ci: CanvasItem, r: Rect2) -> void:
		var c := r.get_center()
		var col := CreatorScreen.SELECT if t.chosen else CreatorScreen.HEADER
		if caption == "Walk":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-10, -16), c + Vector2(14, 0), c + Vector2(-10, 16)]), col)
		else:
			ci.draw_line(c + Vector2(-14, 14), c + Vector2(14, -14), col, 5.0)
			ci.draw_line(c + Vector2(-14, -14), c + Vector2(14, 14), col, 5.0)
	t.pressed.connect(func() -> void:
		t.chosen = not t.chosen
		on_toggle.call(t.chosen)
		_preview.queue_redraw()
		t.queue_redraw())
	_screen.viewbar.add_child(t)


func _refresh_view_tiles() -> void:
	for v in VIEWS:
		var t = _view_tiles[str(v[0])]
		t.chosen = int(v[2]) == _preview.dir
		t.queue_redraw()


# --- Changes ---------------------------------------------------------------------

func _randomize_look() -> void:
	var look := _look()
	var fresh := AppearanceCatalog.random_look(_rng)
	for key in fresh:
		look[key] = fresh[key]
	_show_tab(_screen.current_tab)
	_changed()


func _changed() -> void:
	_refresh_tiles()
	_preview.look = _look()
	_preview.gear = _gear()
	_preview.queue_redraw()
	var hero := UnitStats.compute(_gear(), true)
	var soldier := UnitStats.compute(_gear(), false)
	var kind := "ranged" if hero["ranged"] else "melee"
	_stats.text = "%s\nHP %d   Armor %d   Speed %d\nAttack %d %s (%s), every %.1fs\nBlocks %d%% of stones\nAs a soldier: cost %d, squads of %d" % [
		str(state.leader["name"]), hero["hp"], hero["armor"], int(hero["speed"]),
		hero["damage"], hero["damage_type"], kind, hero["interval"],
		int(round(float(hero["block"]) * 100.0)), soldier["cost"], soldier["squad_size"]]
