class_name GameCamera
extends Camera2D
## Follows the ship with a little look-ahead toward the mouse, shakes on
## impact, and pulls back to frame the whole sector when the map is open.
## Runs on real time, so it keeps moving smoothly through hitstop.

const PLAY_ZOOM := 0.8
const LOOK_AHEAD := 0.22
const MAX_LOOK_AHEAD := 240.0
const MAX_SHAKE := 26.0

var target: Node2D
var play_zoom := PLAY_ZOOM
var map_mode := false
var map_zoom := 0.12
var look_ahead_enabled := true
## How quickly the camera catches up with its target (higher is tighter).
var follow_speed := 9.0

var _trauma := 0.0
var _punch := 0.0
var _zoom_level := PLAY_ZOOM
var _noise := FastNoiseLite.new()
var _time := 0.0


func _ready() -> void:
	_noise.frequency = 0.3
	make_current()


func add_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


func punch(amount: float) -> void:
	_punch = maxf(_punch, amount)


func snap_to(point: Vector2) -> void:
	global_position = point


## Jumps straight to play_zoom (when a mode starts).
func snap_zoom() -> void:
	_zoom_level = play_zoom
	zoom = Vector2.ONE * play_zoom


func _process(delta: float) -> void:
	_time += delta
	var wanted_zoom := map_zoom if map_mode else play_zoom
	_zoom_level = lerpf(_zoom_level, wanted_zoom, 1.0 - exp(-7.0 * delta))
	_punch = lerpf(_punch, 0.0, 1.0 - exp(-9.0 * delta))
	zoom = Vector2.ONE * _zoom_level * (1.0 + _punch)

	var focus := Vector2.ZERO
	if not map_mode and target != null:
		focus = target.global_position
		if look_ahead_enabled:
			var from_center := get_viewport().get_mouse_position() - get_viewport_rect().size * 0.5
			focus += (from_center / _zoom_level * LOOK_AHEAD).limit_length(MAX_LOOK_AHEAD)
	var follow := 4.0 if map_mode else follow_speed
	global_position = global_position.lerp(focus, 1.0 - exp(-follow * delta))

	_trauma = maxf(_trauma - delta * 1.5, 0.0)
	var shake := _trauma * _trauma * MAX_SHAKE
	offset = Vector2(_noise.get_noise_2d(_time * 70.0, 0.0), _noise.get_noise_2d(0.0, _time * 70.0 + 100.0)) * shake
