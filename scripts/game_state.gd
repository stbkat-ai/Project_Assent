extends RefCounted
## The player's saved progress. For now that is just the leader hero.
## Saved as JSON with a format version so later builds can upgrade old saves.

const AppearanceCatalog = preload("res://scripts/data/appearance_catalog.gd")
const GearCatalog = preload("res://scripts/data/gear_catalog.gd")

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


func has_leader() -> bool:
	return not leader.is_empty()


func new_leader() -> void:
	unlocked = GearCatalog.starting_unlocks()
	site_claimed = false
	wilderness_score = 0
	building_designs = {}
	village = []
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
		"site_claimed": site_claimed, "wilderness_score": wilderness_score, "building_designs": building_designs, "village": village}))


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
	return fresh
