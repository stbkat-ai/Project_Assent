extends RefCounted
## The settlement's invisible grid. Buildings snap to cells and may go anywhere
## inside the buildable area as long as their footprints don't overlap. The grid
## is never drawn; it just keeps placement tidy (and easy for the AI to read later).

const BuildingCatalog = preload("res://scripts/data/building_catalog.gd")

## World size of one cell. Cells are shorter than wide because the ground is
## seen at a 3/4 angle.
const CELL := Vector2(32, 24)
## Where buildings may go, in cells.
const AREA := Rect2i(5, 5, 40, 34)


## The cells a building of `type_id` covers when centered on `world_pos`.
static func footprint_at(type_id: String, world_pos: Vector2) -> Rect2i:
	var size: Vector2i = BuildingCatalog.get_type(type_id).get("footprint", Vector2i(3, 3))
	var cx := int(floor(world_pos.x / CELL.x))
	var cy := int(floor(world_pos.y / CELL.y))
	return Rect2i(cx - size.x / 2, cy - size.y / 2, size.x, size.y)


## True if `rect` is inside the buildable area and clear of every footprint in `taken`.
static func can_place(rect: Rect2i, taken: Array) -> bool:
	if not AREA.encloses(rect):
		return false
	for other in taken:
		var r: Rect2i = other
		if r.intersects(rect):
			return false
	return true


## The ground point at the center of a footprint (where the building is drawn).
static func center_of(rect: Rect2i) -> Vector2:
	return Vector2((rect.position.x + rect.size.x / 2.0) * CELL.x, (rect.position.y + rect.size.y / 2.0) * CELL.y)


## Total population (soldiers you can field) of placed buildings [{"type", "x", "y"}].
static func population(placed: Array) -> int:
	var total := 0
	for b in placed:
		total += int(BuildingCatalog.get_type(str(b["type"])).get("housing", 0))
	return total
