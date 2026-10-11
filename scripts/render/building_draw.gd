extends RefCounted
## Draws a building in 3/4 top-down view from its design. Every part is its own
## layer from Luke's hut sheets (assets/sprites/buildings/<shape>_<slot>_<id>/s.png),
## all drawn on one shared canvas, so they simply stack: walls, roof, doorway,
## hanging decoration, roof crest, yard prop. A missing part is skipped; with no
## walls or roof art at all a plain placeholder hut is drawn instead.
##
## `origin` is the center of the building's footprint on the ground; `width` is
## the footprint width in screen pixels.

const BuildingCatalog = preload("res://scripts/data/building_catalog.gd")
const BuildingParts = preload("res://scripts/data/building_parts.gd")
const SpriteLibrary = preload("res://scripts/render/sprite_library.gd")

const LAYERS := ["walls", "roof", "door", "hang", "crest", "yard"]
## Share of the footprint width the walls fill.
const WALL_FILL := 0.9


static func _ellipse(ci: CanvasItem, center: Vector2, rx: float, ry: float, col: Color) -> void:
	ci.draw_set_transform(center, 0.0, Vector2(1.0, ry / rx))
	ci.draw_circle(Vector2.ZERO, rx, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func part_texture(shape: String, slot: String, id: String):
	if id == "" or id == "none":
		return null
	var piece := "%s_%s_%s" % [BuildingCatalog.art_shape(slot, shape), slot, id]
	return SpriteLibrary.frame_at("buildings", piece, "s", "", 0.0)


static func draw_building(ci: CanvasItem, type_id: String, design: Dictionary, origin: Vector2, width: float,
		tint: Color = Color.WHITE) -> void:
	var d := BuildingCatalog.normalized(type_id, design)
	var shape := str(d["shape"])
	var scale := width * WALL_FILL / BuildingParts.wall_width()
	var canvas := BuildingParts.canvas()
	# The canvas is drawn by its bottom center; shift it so its anchor lands on the footprint center.
	var base := origin + Vector2(0.0, canvas.y - BuildingParts.anchor().y) * scale
	_ellipse(ci, origin + Vector2(0, width * 0.08), width * 0.48, width * 0.2, Color(0, 0, 0, 0.22 * tint.a))

	var drawn := 0
	for slot in LAYERS:
		var tex = part_texture(shape, slot, str(d.get(slot, "none")))
		if tex == null:
			continue
		var at := base
		if slot == "crest":
			var apexes: Dictionary = BuildingParts.roof_apexes()
			var apex := float(apexes.get("%s/%s" % [shape, d["roof"]], BuildingParts.crest_apex()))
			at.y += (apex - BuildingParts.crest_apex()) * scale
		SpriteLibrary.draw(ci, tex, at, scale, false, tint)
		drawn += 1
	if drawn == 0:
		_placeholder(ci, type_id, origin, width, tint)


## A plain hut, used only if the hut art is missing.
static func _placeholder(ci: CanvasItem, type_id: String, origin: Vector2, width: float, tint: Color) -> void:
	var rx := width * 0.42
	var ry := rx * 0.55
	var wall_h := rx * (0.75 if type_id == "chief_hut" else 0.65)
	var wall_col := Color(0.50, 0.38, 0.24) * tint
	var roof_col := Color(0.78, 0.66, 0.36) * tint
	_ellipse(ci, origin, rx, ry, wall_col.darkened(0.25))
	ci.draw_rect(Rect2(origin + Vector2(-rx, -wall_h), Vector2(rx * 2.0, wall_h)), wall_col)
	ci.draw_rect(Rect2(origin + Vector2(-rx * 0.19, ry * 0.35 - wall_h * 0.8), Vector2(rx * 0.38, wall_h * 0.8)),
		Color(0.12, 0.09, 0.07) * tint)
	var eave_y := origin.y - wall_h
	var apex := Vector2(origin.x, eave_y - rx)
	_ellipse(ci, Vector2(origin.x, eave_y), rx * 1.18, ry * 1.1, roof_col.darkened(0.15))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(origin.x - rx * 1.18, eave_y), apex,
		Vector2(origin.x + rx * 1.18, eave_y)]), roof_col)
