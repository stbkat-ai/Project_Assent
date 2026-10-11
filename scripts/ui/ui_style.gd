extends RefCounted
## Shared look for the placeholder UI: one theme with phone-sized text and
## buttons, plus a few colors.

const BG := Color(0.09, 0.08, 0.07)
const PANEL := Color(0.15, 0.13, 0.11, 0.92)
const GOLD := Color(0.85, 0.64, 0.25)
const TEXT := Color(0.93, 0.90, 0.84)
const MUTED := Color(0.68, 0.64, 0.57)
const BUTTON_HEIGHT := 56.0


static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 22
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_stylebox("normal", "Button", _box(Color(0.25, 0.21, 0.16)))
	theme.set_stylebox("hover", "Button", _box(Color(0.32, 0.27, 0.20)))
	theme.set_stylebox("pressed", "Button", _box(Color(0.45, 0.34, 0.18)))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_stylebox("disabled", "Button", _box(Color(0.18, 0.16, 0.14)))
	theme.set_stylebox("panel", "PanelContainer", _box(PANEL))
	return theme


static func _box(col: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = col
	box.set_corner_radius_all(6)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


static func button(text: String, min_width: float = 56.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, BUTTON_HEIGHT)
	return b


static func label(text: String, font_size: int = 22, col: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	return l


static func full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c
