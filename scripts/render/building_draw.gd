extends RefCounted
## Draws a building in 3/4 top-down view from its design (walls, roof, door,
## decoration). Every part is its own layer; a part with art in
## assets/sprites/buildings/<type>_<slot>_<option>/s.png is drawn from the sprite,
## otherwise it is a placeholder drawn in code.
##
## `origin` is the center of the building's footprint on the ground; `width` is
## the footprint width in screen pixels.

const BuildingCatalog = preload("res://scripts/data/building_catalog.gd")
const SpriteLibrary = preload("res://scripts/render/sprite_library.gd")

const DARK := Color(0.12, 0.09, 0.07)
const BONE := Color(0.90, 0.86, 0.75)


static func _ellipse(ci: CanvasItem, center: Vector2, rx: float, ry: float, col: Color) -> void:
	ci.draw_set_transform(center, 0.0, Vector2(1.0, ry / rx))
	ci.draw_circle(Vector2.ZERO, rx, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Draw the art for one part if it exists. Art is anchored at the footprint center
## and drawn at `scale` screen pixels per art pixel. Returns false if there is none.
static func _sprite(ci: CanvasItem, type_id: String, slot: String, option: String, origin: Vector2, scale: float) -> bool:
	var tex = SpriteLibrary.frame_at("buildings", "%s_%s_%s" % [type_id, slot, option], "s", "", 0.0)
	if tex == null:
		return false
	SpriteLibrary.draw(ci, tex, origin, scale, false)
	return true


static func draw_building(ci: CanvasItem, type_id: String, design: Dictionary, origin: Vector2, width: float,
		tint: Color = Color.WHITE, art_scale: float = 1.0) -> void:
	var chief := type_id == "chief_hut"
	var rx := width * 0.42
	var ry := rx * 0.55
	var wall_h := rx * (0.75 if chief else 0.65)
	var walls_id := str(design.get("walls", "hide"))
	var roof_id := str(design.get("roof", "thatch"))
	var door_id := str(design.get("door", "hide_flap"))
	var decor_id := str(design.get("decor", "none"))
	var wall_col := BuildingCatalog.color_of("walls", walls_id) * tint
	var roof_col := BuildingCatalog.color_of("roof", roof_id) * tint
	var door_col := BuildingCatalog.color_of("door", door_id) * tint

	_ellipse(ci, origin, rx * 1.15, ry * 1.15, Color(0, 0, 0, 0.25))

	# Walls: a short cylinder.
	if not _sprite(ci, type_id, "walls", walls_id, origin, art_scale):
		_ellipse(ci, origin, rx, ry, wall_col.darkened(0.25))
		ci.draw_rect(Rect2(origin + Vector2(-rx, -wall_h), Vector2(rx * 2.0, wall_h)), wall_col)
		match walls_id:
			"wattle":
				for i in 4:
					var y := origin.y - wall_h + wall_h * (i + 0.5) / 4.0
					ci.draw_line(Vector2(origin.x - rx, y), Vector2(origin.x + rx, y), wall_col.darkened(0.3), 2.0)
			"log":
				for i in 7:
					var x := origin.x - rx + rx * 2.0 * (i + 0.5) / 7.0
					ci.draw_line(Vector2(x, origin.y - wall_h), Vector2(x, origin.y), wall_col.darkened(0.35), 2.0)
			"stone":
				for i in 10:
					var p := origin + Vector2(-rx * 0.85 + (i % 5) * rx * 0.42, -wall_h * (0.3 + 0.4 * float(i / 5)))
					ci.draw_circle(p, rx * 0.08, wall_col.lightened(0.2))

	# Doorway, facing the viewer.
	if not _sprite(ci, type_id, "door", door_id, origin, art_scale):
		var dw := rx * (0.42 if chief else 0.38)
		var dh := wall_h * 0.8
		var door_rect := Rect2(origin + Vector2(-dw / 2.0, ry * 0.35 - dh), Vector2(dw, dh))
		ci.draw_rect(door_rect, DARK * tint)
		match door_id:
			"hide_flap":
				ci.draw_rect(Rect2(door_rect.position, Vector2(dw, dh * 0.7)), door_col)
			"bone_arch", "log_frame":
				var t := 3.0
				ci.draw_rect(Rect2(door_rect.position - Vector2(t, t), Vector2(t, dh + t)), door_col)
				ci.draw_rect(Rect2(door_rect.position + Vector2(dw, -t), Vector2(t, dh + t)), door_col)
				ci.draw_rect(Rect2(door_rect.position - Vector2(t, t), Vector2(dw + t * 2.0, t)), door_col)

	# Roof: a cone with a rounded eave.
	if not _sprite(ci, type_id, "roof", roof_id, origin, art_scale):
		var eave_y := origin.y - wall_h
		var apex := Vector2(origin.x, eave_y - rx * (1.25 if chief else 1.0))
		_ellipse(ci, Vector2(origin.x, eave_y), rx * 1.18, ry * 1.1, roof_col.darkened(0.15))
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(origin.x - rx * 1.18, eave_y), apex, Vector2(origin.x + rx * 1.18, eave_y),
			Vector2(origin.x + rx * 0.6, eave_y + ry * 0.9), Vector2(origin.x - rx * 0.6, eave_y + ry * 0.9)]), roof_col)
		ci.draw_line(apex, Vector2(origin.x - rx * 0.3, eave_y + ry * 0.9), roof_col.darkened(0.2), 2.0)
		ci.draw_line(apex, Vector2(origin.x + rx * 0.5, eave_y + ry * 0.8), roof_col.darkened(0.2), 2.0)
		if chief:
			ci.draw_line(apex, apex + Vector2(-rx * 0.15, -rx * 0.25), DARK * tint, 3.0)
			ci.draw_line(apex, apex + Vector2(rx * 0.15, -rx * 0.25), DARK * tint, 3.0)

	# Decoration.
	if decor_id != "none" and not _sprite(ci, type_id, "decor", decor_id, origin, art_scale):
		var dc := BuildingCatalog.color_of("decor", decor_id) * tint
		match decor_id:
			"skulls":
				for side in [-1.0, 1.0]:
					var p := origin + Vector2(side * rx * 0.62, -wall_h * 0.55)
					ci.draw_circle(p, rx * 0.11, dc)
					ci.draw_rect(Rect2(p + Vector2(-rx * 0.05, -rx * 0.02), Vector2(rx * 0.04, rx * 0.04)), DARK * tint)
			"antlers":
				var top := origin + Vector2(0, -wall_h - rx * (1.25 if chief else 1.0))
				for side in [-1.0, 1.0]:
					ci.draw_line(top, top + Vector2(side * rx * 0.35, -rx * 0.3), dc, 3.0)
					ci.draw_line(top + Vector2(side * rx * 0.2, -rx * 0.17), top + Vector2(side * rx * 0.25, -rx * 0.4), dc, 2.0)
			"totem":
				var base := origin + Vector2(rx * 1.3, ry * 0.4)
				var h := wall_h * 2.2
				ci.draw_rect(Rect2(base + Vector2(-rx * 0.09, -h), Vector2(rx * 0.18, h)), Color(0.45, 0.30, 0.18) * tint)
				for i in 3:
					ci.draw_rect(Rect2(base + Vector2(-rx * 0.13, -h + i * h * 0.3), Vector2(rx * 0.26, h * 0.12)),
						dc if i % 2 == 0 else Color(0.85, 0.65, 0.25) * tint)
			"hides":
				for side in [-1.0, 1.0]:
					ci.draw_rect(Rect2(origin + Vector2(side * rx * 0.62 - rx * 0.13, -wall_h * 0.8), Vector2(rx * 0.26, wall_h * 0.55)), dc)
