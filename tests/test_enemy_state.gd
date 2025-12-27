extends GutTest
## Unit tests for the EnemyState class.

const EnemyStateScript = preload("res://shared/entities/enemy_state.gd")
const EnemyDefinitionScript = preload("res://shared/entities/enemy_definition.gd")


# =============================================================================
# Helper Methods
# =============================================================================

func create_test_definition():
	var def = EnemyDefinitionScript.new("test_enemy", "Test Enemy", 50.0, 10.0)
	def.attack_speed = 1.0
	return def


# =============================================================================
# Creation Tests
# =============================================================================

func test_enemy_state_creation_defaults() -> void:
	var state = EnemyStateScript.new()

	assert_eq(state.id, "")
	assert_eq(state.definition_id, "")
	assert_eq(state.position, Vector2.ZERO)
	assert_eq(state.velocity, Vector2.ZERO)
	assert_eq(state.current_hp, 10.0)
	assert_eq(state.max_hp, 10.0)
	assert_true(state.is_alive)
	assert_eq(state.state, EnemyStateScript.State.IDLE)


func test_enemy_state_creation_with_values() -> void:
	var state = EnemyStateScript.new("enemy_123", "wolf", Vector2(100, 200), 30.0)

	assert_eq(state.id, "enemy_123")
	assert_eq(state.definition_id, "wolf")
	assert_eq(state.spawn_point, Vector2(100, 200))
	assert_eq(state.position, Vector2(100, 200))
	assert_eq(state.max_hp, 30.0)
	assert_eq(state.current_hp, 30.0)


func test_create_from_definition() -> void:
	var def = create_test_definition()
	var state = EnemyStateScript.create_from_definition("enemy_001", def, Vector2(500, 500))

	assert_eq(state.id, "enemy_001")
	assert_eq(state.definition_id, "test_enemy")
	assert_eq(state.spawn_point, Vector2(500, 500))
	assert_eq(state.position, Vector2(500, 500))
	assert_eq(state.max_hp, 50.0)
	assert_eq(state.current_hp, 50.0)


# =============================================================================
# Combat Tests
# =============================================================================

func test_take_damage() -> void:
	var state = EnemyStateScript.new("test", "enemy", Vector2.ZERO, 100.0)

	var actual := state.take_damage(30.0)

	assert_eq(actual, 30.0)
	assert_eq(state.current_hp, 70.0)
	assert_true(state.is_alive)


func test_take_damage_overkill() -> void:
	var state = EnemyStateScript.new("test", "enemy", Vector2.ZERO, 50.0)

	var actual := state.take_damage(100.0)

	assert_eq(actual, 50.0)  # Only takes up to current HP
	assert_eq(state.current_hp, 0.0)
	assert_false(state.is_alive)
	assert_eq(state.state, EnemyStateScript.State.DEAD)


func test_take_damage_emits_signal() -> void:
	var state = EnemyStateScript.new("test", "enemy", Vector2.ZERO, 100.0)
	# Note: take_damage no longer sets target directly (signals handle that now)
	# This test verifies damage still works and the method signature is correct
	assert_eq(state.target_id, "")

	state.take_damage(10.0, "player_123")

	# Target is NOT set by take_damage - that's now handled by AI via signals
	assert_eq(state.target_id, "")
	assert_eq(state.state, EnemyStateScript.State.IDLE)


func test_handle_retaliation_sets_target() -> void:
	var state = EnemyStateScript.new("test", "enemy", Vector2.ZERO, 100.0)
	assert_eq(state.target_id, "")

	state.handle_retaliation("player_123")

	assert_eq(state.target_id, "player_123")
	assert_eq(state.state, EnemyStateScript.State.CHASING)


func test_take_damage_tracks_last_attacker() -> void:
	var state = EnemyStateScript.new("test", "enemy", Vector2.ZERO, 100.0)
	assert_eq(state.last_attacker_id, "")

	state.take_damage(10.0, "player_123")

	assert_eq(state.last_attacker_id, "player_123")

	# Verify it updates with new attackers
	state.take_damage(10.0, "player_456")
	assert_eq(state.last_attacker_id, "player_456")


func test_take_damage_no_attacker_keeps_last() -> void:
	var state = EnemyStateScript.new("test", "enemy", Vector2.ZERO, 100.0)
	state.take_damage(10.0, "player_123")

	# Damage with no attacker should not clear last_attacker_id
	state.take_damage(10.0, "")

	assert_eq(state.last_attacker_id, "player_123")


func test_take_damage_no_damage_when_dead() -> void:
	var state = EnemyStateScript.new("test", "enemy", Vector2.ZERO, 100.0)
	state.is_alive = false

	var actual := state.take_damage(50.0)

	assert_eq(actual, 0.0)


func test_heal() -> void:
	var state = EnemyStateScript.new("test", "enemy", Vector2.ZERO, 100.0)
	state.current_hp = 50.0

	var actual := state.heal(30.0)

	assert_eq(actual, 30.0)
	assert_eq(state.current_hp, 80.0)


func test_heal_capped_at_max() -> void:
	var state = EnemyStateScript.new("test", "enemy", Vector2.ZERO, 100.0)
	state.current_hp = 90.0

	var actual := state.heal(50.0)

	assert_eq(actual, 10.0)  # Only heals to max
	assert_eq(state.current_hp, 100.0)


func test_heal_dead_enemy() -> void:
	var state = EnemyStateScript.new("test", "enemy", Vector2.ZERO, 100.0)
	state.is_alive = false
	state.current_hp = 0.0

	var actual := state.heal(50.0)

	assert_eq(actual, 0.0)
	assert_eq(state.current_hp, 0.0)


func test_get_hp_percent() -> void:
	var state = EnemyStateScript.new("test", "enemy", Vector2.ZERO, 100.0)
	state.current_hp = 75.0

	assert_almost_eq(state.get_hp_percent(), 0.75, 0.001)


func test_is_full_health() -> void:
	var state = EnemyStateScript.new("test", "enemy", Vector2.ZERO, 100.0)

	assert_true(state.is_full_health())

	state.current_hp = 99.0
	assert_false(state.is_full_health())


# =============================================================================
# Attack Tests
# =============================================================================

func test_can_attack_when_ready() -> void:
	var state = EnemyStateScript.new("test", "enemy", Vector2.ZERO, 100.0)
	state.last_attack_time = 0.0

	assert_true(state.can_attack(1.0, 2.0))  # 2 seconds passed, 1 second cooldown


func test_can_attack_on_cooldown() -> void:
	var state = EnemyStateScript.new("test", "enemy", Vector2.ZERO, 100.0)
	state.last_attack_time = 1.0

	assert_false(state.can_attack(1.0, 1.5))  # Only 0.5 seconds passed


func test_can_attack_dead() -> void:
	var state = EnemyStateScript.new("test", "enemy", Vector2.ZERO, 100.0)
	state.is_alive = false

	assert_false(state.can_attack(1.0, 100.0))


func test_record_attack() -> void:
	var state = EnemyStateScript.new("test", "enemy", Vector2.ZERO, 100.0)

	state.record_attack(5.0)

	assert_eq(state.last_attack_time, 5.0)


# =============================================================================
# Target Tests
# =============================================================================

func test_set_target() -> void:
	var state = EnemyStateScript.new("test", "enemy", Vector2.ZERO, 100.0)

	state.set_target("player_001")

	assert_eq(state.target_id, "player_001")
	assert_eq(state.state, EnemyStateScript.State.CHASING)


func test_clear_target() -> void:
	var state = EnemyStateScript.new("test", "enemy", Vector2.ZERO, 100.0)
	state.target_id = "player_001"
	state.state = EnemyStateScript.State.CHASING

	state.clear_target()

	assert_eq(state.target_id, "")
	assert_eq(state.state, EnemyStateScript.State.IDLE)


# =============================================================================
# Leash Tests
# =============================================================================

func test_is_beyond_leash_range_false() -> void:
	var state = EnemyStateScript.new("test", "enemy", Vector2(100, 100), 100.0)
	state.position = Vector2(150, 100)  # 50 units away

	assert_false(state.is_beyond_leash_range(100.0))


func test_is_beyond_leash_range_true() -> void:
	var state = EnemyStateScript.new("test", "enemy", Vector2(100, 100), 100.0)
	state.position = Vector2(300, 100)  # 200 units away

	assert_true(state.is_beyond_leash_range(150.0))


func test_is_near_spawn() -> void:
	var state = EnemyStateScript.new("test", "enemy", Vector2(100, 100), 100.0)

	state.position = Vector2(100, 100)
	assert_true(state.is_near_spawn(10.0))

	state.position = Vector2(105, 105)  # ~7 units away
	assert_true(state.is_near_spawn(10.0))

	state.position = Vector2(120, 100)  # 20 units away
	assert_false(state.is_near_spawn(10.0))


# =============================================================================
# Revive Tests
# =============================================================================

func test_revive() -> void:
	var state = EnemyStateScript.new("test", "enemy", Vector2(100, 100), 50.0)
	state.position = Vector2(500, 500)
	state.current_hp = 0.0
	state.is_alive = false
	state.state = EnemyStateScript.State.DEAD
	state.target_id = "player_001"
	state.velocity = Vector2(100, 0)
	state.last_attacker_id = "player_001"

	state.revive()

	assert_eq(state.current_hp, 50.0)
	assert_true(state.is_alive)
	assert_eq(state.state, EnemyStateScript.State.IDLE)
	assert_eq(state.target_id, "")
	assert_eq(state.velocity, Vector2.ZERO)
	assert_eq(state.position, Vector2(100, 100))  # Back to spawn
	assert_eq(state.last_attacker_id, "")  # Reset on revive


# =============================================================================
# Serialization Tests
# =============================================================================

func test_to_dict() -> void:
	var state = EnemyStateScript.new("enemy_123", "wolf", Vector2(100, 200), 30.0)
	state.position = Vector2(150, 250)
	state.velocity = Vector2(10, 5)
	state.current_hp = 25.0
	state.target_id = "player_001"
	state.state = EnemyStateScript.State.CHASING

	var dict := state.to_dict()

	assert_eq(dict["id"], "enemy_123")
	assert_eq(dict["definition_id"], "wolf")
	assert_eq(dict["position"]["x"], 150.0)
	assert_eq(dict["position"]["y"], 250.0)
	assert_eq(dict["velocity"]["x"], 10.0)
	assert_eq(dict["velocity"]["y"], 5.0)
	assert_eq(dict["current_hp"], 25.0)
	assert_eq(dict["max_hp"], 30.0)
	assert_true(dict["is_alive"])
	assert_eq(dict["target_id"], "player_001")
	assert_eq(dict["state"], EnemyStateScript.State.CHASING)


func test_from_dict() -> void:
	var data := {
		"id": "enemy_456",
		"definition_id": "spider",
		"position": {"x": 300.0, "y": 400.0},
		"velocity": {"x": -5.0, "y": 0.0},
		"current_hp": 15.0,
		"max_hp": 20.0,
		"is_alive": true,
		"spawn_point": {"x": 250.0, "y": 350.0},
		"target_id": "player_002",
		"state": EnemyStateScript.State.ATTACKING,
		"facing_direction": {"x": -1.0, "y": 0.0}
	}

	var state = EnemyStateScript.from_dict(data)

	assert_eq(state.id, "enemy_456")
	assert_eq(state.definition_id, "spider")
	assert_eq(state.position, Vector2(300, 400))
	assert_eq(state.velocity, Vector2(-5, 0))
	assert_eq(state.current_hp, 15.0)
	assert_eq(state.max_hp, 20.0)
	assert_true(state.is_alive)
	assert_eq(state.spawn_point, Vector2(250, 350))
	assert_eq(state.target_id, "player_002")
	assert_eq(state.state, EnemyStateScript.State.ATTACKING)
	assert_eq(state.facing_direction, Vector2(-1, 0))


func test_round_trip_serialization() -> void:
	var original = EnemyStateScript.new("enemy_test", "boar", Vector2(500, 600), 80.0)
	original.position = Vector2(550, 650)
	original.velocity = Vector2(20, 10)
	original.current_hp = 60.0
	original.target_id = "player_test"
	original.state = EnemyStateScript.State.RETURNING
	original.facing_direction = Vector2(0, -1)

	var dict := original.to_dict()
	var restored = EnemyStateScript.from_dict(dict)

	assert_eq(restored.id, original.id)
	assert_eq(restored.definition_id, original.definition_id)
	assert_eq(restored.position, original.position)
	assert_eq(restored.velocity, original.velocity)
	assert_eq(restored.current_hp, original.current_hp)
	assert_eq(restored.max_hp, original.max_hp)
	assert_eq(restored.is_alive, original.is_alive)
	assert_eq(restored.spawn_point, original.spawn_point)
	assert_eq(restored.target_id, original.target_id)
	assert_eq(restored.state, original.state)
	assert_eq(restored.facing_direction, original.facing_direction)
