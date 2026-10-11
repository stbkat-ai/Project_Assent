extends RefCounted
## Stone Age gear. Each item is plain data; stats, cost and squad size are
## worked out from it by unit_stats.gd. Later ages add more items here (or move
## this into Resource files) without changing any other code.
##
## Item fields:
##   id, name, slot, desc, cost
##   damage, damage_type ("blunt" | "slash" | "pierce"), interval (s), range (px)
##   armor, block (chance to stop a ranged hit), speed_mult


static func slots() -> Array:
	return [
		["body", "Body armor"],
		["main_hand", "Main hand"],
		["off_hand", "Off hand"],
	]


static func items() -> Array:
	return [
		# --- Body armor ---
		{"id": "none_body", "name": "None", "slot": "body", "desc": "Nothing but skin.", "cost": 0},
		{"id": "hide_wrap", "name": "Hide Wrap", "slot": "body", "desc": "Light hide tied around the chest.",
			"cost": 3, "armor": 1},
		{"id": "leather_armor", "name": "Leather Armor", "slot": "body", "desc": "Cured leather. Solid, a little heavy.",
			"cost": 6, "armor": 2, "speed_mult": 0.95},
		{"id": "bone_hide", "name": "Bone-and-Hide", "slot": "body", "desc": "Hide sewn with bone plates. Tough but slow.",
			"cost": 10, "armor": 3, "speed_mult": 0.88},

		# --- Main hand ---
		{"id": "fists", "name": "Bare Hands", "slot": "main_hand", "desc": "Better than nothing. Barely.",
			"cost": 0, "damage": 2, "damage_type": "blunt", "interval": 0.8, "range": 22},
		{"id": "club", "name": "Club", "slot": "main_hand", "desc": "Heavy wood. Blunt hits ignore half of armor.",
			"cost": 2, "damage": 6, "damage_type": "blunt", "interval": 1.0, "range": 24},
		{"id": "spear", "name": "Stone Spear", "slot": "main_hand", "desc": "Long reach. Pierces unarmored foes.",
			"cost": 4, "damage": 5, "damage_type": "pierce", "interval": 0.9, "range": 38},
		{"id": "stone_axe", "name": "Stone Axe", "slot": "main_hand", "desc": "A sharp stone head. Strong slashing hits.",
			"cost": 5, "damage": 7, "damage_type": "slash", "interval": 1.0, "range": 24},
		{"id": "flail", "name": "Flail", "slot": "main_hand", "desc": "A stone on a cord. Slow, crushing blunt hits.",
			"cost": 6, "damage": 9, "damage_type": "blunt", "interval": 1.3, "range": 28},
		{"id": "sling", "name": "Sling", "slot": "main_hand", "desc": "Hurls stones from a distance. Shields can block it.",
			"cost": 4, "damage": 4, "damage_type": "pierce", "interval": 1.2, "range": 170},

		# --- Off hand ---
		{"id": "none_off", "name": "None", "slot": "off_hand", "desc": "A free hand.", "cost": 0},
		{"id": "hide_shield", "name": "Hide Shield", "slot": "off_hand", "desc": "Stretched hide on a frame. Blocks some stones.",
			"cost": 3, "armor": 1, "block": 0.3, "speed_mult": 0.97},
		{"id": "bone_shield", "name": "Bone Shield", "slot": "off_hand", "desc": "Heavy and sturdy. Blocks many stones.",
			"cost": 6, "armor": 2, "block": 0.5, "speed_mult": 0.92},
	]


static func get_item(id: String) -> Dictionary:
	for item in items():
		if item["id"] == id:
			return item
	return {}


static func for_slot(slot: String) -> Array:
	var out: Array = []
	for item in items():
		if item["slot"] == slot:
			out.append(item)
	return out


## [id, name] pairs for a slot, the format the editor's choice rows use.
static func options_for_slot(slot: String) -> Array:
	var out: Array = []
	for item in for_slot(slot):
		out.append([item["id"], item["name"]])
	return out


static func default_gear() -> Dictionary:
	return {"body": "none_body", "main_hand": "club", "off_hand": "none_off"}
