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


# ===== Inventory Integration Tests =====

func test_inventory_fields_default_to_empty() -> void:
	var player := PlayerState.new("p1", "Test")

	assert_eq(player.inventory, {}, "Inventory should default to empty dict")
	assert_eq(player.equipment, {}, "Equipment should default to empty dict")
	assert_eq(player.hotbar, {}, "Hotbar should default to empty dict")
	assert_eq(player.stats, {}, "Stats should default to empty dict")
	assert_eq(player.skills, {}, "Skills should default to empty dict")


func test_to_dict_includes_inventory_fields() -> void:
	var player := PlayerState.new("p1", "Test")
	player.inventory = {"max_weight": 100.0, "stacks": []}
	player.equipment = {"5": {"definition_id": "basic_sword"}}
	player.hotbar = {"selected": 0, "slots": []}
	player.stats = {"strength": 10}
	player.skills = {"mining": {"level": 1, "xp": 0}}

	var dict := player.to_dict()

	assert_eq(dict["inventory"], player.inventory, "Inventory should be in dict")
	assert_eq(dict["equipment"], player.equipment, "Equipment should be in dict")
	assert_eq(dict["hotbar"], player.hotbar, "Hotbar should be in dict")
	assert_eq(dict["stats"], player.stats, "Stats should be in dict")
	assert_eq(dict["skills"], player.skills, "Skills should be in dict")


func test_from_dict_loads_inventory_fields() -> void:
	var dict := {
		"id": "p1",
		"name": "Test",
		"position": {"x": 0.0, "y": 0.0},
		"velocity": {"x": 0.0, "y": 0.0},
		"aim_angle": 0.0,
		"inventory": {"max_weight": 150.0, "stacks": [{"item": {"definition_id": "stone"}, "count": 10}]},
		"equipment": {"4": {"definition_id": "basic_pickaxe"}},
		"hotbar": {"selected": 2, "slots": []},
		"stats": {"fortitude": 5},
		"skills": {"smithing": {"level": 3, "xp": 500}}
	}

	var player := PlayerState.from_dict(dict)

	assert_eq(player.inventory, dict["inventory"], "Inventory should load from dict")
	assert_eq(player.equipment, dict["equipment"], "Equipment should load from dict")
	assert_eq(player.hotbar, dict["hotbar"], "Hotbar should load from dict")
	assert_eq(player.stats, dict["stats"], "Stats should load from dict")
	assert_eq(player.skills, dict["skills"], "Skills should load from dict")


func test_from_dict_backwards_compatible() -> void:
	# Old format without inventory fields should work
	var dict := {
		"id": "p1",
		"name": "OldPlayer",
		"position": {"x": 100.0, "y": 200.0},
		"velocity": {"x": 0.0, "y": 0.0},
		"aim_angle": 1.5
	}

	var player := PlayerState.from_dict(dict)

	assert_eq(player.id, "p1", "ID should load")
	assert_eq(player.name, "OldPlayer", "Name should load")
	assert_eq(player.inventory, {}, "Missing inventory should default to empty")
	assert_eq(player.equipment, {}, "Missing equipment should default to empty")
	assert_eq(player.hotbar, {}, "Missing hotbar should default to empty")
	assert_eq(player.stats, {}, "Missing stats should default to empty")
	assert_eq(player.skills, {}, "Missing skills should default to empty")


func test_clone_deep_copies_inventory_fields() -> void:
	var original := PlayerState.new("p1", "Test")
	original.inventory = {"max_weight": 100.0, "stacks": [{"count": 5}]}
	original.equipment = {"5": {"id": "sword"}}
	original.stats = {"strength": 10}

	var cloned := original.clone()

	# Values should match
	assert_eq(cloned.inventory, original.inventory, "Inventory should match")
	assert_eq(cloned.equipment, original.equipment, "Equipment should match")
	assert_eq(cloned.stats, original.stats, "Stats should match")

	# Should be deep copies (independent)
	cloned.inventory["max_weight"] = 999.0
	cloned.equipment["5"]["id"] = "axe"
	cloned.stats["strength"] = 99

	assert_eq(original.inventory["max_weight"], 100.0, "Original inventory should be unchanged")
	assert_eq(original.equipment["5"]["id"], "sword", "Original equipment should be unchanged")
	assert_eq(original.stats["strength"], 10, "Original stats should be unchanged")


func test_roundtrip_serialization_with_inventory() -> void:
	var original := PlayerState.new("p1", "FullPlayer")
	original.position = Vector2(100, 200)
	original.inventory = {
		"max_weight": 120.0,
		"stacks": [
			{"item": {"definition_id": "basic_pickaxe", "durability": 50}, "count": 1},
			{"item": {"definition_id": "stone"}, "count": 64}
		]
	}
	original.equipment = {
		"5": {"definition_id": "basic_sword", "durability": 100}
	}
	original.hotbar = {
		"selected": 0,
		"slots": [{"slot": 0, "stack": {"item": {"definition_id": "stone"}, "count": 64}}]
	}
	original.stats = {"strength": 15, "precision": 8}
	original.skills = {"mining": {"level": 5, "xp": 2500}, "combat": {"level": 2, "xp": 100}}

	var dict := original.to_dict()
	var restored := PlayerState.from_dict(dict)

	assert_eq(restored.inventory, original.inventory, "Inventory should survive roundtrip")
	assert_eq(restored.equipment, original.equipment, "Equipment should survive roundtrip")
	assert_eq(restored.hotbar, original.hotbar, "Hotbar should survive roundtrip")
	assert_eq(restored.stats, original.stats, "Stats should survive roundtrip")
	assert_eq(restored.skills, original.skills, "Skills should survive roundtrip")
