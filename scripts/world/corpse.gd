extends Node2D
## What's left after a unit falls: its death sprite (or, for a person, their
## figure lying on the ground), fading away after a while.

const SpriteLibrary = preload("res://scripts/render/sprite_library.gd")
const Figure = preload("res://scripts/render/figure.gd")

const LINGER := 10.0
const FADE := 3.0

var tex: Texture2D
var mirrored := false
var scale_factor := 1.0
## A fallen person: drawn as their figure, laid on its back (the node is turned on its side).
var figure := false
var look: Dictionary = {}
var gear: Dictionary = {}
var dir := 2
var px := 2.4
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t > LINGER:
		modulate.a = maxf(0.0, 1.0 - (_t - LINGER) / FADE)
		if modulate.a <= 0.0:
			queue_free()


func _draw() -> void:
	if figure:
		Figure.draw_human(self, Vector2.ZERO, px, look, gear, dir)
	elif tex != null:
		SpriteLibrary.draw(self, tex, Vector2.ZERO, scale_factor, mirrored)
