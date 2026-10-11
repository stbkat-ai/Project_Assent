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
	"res://scripts/data/scenery_catalog.gd",
	"res://scripts/data/rig_male.gd",
	"res://scripts/render/directions.gd",
	"res://scripts/render/sprite_library.gd",
	"res://scripts/render/figure.gd",
	"res://scripts/ui/ui_style.gd",
	"res://scripts/ui/leader_editor.gd",
	"res://scripts/ui/title_screen.gd",
	"res://scripts/world/creature.gd",
	"res://scripts/world/projectile.gd",
	"res://scripts/world/scenery.gd",
	"res://scripts/world/corpse.gd",
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
	var scenery = load("res://scripts/data/scenery_catalog.gd")
	if sprites != null and scenery != null:
		_test_art(sprites, scenery)
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
	var brute = stats.compute({"body": "none_body", "main_hand": "great_club", "off_hand": "bone_shield"})
	_check(brute["armor"] == 0 and brute["block"] == 0.0, "a two-handed weapon leaves no hand for the shield")
	_check(brute["damage"] == 13 and brute["damage_type"] == "blunt", "great club hits hard")
	var archer = stats.compute({"main_hand": "bow"})
	_check(archer["ranged"] == true and archer["range"] > 200.0, "bows shoot farther than slings")
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
	var weapons_ok := true
	for item in gear.for_slot("main_hand"):
		if not item.has("kind") or not item.has("damage") or not ["thrust", "swing", "shoot", "punch"].has(item["kind"]):
			weapons_ok = false
	_check(weapons_ok, "every weapon has damage and an attack kind")
	_check(gear.for_slot("main_hand").size() >= 17, "the full Stone Age weapon list is available")
	_check(gear.is_two_handed("bow") and not gear.is_two_handed("spear"), "bows are two-handed, spears are not")
	var start_weapons: Array = gear.unlocked_options_for_slot("main_hand", gear.starting_unlocks())
	var start_ids: Array = []
	for option in start_weapons:
		start_ids.append(option[0])
	start_ids.sort()
	_check(start_ids == ["club", "spear", "stone_axe"], "a new game starts with only the spear, club and axe")
	_check(gear.unlocked_options_for_slot("off_hand", gear.starting_unlocks()).size() == gear.for_slot("off_hand").size(),
		"all shields are available from the start")
	_check(gear.starting_unlocks().has(gear.default_gear()["main_hand"]), "the default weapon is a starting weapon")
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
	_check(p["body"][1].begins_with("body_female__"), "body piece follows sex")
	_check(p["hair"][1] == "", "bald draws no hair layer")
	var q: Dictionary = figure.pieces({"sex": "male", "skin": "skin5", "hair": "braids", "hair_color": "grey"}, {})
	_check(q["body"][1] == "body_male__skin5__grey", "body art is picked per skin tone and hair color")
	_check(q["hair"][1] == "braids__grey", "hair art is picked per hair color")
	_check(p["headwear"][1] == "" and p["cloak"][1] == "fur_cloak", "clothing pieces map to sprite ids")
	_check(p["armor"][1] == "leather_armor" and p["weapon"][1] == "flail" and p["shield"][1] == "", "gear maps to sprite ids")


func _test_art(sprites, scenery) -> void:
	print("Art in the game:")
	var missing := PackedStringArray()
	for id in scenery.all_ids():
		if sprites.frames("scenery", id, "s").is_empty():
			missing.append(id)
	_check(missing.is_empty(), "every scenery piece has a sprite (missing: %s)" % ", ".join(missing))
	for unit in [["beasts", "wolf_gray"], ["beasts", "wolf_brown"], ["units", "caveman_spear"]]:
		var views_ok := true
		for view in ["s", "se", "e", "ne", "n"]:
			if sprites.frames(unit[0], unit[1], view).is_empty():
				views_ok = false
		_check(views_ok, "%s has all 5 views" % unit[1])
		_check(not sprites.frames(unit[0], unit[1], "e", "death").is_empty(), "%s has a death sprite" % unit[1])
	_check(ResourceLoader.exists("res://assets/ui/title.png"), "title screen art exists")
	var bodies_ok := true
	for skin in ["skin1", "skin2", "skin3", "skin4", "skin5", "skin6"]:
		for hair in ["black", "brown", "auburn", "blond", "grey"]:
			for view in ["s", "se", "e", "ne", "n"]:
				if sprites.frames("bodies", "body_male__%s__%s" % [skin, hair], view).is_empty():
					bodies_ok = false
	_check(bodies_ok, "male body art exists for every skin tone and hair color, in all 5 views")
	var layers_ok := true
	for layer in [["gear", "hide_wrap"], ["gear", "leather_armor"], ["gear", "spear"], ["gear", "bone_spear"],
			["gear", "hide_shield"], ["gear", "bone_shield"], ["clothing", "fur_cloak"], ["clothing", "animal_hood"],
			["clothing", "antler_skull"], ["hair", "long__blond"], ["hair", "braids__black"]]:
		for view in ["s", "se", "e", "ne", "n"]:
			if sprites.frames(layer[0], layer[1], view).is_empty():
				layers_ok = false
	_check(layers_ok, "every paper-doll layer has all 5 views")
	var rig = load("res://scripts/data/rig_male.gd")
	var rig_ok: bool = rig != null
	if rig != null:
		for view in ["s", "se", "e", "ne", "n"]:
			var r = rig.views().get(view)
			if r == null or not r.has("main_hand") or float(r["hip"]) >= 0.0:
				rig_ok = false
	_check(rig_ok, "the leader rig has hands and hips for all 5 views")
