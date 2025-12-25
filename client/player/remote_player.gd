class_name RemotePlayer
extends Node2D

var player_id: String = ""
var player_name: String = ""

# Interpolation buffer: stores recent server states
var state_buffer: Array = []  # Array of {tick, position, aim_angle, timestamp}
const BUFFER_SIZE: int = 10

# Visual elements
var body: ColorRect
var aim_indicator: Polygon2D
var name_label: Label

# Interpolation
var render_delay: float = GameConstants.INTERPOLATION_DELAY

func _ready() -> void:
	_create_visuals()

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

	# Initialize buffer with current position
	var now := Time.get_ticks_msec() / 1000.0
	state_buffer.append({
		"position": pos,
		"aim_angle": 0.0,
		"timestamp": now
	})

func update_state(new_position: Vector2, new_aim_angle: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0

	state_buffer.append({
		"position": new_position,
		"aim_angle": new_aim_angle,
		"timestamp": now
	})

	# Trim old states
	while state_buffer.size() > BUFFER_SIZE:
		state_buffer.pop_front()

func _process(_delta: float) -> void:
	_interpolate()

func _interpolate() -> void:
	if state_buffer.size() < 2:
		# Not enough data to interpolate, just use latest
		if state_buffer.size() == 1:
			var state: Dictionary = state_buffer[0]
			position = state["position"]
			aim_indicator.rotation = state["aim_angle"]
		return

	# Render time is current time minus delay
	var render_time: float = Time.get_ticks_msec() / 1000.0 - render_delay

	# Find the two states to interpolate between
	var older_state: Dictionary = state_buffer[0]
	var newer_state: Dictionary = state_buffer[0]
	var found_states := false

	for i in range(state_buffer.size() - 1):
		var state_i: Dictionary = state_buffer[i]
		var state_i_next: Dictionary = state_buffer[i + 1]
		var ts_i: float = state_i["timestamp"]
		var ts_i_next: float = state_i_next["timestamp"]
		if ts_i <= render_time and ts_i_next >= render_time:
			older_state = state_i
			newer_state = state_i_next
			found_states = true
			break
		elif ts_i > render_time:
			# Render time is before our oldest data, use oldest
			older_state = state_buffer[0]
			newer_state = state_buffer[0]
			found_states = true
			break

	if not found_states:
		# Render time is after our newest data, use newest
		older_state = state_buffer[state_buffer.size() - 1]
		newer_state = older_state

	# Calculate interpolation factor
	var older_time: float = older_state["timestamp"]
	var newer_time: float = newer_state["timestamp"]
	var time_diff: float = newer_time - older_time
	var t: float = 0.0
	if time_diff > 0:
		t = (render_time - older_time) / time_diff
		t = clampf(t, 0.0, 1.0)

	# Interpolate position and aim
	var older_pos: Vector2 = older_state["position"]
	var newer_pos: Vector2 = newer_state["position"]
	position = older_pos.lerp(newer_pos, t)
	var old_aim: float = older_state["aim_angle"]
	var new_aim: float = newer_state["aim_angle"]
	aim_indicator.rotation = lerp_angle(old_aim, new_aim, t)
