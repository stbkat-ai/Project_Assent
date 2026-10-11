extends RefCounted
## Cosmetic choices for a character or a civilization's uniform. Appearance
## never changes stats; gear does that. Values are stored as string ids (not
## indices) so saved games stay valid when options are added later.
##
## Stone Age clothing comes in two mix-and-match collections:
##   Shaman  - animal-head hood, fur cloak, hide skirt
##   Caveman - bone headband, loincloth, bare torso


## Every editable appearance field: key, label, and [id, name] options.
static func fields() -> Array:
	return [
		{"key": "sex", "label": "Body", "options": [["male", "Male"], ["female", "Female"]]},
		{"key": "skin", "label": "Skin", "options": _pairs(skin_tones())},
		{"key": "hair", "label": "Hair", "options": [["bald", "Bald"], ["short", "Short"], ["long", "Long"], ["braids", "Braids"]]},
		{"key": "hair_color", "label": "Hair color", "options": _pairs(hair_colors())},
		{"key": "headwear", "label": "Headwear", "options": [
			["none", "None"], ["animal_hood", "Wolf-pelt hood (Shaman)"], ["antler_skull", "Antler skull helm (Shaman)"],
			["bone_headband", "Bone headband (Caveman)"]]},
		{"key": "cloak", "label": "Cloak", "options": [["none", "None"], ["fur_cloak", "Fur mantle (Shaman)"]]},
		{"key": "lower", "label": "Lower", "options": [["loincloth", "Loincloth (Caveman)"], ["hide_skirt", "Hide skirt (Shaman)"]]},
		{"key": "paint", "label": "War paint", "options": [["none", "None"], ["red", "Red ochre"], ["white", "White clay"]]},
		{"key": "tribe_color", "label": "Tribe color", "options": _pairs(tribe_colors())},
	]


static func skin_tones() -> Array:
	return [
		["skin1", "Light", Color(0.95, 0.82, 0.71)],
		["skin2", "Fair", Color(0.88, 0.70, 0.56)],
		["skin3", "Tan", Color(0.76, 0.57, 0.42)],
		["skin4", "Brown", Color(0.60, 0.42, 0.29)],
		["skin5", "Dark", Color(0.44, 0.30, 0.20)],
		["skin6", "Deep", Color(0.31, 0.21, 0.15)],
	]


static func hair_colors() -> Array:
	return [
		["black", "Black", Color(0.12, 0.10, 0.09)],
		["brown", "Brown", Color(0.36, 0.23, 0.14)],
		["auburn", "Auburn", Color(0.55, 0.25, 0.13)],
		["blond", "Blond", Color(0.85, 0.70, 0.40)],
		["grey", "Grey", Color(0.62, 0.60, 0.57)],
	]


static func tribe_colors() -> Array:
	return [
		["ochre", "Ochre", Color(0.80, 0.55, 0.20)],
		["blood", "Blood red", Color(0.62, 0.16, 0.13)],
		["forest", "Forest green", Color(0.27, 0.45, 0.22)],
		["sky", "Sky blue", Color(0.30, 0.52, 0.72)],
		["bone", "Bone white", Color(0.88, 0.85, 0.76)],
		["ash", "Ash grey", Color(0.45, 0.44, 0.42)],
	]


static func paint_color(id: String) -> Color:
	if id == "white":
		return Color(0.93, 0.92, 0.88)
	return Color(0.72, 0.18, 0.12)


## Color for a color field ("skin", "hair_color", "tribe_color") by id.
static func color_of(field: String, id: String) -> Color:
	var table: Array = []
	match field:
		"skin":
			table = skin_tones()
		"hair_color":
			table = hair_colors()
		"tribe_color":
			table = tribe_colors()
	for row in table:
		if row[0] == id:
			return row[2]
	if table.is_empty():
		return Color.MAGENTA
	return table[0][2]


static func default_look() -> Dictionary:
	return {
		"sex": "male", "skin": "skin3", "hair": "long", "hair_color": "brown",
		"headwear": "none", "cloak": "none", "lower": "loincloth", "paint": "none",
		"tribe_color": "ochre",
	}


static func random_look(rng: RandomNumberGenerator) -> Dictionary:
	var look := {}
	for field in fields():
		var options: Array = field["options"]
		look[field["key"]] = options[rng.randi_range(0, options.size() - 1)][0]
	return look


static func _pairs(rows: Array) -> Array:
	var out: Array = []
	for row in rows:
		out.append([row[0], row[1]])
	return out
