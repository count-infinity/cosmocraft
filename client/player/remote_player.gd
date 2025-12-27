class_name RemotePlayer
extends Node2D

var player_id: String = ""
var player_name: String = ""

## State interpolator for smooth movement between server updates
var _interpolator: StateInterpolator

# Visual elements
var body: ColorRect
var aim_indicator: Polygon2D
var name_label: Label

func _ready() -> void:
	_create_visuals()
	_interpolator = StateInterpolator.new()

func _create_visuals() -> void:
	var size := GameConstants.PLAYER_SIZE
	var half_size := size / 2.0

	# Body - green square (different from local player)
	body = ColorRect.new()
	body.size = Vector2(size, size)
	body.position = Vector2(-half_size, -half_size)
	body.color = Color(0.2, 0.8, 0.3)  # Green
	add_child(body)

	# Aim indicator (scaled to player size)
	var indicator_length := size * 0.75
	var indicator_base := size * 0.25
	aim_indicator = Polygon2D.new()
	aim_indicator.polygon = PackedVector2Array([
		Vector2(indicator_length, 0),
		Vector2(indicator_length * 0.5, -indicator_base),
		Vector2(indicator_length * 0.5, indicator_base)
	])
	aim_indicator.color = Color(0.9, 0.9, 0.2)
	add_child(aim_indicator)

	# Name label
	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(-50, -half_size - 15)
	name_label.size = Vector2(100, 20)
	add_child(name_label)

func initialize(id: String, name: String, pos: Vector2) -> void:
	player_id = id
	player_name = name
	name_label.text = name
	position = pos

	# Initialize interpolator with current position
	if _interpolator == null:
		_interpolator = StateInterpolator.new()
	_interpolator.initialize_with_state({
		"position": pos,
		"aim_angle": 0.0
	})

func update_state(new_position: Vector2, new_aim_angle: float) -> void:
	_interpolator.add_state({
		"position": new_position,
		"aim_angle": new_aim_angle
	})

func _process(_delta: float) -> void:
	_apply_interpolation()

func _apply_interpolation() -> void:
	if _interpolator == null or not _interpolator.has_data():
		return

	position = _interpolator.interpolate_position()
	aim_indicator.rotation = _interpolator.interpolate_angle("aim_angle")
