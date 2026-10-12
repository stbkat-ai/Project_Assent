extends SceneTree
## Headless test runner: `godot --headless --path . -s res://tests/run_tests.gd`
## Loads every script (catching parse errors) and checks the game rules.
## Exits with code 1 if anything fails. CI runs this on every push.

const SCRIPTS := [
	# Screens first: a script that fails to compile reports its own error lines only
	# when it is loaded directly, not when main.gd's preload pulls it in.
	"res://scripts/ui/creator_screen.gd",
	"res://scripts/ui/leader_editor.gd",
	"res://scripts/ui/building_editor.gd",
	"res://scripts/ui/soldier_editor.gd",
	"res://scripts/main.gd",
	"res://scripts/game_state.gd",
	"res://scripts/data/gear_catalog.gd",
	"res://scripts/data/appearance_catalog.gd",
	"res://scripts/data/unit_stats.gd",
	"res://scripts/data/scenery_catalog.gd",
	"res://scripts/data/rig.gd",
	"res://scripts/data/walk_rig.gd",
	"res://scripts/data/building_catalog.gd",
	"res://scripts/data/building_parts.gd",
	"res://scripts/data/village_layout.gd",
	"res://scripts/data/wildlife_catalog.gd",
	"res://scripts/render/building_draw.gd",
	"res://scripts/world/building.gd",
	"res://scripts/world/map_controls.gd",
	"res://scripts/world/village.gd",
	"res://scripts/render/directions.gd",
	"res://scripts/render/sprite_library.gd",
	"res://scripts/render/figure.gd",
	"res://scripts/ui/ui_style.gd",
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
	var layout = load("res://scripts/data/village_layout.gd")
	var buildings = load("res://scripts/data/building_catalog.gd")
	if layout != null and buildings != null:
		_test_village(layout, buildings)
	var wildlife = load("res://scripts/data/wildlife_catalog.gd")
	if wildlife != null:
		_test_wildlife(wildlife)
	var game_state = load("res://scripts/game_state.gd")
	if game_state != null:
		_test_army(game_state)
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
	var p: Dictionary = figure.pieces({"sex": "female", "skin": "skin2", "hair": "bald", "headwear": "none", "cloak": "fur_cloak"},
		{"body": "leather_armor", "main_hand": "great_club", "off_hand": "bone_shield"})
	_check(p["body"][1] == "body_female__skin2", "body art is picked per sex and skin tone")
	_check(p["hair"][1] == "" and p["headwear"][1] == "", "bald and no headwear draw nothing")
	_check(p["cloak"][1] == "female_fur_cloak" and p["armor"][1] == "female_leather_armor", "worn pieces use the body's own art")
	_check(p["shield"][2] == "", "no shield with a two-handed weapon")
	var q: Dictionary = figure.pieces({"sex": "male", "skin": "skin5", "hair": "braids", "hair_color": "grey", "paint": "tribal"},
		{"main_hand": "club"})
	_check(q["hair"][1] == "male_braids__grey", "hair art is picked per sex and hair color")
	_check(q["paint"][1] == "male_paint_tribal", "war paint is one tribal layer per body (drawn in the tribe's color)")
	_check(q["weapon"][1] == "male_club", "weapons are fitted per body")


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
	var wildlife_art = load("res://scripts/data/wildlife_catalog.gd")
	var animals_ok := true
	var animals_missing := PackedStringArray()
	for s in wildlife_art.species():
		for piece in s["pieces"]:
			for view in ["s", "se", "e", "ne", "n"]:
				if sprites.frames("beasts", str(piece), view).is_empty():
					animals_ok = false
					animals_missing.append("%s/%s" % [piece, view])
	_check(animals_ok, "every wilderness animal has all 5 views (missing: %s)" % ", ".join(animals_missing))
	var legs_ok := true
	for sex in ["male", "female"]:
		for skin in ["skin1", "skin2", "skin3", "skin4", "skin5", "skin6"]:
			for view in ["s", "se", "e", "ne", "n"]:
				if sprites.frames("bodies", "legs_%s__%s" % [sex, skin], view, "walk").size() != 4:
					legs_ok = false
	_check(legs_ok, "4 walk-cycle leg frames for every body, skin tone and view")
	var fig = load("res://scripts/render/figure.gd")
	var rest_ok := true
	for kind in ["thrust", "swing", "shoot", "sweep_thrust", "overhead_thrust", "overhead", "sweep"]:
		for v in fig.attack_pose(kind, 0.0) + fig.attack_pose(kind, 1.0):
			if absf(float(v)) > 0.001:
				rest_ok = false
	_check(rest_ok, "attacks start and end at rest")
	_check(float(fig.attack_pose("swing", 0.35)[0]) < -1.0, "a club or axe is raised back before the strike")
	_check(float(fig.attack_pose("thrust", 0.55)[1]) > 4.0, "a spear is pushed forward in the thrust")
	_check(fig.attack_name("swing", 1) == "overhead" and fig.attack_name("thrust", 4) == "sweep_thrust",
		"each weapon kind mixes three attacks")
	_check(ResourceLoader.exists("res://assets/ui/title.png"), "title screen art exists")
	_check(ResourceLoader.exists("res://assets/ui/leader_screen.png") and ResourceLoader.exists("res://assets/ui/hut_screen.png"),
		"leader and hut creator screen art exists")
	var bodies_ok := true
	for skin in ["skin1", "skin2", "skin3", "skin4", "skin5", "skin6"]:
		for sex in ["male", "female"]:
			for view in ["s", "se", "e", "ne", "n"]:
				if sprites.frames("bodies", "body_%s__%s" % [sex, skin], view).is_empty():
					bodies_ok = false
	_check(bodies_ok, "male and female body art exists for every skin tone, in all 5 views")
	var layers_ok := true
	for sex in ["male", "female"]:
		for layer in [["gear", "hide_wrap"], ["gear", "leather_armor"], ["gear", "bone_hide"], ["gear", "spear"],
				["gear", "bone_spear"], ["gear", "club"], ["gear", "stone_axe"], ["gear", "flail"], ["gear", "sling"],
				["gear", "hide_shield"], ["gear", "bone_shield"], ["clothing", "fur_cloak"], ["clothing", "hide_skirt"],
				["clothing", "bone_headband"], ["clothing", "animal_hood"], ["clothing", "antler_skull"],
				["hair", "long__blond"], ["hair", "braids__black"], ["hair", "short__grey"]]:
			for view in ["s", "se", "e", "ne", "n"]:
				if sprites.frames(layer[0], sex + "_" + layer[1], view).is_empty():
					layers_ok = false
	_check(layers_ok, "every paper-doll layer has all 5 views for both bodies")
	var paint_ok := true
	for sex in ["male", "female"]:
		for view in ["s", "se", "e", "ne", "n"]:
			if sprites.frames("clothing", "%s_paint_tribal" % sex, view).is_empty():
				paint_ok = false
	_check(paint_ok, "tribal war paint has art for both bodies in all 5 views")
	var tinted := 0
	for slot in ["roof", "hang"]:
		for shape in ["round", "long"]:
			var parts = load("res://scripts/data/building_catalog.gd")
			for row in parts.options(slot, shape, "chief_hut"):
				var piece := "%s_%s_%s__tint" % [parts.art_shape(slot, shape), slot, row[0]]
				if not sprites.frames("buildings", piece, "s").is_empty():
					tinted += 1
	_check(tinted >= 10, "hut banners and dyed roofs have a tribal-color layer")
	var rig = load("res://scripts/data/rig.gd")
	var rig_ok: bool = rig != null
	if rig != null:
		for sex in ["male", "female"]:
			for view in ["s", "se", "e", "ne", "n"]:
				var r = rig.bodies().get(sex, {}).get(view)
				if r == null or not r.has("main_hand") or float(r["hip"]) >= 0.0:
					rig_ok = false
	_check(rig_ok, "the rig has hands and hips for both bodies in all 5 views")


func _test_village(layout, buildings) -> void:
	print("Village:")
	_check(buildings.get_type("hut")["housing"] == 4, "a hut houses a family of four")
	_check(layout.population([{"type": "chief_hut"}, {"type": "hut"}, {"type": "hut"}]) == 8, "two huts = 8 soldiers you can field")
	var a: Rect2i = layout.footprint_at("hut", Vector2(500, 400))
	_check(a.size == Vector2i(3, 3), "a hut covers 3 x 3 cells")
	_check(layout.can_place(a, []), "a hut fits in an empty clearing")
	_check(not layout.can_place(a, [a]), "buildings can't overlap")
	var b: Rect2i = layout.footprint_at("hut", Vector2(500 + 3 * 32, 400))
	_check(layout.can_place(b, [a]), "buildings can stand side by side")
	_check(not layout.can_place(layout.footprint_at("hut", Vector2(10, 10)), []), "nothing can be built outside the clearing")
	for t in buildings.types():
		var design: Dictionary = buildings.default_design(t["id"])
		_check(buildings.normalized(t["id"], design) == design, "default %s design uses real parts" % t["id"])
	var old: Dictionary = buildings.normalized("hut", {"walls": "hide", "roof": "thatch", "door": "hide_flap", "decor": "none"})
	_check(old == buildings.default_design("hut"), "a hut design from 0.7 becomes the default hut")
	var long_hut: Dictionary = buildings.normalized("hut", {"shape": "long", "walls": "post_ring"})
	_check(buildings.has_option("walls", "long", "hut", str(long_hut["walls"])), "switching to a longhouse picks longhouse walls")
	_check(not buildings.has_option("roof", "round", "hut", "antler_crown"), "the Chief's decorated roofs are only for the Chief's Hut")
	_check(buildings.has_option("roof", "round", "chief_hut", "antler_crown"), "the Chief's Hut can use them")
	var sprites = load("res://scripts/render/sprite_library.gd")
	var missing := PackedStringArray()
	for shape in ["round", "long"]:
		for slot_pair in buildings.part_slots():
			var slot: String = slot_pair[0]
			if slot == "shape":
				continue
			for row in buildings.options(slot, shape, "chief_hut"):
				if row[0] == "none":
					continue
				var piece := "%s_%s_%s" % [buildings.art_shape(slot, shape), slot, row[0]]
				if sprites.frames("buildings", piece, "s").is_empty():
					missing.append(piece)
	_check(missing.is_empty(), "every hut part has art (missing: %s)" % ", ".join(missing))


func _test_wildlife(wildlife) -> void:
	print("Wilderness score:")
	_check(wildlife.huts_for_score(0) == 2, "with no score the village starts with 2 Huts")
	_check(wildlife.huts_for_score(149) == 2, "149 points is not yet a third Hut")
	_check(wildlife.huts_for_score(150) == 3, "150 points earns a third Hut")
	_check(wildlife.huts_for_score(100000) == 6, "Huts are capped at 6 for now")
	_check(wildlife.points_to_next_hut(100) == 50, "100 points is 50 short of the next Hut")
	_check(wildlife.points_to_next_hut(900) == 0, "nothing more to earn at the cap")
	_check(wildlife.points("bear") > wildlife.points("wolf") and wildlife.points("wolf") > wildlife.points("rabbit"),
		"dangerous animals are worth more")
	_check(wildlife.points("caveman") > 0, "hostile cavemen score points")
	var tempers_ok := true
	for s in wildlife.species():
		if not ["aggressive", "territorial", "defensive", "skittish"].has(s["temper"]):
			tempers_ok = false
		if s["temper"] == "skittish" and int(s["damage"]) != 0:
			tempers_ok = false
	_check(tempers_ok, "every animal has a known temper, and skittish ones never fight back")


func _test_army(game_state) -> void:
	print("Army:")
	var gs = game_state.new()
	gs.new_leader()
	gs.village = [{"type": "chief_hut", "x": 10, "y": 10}, {"type": "hut", "x": 20, "y": 10}, {"type": "hut", "x": 24, "y": 10}]
	_check(gs.population() == 8 and gs.free_population() == 8, "two huts: 8 people, all free")
	var bp: Dictionary = gs.new_blueprint()
	_check(str(bp["look"]["tribe_color"]) == gs.tribe_color(), "a new design wears the tribe's color")
	_check(gs.squad_size_of(str(bp["id"])) == 8, "cheap spearmen come in squads of 8")
	var q: Dictionary = gs.raise_squad(str(bp["id"]))
	_check(not q.is_empty() and gs.free_population() == 0, "raising a squad takes its people from the village")
	_check(gs.raise_squad(str(bp["id"])).is_empty(), "no squad without enough free people")
	bp["gear"]["body"] = "bone_hide"
	bp["gear"]["main_hand"] = "stone_axe"
	bp["gear"]["off_hand"] = "bone_shield"
	gs.refit_squads(str(bp["id"]))
	_check(int(gs.squads[0]["size"]) == gs.squad_size_of(str(bp["id"])) and int(gs.squads[0]["size"]) < 8,
		"pricier gear shrinks the design's squads")
	gs.disband_squad(str(q["id"]))
	_check(gs.squads.is_empty() and gs.free_population() == 8, "disbanding returns the people")
	var bp2: Dictionary = gs.new_blueprint()
	_check(str(bp2["id"]) != str(bp["id"]), "designs get their own ids")
	gs.raise_squad(str(bp2["id"]))
	gs.delete_blueprint(str(bp2["id"]))
	_check(gs.squads.is_empty() and gs.get_blueprint(str(bp2["id"])).is_empty(), "deleting a design disbands its squads")
