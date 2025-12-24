extends GutTest

var game_state: GameState

func before_each() -> void:
	game_state = GameState.new()

func test_initial_state() -> void:
	assert_eq(game_state.current_tick, 0, "Initial tick should be 0")
	assert_eq(game_state.get_player_count(), 0, "Initial player count should be 0")

func test_add_player() -> void:
	var player := game_state.add_player("p1", "TestPlayer")

	assert_not_null(player, "Should return player state")
	assert_eq(player.id, "p1", "Player ID should match")
	assert_eq(player.name, "TestPlayer", "Player name should match")
	assert_eq(game_state.get_player_count(), 1, "Player count should be 1")
	assert_true(game_state.has_player("p1"), "Should have player p1")

func test_add_player_spawn_position() -> void:
	var player := game_state.add_player("p1", "TestPlayer")

	# Should spawn at center of world
	var expected_x := GameConstants.WORLD_WIDTH / 2.0
	var expected_y := GameConstants.WORLD_HEIGHT / 2.0
	assert_eq(player.position.x, expected_x, "Should spawn at center X")
	assert_eq(player.position.y, expected_y, "Should spawn at center Y")

func test_remove_player() -> void:
	game_state.add_player("p1", "TestPlayer")
	assert_eq(game_state.get_player_count(), 1, "Should have 1 player")

	var removed := game_state.remove_player("p1")
	assert_true(removed, "Should return true when player removed")
	assert_eq(game_state.get_player_count(), 0, "Player count should be 0")
	assert_false(game_state.has_player("p1"), "Should not have player p1")

func test_remove_nonexistent_player() -> void:
	var removed := game_state.remove_player("nonexistent")
	assert_false(removed, "Should return false for nonexistent player")

func test_get_player() -> void:
	game_state.add_player("p1", "TestPlayer")

	var player := game_state.get_player("p1")
	assert_not_null(player, "Should return player")
	assert_eq(player.id, "p1", "Player ID should match")

func test_get_nonexistent_player() -> void:
	var player := game_state.get_player("nonexistent")
	assert_null(player, "Should return null for nonexistent player")

func test_get_all_player_ids() -> void:
	game_state.add_player("p1", "Player1")
	game_state.add_player("p2", "Player2")
	game_state.add_player("p3", "Player3")

	var ids := game_state.get_all_player_ids()
	assert_eq(ids.size(), 3, "Should have 3 player IDs")
	assert_true(ids.has("p1"), "Should have p1")
	assert_true(ids.has("p2"), "Should have p2")
	assert_true(ids.has("p3"), "Should have p3")

func test_increment_tick() -> void:
	assert_eq(game_state.current_tick, 0, "Initial tick should be 0")

	game_state.increment_tick()
	assert_eq(game_state.current_tick, 1, "Tick should be 1")

	game_state.increment_tick()
	game_state.increment_tick()
	assert_eq(game_state.current_tick, 3, "Tick should be 3")

func test_last_processed_input() -> void:
	game_state.add_player("p1", "TestPlayer")

	assert_eq(game_state.get_last_processed_input("p1"), 0, "Initial should be 0")

	game_state.set_last_processed_input("p1", 42)
	assert_eq(game_state.get_last_processed_input("p1"), 42, "Should be 42")

func test_get_snapshot() -> void:
	var player := game_state.add_player("p1", "TestPlayer")
	player.position = Vector2(100, 200)
	game_state.increment_tick()
	game_state.increment_tick()

	var snapshot := game_state.get_snapshot()

	assert_eq(snapshot["tick"], 2, "Tick should be 2")
	assert_has(snapshot, "players", "Should have players")
	assert_has(snapshot["players"], "p1", "Should have player p1")
	assert_eq(snapshot["players"]["p1"]["name"], "TestPlayer", "Player name should match")

func test_get_delta() -> void:
	var player := game_state.add_player("p1", "TestPlayer")
	player.position = Vector2(100, 200)
	player.velocity = Vector2(10, 20)
	player.aim_angle = 1.5
	game_state.increment_tick()

	var delta := game_state.get_delta()

	assert_eq(delta["tick"], 1, "Tick should be 1")
	assert_has(delta["players"], "p1", "Should have player p1")

	var p1_data = delta["players"]["p1"]
	assert_eq(p1_data["position"]["x"], 100.0, "Position X should match")
	assert_eq(p1_data["position"]["y"], 200.0, "Position Y should match")
	assert_eq(p1_data["velocity"]["x"], 10.0, "Velocity X should match")
	assert_eq(p1_data["velocity"]["y"], 20.0, "Velocity Y should match")
	assert_eq(p1_data["aim_angle"], 1.5, "Aim angle should match")

func test_multiple_players() -> void:
	game_state.add_player("p1", "Player1")
	game_state.add_player("p2", "Player2")

	assert_eq(game_state.get_player_count(), 2, "Should have 2 players")

	game_state.remove_player("p1")
	assert_eq(game_state.get_player_count(), 1, "Should have 1 player")
	assert_false(game_state.has_player("p1"), "Should not have p1")
	assert_true(game_state.has_player("p2"), "Should still have p2")
