extends RefCounted
## Stone Age buildings. Like the leader, each building is a base model with
## interchangeable parts the player picks in a designer. Parts are cosmetic;
## the building type sets what it does (the Chief's Hut is the HQ, each Hut
## houses a family of four = four soldiers you can field).
##
## A design picks a shape (round hut or longhouse), then a part for each slot.
## The parts come from Luke's ChatGPT hut sheets (building_parts.gd, generated
## by tools/huts/build.py). Walls, roof, doorway and crest belong to a shape;
## hanging decorations and yard props fit both.
##
## Footprints are in cells of the settlement's invisible grid (village_layout.gd).

const BuildingParts = preload("res://scripts/data/building_parts.gd")

## Slots that may be left empty.
const OPTIONAL_SLOTS := ["hang", "crest", "yard"]


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


static func shapes() -> Array:
	return [["round", "Round hut"], ["long", "Longhouse"]]


## Design slots, in the order the designer shows them.
static func part_slots() -> Array:
	return [["shape", "Shape"], ["walls", "Walls"], ["roof", "Roof"], ["door", "Doorway"],
		["crest", "Roof crest"], ["hang", "Hanging"], ["yard", "Yard"]]


## Which art set a slot uses: walls, roof, door and crest are per shape; the rest fit any shape.
static func art_shape(slot: String, shape: String) -> String:
	return "any" if slot == "hang" or slot == "yard" else shape


## [id, name] options for a slot of a building with this shape. The Chief's
## decorated roofs are only offered for the Chief's Hut.
static func options(slot: String, shape: String, type_id: String) -> Array:
	if slot == "shape":
		return shapes()
	var out: Array = []
	if OPTIONAL_SLOTS.has(slot):
		out.append(["none", "None"])
	var all: Dictionary = BuildingParts.options()
	var key := "%s/%s" % [art_shape(slot, shape), slot]
	for row in all.get(key, []):
		if bool(row[2]) and type_id != "chief_hut":
			continue
		out.append([str(row[0]), str(row[1])])
	return out


static func has_option(slot: String, shape: String, type_id: String, id: String) -> bool:
	for row in options(slot, shape, type_id):
		if row[0] == id:
			return true
	return false


static func default_design(type_id: String) -> Dictionary:
	if type_id == "chief_hut":
		return {"shape": "round", "walls": "painted_palisade", "roof": "antler_crown", "door": "antler_skull",
			"crest": "none", "hang": "blue_banner", "yard": "fire_pit"}
	return {"shape": "round", "walls": "post_ring", "roof": "thick_thatch", "door": "hide_flap",
		"crest": "pole_bundle", "hang": "none", "yard": "none"}


## A copy of `design` with every slot valid for its shape (old saves, or after
## the shape changes): unknown parts fall back to the default, then the first option.
static func normalized(type_id: String, design: Dictionary) -> Dictionary:
	var fallback := default_design(type_id)
	var out := {}
	var shape := str(design.get("shape", ""))
	if not has_option("shape", "", type_id, shape):
		shape = str(fallback["shape"])
	out["shape"] = shape
	for slot_pair in part_slots():
		var slot: String = slot_pair[0]
		if slot == "shape":
			continue
		var id := str(design.get(slot, ""))
		if not has_option(slot, shape, type_id, id):
			id = str(fallback.get(slot, ""))
			if not has_option(slot, shape, type_id, id):
				var opts := options(slot, shape, type_id)
				id = str(opts[0][0]) if not opts.is_empty() else "none"
		out[slot] = id
	return out
