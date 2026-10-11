extends Control
## Opening phase 4: design a soldier (a blueprint every soldier of a squad
## copies) on Luke's "Create soldier" screen. Body type and skin on the left,
## head / torso / arms / legs / war paint on the right, weapon, shield and the
## tribe's color along the bottom; the stage shows the soldier (tap to turn).
## Looks are cosmetic; armor, weapon and shield set the stats, the cost and so
## the squad size.

signal done(action: String)  # "confirm" or "cancel"

const GameState = preload("res://scripts/game_state.gd")
const AppearanceCatalog = preload("res://scripts/data/appearance_catalog.gd")
const GearCatalog = preload("res://scripts/data/gear_catalog.gd")
const UnitStats = preload("res://scripts/data/unit_stats.gd")
const UiStyle = preload("res://scripts/ui/ui_style.gd")
const FigureArt = preload("res://scripts/render/figure.gd")
const Dirs = preload("res://scripts/render/directions.gd")
const CreatorScreen = preload("res://scripts/ui/creator_screen.gd")
const SpriteLibrary = preload("res://scripts/render/sprite_library.gd")

## Where things sit on the soldier screen art (assets/ui/soldier_screen.png), in art pixels.
const LAYOUT := {
	"tabs": [Rect2(38, 122, 160, 73), Rect2(38, 205, 160, 67), Rect2(38, 282, 160, 68), Rect2(38, 357, 160, 68),
		Rect2(38, 435, 160, 70), Rect2(38, 515, 172, 70), Rect2(38, 592, 172, 70), Rect2(38, 670, 172, 70)],
	"zones": {"randomize_tab": Rect2(38, 748, 172, 74)},
	"randomize": Rect2(35, 905, 270, 80),
	"confirm": Rect2(590, 900, 360, 82),
	"cancel": Rect2(1270, 908, 235, 82),
	"stage": Rect2(560, 120, 505, 585),
	"panel": Rect2(1072, 105, 433, 595),
	"panels": {"body": Rect2(215, 140, 343, 358), "weapon": Rect2(230, 738, 465, 127),
		"shield": Rect2(705, 738, 520, 127), "color": Rect2(1240, 745, 265, 118)},
	"strips": ["weapon", "shield", "color"],
}
## The tab -> the right-panel section it scrolls to ("" = the tab's own panel).
const TAB_SECTIONS := ["", "head", "torso", "arms", "legs", "", "", "paint"]
const FIGURE_TILE := Vector2(92, 124)
const BODY_TILE := Vector2(110, 150)
const STRIP_TILE := Vector2(100, 100)
const SWATCH := Vector2(42, 42)
## Weapon id -> icon (assets/ui/icons/weapon_<icon>.png, from the soldier weapon sheet).
const WEAPON_ICONS := {
	"spear": "spear", "bone_spear": "spear", "war_spear": "spear", "club": "club", "bone_club": "club",
	"stone_club": "club", "great_club": "club", "stone_mace": "club", "flail": "club", "stone_axe": "axe",
	"flint_axe": "axe", "stone_halberd": "axe", "bow": "bow", "reinforced_bow": "bow", "sling": "sling",
	"stone_knife": "knife", "bone_knife": "long_knife",
}


## The soldier on the stage. Tap to turn them and watch a swing.
class Preview extends Control:
	const Figure = preload("res://scripts/render/figure.gd")
	var look: Dictionary = {}
	var gear: Dictionary = {}
	var dir := 1
	var _t := 0.0
	var _swing := 0.0
	var _variant := 0

	func _process(delta: float) -> void:
		_t += delta
		_swing = maxf(0.0, _swing - delta)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		var e = event
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			dir = posmod(dir + 1, 8)
			_swing = Figure.ATTACK_TIME
			_variant += 1
			accept_event()

	func _draw() -> void:
		var zoom := minf(size.x / 84.0, size.y / 87.0)
		Figure.draw_human(self, Vector2(size.x * 0.5, size.y * 0.89), Figure.REF_PX * zoom, look, gear, dir, 0.0, _swing, _variant)


var state: GameState
var blueprint: Dictionary = {}
var is_new := false
var _screen: CreatorScreen
var _preview: Preview
var _stats: Label
var _groups: Array = []  # {"key", "target", "tiles"}
var _sections := {}  # section key -> header node in the right panel
var _rng := RandomNumberGenerator.new()
static var _used_rects := {}


func setup(game_state: GameState, blueprint_id: String, new_design: bool = false) -> void:
	state = game_state
	blueprint = state.get_blueprint(blueprint_id)
	is_new = new_design


func _ready() -> void:
	UiStyle.full_rect(self)
	_rng.randomize()
	_screen = CreatorScreen.new()
	_screen.configure("res://assets/ui/soldier_screen.png", LAYOUT)
	add_child(_screen)

	_preview = Preview.new()
	_preview.size = Rect2(LAYOUT["stage"]).size
	_screen.stage.add_child(_preview)
	_screen.stage.mouse_filter = Control.MOUSE_FILTER_PASS

	var info := VBoxContainer.new()
	info.position = Vector2(12, 12)
	info.add_theme_constant_override("separation", 6)
	_screen.stage.add_child(info)
	var name_edit := LineEdit.new()
	name_edit.text = str(blueprint.get("name", "Soldiers"))
	name_edit.max_length = 24
	name_edit.custom_minimum_size = Vector2(300, 52)
	name_edit.add_theme_font_size_override("font_size", 26)
	name_edit.text_changed.connect(func(t: String) -> void:
		blueprint["name"] = t.strip_edges() if t.strip_edges() != "" else "Soldiers")
	info.add_child(name_edit)
	_stats = UiStyle.label("", 20)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.08, 0.07, 0.06, 0.72)
	box.set_content_margin_all(8)
	box.set_corner_radius_all(4)
	_stats.add_theme_stylebox_override("normal", box)
	info.add_child(_stats)

	_screen.tab_selected.connect(_on_tab)
	_screen.action.connect(_on_action)
	_build()
	_screen.select_tab(0)
	_changed()


func _look() -> Dictionary:
	return blueprint["look"]


func _gear() -> Dictionary:
	return blueprint["gear"]


func _on_action(act: String) -> void:
	match act:
		"randomize", "randomize_tab":
			_randomize()
		"confirm":
			state.save_game()
			done.emit("confirm")
		"cancel":
			if is_new:
				state.delete_blueprint(str(blueprint["id"]))
			state.save_game()
			done.emit("cancel")


## Tabs jump to their section; weapon and shield live in their own strips below.
func _on_tab(index: int) -> void:
	var key: String = TAB_SECTIONS[index]
	if key == "" or not _sections.has(key):
		return
	var scroll := _screen.panel.get_parent() as ScrollContainer
	var header: Control = _sections[key]
	scroll.set_deferred("scroll_vertical", int(header.position.y))


# --- Panels ------------------------------------------------------------------------

func _build() -> void:
	for p in ["main", "body", "weapon", "shield", "color"]:
		_screen.clear_panel(p)
	_groups.clear()
	_sections.clear()
	var look := _look()
	var gear := _gear()
	_screen.add_header("Body type", "body")
	_figure_row(look, "sex", _field_options("sex"), BODY_TILE, "body")
	_screen.add_header("Skin tone", "body")
	_swatch_row(look, "skin", AppearanceCatalog.skin_tones(), "body")

	_section("head", "Head")
	_figure_row(look, "hair", _field_options("hair"))
	_swatch_row(look, "hair_color", AppearanceCatalog.hair_colors())
	_figure_row(look, "headwear", _field_options("headwear"))
	_section("torso", "Torso")
	_figure_row(gear, "body", GearCatalog.unlocked_options_for_slot("body", state.unlocked))
	_figure_row(look, "cloak", _field_options("cloak"))
	_section("arms", "Arms")
	_screen.add_note("Arm guards and bracers arrive with the soldier armor sheets.")
	_section("legs", "Legs")
	_figure_row(look, "lower", _field_options("lower"))
	_section("paint", "War paint")
	_figure_row(look, "paint", _field_options("paint"))
	_screen.add_note("* no art for this yet: it still counts, but isn't drawn")

	_item_row(gear, "main_hand", GearCatalog.unlocked_options_for_slot("main_hand", state.unlocked), "weapon")
	_item_row(gear, "off_hand", GearCatalog.unlocked_options_for_slot("off_hand", state.unlocked), "shield")
	var colors: Array = AppearanceCatalog.tribe_colors()
	var pick_color := func(id: String) -> void:
		# The tribe's color is shared by the leader and every soldier.
		state.leader["look"]["tribe_color"] = id
		for bp in state.blueprints:
			bp["look"]["tribe_color"] = id
		_changed()
	var draw_color := func(ci: CanvasItem, r: Rect2, id: String) -> void:
		ci.draw_rect(r.grow(-1), AppearanceCatalog.color_of("tribe_color", id))
	var options: Array = []
	for row in colors:
		options.append([row[0], row[1]])
	var tiles := _screen.add_tiles(options, state.tribe_color(), SWATCH, draw_color, pick_color, false, "color")
	_groups.append({"key": "tribe_color", "target": {}, "tiles": tiles})
	_refresh_tiles()


func _section(key: String, title: String) -> void:
	_screen.add_header(title)
	var box: VBoxContainer = _screen.panels["main"]
	_sections[key] = box.get_child(box.get_child_count() - 1)


func _field_options(key: String) -> Array:
	for field in AppearanceCatalog.fields():
		if field["key"] == key:
			return field["options"]
	return []


## Tiles that show the soldier wearing each option.
func _figure_row(target: Dictionary, key: String, options: Array, tile: Vector2 = FIGURE_TILE, into: String = "main") -> void:
	var labelled: Array = []
	for option in options:
		var id := str(option[0])
		labelled.append([id, str(option[1]).get_slice(" (", 0) + ("" if _art_ok(key, id) else " *")])
	var draw_tile := func(ci: CanvasItem, r: Rect2, id: String) -> void: _draw_trial(ci, r, target, key, id)
	var pick := func(id: String) -> void: _pick(target, key, id)
	var tiles := _screen.add_tiles(labelled, str(target.get(key, "")), tile, draw_tile, pick, true, into)
	_groups.append({"key": key, "target": target, "tiles": tiles})


func _swatch_row(target: Dictionary, key: String, colors: Array, into: String = "main") -> void:
	var options: Array = []
	for row in colors:
		options.append([row[0], row[1]])
	var draw_swatch := func(ci: CanvasItem, r: Rect2, id: String) -> void:
		for row in colors:
			if row[0] == id:
				ci.draw_rect(r.grow(-1), row[2])
	var pick := func(id: String) -> void: _pick(target, key, id)
	var tiles := _screen.add_tiles(options, str(target.get(key, "")), SWATCH, draw_swatch, pick, false, into)
	_groups.append({"key": key, "target": target, "tiles": tiles})


## Weapon and shield tiles: the item itself (weapon icons from the soldier weapon sheet).
func _item_row(target: Dictionary, key: String, options: Array, into: String) -> void:
	var labelled: Array = []
	for option in options:
		labelled.append([str(option[0]), str(option[1]).get_slice(" (", 0)])
	var draw_tile := func(ci: CanvasItem, r: Rect2, id: String) -> void: _draw_item(ci, r, key, id)
	var pick := func(id: String) -> void: _pick(target, key, id)
	var tiles := _screen.add_tiles(labelled, str(target.get(key, "")), STRIP_TILE, draw_tile, pick, true, into)
	_groups.append({"key": key, "target": target, "tiles": tiles})


func _draw_item(ci: CanvasItem, r: Rect2, key: String, id: String) -> void:
	var tex = null
	if WEAPON_ICONS.has(id):
		var path := "res://assets/ui/icons/weapon_%s.png" % WEAPON_ICONS[id]
		if ResourceLoader.exists(path):
			tex = load(path)
	elif key == "off_hand" and id != "none_off":
		tex = SpriteLibrary.frame_at("gear", "%s_%s" % [str(_look().get("sex", "male")), id], "s", "", 0.0)
	if tex == null:
		if id == "none_off" or id == "fists":
			var c := r.get_center()
			var rad := minf(r.size.x, r.size.y) * 0.3
			ci.draw_arc(c, rad, 0.0, TAU, 28, CreatorScreen.HEADER.darkened(0.3), 4.0)
			ci.draw_line(c + Vector2(-rad, rad) * 0.7, c + Vector2(rad, -rad) * 0.7, CreatorScreen.HEADER.darkened(0.3), 4.0)
		return
	var used := _used_rect(tex)
	var zoom := minf(r.size.x / used.size.x, r.size.y / used.size.y) * 0.95
	ci.draw_texture_rect_region(tex, Rect2(r.get_center() - used.size * zoom / 2.0, used.size * zoom), used)


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


func _draw_trial(ci: CanvasItem, r: Rect2, target: Dictionary, key: String, id: String) -> void:
	var look := _look().duplicate()
	var gear := _gear().duplicate()
	if is_same(target, _gear()):
		gear[key] = id
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
	if key == "sex":
		_build()  # the "*" marks depend on the body
	_changed()


func _art_ok(key: String, id: String) -> bool:
	var look := _look()
	if key == "sex":
		var trial := look.duplicate()
		trial["sex"] = id
		return FigureArt.has_body_art(trial)
	if not FigureArt.has_body_art(look):
		return true
	return FigureArt.option_has_art(key, id, look)


func _randomize() -> void:
	var fresh := AppearanceCatalog.random_look(_rng)
	fresh["tribe_color"] = state.tribe_color()
	for key in fresh:
		_look()[key] = fresh[key]
	for slot in ["body", "main_hand", "off_hand"]:
		var options := GearCatalog.unlocked_options_for_slot(slot, state.unlocked)
		_pick(_gear(), slot, str(options[_rng.randi_range(0, options.size() - 1)][0]))
	_build()
	_changed()


func _refresh_tiles() -> void:
	var hands_full := GearCatalog.is_two_handed(str(_gear().get("main_hand", "")))
	for group in _groups:
		var current := state.tribe_color() if group["key"] == "tribe_color" else str(group["target"].get(group["key"], ""))
		var tiles: Dictionary = group["tiles"]
		for id in tiles:
			var tile = tiles[id]
			tile.chosen = str(id) == current
			tile.dimmed = group["key"] == "off_hand" and hands_full
			tile.queue_redraw()


func _changed() -> void:
	_refresh_tiles()
	_preview.look = _look()
	_preview.gear = _gear()
	var s := UnitStats.compute(_gear(), false)
	var kind := "ranged" if s["ranged"] else "melee"
	_stats.text = "Squads of %d   (cost %d each)\nHP %d   Armor %d   Speed %d\nAttack %d %s (%s), every %.1fs" % [
		s["squad_size"], s["cost"], s["hp"], s["armor"], int(s["speed"]), s["damage"], s["damage_type"], kind, s["interval"]]
