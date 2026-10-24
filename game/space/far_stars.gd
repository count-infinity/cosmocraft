class_name FarStars
extends Node2D
## Distant stars on a layer behind everything, drifting slowly as the camera
## moves so space has some depth. Lives on its own CanvasLayer.

const COUNT := 240
const TILE := Vector2(1600.0, 1000.0)
const PARALLAX := 0.05

var camera: Camera2D

var _points := PackedVector2Array()
var _colors := PackedColorArray()


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in COUNT:
		_points.append(Vector2(rng.randf() * TILE.x, rng.randf() * TILE.y))
		var brightness := rng.randf()
		_colors.append(Color(0.55, 0.6, 0.9, 0.12 + 0.3 * brightness * brightness))


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size
	var shift := Vector2.ZERO
	if camera != null:
		shift = -camera.global_position * PARALLAX
	for i in COUNT:
		var x := fposmod(_points[i].x + shift.x, TILE.x)
		while x < view.x:
			var y := fposmod(_points[i].y + shift.y, TILE.y)
			while y < view.y:
				draw_rect(Rect2(x, y, 1.5, 1.5), _colors[i])
				y += TILE.y
			x += TILE.x
