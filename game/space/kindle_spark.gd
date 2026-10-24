class_name KindleSpark
extends Node2D
## The spark you drop to start a claim. Its ring shows claim progress, and
## Snuffers go straight for it.

const CORE_COLOR := Color(3.0, 2.3, 1.2)
const RING_COLOR := Color(2.0, 1.5, 0.6)
const SNUFF_COLOR := Color(1.8, 0.3, 2.0)

var progress := 0.0

var _time := 0.0
var _snuff_flash := 0.0


func snuffed() -> void:
	_snuff_flash = 1.0


func _process(delta: float) -> void:
	_time += delta
	_snuff_flash = maxf(_snuff_flash - delta * 2.0, 0.0)
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	draw_circle(Vector2.ZERO, 40.0 + 6.0 * pulse, Color(1.0, 0.7, 0.3, 0.06))
	draw_circle(Vector2.ZERO, 22.0 + 3.0 * pulse, Color(1.0, 0.75, 0.35, 0.14))
	draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 64, Color(1.0, 0.75, 0.35, 0.18), 1.0)
	if progress > 0.0:
		draw_arc(Vector2.ZERO, 30.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 64, RING_COLOR, 3.0)
	for i in 3:
		var angle := _time * 1.6 + i * TAU / 3.0
		draw_line(Vector2.from_angle(angle) * 13.0, Vector2.from_angle(angle) * 19.0, RING_COLOR, 2.0)
	draw_circle(Vector2.ZERO, 6.0 + pulse, CORE_COLOR)
	if _snuff_flash > 0.0:
		var color := SNUFF_COLOR
		color.a = _snuff_flash * 0.6
		draw_circle(Vector2.ZERO, 30.0 + 50.0 * (1.0 - _snuff_flash), color)
