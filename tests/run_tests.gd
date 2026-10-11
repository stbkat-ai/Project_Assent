extends SceneTree
## Headless test runner: `godot --headless --path . -s res://tests/run_tests.gd`
## Loads every script (catching parse errors) and checks the game rules.
## Exits with code 1 if anything fails. CI runs this on every push.

const SCRIPTS := [
	"res://scripts/main.gd",
	"res://scripts/game_state.gd",
	"res://scripts/data/gear_catalog.gd",
	"res://scripts/data/appearance_catalog.gd",
	"res://scripts/data/unit_stats.gd",
	"res://scripts/render/directions.gd",
	"res://scripts/render/sprite_library.gd",
	"res://scripts/render/figure.gd",
	"res://scripts/ui/ui_style.gd",
	"res://scripts/ui/leader_editor.gd",
	"res://scripts/world/creature.gd",
	"res://scripts/world/projectile.gd",
	"res://scripts/world/scenery.gd",
	"res://scripts/world/wilderness.gd",
]

var _failures := 0
var _passes := 0


func _init() -> void:
	_test_scripts_load()
	var stats = load("res://scripts/data/unit_stats.gd")
	var gear = load("res://scripts/data/gear_catalog.gd")
	var looks = load("res://scripts/data/appearance_catalog.gd")
	if stats != null and gear != null and looks != null:
		_test_damage(stats)
		_test_squad_size(stats)
		_test_compute(stats)
		_test_catalogs(gear, looks)
	var dirs = load("res://scripts/render/directions.gd")
	var sprites = load("res://scripts/render/sprite_library.gd")
	var figure = load("res://scripts/render/figure.gd")
	if dirs != null and sprites != null and figure != null:
		_test_directions(dirs)
		_test_sprites(sprites, figure)
	print("\n%d passed, %d failed" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, what: String) -> void:
	if condition:
		_passes += 1
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)


func _test_scripts_load() -> void:
	print("Scripts load:")
	for path in SCRIPTS:
		var script = load(path)
		_check(script != null and script.can_instantiate(), path)


func _test_damage(stats) -> void:
	print("Damage rules:")
	_check(stats.resolve_damage(8, "slash", 4, false, 0.0, 0.5) == 4, "slash takes full armor (8 - 4 = 4)")
	_check(stats.resolve_damage(8, "blunt", 4, false, 0.0, 0.5) == 6, "blunt ignores half armor (8 - 2 = 6)")
	_check(stats.resolve_damage(4, "pierce", 0, false, 0.0, 0.5) == 5, "pierce +25% vs unarmored (4 -> 5)")
	_check(stats.resolve_damage(4, "pierce", 3, false, 0.0, 0.5) == 1, "damage never drops below 1")
	_check(stats.resolve_damage(4, "pierce", 0, true, 0.5, 0.2) == 0, "shield blocks a ranged hit when roll < block")
	_check(stats.resolve_damage(4, "pierce", 0, true, 0.5, 0.8) > 0, "shield misses when roll >= block")
	_check(stats.resolve_damage(6, "blunt", 0, false, 0.9, 0.0) > 0, "block never stops melee")


func _test_squad_size(stats) -> void:
	print("Squad size:")
	_check(stats.squad_size("infantry", 8) == 8, "cheap infantry: 8")
	_check(stats.squad_size("infantry", 18) == 6, "mid infantry: 6")
	_check(stats.squad_size("infantry", 30) == 4, "expensive infantry: 4")
	_check(stats.squad_size("beast", 10) == 4, "cheap beasts: 4")
	_check(stats.squad_size("beast", 40) == 2, "expensive beasts: 2")
	_check(stats.squad_size("vehicle", 60) == 1, "expensive vehicle: 1")


func _test_compute(stats) -> void:
	print("Blueprint stats:")
	var frontman = stats.compute({"body": "leather_armor", "main_hand": "flail", "off_hand": "hide_shield"})
	_check(frontman["armor"] == 3, "Frontman armor = leather 2 + shield 1")
	_check(frontman["damage"] == 9 and frontman["damage_type"] == "blunt", "Frontman hits with the flail")
	_check(frontman["cost"] == 5 + 6 + 6 + 3, "Frontman cost = base + parts")
	_check(frontman["speed"] < 80.0, "heavy gear slows the unit")
	_check(frontman["squad_size"] == 6, "Frontman squads of 6")
	var slinger = stats.compute({"body": "none_body", "main_hand": "sling", "off_hand": "none_off"})
	_check(slinger["ranged"] == true, "sling is ranged")
	_check(slinger["squad_size"] == 8, "cheap slingers come 8 to a squad")
	var hero = stats.compute({"body": "none_body", "main_hand": "club", "off_hand": "none_off"}, true)
	_check(hero["hp"] == 200 and hero["damage"] == 12, "hero gets 5x HP and 2x damage")
	var unknown = stats.compute({"body": "made_up_item"})
	_check(unknown["hp"] == 40 and unknown["damage"] == 2, "unknown gear ids are ignored safely")


func _test_catalogs(gear, looks) -> void:
	print("Catalogs:")
	var ids := {}
	var dupes := false
	for item in gear.items():
		if ids.has(item["id"]):
			dupes = true
		ids[item["id"]] = true
	_check(not dupes, "gear ids are unique")
	for slot_pair in gear.slots():
		_check(gear.for_slot(slot_pair[0]).size() >= 2, "slot %s has choices" % slot_pair[0])
	var default_gear: Dictionary = gear.default_gear()
	for slot in default_gear:
		_check(not gear.get_item(default_gear[slot]).is_empty(), "default gear '%s' exists" % default_gear[slot])
	var look: Dictionary = looks.default_look()
	for field in looks.fields():
		var valid := false
		for option in field["options"]:
			if option[0] == look.get(field["key"]):
				valid = true
		_check(valid, "default look has a valid '%s'" % field["key"])


func _test_directions(dirs) -> void:
	print("Directions:")
	_check(dirs.from_vector(Vector2(1, 0)) == 0, "right is east")
	_check(dirs.from_vector(Vector2(0, 1)) == 2, "screen-down is south")
	_check(dirs.from_vector(Vector2(0, -1)) == 6, "screen-up is north")
	_check(dirs.from_vector(Vector2(-1, 1)) == 3, "down-left is south-west")
	_check(dirs.from_vector(Vector2(-1, -1)) == 5, "up-left is north-west")
	_check(dirs.from_vector(Vector2(10, -1)) == 0, "nearly right snaps to east")
	var drawn := {}
	for d in 8:
		drawn[dirs.view_of(d)] = true
	_check(drawn.size() == 5, "8 directions use exactly 5 drawn views")
	_check(dirs.view_of(4) == "e" and dirs.is_mirrored(4), "west is east mirrored")
	_check(dirs.view_of(3) == "se" and dirs.is_mirrored(3), "south-west is south-east mirrored")
	_check(dirs.view_of(5) == "ne" and dirs.is_mirrored(5), "north-west is north-east mirrored")
	_check(not dirs.is_mirrored(2) and not dirs.is_mirrored(6), "south and north are not mirrored")
	_check(dirs.turn(7, 1) == 0 and dirs.turn(0, -1) == 7, "turning wraps around")


func _test_sprites(sprites, figure) -> void:
	print("Sprites:")
	_check(sprites.frames("gear", "no_such_piece", "s", "walk").is_empty(), "missing art falls back to placeholders")
	_check(sprites.frame_at("gear", "no_such_piece", "s", "", 0.0) == null, "missing frame is null")
	var p: Dictionary = figure.pieces({"sex": "female", "hair": "bald", "headwear": "none", "cloak": "fur_cloak"},
		{"body": "leather_armor", "main_hand": "flail", "off_hand": "none_off"})
	_check(p["body"][1] == "body_female", "body piece follows sex")
	_check(p["hair"][1] == "", "bald draws no hair layer")
	_check(p["headwear"][1] == "" and p["cloak"][1] == "fur_cloak", "clothing pieces map to sprite ids")
	_check(p["armor"][1] == "leather_armor" and p["weapon"][1] == "flail" and p["shield"][1] == "", "gear maps to sprite ids")
