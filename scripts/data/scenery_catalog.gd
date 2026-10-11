extends RefCounted
## Scenery sprites (assets/sprites/scenery/<id>/s.png), grouped by how a map uses them.

static func trees() -> Array:
	return ["oak_large", "oak_medium", "oak_small", "pine_large", "pine_medium", "pine_small",
		"birch_medium", "birch_small", "dead_tree"]


static func bushes() -> Array:
	return ["bush_dense", "bush_sparse", "bush_sparse_small", "bush_berry_orange", "bush_berry_small",
		"bush_blueberry", "bush_raspberry"]


static func rocks() -> Array:
	return ["rock_large", "rock_tall", "rock_medium", "rock_small", "rock_flat", "rock_mossy_small", "boulder_mossy"]


## Small things on the ground: plants, flowers, mushrooms, stumps, logs.
static func ground_cover() -> Array:
	return ["grass_small", "grass_medium", "grass_large", "grass_thin", "fern_small", "fern_large",
		"flowers_white", "flowers_yellow", "mushrooms_small", "mushrooms_large", "stump_small", "stump_large",
		"roots_small", "roots_large", "log"]


static func all_ids() -> Array:
	return trees() + bushes() + rocks() + ground_cover()
