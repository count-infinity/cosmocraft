extends GutTest

var prediction: ClientPrediction

func before_each() -> void:
	prediction = ClientPrediction.new()

func test_initial_state() -> void:
	assert_eq(prediction.input_buffer.size(), 0, "Buffer should start empty")

func test_store_input() -> void:
	var input := {"move_direction": Vector2(1, 0), "aim_angle": 0.0}
	prediction.store_input(1, input, Vector2(100, 100))

	assert_eq(prediction.input_buffer.size(), 1, "Buffer should have 1 entry")
	assert_true(prediction.input_buffer.has(1), "Buffer should have sequence 1")

func test_acknowledge_clears_old_inputs() -> void:
	prediction.store_input(1, {}, Vector2.ZERO)
	prediction.store_input(2, {}, Vector2.ZERO)
	prediction.store_input(3, {}, Vector2.ZERO)

	prediction.acknowledge_up_to(2)

	assert_eq(prediction.input_buffer.size(), 1, "Should have 1 remaining")
	assert_false(prediction.input_buffer.has(1), "Should not have seq 1")
	assert_false(prediction.input_buffer.has(2), "Should not have seq 2")
	assert_true(prediction.input_buffer.has(3), "Should still have seq 3")

func test_get_unacknowledged_inputs() -> void:
	var input1 := {"move_direction": Vector2(1, 0)}
	var input2 := {"move_direction": Vector2(0, 1)}
	prediction.store_input(1, input1, Vector2.ZERO)
	prediction.store_input(2, input2, Vector2.ZERO)

	var inputs := prediction.get_unacknowledged_inputs()

	assert_eq(inputs.size(), 2, "Should have 2 inputs")
	assert_eq(inputs[0]["move_direction"], Vector2(1, 0), "First should be right")
	assert_eq(inputs[1]["move_direction"], Vector2(0, 1), "Second should be down")

func test_reconcile_no_inputs() -> void:
	var server_pos := Vector2(500, 500)
	var result := prediction.reconcile(server_pos, 0, GameConstants.TICK_INTERVAL)

	assert_eq(result, server_pos, "Should return server position when no inputs")

func test_reconcile_with_inputs() -> void:
	var input := {"move_direction": Vector2(1, 0), "aim_angle": 0.0}
	prediction.store_input(1, input, Vector2.ZERO)
	prediction.store_input(2, input, Vector2.ZERO)

	var server_pos := Vector2(500, 500)
	# Server processed seq 1, seq 2 is unacked
	var result := prediction.reconcile(server_pos, 1, GameConstants.TICK_INTERVAL)

	# Should have replayed seq 2, moving right
	assert_gt(result.x, server_pos.x, "Should have moved right from server pos")
	assert_eq(result.y, server_pos.y, "Y should not change")

func test_reconcile_clamps_to_bounds() -> void:
	# Input that would move past right boundary
	var input := {"move_direction": Vector2(1, 0), "aim_angle": 0.0}
	prediction.store_input(1, input, Vector2.ZERO)

	var server_pos := Vector2(GameConstants.WORLD_WIDTH - 5, 500)
	var result := prediction.reconcile(server_pos, 0, 1.0)  # Large delta

	assert_eq(result.x, GameConstants.WORLD_WIDTH, "Should be clamped to world width")

func test_clear() -> void:
	prediction.store_input(1, {}, Vector2.ZERO)
	prediction.store_input(2, {}, Vector2.ZERO)

	prediction.clear()

	assert_eq(prediction.input_buffer.size(), 0, "Buffer should be empty")

func test_buffer_trim() -> void:
	# Store more than max buffer size
	for i in range(GameConstants.MAX_INPUT_BUFFER_SIZE + 10):
		prediction.store_input(i, {}, Vector2.ZERO)

	assert_true(prediction.input_buffer.size() <= GameConstants.MAX_INPUT_BUFFER_SIZE, "Buffer should be trimmed")
