extends RefCounted
## The rules that turn a blueprint's gear into stats, cost and squad size, plus
## how damage is resolved. All numbers are first-pass placeholders for balance.

const GearCatalog = preload("res://scripts/data/gear_catalog.gd")

const BASE_HP := 40
const HERO_HP_MULT := 3.0
const HERO_DAMAGE_MULT := 1.5
const BASE_SPEED := 80.0
const BASE_COST := 5
const MAX_BLOCK := 0.75
## Attacks with a range above this are ranged (they fire projectiles).
const RANGED_THRESHOLD := 60.0


## Stats for a unit carrying `gear` (slot -> item id).
static func compute(gear: Dictionary, is_hero: bool = false) -> Dictionary:
	var stats := {
		"hp": BASE_HP, "damage": 2, "damage_type": "blunt", "interval": 0.8, "range": 22.0,
		"armor": 0, "block": 0.0, "speed": BASE_SPEED, "cost": BASE_COST,
	}
	for slot_pair in GearCatalog.slots():
		var item: Dictionary = GearCatalog.get_item(str(gear.get(slot_pair[0], "")))
		if item.is_empty():
			continue
		stats["cost"] += int(item.get("cost", 0))
		stats["armor"] += int(item.get("armor", 0))
		stats["block"] += float(item.get("block", 0.0))
		stats["speed"] *= float(item.get("speed_mult", 1.0))
		if item.has("damage"):
			stats["damage"] = int(item["damage"])
			stats["damage_type"] = str(item["damage_type"])
			stats["interval"] = float(item["interval"])
			stats["range"] = float(item["range"])
	stats["block"] = minf(float(stats["block"]), MAX_BLOCK)
	if is_hero:
		stats["hp"] = int(round(BASE_HP * HERO_HP_MULT))
		stats["damage"] = int(round(int(stats["damage"]) * HERO_DAMAGE_MULT))
	stats["ranged"] = float(stats["range"]) > RANGED_THRESHOLD
	stats["squad_size"] = squad_size("infantry", int(stats["cost"]))
	return stats


## Squad size is fixed by unit type and how expensive the gear is:
## pricier units come in smaller squads.
static func squad_size(unit_type: String, cost: int) -> int:
	match unit_type:
		"beast":
			if cost <= 15:
				return 4
			if cost <= 25:
				return 3
			return 2
		"vehicle":
			if cost <= 30:
				return 3
			if cost <= 50:
				return 2
			return 1
		_:
			if cost <= 12:
				return 8
			if cost <= 22:
				return 6
			return 4


## Damage left after armor. Blunt ignores half of armor; pierce hits the
## lightly armored harder. A shield's block chance can stop a ranged hit
## entirely. `roll` is a random number in [0, 1).
static func resolve_damage(damage: int, damage_type: String, armor: int, ranged: bool, block: float, roll: float) -> int:
	if ranged and roll < block:
		return 0
	var effective_armor := float(armor)
	if damage_type == "blunt":
		effective_armor *= 0.5
	var dealt := float(damage) - effective_armor
	if damage_type == "pierce" and armor <= 1:
		dealt *= 1.25
	return maxi(1, int(round(dealt)))
