extends Node
## Touch and mouse controls for a map: drag to pan, pinch (or mouse wheel) to
## zoom, and tap. Emits `tapped` with the world position of each tap.

signal tapped(world_pos: Vector2)
signal panned

const TAP_SLOP := 14.0

var camera: Camera2D
var bounds := Rect2(0, 0, 1000, 1000)
var min_zoom := 0.6
var max_zoom := 2.4
var enabled := true

var _press_pos = null
var _dragged := false
var _touches := {}
var _pinch_dist := 0.0
var _gestured := false


func _unhandled_input(input_event: InputEvent) -> void:
	if not enabled or camera == null:
		return
	var event = input_event  # untyped: fields differ per event class
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		if _touches.size() >= 2:
			_gestured = true
			_pinch_dist = _two_finger_distance()
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			var d := _two_finger_distance()
			if _pinch_dist > 0.0 and d > 0.0:
				set_zoom(camera.zoom.x * d / _pinch_dist)
			_pinch_dist = d
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			set_zoom(camera.zoom.x * 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			set_zoom(camera.zoom.x / 1.1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_pos = event.position
				_dragged = false
				if _touches.size() <= 1:
					_gestured = false
			else:
				if _press_pos != null and not _dragged and not _gestured:
					var world: Vector2 = camera.get_canvas_transform().affine_inverse() * event.position
					tapped.emit(world)
				_press_pos = null
	elif event is InputEventMouseMotion:
		if _press_pos != null and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if not _dragged and event.position.distance_to(_press_pos) > TAP_SLOP:
				_dragged = true
			if _dragged and not _gestured and _touches.size() < 2:
				camera.position -= event.relative / camera.zoom.x
				camera.position = camera.position.clamp(bounds.position, bounds.end)
				panned.emit()


func _two_finger_distance() -> float:
	var points := _touches.values()
	if points.size() < 2:
		return 0.0
	var a: Vector2 = points[0]
	var b: Vector2 = points[1]
	return a.distance_to(b)


func set_zoom(z: float) -> void:
	var clamped := clampf(z, min_zoom, max_zoom)
	camera.zoom = Vector2(clamped, clamped)
