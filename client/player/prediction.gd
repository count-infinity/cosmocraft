class_name ClientPrediction
extends RefCounted

# Buffer of unacknowledged inputs: sequence -> {input_data, predicted_position}
var input_buffer: Dictionary = {}

# Reference to chunk manager for collision checking during reconciliation
var chunk_manager: ChunkManager = null

# Store an input and its predicted result
func store_input(sequence: int, input_data: Dictionary, predicted_position: Vector2) -> void:
	input_buffer[sequence] = {
		"input": input_data,
		"position": predicted_position
	}

	# Limit buffer size
	_trim_buffer()

# Clear inputs that have been acknowledged by server
func acknowledge_up_to(sequence: int) -> void:
	var to_remove: Array = []
	for seq in input_buffer:
		if seq <= sequence:
			to_remove.append(seq)

	for seq in to_remove:
		input_buffer.erase(seq)

# Get unacknowledged inputs for replay (sorted by sequence)
func get_unacknowledged_inputs() -> Array:
	var sequences := input_buffer.keys()
	sequences.sort()

	var inputs: Array = []
	for seq in sequences:
		inputs.append(input_buffer[seq]["input"])
	return inputs

# Reconcile client position with server position
# Returns the corrected position after replaying unacknowledged inputs
func reconcile(server_position: Vector2, last_processed_sequence: int, delta: float) -> Vector2:
	# First, clear acknowledged inputs
	acknowledge_up_to(last_processed_sequence)

	# Check if we need correction
	var unacked := get_unacknowledged_inputs()
	if unacked.is_empty():
		return server_position

	# Replay unacknowledged inputs from server position
	var position := server_position
	for input_data in unacked:
		var move_dir: Vector2 = input_data.get("move_direction", Vector2.ZERO)
		var velocity := move_dir.normalized() * GameConstants.PLAYER_SPEED
		var movement := velocity * delta

		# Apply movement with collision checking if chunk manager available
		if chunk_manager != null:
			position = CollisionHelper.apply_movement_with_collision(
				position, movement, chunk_manager
			)
		else:
			position += movement

		position = _clamp_position(position)

	return position

func _clamp_position(pos: Vector2) -> Vector2:
	pos.x = clampf(pos.x, 0.0, GameConstants.WORLD_WIDTH)
	pos.y = clampf(pos.y, 0.0, GameConstants.WORLD_HEIGHT)
	return pos

func _trim_buffer() -> void:
	# Keep only the most recent inputs
	while input_buffer.size() > GameConstants.MAX_INPUT_BUFFER_SIZE:
		var min_seq: int = input_buffer.keys().min()
		input_buffer.erase(min_seq)

func clear() -> void:
	input_buffer.clear()
