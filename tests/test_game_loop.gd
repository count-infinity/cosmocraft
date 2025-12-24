extends GutTest

var game_state: GameState
var game_loop: GameLoop

func before_each() -> void:
	game_state = GameState.new()
	game_loop = GameLoop.new(game_state)

func test_initial_state() -> void:
	assert_eq(game_loop.accumulated_time, 0.0, "Accumulated time should start at 0")
	assert_eq(game_loop.tick_interval, GameConstants.TICK_INTERVAL, "Tick interval should match constant")

func test_update_no_tick() -> void:
	# Update with less than tick interval - should not tick
	var ticked := game_loop.update(0.01)  # 10ms, less than 50ms tick interval

	assert_false(ticked, "Should not have ticked")
	assert_eq(game_state.current_tick, 0, "Tick should still be 0")

func test_update_single_tick() -> void:
	# Update with exactly one tick interval
	var ticked := game_loop.update(GameConstants.TICK_INTERVAL)

	assert_true(ticked, "Should have ticked")
	assert_eq(game_state.current_tick, 1, "Tick should be 1")

func test_update_multiple_ticks() -> void:
	# Update with 3 tick intervals worth of time
	var ticked := game_loop.update(GameConstants.TICK_INTERVAL * 3)

	assert_true(ticked, "Should have ticked")
	assert_eq(game_state.current_tick, 3, "Tick should be 3")

func test_update_accumulated_time() -> void:
	# Update with partial ticks
	game_loop.update(0.03)  # 30ms
	assert_eq(game_state.current_tick, 0, "Should not have ticked yet")

	game_loop.update(0.03)  # Another 30ms, total 60ms > 50ms
	assert_eq(game_state.current_tick, 1, "Should have ticked once")

	# Should have 10ms remaining
	assert_almost_eq(game_loop.accumulated_time, 0.01, 0.001, "Should have 10ms remaining")

func test_force_tick() -> void:
	game_loop.force_tick()
	assert_eq(game_state.current_tick, 1, "Tick should be 1")

	game_loop.force_tick()
	game_loop.force_tick()
	assert_eq(game_state.current_tick, 3, "Tick should be 3")

func test_queue_input() -> void:
	game_state.add_player("p1", "TestPlayer")

	var input_data := {
		"sequence": 1,
		"move_direction": Vector2(1, 0),
		"aim_angle": 0.0
	}
	game_loop.queue_input("p1", input_data)

	assert_true(game_loop.pending_inputs.has("p1"), "Should have pending input for p1")

func test_input_applied_on_tick() -> void:
	var player := game_state.add_player("p1", "TestPlayer")
	var start_pos := player.position

	var input_data := {
		"sequence": 1,
		"move_direction": Vector2(1, 0),
		"aim_angle": 1.5
	}
	game_loop.queue_input("p1", input_data)
	game_loop.force_tick()

	# Player should have moved right
	assert_gt(player.position.x, start_pos.x, "Player should have moved right")
	assert_eq(player.aim_angle, 1.5, "Aim angle should be updated")

func test_input_cleared_after_tick() -> void:
	game_state.add_player("p1", "TestPlayer")

	game_loop.queue_input("p1", {"move_direction": Vector2(1, 0), "aim_angle": 0.0})
	assert_true(game_loop.pending_inputs.has("p1"), "Should have pending input")

	game_loop.force_tick()
	assert_false(game_loop.pending_inputs.has("p1"), "Pending input should be cleared")

func test_no_input_stops_player() -> void:
	var player := game_state.add_player("p1", "TestPlayer")

	# First give the player some velocity via input
	game_loop.queue_input("p1", {"move_direction": Vector2(1, 0), "aim_angle": 0.0})
	game_loop.force_tick()
	assert_ne(player.velocity, Vector2.ZERO, "Player should have velocity")

	# Now tick without input - player should stop
	game_loop.force_tick()
	assert_eq(player.velocity, Vector2.ZERO, "Player velocity should be zero")

var _signal_tick_received: int = 0

func test_tick_completed_signal() -> void:
	_signal_tick_received = 0
	game_loop.tick_completed.connect(_on_tick_received)

	game_loop.force_tick()
	assert_eq(_signal_tick_received, 1, "Should have received tick 1")

	game_loop.force_tick()
	assert_eq(_signal_tick_received, 2, "Should have received tick 2")

	game_loop.tick_completed.disconnect(_on_tick_received)

func _on_tick_received(tick: int) -> void:
	_signal_tick_received = tick

func test_latest_input_wins() -> void:
	var player := game_state.add_player("p1", "TestPlayer")

	# Queue multiple inputs - latest should win
	game_loop.queue_input("p1", {"move_direction": Vector2(1, 0), "aim_angle": 0.0})
	game_loop.queue_input("p1", {"move_direction": Vector2(0, 1), "aim_angle": 1.5})

	game_loop.force_tick()

	# Velocity should be downward (0, 1), not right (1, 0)
	assert_almost_eq(player.velocity.x, 0.0, 0.01, "Velocity X should be ~0")
	assert_gt(player.velocity.y, 0.0, "Velocity Y should be positive (down)")
	assert_eq(player.aim_angle, 1.5, "Aim angle should be from latest input")
