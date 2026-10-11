extends Control
## The title screen: the painted title art fills the screen (cropped to fit,
## never stretched), and its painted buttons are tap zones.

signal chosen(action: String)  # "new", "load", "settings", "credits" or "exit"

const ART := "res://assets/ui/title.png"
const ART_SIZE := Vector2(1672, 941)
## Where each painted button sits in the art, in art pixels.
const ZONES := {
	"new": Rect2(1145, 452, 365, 68),
	"load": Rect2(1145, 532, 365, 68),
	"settings": Rect2(1145, 612, 365, 70),
	"credits": Rect2(1145, 692, 365, 70),
	"exit": Rect2(1145, 774, 365, 68),
}

var _tex: Texture2D = null
var _pressed := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists(ART):
		_tex = load(ART)
	resized.connect(queue_redraw)


## Scale and offset that make the art cover the whole screen.
func _fit() -> Array:
	var s := maxf(size.x / ART_SIZE.x, size.y / ART_SIZE.y)
	return [s, (size - ART_SIZE * s) / 2.0]


func _zone_at(screen_pos: Vector2) -> String:
	var fit := _fit()
	var art_pos: Vector2 = (screen_pos - fit[1]) / fit[0]
	for key in ZONES:
		var zone: Rect2 = ZONES[key]
		if zone.has_point(art_pos):
			return key
	return ""


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.05, 0.05))
	if _tex == null:
		return
	var fit := _fit()
	var s: float = fit[0]
	var offset: Vector2 = fit[1]
	draw_texture_rect(_tex, Rect2(offset, ART_SIZE * s), false)
	if _pressed != "":
		var zone: Rect2 = ZONES[_pressed]
		draw_rect(Rect2(offset + zone.position * s, zone.size * s), Color(1.0, 0.85, 0.5, 0.18))


func _gui_input(event: InputEvent) -> void:
	var e = event
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_pressed = _zone_at(e.position)
		else:
			var released := _zone_at(e.position)
			if released != "" and released == _pressed:
				chosen.emit(released)
			_pressed = ""
		queue_redraw()
