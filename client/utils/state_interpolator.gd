class_name StateInterpolator
extends RefCounted
## Shared utility for interpolating network entity state.
## Used by RemotePlayer and EnemyVisual to smoothly render positions
## between server updates with a configurable delay.


## Maximum number of states to keep in the buffer
const DEFAULT_BUFFER_SIZE: int = 10


## State buffer: stores recent server states
## Each entry is a Dictionary with at minimum: "position", "timestamp"
## Additional fields (aim_angle, facing_angle, etc.) are preserved
var state_buffer: Array[Dictionary] = []

## Maximum buffer size
var buffer_size: int = DEFAULT_BUFFER_SIZE

## Render delay in seconds (how far behind live we render)
var render_delay: float = GameConstants.INTERPOLATION_DELAY


## Add a new state to the buffer with the current timestamp
func add_state(state: Dictionary) -> void:
	state["timestamp"] = Time.get_ticks_msec() / 1000.0
	state_buffer.append(state)

	# Trim old states
	while state_buffer.size() > buffer_size:
		state_buffer.pop_front()


## Get the interpolated state at the current render time
## Returns a Dictionary with interpolated values, or empty if no data
func get_interpolated_state() -> Dictionary:
	if state_buffer.is_empty():
		return {}

	if state_buffer.size() < 2:
		# Not enough data to interpolate, return latest
		return state_buffer[0].duplicate()

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

	# Return interpolated result
	return {
		"older_state": older_state,
		"newer_state": newer_state,
		"t": t,
		"render_time": render_time
	}


## Convenience: Interpolate a Vector2 position
func interpolate_position() -> Vector2:
	var result := get_interpolated_state()
	if result.is_empty():
		return Vector2.ZERO

	var older_pos: Vector2 = result["older_state"].get("position", Vector2.ZERO)
	var newer_pos: Vector2 = result["newer_state"].get("position", Vector2.ZERO)
	var t: float = result["t"]

	return older_pos.lerp(newer_pos, t)


## Convenience: Interpolate an angle (uses lerp_angle for proper wrap-around)
func interpolate_angle(key: String) -> float:
	var result := get_interpolated_state()
	if result.is_empty():
		return 0.0

	var old_angle: float = result["older_state"].get(key, 0.0)
	var new_angle: float = result["newer_state"].get(key, 0.0)
	var t: float = result["t"]

	return lerp_angle(old_angle, new_angle, t)


## Get the latest state without interpolation (for reading current values)
func get_latest_state() -> Dictionary:
	if state_buffer.is_empty():
		return {}
	return state_buffer[-1]


## Check if the buffer has any data
func has_data() -> bool:
	return not state_buffer.is_empty()


## Clear all buffered states
func clear() -> void:
	state_buffer.clear()


## Initialize with an initial state
func initialize_with_state(state: Dictionary) -> void:
	clear()
	add_state(state)
