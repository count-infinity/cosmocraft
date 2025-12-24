extends GutTest

func test_create_player_with_defaults() -> void:
	var player := PlayerState.new()

	assert_eq(player.id, "", "ID should be empty by default")
	assert_eq(player.name, "", "Name should be empty by default")
	assert_eq(player.position, Vector2.ZERO, "Position should be zero")
	assert_eq(player.velocity, Vector2.ZERO, "Velocity should be zero")
	assert_eq(player.aim_angle, 0.0, "Aim angle should be zero")

func test_create_player_with_id_and_name() -> void:
	var player := PlayerState.new("player-123", "TestPlayer")

	assert_eq(player.id, "player-123", "ID should match")
	assert_eq(player.name, "TestPlayer", "Name should match")

func test_to_dict() -> void:
	var player := PlayerState.new("p1", "Alice")
	player.position = Vector2(100, 200)
	player.velocity = Vector2(10, 20)
	player.aim_angle = 1.5

	var dict := player.to_dict()

	assert_eq(dict["id"], "p1", "ID should match")
	assert_eq(dict["name"], "Alice", "Name should match")
	assert_eq(dict["position"]["x"], 100.0, "Position X should match")
	assert_eq(dict["position"]["y"], 200.0, "Position Y should match")
	assert_eq(dict["velocity"]["x"], 10.0, "Velocity X should match")
	assert_eq(dict["velocity"]["y"], 20.0, "Velocity Y should match")
	assert_eq(dict["aim_angle"], 1.5, "Aim angle should match")

func test_from_dict() -> void:
	var dict := {
		"id": "p2",
		"name": "Bob",
		"position": {"x": 50.0, "y": 75.0},
		"velocity": {"x": 5.0, "y": -5.0},
		"aim_angle": 0.8
	}

	var player := PlayerState.from_dict(dict)

	assert_eq(player.id, "p2", "ID should match")
	assert_eq(player.name, "Bob", "Name should match")
	assert_eq(player.position, Vector2(50, 75), "Position should match")
	assert_eq(player.velocity, Vector2(5, -5), "Velocity should match")
	assert_eq(player.aim_angle, 0.8, "Aim angle should match")

func test_from_dict_with_missing_fields() -> void:
	var dict := {}

	var player := PlayerState.from_dict(dict)

	assert_eq(player.id, "", "ID should default to empty")
	assert_eq(player.name, "", "Name should default to empty")
	assert_eq(player.position, Vector2.ZERO, "Position should default to zero")
	assert_eq(player.velocity, Vector2.ZERO, "Velocity should default to zero")
	assert_eq(player.aim_angle, 0.0, "Aim angle should default to zero")

func test_clone() -> void:
	var original := PlayerState.new("p1", "Original")
	original.position = Vector2(100, 100)
	original.velocity = Vector2(10, 10)
	original.aim_angle = 2.0

	var cloned := original.clone()

	# Values should match
	assert_eq(cloned.id, original.id, "ID should match")
	assert_eq(cloned.name, original.name, "Name should match")
	assert_eq(cloned.position, original.position, "Position should match")
	assert_eq(cloned.velocity, original.velocity, "Velocity should match")
	assert_eq(cloned.aim_angle, original.aim_angle, "Aim angle should match")

	# Should be independent objects
	cloned.position = Vector2(999, 999)
	assert_ne(original.position, cloned.position, "Clone should be independent")

func test_apply_input_updates_velocity() -> void:
	var player := PlayerState.new("p1", "Test")
	player.position = Vector2(500, 500)

	var direction := Vector2(1, 0).normalized()
	player.apply_input(direction, 0.0, 0.1)

	assert_eq(player.velocity.x, GameConstants.PLAYER_SPEED, "Velocity X should be player speed")
	assert_eq(player.velocity.y, 0.0, "Velocity Y should be zero")

func test_apply_input_updates_position() -> void:
	var player := PlayerState.new("p1", "Test")
	player.position = Vector2(500, 500)

	var direction := Vector2(1, 0).normalized()
	var delta := 0.1
	player.apply_input(direction, 0.0, delta)

	var expected_x := 500 + GameConstants.PLAYER_SPEED * delta
	assert_almost_eq(player.position.x, expected_x, 0.01, "Position X should update")
	assert_eq(player.position.y, 500.0, "Position Y should not change")

func test_apply_input_updates_aim_angle() -> void:
	var player := PlayerState.new("p1", "Test")
	player.aim_angle = 0.0

	player.apply_input(Vector2.ZERO, 1.57, 0.1)

	assert_eq(player.aim_angle, 1.57, "Aim angle should update")

func test_apply_input_diagonal_normalized() -> void:
	var player := PlayerState.new("p1", "Test")
	player.position = Vector2(500, 500)

	# Diagonal movement should be normalized
	var direction := Vector2(1, 1)  # Not normalized
	player.apply_input(direction, 0.0, 0.1)

	# Velocity magnitude should equal PLAYER_SPEED
	var speed := player.velocity.length()
	assert_almost_eq(speed, GameConstants.PLAYER_SPEED, 0.01, "Speed should equal PLAYER_SPEED")

func test_apply_input_clamps_to_left_boundary() -> void:
	var player := PlayerState.new("p1", "Test")
	player.position = Vector2(10, 500)

	# Move left
	var direction := Vector2(-1, 0)
	player.apply_input(direction, 0.0, 1.0)  # Large delta to overshoot

	assert_eq(player.position.x, 0.0, "Position X should be clamped to 0")

func test_apply_input_clamps_to_right_boundary() -> void:
	var player := PlayerState.new("p1", "Test")
	player.position = Vector2(GameConstants.WORLD_WIDTH - 10, 500)

	# Move right
	var direction := Vector2(1, 0)
	player.apply_input(direction, 0.0, 1.0)  # Large delta to overshoot

	assert_eq(player.position.x, GameConstants.WORLD_WIDTH, "Position X should be clamped to world width")

func test_apply_input_clamps_to_top_boundary() -> void:
	var player := PlayerState.new("p1", "Test")
	player.position = Vector2(500, 10)

	# Move up
	var direction := Vector2(0, -1)
	player.apply_input(direction, 0.0, 1.0)

	assert_eq(player.position.y, 0.0, "Position Y should be clamped to 0")

func test_apply_input_clamps_to_bottom_boundary() -> void:
	var player := PlayerState.new("p1", "Test")
	player.position = Vector2(500, GameConstants.WORLD_HEIGHT - 10)

	# Move down
	var direction := Vector2(0, 1)
	player.apply_input(direction, 0.0, 1.0)

	assert_eq(player.position.y, GameConstants.WORLD_HEIGHT, "Position Y should be clamped to world height")

func test_apply_input_zero_direction_stops() -> void:
	var player := PlayerState.new("p1", "Test")
	player.position = Vector2(500, 500)
	player.velocity = Vector2(100, 100)

	player.apply_input(Vector2.ZERO, 0.0, 0.1)

	# With zero input, velocity should be zero (no momentum in this simple model)
	assert_eq(player.velocity, Vector2.ZERO, "Velocity should be zero with no input")

func test_roundtrip_serialization() -> void:
	var original := PlayerState.new("p1", "RoundTrip")
	original.position = Vector2(123.456, 789.012)
	original.velocity = Vector2(11.1, 22.2)
	original.aim_angle = 3.14159

	var dict := original.to_dict()
	var restored := PlayerState.from_dict(dict)

	assert_eq(restored.id, original.id, "ID should survive roundtrip")
	assert_eq(restored.name, original.name, "Name should survive roundtrip")
	assert_almost_eq(restored.position.x, original.position.x, 0.001, "Position X should survive roundtrip")
	assert_almost_eq(restored.position.y, original.position.y, 0.001, "Position Y should survive roundtrip")
	assert_almost_eq(restored.velocity.x, original.velocity.x, 0.001, "Velocity X should survive roundtrip")
	assert_almost_eq(restored.velocity.y, original.velocity.y, 0.001, "Velocity Y should survive roundtrip")
	assert_almost_eq(restored.aim_angle, original.aim_angle, 0.00001, "Aim angle should survive roundtrip")
