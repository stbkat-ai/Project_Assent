extends RefCounted
## The wilderness's creatures: their stats, how they behave and how many points
## they're worth. Points add up to the opening's score, and the score decides how
## many Huts the new village can raise at first (risk and reward: the dangerous
## animals are worth the most).
##
## Tempers:
##   aggressive  - attacks anything that comes within aggro range
##   territorial - attacks only when you come close (small aggro range)
##   defensive   - leaves you alone, but fights back when hit
##   skittish    - runs from you and never fights back

## Huts the village may raise before any score; then one more per HUT_POINTS.
const BASE_HUTS := 2
const HUT_POINTS := 150
const MAX_HUTS := 6


static func species() -> Array:
	return [
		{"id": "rabbit", "name": "Rabbit", "pieces": ["rabbit"], "points": 5, "temper": "skittish",
			"hp": 4, "damage": 0, "interval": 1.0, "speed": 72.0, "aggro": 0.0},
		{"id": "squirrel", "name": "Squirrel", "pieces": ["squirrel"], "points": 5, "temper": "skittish",
			"hp": 3, "damage": 0, "interval": 1.0, "speed": 70.0, "aggro": 0.0},
		{"id": "turkey", "name": "Wild turkey", "pieces": ["turkey"], "points": 10, "temper": "skittish",
			"hp": 8, "damage": 0, "interval": 1.0, "speed": 66.0, "aggro": 0.0},
		{"id": "doe", "name": "Doe", "pieces": ["deer_doe"], "points": 20, "temper": "skittish",
			"hp": 18, "damage": 0, "interval": 1.0, "speed": 74.0, "aggro": 0.0},
		{"id": "fox", "name": "Fox", "pieces": ["fox"], "points": 15, "temper": "defensive",
			"hp": 12, "damage": 2, "interval": 0.9, "speed": 85.0, "aggro": 0.0},
		{"id": "stag", "name": "Stag", "pieces": ["deer_stag"], "points": 35, "temper": "defensive",
			"hp": 35, "damage": 5, "interval": 1.2, "speed": 90.0, "aggro": 0.0},
		{"id": "wolf", "name": "Wolf", "pieces": ["wolf_gray", "wolf_brown"], "points": 25, "temper": "aggressive",
			"hp": 20, "damage": 3, "interval": 1.0, "speed": 100.0, "aggro": 190.0},
		{"id": "alpha_wolf", "name": "Alpha wolf", "pieces": ["wolf_gray"], "points": 60, "temper": "aggressive",
			"hp": 60, "damage": 6, "interval": 0.9, "speed": 105.0, "aggro": 220.0, "scale": 1.3},
		{"id": "boar", "name": "Wild boar", "pieces": ["boar"], "points": 40, "temper": "territorial",
			"hp": 50, "damage": 6, "interval": 1.2, "speed": 95.0, "aggro": 110.0},
		{"id": "bear", "name": "Brown bear", "pieces": ["bear"], "points": 100, "temper": "territorial",
			"hp": 140, "damage": 11, "interval": 1.5, "speed": 75.0, "aggro": 120.0},
	]


## Points for defeating a hostile caveman (a person, not an animal).
const CAVEMAN_POINTS := 40


static func get_species(id: String) -> Dictionary:
	for s in species():
		if s["id"] == id:
			return s
	return {}


## Combat stats in the shape Creature.apply_stats() takes.
static func stats(id: String) -> Dictionary:
	var s := get_species(id)
	return {"hp": int(s.get("hp", 10)), "damage": int(s.get("damage", 0)), "damage_type": "slash",
		"interval": float(s.get("interval", 1.0)), "range": 22.0, "ranged": false, "armor": 0, "block": 0.0,
		"speed": float(s.get("speed", 80.0))}


static func points(id: String) -> int:
	if id == "caveman":
		return CAVEMAN_POINTS
	return int(get_species(id).get("points", 0))


## How many Huts a village founded with this wilderness score may raise.
static func huts_for_score(score: int) -> int:
	return mini(MAX_HUTS, BASE_HUTS + maxi(score, 0) / HUT_POINTS)


## Points still needed for the next Hut, or 0 at the cap.
static func points_to_next_hut(score: int) -> int:
	if huts_for_score(score) >= MAX_HUTS:
		return 0
	return HUT_POINTS - maxi(score, 0) % HUT_POINTS
