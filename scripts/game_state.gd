extends RefCounted
## The player's saved progress: the leader, the village, soldier designs and squads.
## Saved as JSON with a format version so later builds can upgrade old saves.

const AppearanceCatalog = preload("res://scripts/data/appearance_catalog.gd")
const GearCatalog = preload("res://scripts/data/gear_catalog.gd")
const VillageLayout = preload("res://scripts/data/village_layout.gd")
const UnitStats = preload("res://scripts/data/unit_stats.gd")

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

## {"name": String, "look": Dictionary, "gear": Dictionary}
var leader: Dictionary = {}
## Gear ids the player can equip (weapons beyond the starting three unlock later).
var unlocked: Array = GearCatalog.starting_unlocks()
## Opening progress: the wilderness clearing has been claimed.
var site_claimed := false
## Score from the wilderness run that claimed the site; sets the starting Hut limit.
var wilderness_score := 0
## Building designs, by building type: {"chief_hut": {"walls": ..., "roof": ...}, "hut": {...}}
var building_designs: Dictionary = {}
## Buildings placed in the capital: [{"type": "hut", "x": int, "y": int}] (x, y = footprint corner cell)
var village: Array = []
## Soldier designs (blueprints): [{"id": "bp_1", "name": String, "look": Dictionary, "gear": Dictionary}].
## Every soldier of a design wears the same; the tribe color is the leader's (the whole tribe's).
var blueprints: Array = []
## Squads raised from the village's people: [{"id": "sq_1", "blueprint": "bp_1", "size": int}].
var squads: Array = []


func has_leader() -> bool:
	return not leader.is_empty()


func new_leader() -> void:
	unlocked = GearCatalog.starting_unlocks()
	site_claimed = false
	wilderness_score = 0
	building_designs = {}
	village = []
	blueprints = []
	squads = []
	leader = {
		"name": "Ugo",
		"look": AppearanceCatalog.default_look(),
		"gear": GearCatalog.default_gear(),
	}


func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write save file: %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify({"version": SAVE_VERSION, "leader": leader, "unlocked": unlocked,
		"site_claimed": site_claimed, "wilderness_score": wilderness_score, "building_designs": building_designs, "village": village,
		"blueprints": blueprints, "squads": squads}))


func has_chief_hut() -> bool:
	for b in village:
		if str(b["type"]) == "chief_hut":
			return true
	return false


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (data is Dictionary):
		return
	if data.get("unlocked") is Array:
		unlocked = []
		for id in data["unlocked"]:
			unlocked.append(str(id))
		for id in GearCatalog.starting_unlocks():
			if not unlocked.has(id):
				unlocked.append(id)
	site_claimed = bool(data.get("site_claimed", false))
	wilderness_score = int(data.get("wilderness_score", 0))
	if data.get("building_designs") is Dictionary:
		var designs: Dictionary = data["building_designs"]
		for type_id in designs:
			if designs[type_id] is Dictionary:
				var parts := {}
				var saved_parts: Dictionary = designs[type_id]
				for slot in saved_parts:
					parts[str(slot)] = str(saved_parts[slot])
				building_designs[str(type_id)] = parts
	if data.get("village") is Array:
		village = []
		for b in data["village"]:
			if b is Dictionary and b.has("type"):
				village.append({"type": str(b["type"]), "x": int(b.get("x", 0)), "y": int(b.get("y", 0))})
	if data.get("blueprints") is Array:
		blueprints = []
		for b in data["blueprints"]:
			if b is Dictionary and b.has("id"):
				var bp := _upgrade_leader(b)
				bp["id"] = str(b["id"])
				if not unlocked.has(str(bp["gear"].get("main_hand", ""))):
					bp["gear"]["main_hand"] = "spear"
				blueprints.append(bp)
	if data.get("squads") is Array:
		squads = []
		for q in data["squads"]:
			if q is Dictionary and q.has("id") and not get_blueprint(str(q.get("blueprint", ""))).is_empty():
				squads.append({"id": str(q["id"]), "blueprint": str(q["blueprint"]), "size": int(q.get("size", 1))})
	if data.get("leader") is Dictionary:
		leader = _upgrade_leader(data["leader"])
		var gear: Dictionary = leader["gear"]
		if not unlocked.has(str(gear.get("main_hand", ""))):
			gear["main_hand"] = "club"  # saved before weapons were locked


## Fill in any fields a save from an older build is missing.
func _upgrade_leader(saved: Dictionary) -> Dictionary:
	var fresh := {"name": "Ugo", "look": AppearanceCatalog.default_look(), "gear": GearCatalog.default_gear()}
	if saved.get("name") is String:
		fresh["name"] = saved["name"]
	for key in ["look", "gear"]:
		if saved.get(key) is Dictionary:
			var target: Dictionary = fresh[key]
			var source: Dictionary = saved[key]
			for field in source:
				target[field] = str(source[field])
	var look: Dictionary = fresh["look"]
	if not ["none", "tribal"].has(str(look.get("paint", "none"))):
		look["paint"] = "tribal"  # red ochre / white clay from before paint took the tribe's color
	return fresh


# --- Army ------------------------------------------------------------------------

## The tribe's color, shown on every soldier (it is set on the leader).
func tribe_color() -> String:
	return str(leader.get("look", {}).get("tribe_color", "ochre"))


func get_blueprint(id: String) -> Dictionary:
	for b in blueprints:
		if str(b["id"]) == id:
			return b
	return {}


## A new soldier design: spear-armed and unarmored, in the tribe's color.
func new_blueprint() -> Dictionary:
	var look := AppearanceCatalog.default_look()
	look["tribe_color"] = tribe_color()
	var bp := {"id": _next_id("bp_", blueprints), "name": "Spearmen %d" % (blueprints.size() + 1), "look": look,
		"gear": {"body": "none_body", "main_hand": "spear", "off_hand": "none_off"}}
	blueprints.append(bp)
	return bp


func delete_blueprint(id: String) -> void:
	for q in squads.duplicate():
		if str(q["blueprint"]) == id:
			squads.erase(q)
	for b in blueprints.duplicate():
		if str(b["id"]) == id:
			blueprints.erase(b)


## How many soldiers a squad of this design has (fixed by its gear's cost).
func squad_size_of(blueprint_id: String) -> int:
	var bp := get_blueprint(blueprint_id)
	if bp.is_empty():
		return 0
	return int(UnitStats.compute(bp["gear"], false)["squad_size"])


## Everyone the village houses (each Hut: a family of four).
func population() -> int:
	return VillageLayout.population(village)


func soldiers_in_squads() -> int:
	var total := 0
	for q in squads:
		total += int(q["size"])
	return total


## People not yet serving in a squad.
func free_population() -> int:
	return population() - soldiers_in_squads()


func can_raise_squad(blueprint_id: String) -> bool:
	var size := squad_size_of(blueprint_id)
	return size > 0 and size <= free_population()


## Raise a squad of a design from the free population. Returns the squad, or {} if there aren't enough people.
func raise_squad(blueprint_id: String) -> Dictionary:
	if not can_raise_squad(blueprint_id):
		return {}
	var q := {"id": _next_id("sq_", squads), "blueprint": blueprint_id, "size": squad_size_of(blueprint_id)}
	squads.append(q)
	return q


func disband_squad(squad_id: String) -> void:
	for q in squads.duplicate():
		if str(q["id"]) == squad_id:
			squads.erase(q)


func _next_id(prefix: String, items: Array) -> String:
	var n := 1
	for item in items:
		var id := str(item["id"])
		if id.begins_with(prefix):
			n = maxi(n, int(id.substr(prefix.length())) + 1)
	return "%s%d" % [prefix, n]


## After a design changes, its squads take the new squad size (growing only as far as free people allow).
func refit_squads(blueprint_id: String) -> void:
	var target := squad_size_of(blueprint_id)
	for q in squads:
		if str(q["blueprint"]) != blueprint_id:
			continue
		var size := int(q["size"])
		if target < size:
			q["size"] = target
		elif target > size:
			q["size"] = size + mini(target - size, maxi(free_population(), 0))
