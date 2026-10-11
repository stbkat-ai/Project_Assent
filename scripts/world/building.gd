extends Node2D
## A building placed in the settlement. Sits in the depth-sorted layer with
## units; its position is the center of its footprint on the ground.

const BuildingDraw = preload("res://scripts/render/building_draw.gd")
const VillageLayout = preload("res://scripts/data/village_layout.gd")

var type_id := "hut"
var design: Dictionary = {}
var rect := Rect2i()
var selected := false
var ghost := false  # placement preview
var valid := true


func setup(t: String, d: Dictionary, r: Rect2i) -> void:
	type_id = t
	design = d
	rect = r
	position = VillageLayout.center_of(r)
	queue_redraw()


func _draw() -> void:
	var width := rect.size.x * VillageLayout.CELL.x
	var tint := Color.WHITE
	if ghost:
		tint = Color(0.6, 1.0, 0.6, 0.75) if valid else Color(1.0, 0.45, 0.4, 0.75)
	if selected or ghost:
		var rx := width * 0.55
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
		draw_arc(Vector2.ZERO, rx, 0.0, TAU, 40, Color(0.95, 0.80, 0.30, 0.9) if valid else Color(1, 0.3, 0.3, 0.9), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	BuildingDraw.draw_building(self, type_id, design, Vector2.ZERO, width, tint)
