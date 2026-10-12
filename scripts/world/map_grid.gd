extends RefCounted
## A battle map's grid: square cells the size of one person (like the original
## Warcraft). Knows which squares are solid (walls, deep water, trees, rocks...),
## how fast each square's terrain is to cross, and finds paths around obstacles.
## Built from a generated map script such as scripts/data/wilderness_map.gd.

var tile := 32
var size := Vector2i.ZERO
var _astar := AStarGrid2D.new()
var _speed := PackedFloat32Array()
var _terrain: Array = []


func setup(map) -> void:
	tile = int(map.tile())
	size = map.size()
	_terrain = map.terrain()
	var speeds: Dictionary = map.speeds()
	var solid: Array = map.solid()
	_astar.region = Rect2i(Vector2i.ZERO, size)
	_astar.cell_size = Vector2(tile, tile)
	_astar.offset = Vector2(tile, tile) / 2.0  # paths run through square centers
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	_speed.resize(size.x * size.y)
	for y in size.y:
		var row: String = _terrain[y]
		var solid_row: String = solid[y]
		for x in size.x:
			var cell := Vector2i(x, y)
			var sp := float(speeds.get(row[x], 1.0))
			if solid_row[x] == "#" or sp <= 0.0:
				_astar.set_point_solid(cell, true)
				sp = 0.0
			else:
				# Slow ground costs more, so paths prefer the quick way round.
				_astar.set_point_weight_scale(cell, 1.0 / sp)
			_speed[y * size.x + x] = sp


func world_size() -> Vector2:
	return Vector2(size * tile)


func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(clampi(int(floor(pos.x / tile)), 0, size.x - 1), clampi(int(floor(pos.y / tile)), 0, size.y - 1))


func center_of(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * tile


func walkable(cell: Vector2i) -> bool:
	return _astar.region.has_point(cell) and not _astar.is_point_solid(cell)


## The terrain letter of a square (see the map script).
func terrain_at(cell: Vector2i) -> String:
	if not _astar.region.has_point(cell):
		return ""
	var row: String = _terrain[cell.y]
	return row[cell.x]


## How fast a unit moves here (1 = normal; tall grass and shallow water are slower).
func speed_at(pos: Vector2) -> float:
	var cell := cell_of(pos)
	var sp := _speed[cell.y * size.x + cell.x]
	return sp if sp > 0.0 else 1.0


## The open square nearest `cell` (itself if open).
func nearest_open(cell: Vector2i) -> Vector2i:
	if walkable(cell):
		return cell
	for r in range(1, 12):
		var best := Vector2i(-1, -1)
		var best_d := 1e9
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var c := cell + Vector2i(dx, dy)
				if walkable(c):
					var d := float(dx * dx + dy * dy)
					if d < best_d:
						best_d = d
						best = c
		if best.x >= 0:
			return best
	return cell


## Waypoints (world positions) from `from` to `to`, around every obstacle. If `to`
## is inside something solid, the path ends at the nearest open square; if it can't be
## reached at all, it gets as close as it can.
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := nearest_open(cell_of(from))
	var b := nearest_open(cell_of(to))
	var path := _astar.get_point_path(a, b, true)
	if path.size() > 0 and cell_of(to) == b:
		path[path.size() - 1] = to  # finish exactly where asked
	return path
