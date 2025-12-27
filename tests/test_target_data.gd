extends GutTest
## Unit tests for the TargetData class.


const TargetDataScript = preload("res://shared/combat/target_data.gd")


## Helper to create a TargetData instance
func _create_target(id: String = "", pos: Vector2 = Vector2.ZERO, radius: float = 16.0, faction: int = 0):
	return TargetDataScript.new(id, pos, radius, faction)


# =============================================================================
# Creation Tests
# =============================================================================

func test_target_data_creation_with_defaults() -> void:
	var target = _create_target()

	assert_eq(target.id, "")
	assert_eq(target.position, Vector2.ZERO)
	assert_eq(target.hitbox_radius, 16.0)
	assert_eq(target.faction, TargetDataScript.Faction.NEUTRAL)


func test_target_data_creation_with_values() -> void:
	var target = _create_target("enemy_1", Vector2(100, 50), 25.0, TargetDataScript.Faction.ENEMY)

	assert_eq(target.id, "enemy_1")
	assert_eq(target.position, Vector2(100, 50))
	assert_eq(target.hitbox_radius, 25.0)
	assert_eq(target.faction, TargetDataScript.Faction.ENEMY)


func test_target_data_from_player() -> void:
	var target = TargetDataScript.from_player("player_123", Vector2(200, 150))

	assert_eq(target.id, "player_123")
	assert_eq(target.position, Vector2(200, 150))
	assert_eq(target.hitbox_radius, 16.0)
	assert_eq(target.faction, TargetDataScript.Faction.PLAYER)


func test_target_data_from_enemy() -> void:
	var target = TargetDataScript.from_enemy("wolf_42", Vector2(300, 250), 12.0)

	assert_eq(target.id, "wolf_42")
	assert_eq(target.position, Vector2(300, 250))
	assert_eq(target.hitbox_radius, 12.0)
	assert_eq(target.faction, TargetDataScript.Faction.ENEMY)


# =============================================================================
# Faction Tests
# =============================================================================

func test_is_player() -> void:
	var player_target = TargetDataScript.from_player("player_1", Vector2.ZERO)
	var enemy_target = TargetDataScript.from_enemy("enemy_1", Vector2.ZERO, 10.0)
	var neutral_target = _create_target("neutral_1", Vector2.ZERO, 10.0, TargetDataScript.Faction.NEUTRAL)

	assert_true(player_target.is_player())
	assert_false(enemy_target.is_player())
	assert_false(neutral_target.is_player())


func test_is_enemy() -> void:
	var player_target = TargetDataScript.from_player("player_1", Vector2.ZERO)
	var enemy_target = TargetDataScript.from_enemy("enemy_1", Vector2.ZERO, 10.0)
	var neutral_target = _create_target("neutral_1", Vector2.ZERO, 10.0, TargetDataScript.Faction.NEUTRAL)

	assert_false(player_target.is_enemy())
	assert_true(enemy_target.is_enemy())
	assert_false(neutral_target.is_enemy())


func test_is_hostile_to_same_faction() -> void:
	var player1 = TargetDataScript.from_player("p1", Vector2.ZERO)
	var player2 = TargetDataScript.from_player("p2", Vector2.ZERO)

	assert_false(player1.is_hostile_to(player2.faction))


func test_is_hostile_to_different_faction() -> void:
	var player = TargetDataScript.from_player("p1", Vector2.ZERO)
	var enemy = TargetDataScript.from_enemy("e1", Vector2.ZERO, 10.0)

	assert_true(player.is_hostile_to(enemy.faction))
	assert_true(enemy.is_hostile_to(player.faction))


func test_is_hostile_to_neutral() -> void:
	var player = TargetDataScript.from_player("p1", Vector2.ZERO)
	var neutral = _create_target("n1", Vector2.ZERO, 10.0, TargetDataScript.Faction.NEUTRAL)

	assert_false(player.is_hostile_to(neutral.faction))
	assert_false(neutral.is_hostile_to(player.faction))


# =============================================================================
# Serialization Tests
# =============================================================================

func test_to_dict() -> void:
	var target = _create_target("test_id", Vector2(100, 200), 20.0, TargetDataScript.Faction.ENEMY)
	var dict := target.to_dict()

	assert_eq(dict["id"], "test_id")
	assert_eq(dict["position"]["x"], 100.0)
	assert_eq(dict["position"]["y"], 200.0)
	assert_eq(dict["hitbox_radius"], 20.0)
	assert_eq(dict["faction"], TargetDataScript.Faction.ENEMY)


func test_from_dict_with_position() -> void:
	var data := {
		"id": "enemy_test",
		"position": {"x": 150.0, "y": 250.0},
		"hitbox_radius": 15.0,
		"faction": TargetDataScript.Faction.ENEMY
	}

	var target = TargetDataScript.from_dict(data)

	assert_eq(target.id, "enemy_test")
	assert_eq(target.position, Vector2(150, 250))
	assert_eq(target.hitbox_radius, 15.0)
	assert_eq(target.faction, TargetDataScript.Faction.ENEMY)


func test_from_dict_with_xy() -> void:
	var data := {
		"id": "test",
		"x": 75.0,
		"y": 125.0
	}

	var target = TargetDataScript.from_dict(data, 12.0)

	assert_eq(target.position, Vector2(75, 125))
	assert_eq(target.hitbox_radius, 12.0)


func test_from_dict_defaults() -> void:
	var target = TargetDataScript.from_dict({})

	assert_eq(target.id, "")
	assert_eq(target.position, Vector2.ZERO)
	assert_eq(target.hitbox_radius, 16.0)  # Default radius
	assert_eq(target.faction, TargetDataScript.Faction.NEUTRAL)


func test_round_trip_serialization() -> void:
	var original = _create_target("round_trip", Vector2(123, 456), 18.5, TargetDataScript.Faction.PLAYER)
	var dict := original.to_dict()
	var restored = TargetDataScript.from_dict(dict)

	assert_eq(restored.id, original.id)
	assert_eq(restored.position, original.position)
	assert_eq(restored.hitbox_radius, original.hitbox_radius)
	assert_eq(restored.faction, original.faction)
