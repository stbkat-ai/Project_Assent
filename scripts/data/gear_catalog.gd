extends RefCounted
## Stone Age gear. Each item is plain data; stats, cost and squad size are
## worked out from it by unit_stats.gd. Later ages add more items here (or move
## this into Resource files) without changing any other code.
##
## Item fields:
##   id, name, slot, desc, cost
##   kind (thrust / swing / shoot / punch), shape (placeholder drawing), two_handed
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
		# kind: how it attacks (thrust / swing / shoot / punch) - drives the animation.
		# shape: which placeholder drawing to use until the weapon has art.
		{"id": "fists", "name": "Bare Hands", "slot": "main_hand", "desc": "Better than nothing. Barely.",
			"cost": 0, "damage": 2, "damage_type": "blunt", "interval": 0.8, "range": 22, "kind": "punch", "shape": ""},
		# Knives: quick, light hits.
		{"id": "stone_knife", "name": "Stone Knife", "slot": "main_hand", "desc": "A chipped stone blade. Fast, light cuts.",
			"cost": 2, "damage": 4, "damage_type": "slash", "interval": 0.6, "range": 20, "kind": "swing", "shape": "knife"},
		{"id": "bone_knife", "name": "Bone Knife", "slot": "main_hand", "desc": "A sharpened bone. Fast stabs.",
			"cost": 2, "damage": 4, "damage_type": "pierce", "interval": 0.6, "range": 20, "kind": "swing", "shape": "knife"},
		# Clubs and maces: blunt hits ignore half of armor.
		{"id": "club", "name": "Wooden Club", "slot": "main_hand", "desc": "Heavy wood. Blunt hits ignore half of armor.",
			"cost": 2, "damage": 6, "damage_type": "blunt", "interval": 1.0, "range": 24, "kind": "swing", "shape": "club"},
		{"id": "bone_club", "name": "Bone Club", "slot": "main_hand", "desc": "A great thigh bone. Hits a little harder.",
			"cost": 3, "damage": 7, "damage_type": "blunt", "interval": 1.0, "range": 24, "kind": "swing", "shape": "club"},
		{"id": "stone_club", "name": "Stone Club", "slot": "main_hand", "desc": "Wood bound with a stone head.",
			"cost": 4, "damage": 8, "damage_type": "blunt", "interval": 1.1, "range": 24, "kind": "swing", "shape": "club"},
		{"id": "stone_mace", "name": "Stone Mace", "slot": "main_hand", "desc": "A heavy round stone on a haft. Slow but crushing.",
			"cost": 6, "damage": 10, "damage_type": "blunt", "interval": 1.25, "range": 26, "kind": "swing", "shape": "mace"},
		{"id": "flail", "name": "Flail", "slot": "main_hand", "desc": "A stone on a cord. Slow, crushing blunt hits.",
			"cost": 6, "damage": 9, "damage_type": "blunt", "interval": 1.3, "range": 28, "kind": "swing", "shape": "flail"},
		# Axes: strong slashing hits.
		{"id": "stone_axe", "name": "Stone Axe", "slot": "main_hand", "desc": "A sharp stone head. Strong slashing hits.",
			"cost": 5, "damage": 7, "damage_type": "slash", "interval": 1.0, "range": 24, "kind": "swing", "shape": "axe"},
		{"id": "flint_axe", "name": "Flint Axe", "slot": "main_hand", "desc": "Knapped flint, keener than stone.",
			"cost": 6, "damage": 8, "damage_type": "slash", "interval": 1.0, "range": 24, "kind": "swing", "shape": "axe"},
		# Spears: reach, and they pierce the unarmored.
		{"id": "spear", "name": "Stone Spear", "slot": "main_hand", "desc": "Long reach. Pierces unarmored foes.",
			"cost": 4, "damage": 5, "damage_type": "pierce", "interval": 0.9, "range": 38, "kind": "thrust", "shape": "spear"},
		{"id": "bone_spear", "name": "Bone-tipped Spear", "slot": "main_hand", "desc": "A longer spear with a barbed bone head.",
			"cost": 6, "damage": 6, "damage_type": "pierce", "interval": 0.95, "range": 42, "kind": "thrust", "shape": "spear"},
		# Two-handed: big hits, but no shield.
		{"id": "great_club", "name": "Great Club", "slot": "main_hand", "desc": "Two-handed. A tree limb that flattens anything.",
			"cost": 8, "damage": 13, "damage_type": "blunt", "interval": 1.6, "range": 30, "kind": "swing", "shape": "great_club",
			"two_handed": true},
		{"id": "war_spear", "name": "War Spear", "slot": "main_hand", "desc": "Two-handed. The longest reach in the Stone Age.",
			"cost": 8, "damage": 9, "damage_type": "pierce", "interval": 1.1, "range": 50, "kind": "thrust", "shape": "spear",
			"two_handed": true},
		{"id": "stone_halberd", "name": "Stone Halberd", "slot": "main_hand", "desc": "Two-handed. An axe head on a long pole.",
			"cost": 10, "damage": 12, "damage_type": "slash", "interval": 1.4, "range": 44, "kind": "swing", "shape": "halberd",
			"two_handed": true},
		# Ranged.
		{"id": "sling", "name": "Sling", "slot": "main_hand", "desc": "Hurls stones from a distance. Shields can block it.",
			"cost": 4, "damage": 4, "damage_type": "pierce", "interval": 1.2, "range": 170, "kind": "shoot", "shape": "sling"},
		{"id": "bow", "name": "Bow", "slot": "main_hand", "desc": "Two-handed. Arrows from far away. Shields can block them.",
			"cost": 6, "damage": 5, "damage_type": "pierce", "interval": 1.3, "range": 220, "kind": "shoot", "shape": "bow",
			"two_handed": true},
		{"id": "reinforced_bow", "name": "Reinforced Bow", "slot": "main_hand", "desc": "Two-handed. Sinew-backed: stronger and farther.",
			"cost": 9, "damage": 7, "damage_type": "pierce", "interval": 1.4, "range": 240, "kind": "shoot", "shape": "bow",
			"two_handed": true},

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
		out.append([item["id"], str(item["name"]) + (" (two-handed)" if item.get("two_handed", false) else "")])
	return out


## Weapons a new game starts with. The others unlock later (tech, conquest rewards).
const STARTING_WEAPONS := ["spear", "club", "stone_axe"]


## Gear ids unlocked at the start of a new game: the starting weapons and all
## body armor and shields.
static func starting_unlocks() -> Array:
	var out: Array = []
	for item in items():
		if item["slot"] != "main_hand" or STARTING_WEAPONS.has(item["id"]):
			out.append(item["id"])
	return out


## [id, name] pairs for a slot, limited to unlocked ids.
static func unlocked_options_for_slot(slot: String, unlocked: Array) -> Array:
	var out: Array = []
	for option in options_for_slot(slot):
		if unlocked.has(option[0]):
			out.append(option)
	return out


## True for weapons that need both hands (no shield).
static func is_two_handed(id: String) -> bool:
	return bool(get_item(id).get("two_handed", false))


## How a weapon attacks: "thrust", "swing", "shoot" or "punch".
static func attack_kind(id: String) -> String:
	return str(get_item(id).get("kind", "punch"))


static func default_gear() -> Dictionary:
	return {"body": "none_body", "main_hand": "club", "off_hand": "none_off"}
