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


func has_leader() -> bool:
	return not leader.is_empty()


func new_leader() -> void:
	unlocked = GearCatalog.starting_unlocks()
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
	file.store_string(JSON.stringify({"version": SAVE_VERSION, "leader": leader, "unlocked": unlocked}))


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
