extends RefCounted
## Stone Age buildings. Like the leader, each building is a base model with
## interchangeable parts the player picks in a designer. Parts are cosmetic;
## the building type sets what it does (the Chief's Hut is the HQ, each Hut
## houses a family of four = four soldiers you can field).
##
## Footprints are in cells of the settlement's invisible grid (village_layout.gd).

static func types() -> Array:
	return [
		{"id": "chief_hut", "name": "Chief's Hut", "desc": "Your leader's home and the heart of the village.",
			"footprint": Vector2i(4, 4), "housing": 0, "unique": true},
		{"id": "hut", "name": "Hut", "desc": "Houses a family of four: four more soldiers you can field.",
			"footprint": Vector2i(3, 3), "housing": 4, "unique": false},
	]


static func get_type(id: String) -> Dictionary:
	for t in types():
		if t["id"] == id:
			return t
	return {}


## Design slots, in the order the designer shows them.
static func part_slots() -> Array:
	return [["walls", "Walls"], ["roof", "Roof"], ["door", "Doorway"], ["decor", "Decoration"]]


## [id, name, color] options for a part slot.
static func options(slot: String) -> Array:
	match slot:
		"walls":
			return [["hide", "Stretched hide", Color(0.66, 0.53, 0.37)], ["wattle", "Woven wattle", Color(0.50, 0.38, 0.24)],
				["log", "Split logs", Color(0.40, 0.27, 0.16)], ["stone", "Piled stone", Color(0.52, 0.51, 0.48)]]
		"roof":
			return [["thatch", "Grass thatch", Color(0.78, 0.66, 0.36)], ["hide", "Hide cover", Color(0.71, 0.60, 0.45)],
				["bark", "Bark shingles", Color(0.36, 0.26, 0.18)], ["fur", "Fur pelts", Color(0.48, 0.38, 0.28)]]
		"door":
			return [["hide_flap", "Hide flap", Color(0.55, 0.40, 0.25)], ["open", "Open arch", Color(0.12, 0.09, 0.07)],
				["bone_arch", "Bone arch", Color(0.90, 0.86, 0.75)], ["log_frame", "Log frame", Color(0.33, 0.22, 0.13)]]
		"decor":
			return [["none", "None", Color.WHITE], ["skulls", "Animal skulls", Color(0.92, 0.89, 0.80)],
				["antlers", "Antlers", Color(0.85, 0.78, 0.62)], ["totem", "Totem pole", Color(0.70, 0.30, 0.20)],
				["hides", "Drying hides", Color(0.74, 0.62, 0.45)]]
	return []


static func color_of(slot: String, id: String) -> Color:
	for row in options(slot):
		if row[0] == id:
			return row[2]
	return Color.MAGENTA


## [id, name] pairs, the format the designer's choice rows use.
static func option_pairs(slot: String) -> Array:
	var out: Array = []
	for row in options(slot):
		out.append([row[0], row[1]])
	return out


static func default_design(type_id: String) -> Dictionary:
	if type_id == "chief_hut":
		return {"walls": "log", "roof": "fur", "door": "bone_arch", "decor": "totem"}
	return {"walls": "hide", "roof": "thatch", "door": "hide_flap", "decor": "none"}
