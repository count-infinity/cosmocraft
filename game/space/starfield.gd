class_name Starfield
extends Node2D
## Stars scattered across the sector in world space. Region fog draws over
## them, so they only really shine in claimed space.

const STAR_COUNT := 1800
const TINTS: Array[Color] = [Color(1.0, 1.0, 1.0), Color(0.8, 0.88, 1.0), Color(1.0, 0.9, 0.75)]

var _positions := PackedVector2Array()
var _sizes := PackedFloat32Array()
var _colors := PackedColorArray()


func build(radius: float, star_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = star_seed
	_positions.clear()
	_sizes.clear()
	_colors.clear()
	var reach := radius * 1.45
	for i in STAR_COUNT:
		_positions.append(Vector2(rng.randf_range(-reach, reach), rng.randf_range(-reach, reach)))
		var brightness := pow(rng.randf(), 3.0)
		_sizes.append(1.2 + brightness * 2.4)
		var color := TINTS[rng.randi() % TINTS.size()] * (0.35 + brightness * 1.3)
		color.a = 1.0
		_colors.append(color)
	queue_redraw()


func _draw() -> void:
	for i in _positions.size():
		var size := _sizes[i]
		draw_rect(Rect2(_positions[i] - Vector2(size, size) * 0.5, Vector2(size, size)), _colors[i])
