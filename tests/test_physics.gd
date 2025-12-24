extends GutTest

func test_apply_player_input_updates_position() -> void:
	var player := PlayerState.new("p1", "Test")
	player.position = Vector2(500, 500)

	ServerPhysics.apply_player_input(player, Vector2(1, 0), 0.0, 0.1)

	var expected_move := GameConstants.PLAYER_SPEED * 0.1
	assert_almost_eq(player.position.x, 500 + expected_move, 0.01, "Position X should increase")
	assert_eq(player.position.y, 500.0, "Position Y should not change")

func test_apply_player_input_updates_aim() -> void:
	var player := PlayerState.new("p1", "Test")

	ServerPhysics.apply_player_input(player, Vector2.ZERO, 2.5, 0.1)

	assert_eq(player.aim_angle, 2.5, "Aim angle should be updated")

func test_apply_player_input_normalizes_diagonal() -> void:
	var player := PlayerState.new("p1", "Test")
	player.position = Vector2(500, 500)

	# Diagonal movement should be normalized
	ServerPhysics.apply_player_input(player, Vector2(1, 1), 0.0, 0.1)

	var speed := player.velocity.length()
	assert_almost_eq(speed, GameConstants.PLAYER_SPEED, 0.01, "Speed should equal PLAYER_SPEED")

func test_tick_processes_all_players() -> void:
	var game_state := GameState.new()
	var p1 := game_state.add_player("p1", "Player1")
	var p2 := game_state.add_player("p2", "Player2")

	var start_p1 := p1.position
	var start_p2 := p2.position

	var inputs := {
		"p1": {"move_direction": Vector2(1, 0), "aim_angle": 0.0},
		"p2": {"move_direction": Vector2(0, 1), "aim_angle": 1.0}
	}

	ServerPhysics.tick(game_state, inputs, GameConstants.TICK_INTERVAL)

	# Both players should have moved
	assert_gt(p1.position.x, start_p1.x, "P1 should have moved right")
	assert_gt(p2.position.y, start_p2.y, "P2 should have moved down")

func test_tick_no_input_stops_player() -> void:
	var game_state := GameState.new()
	var player := game_state.add_player("p1", "Test")
	player.velocity = Vector2(100, 100)  # Give initial velocity

	# Tick with no inputs
	ServerPhysics.tick(game_state, {}, GameConstants.TICK_INTERVAL)

	assert_eq(player.velocity, Vector2.ZERO, "Velocity should be zero without input")

func test_tick_partial_inputs() -> void:
	var game_state := GameState.new()
	var p1 := game_state.add_player("p1", "Player1")
	var p2 := game_state.add_player("p2", "Player2")

	# Only p1 has input
	var inputs := {
		"p1": {"move_direction": Vector2(1, 0), "aim_angle": 0.0}
	}

	# Give p2 some velocity
	p2.velocity = Vector2(50, 50)

	ServerPhysics.tick(game_state, inputs, GameConstants.TICK_INTERVAL)

	# p1 should have velocity, p2 should not
	assert_ne(p1.velocity, Vector2.ZERO, "P1 should have velocity")
	assert_eq(p2.velocity, Vector2.ZERO, "P2 should have zero velocity (no input)")
