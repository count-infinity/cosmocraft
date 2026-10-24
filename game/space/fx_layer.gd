class_name FxLayer
extends Node2D
## Additive particle streaks and shockwave rings, simulated as plain arrays and
## drawn in one pass. Cheap enough to throw around on every hit.

const MAX_PARTICLES := 2000
const DRAG := 3.2

var _positions := PackedVector2Array()
var _velocities := PackedVector2Array()
var _life := PackedFloat32Array()
var _max_life := PackedFloat32Array()
var _widths := PackedFloat32Array()
var _colors := PackedColorArray()
var _rings: Array[Dictionary] = []


func _ready() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive


## Throws `count` streaks out of `origin`. `direction` and `spread` (radians)
## narrow the cone; the default spread of PI is a full circle.
func burst(origin: Vector2, color: Color, count: int, speed_min: float, speed_max: float, life: float, width: float, direction := 0.0, spread := PI) -> void:
	for i in count:
		if _positions.size() >= MAX_PARTICLES:
			return
		var particle_life := life * randf_range(0.6, 1.0)
		_positions.append(origin)
		_velocities.append(Vector2.from_angle(direction + randf_range(-spread, spread)) * randf_range(speed_min, speed_max))
		_life.append(particle_life)
		_max_life.append(particle_life)
		_widths.append(width * randf_range(0.7, 1.2))
		_colors.append(color)


func ring(origin: Vector2, color: Color, max_radius: float, life: float, width: float) -> void:
	_rings.append({"origin": origin, "color": color, "max_radius": max_radius, "life": life, "max_life": life, "width": width})


func update(delta: float) -> void:
	var drag := exp(-DRAG * delta)
	var i := 0
	while i < _positions.size():
		_life[i] -= delta
		if _life[i] <= 0.0:
			_remove(i)
			continue
		_velocities[i] *= drag
		_positions[i] += _velocities[i] * delta
		i += 1
	var rings: Array[Dictionary] = []
	for ring_data in _rings:
		ring_data["life"] = float(ring_data["life"]) - delta
		if float(ring_data["life"]) > 0.0:
			rings.append(ring_data)
	_rings = rings
	queue_redraw()


func _remove(i: int) -> void:
	var last := _positions.size() - 1
	_positions[i] = _positions[last]
	_velocities[i] = _velocities[last]
	_life[i] = _life[last]
	_max_life[i] = _max_life[last]
	_widths[i] = _widths[last]
	_colors[i] = _colors[last]
	_positions.resize(last)
	_velocities.resize(last)
	_life.resize(last)
	_max_life.resize(last)
	_widths.resize(last)
	_colors.resize(last)


func _draw() -> void:
	for i in _positions.size():
		var fade := _life[i] / _max_life[i]
		var color := _colors[i]
		color.a *= fade
		var tail := _velocities[i] * 0.035
		if tail.length_squared() < 2.25:
			tail = tail.normalized() * 1.5
		draw_line(_positions[i] - tail, _positions[i], color, _widths[i] * (0.4 + 0.6 * fade))
	for ring_data in _rings:
		var t := 1.0 - float(ring_data["life"]) / float(ring_data["max_life"])
		var radius := float(ring_data["max_radius"]) * (1.0 - pow(1.0 - t, 3.0))
		var color: Color = ring_data["color"]
		color.a *= 1.0 - t
		draw_arc(ring_data["origin"], radius, 0.0, TAU, 64, color, float(ring_data["width"]) * (1.0 - t * 0.5))
