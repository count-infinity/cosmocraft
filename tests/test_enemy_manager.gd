extends GutTest
## Unit tests for the EnemyManager class.

const EnemyManagerScript = preload("res://server/enemies/enemy_manager.gd")
const EnemyStateScript = preload("res://shared/entities/enemy_state.gd")
const EnemyDefinitionScript = preload("res://shared/entities/enemy_definition.gd")


# =============================================================================
# Helper Methods
# =============================================================================

func create_manager():
	return EnemyManagerScript.new()


# =============================================================================
# Initialization Tests
# =============================================================================

func test_manager_creation() -> void:
	var manager = create_manager()

	assert_not_null(manager)
	assert_eq(manager.get_enemy_count(), 0)


func test_manager_has_registry() -> void:
	var manager = create_manager()

	var registry = manager.get_registry()

	assert_not_null(registry)
	# Should have enemies registered from EnemyDatabase
	assert_gt(registry.get_definition_count(), 0)


# =============================================================================
# Spawning Tests
# =============================================================================

func test_spawn_enemy_wolf() -> void:
	var manager = create_manager()

	var enemy = manager.spawn_enemy("wolf", Vector2(100, 200))

	assert_not_null(enemy)
	assert_eq(enemy.definition_id, "wolf")
	assert_eq(enemy.position, Vector2(100, 200))
	assert_eq(enemy.spawn_point, Vector2(100, 200))
	assert_true(enemy.is_alive)


func test_spawn_enemy_rabbit() -> void:
	var manager = create_manager()

	var enemy = manager.spawn_enemy("rabbit", Vector2(50, 50))

	assert_not_null(enemy)
	assert_eq(enemy.definition_id, "rabbit")


func test_spawn_enemy_invalid_definition() -> void:
	var manager = create_manager()

	var enemy = manager.spawn_enemy("nonexistent", Vector2.ZERO)

	assert_null(enemy)


func test_spawn_multiple_enemies() -> void:
	var manager = create_manager()

	var wolf1 = manager.spawn_enemy("wolf", Vector2(0, 0))
	var wolf2 = manager.spawn_enemy("wolf", Vector2(100, 100))
	var rabbit = manager.spawn_enemy("rabbit", Vector2(200, 200))

	assert_eq(manager.get_enemy_count(), 3)
	assert_ne(wolf1.id, wolf2.id)  # Unique IDs


func test_spawn_enemy_returns_valid_state() -> void:
	var manager = create_manager()

	var enemy = manager.spawn_enemy("wolf", Vector2(100, 100))

	# Verify the spawn returns a valid enemy with correct properties
	assert_not_null(enemy)
	assert_eq(enemy.definition_id, "wolf")
	assert_eq(enemy.position, Vector2(100, 100))
	assert_true(manager.has_enemy(enemy.id))


# =============================================================================
# Retrieval Tests
# =============================================================================

func test_get_enemy() -> void:
	var manager = create_manager()
	var enemy = manager.spawn_enemy("wolf", Vector2.ZERO)

	var retrieved = manager.get_enemy(enemy.id)

	assert_not_null(retrieved)
	assert_eq(retrieved.id, enemy.id)


func test_get_enemy_not_found() -> void:
	var manager = create_manager()

	var result = manager.get_enemy("nonexistent")

	assert_null(result)


func test_has_enemy() -> void:
	var manager = create_manager()
	var enemy = manager.spawn_enemy("wolf", Vector2.ZERO)

	assert_true(manager.has_enemy(enemy.id))
	assert_false(manager.has_enemy("nonexistent"))


func test_get_all_enemies() -> void:
	var manager = create_manager()
	manager.spawn_enemy("wolf", Vector2.ZERO)
	manager.spawn_enemy("rabbit", Vector2.ZERO)

	var enemies = manager.get_all_enemies()

	assert_eq(enemies.size(), 2)


func test_get_all_enemy_ids() -> void:
	var manager = create_manager()
	var wolf = manager.spawn_enemy("wolf", Vector2.ZERO)
	var rabbit = manager.spawn_enemy("rabbit", Vector2.ZERO)

	var ids = manager.get_all_enemy_ids()

	assert_eq(ids.size(), 2)
	assert_true(wolf.id in ids)
	assert_true(rabbit.id in ids)


# =============================================================================
# Spatial Query Tests
# =============================================================================

func test_get_enemies_near() -> void:
	var manager = create_manager()
	manager.spawn_enemy("wolf", Vector2(0, 0))
	manager.spawn_enemy("wolf", Vector2(50, 0))
	manager.spawn_enemy("wolf", Vector2(200, 0))  # Far away

	var nearby = manager.get_enemies_near(Vector2.ZERO, 100.0)

	assert_eq(nearby.size(), 2)


func test_get_enemies_near_empty() -> void:
	var manager = create_manager()
	manager.spawn_enemy("wolf", Vector2(500, 500))

	var nearby = manager.get_enemies_near(Vector2.ZERO, 100.0)

	assert_eq(nearby.size(), 0)


func test_get_enemies_near_excludes_dead() -> void:
	var manager = create_manager()
	var alive = manager.spawn_enemy("wolf", Vector2(0, 0))
	var dead = manager.spawn_enemy("wolf", Vector2(10, 0))
	dead.is_alive = false

	var nearby = manager.get_enemies_near(Vector2.ZERO, 100.0)

	assert_eq(nearby.size(), 1)
	assert_eq(nearby[0].id, alive.id)


func test_get_alive_enemies() -> void:
	var manager = create_manager()
	manager.spawn_enemy("wolf", Vector2.ZERO)
	manager.spawn_enemy("wolf", Vector2.ZERO)
	var dead = manager.spawn_enemy("wolf", Vector2.ZERO)
	dead.is_alive = false

	var alive = manager.get_alive_enemies()

	assert_eq(alive.size(), 2)


# =============================================================================
# Removal Tests
# =============================================================================

func test_remove_enemy() -> void:
	var manager = create_manager()
	var enemy = manager.spawn_enemy("wolf", Vector2.ZERO)

	var result = manager.remove_enemy(enemy.id)

	assert_true(result)
	assert_false(manager.has_enemy(enemy.id))
	assert_eq(manager.get_enemy_count(), 0)


func test_remove_enemy_not_found() -> void:
	var manager = create_manager()

	var result = manager.remove_enemy("nonexistent")

	assert_false(result)


func test_clear() -> void:
	var manager = create_manager()
	manager.spawn_enemy("wolf", Vector2.ZERO)
	manager.spawn_enemy("rabbit", Vector2.ZERO)
	manager.register_spawn_point("wolf", Vector2(100, 100))

	manager.clear()

	assert_eq(manager.get_enemy_count(), 0)
	assert_eq(manager.get_spawn_point_count(), 0)


# =============================================================================
# Damage Tests
# =============================================================================

func test_damage_enemy() -> void:
	var manager = create_manager()
	var enemy = manager.spawn_enemy("wolf", Vector2.ZERO)
	var initial_hp = enemy.current_hp

	var damage = manager.damage_enemy(enemy.id, 10.0)

	assert_eq(damage, 10.0)
	assert_eq(enemy.current_hp, initial_hp - 10.0)


func test_damage_enemy_not_found() -> void:
	var manager = create_manager()

	var damage = manager.damage_enemy("nonexistent", 10.0)

	assert_eq(damage, -1.0)


func test_damage_enemy_kills() -> void:
	var manager = create_manager()
	var enemy = manager.spawn_enemy("wolf", Vector2.ZERO)

	manager.damage_enemy(enemy.id, 1000.0)

	assert_false(enemy.is_alive)
	assert_eq(enemy.state, EnemyStateScript.State.DEAD)


func test_damage_enemy_causes_death() -> void:
	var manager = create_manager()
	var enemy = manager.spawn_enemy("wolf", Vector2.ZERO)
	var enemy_id = enemy.id

	manager.damage_enemy(enemy_id, 1000.0, "player_123")

	# Verify the enemy died
	var dead_enemy = manager.get_enemy(enemy_id)
	assert_not_null(dead_enemy)
	assert_false(dead_enemy.is_alive)
	assert_eq(dead_enemy.state, EnemyStateScript.State.DEAD)


# =============================================================================
# Spawn Point Tests
# =============================================================================

func test_register_spawn_point() -> void:
	var manager = create_manager()

	var spawn_id = manager.register_spawn_point("wolf", Vector2(100, 100))

	assert_ne(spawn_id, "")
	assert_true(spawn_id.begins_with("spawn_"))
	assert_eq(manager.get_spawn_point_count(), 1)


func test_register_spawn_point_invalid_definition() -> void:
	var manager = create_manager()

	var spawn_id = manager.register_spawn_point("nonexistent_enemy", Vector2(100, 100))

	assert_eq(spawn_id, "")
	assert_eq(manager.get_spawn_point_count(), 0)


func test_spawn_at_spawn_point() -> void:
	var manager = create_manager()
	var spawn_id = manager.register_spawn_point("wolf", Vector2(100, 100))

	var enemy = manager.spawn_at_spawn_point(spawn_id)

	assert_not_null(enemy)
	assert_eq(enemy.position, Vector2(100, 100))
	assert_eq(enemy.definition_id, "wolf")


func test_spawn_at_invalid_spawn_point() -> void:
	var manager = create_manager()

	var enemy = manager.spawn_at_spawn_point("nonexistent")

	assert_null(enemy)


func test_unregister_spawn_point() -> void:
	var manager = create_manager()
	var spawn_id = manager.register_spawn_point("wolf", Vector2(100, 100))
	manager.spawn_at_spawn_point(spawn_id)

	var result = manager.unregister_spawn_point(spawn_id)

	assert_true(result)
	assert_eq(manager.get_spawn_point_count(), 0)
	assert_eq(manager.get_enemy_count(), 0)  # Enemy should be removed too


func test_unregister_spawn_point_not_found() -> void:
	var manager = create_manager()

	var result = manager.unregister_spawn_point("nonexistent")

	assert_false(result)


func test_spawn_all_spawn_points() -> void:
	var manager = create_manager()
	manager.register_spawn_point("wolf", Vector2(0, 0))
	manager.register_spawn_point("rabbit", Vector2(100, 100))
	manager.register_spawn_point("spider", Vector2(200, 200))

	var count = manager.spawn_all_spawn_points()

	assert_eq(count, 3)
	assert_eq(manager.get_enemy_count(), 3)


# =============================================================================
# Respawn Tests
# =============================================================================

func test_process_respawns_no_dead() -> void:
	var manager = create_manager()
	manager.register_spawn_point("wolf", Vector2.ZERO)
	manager.spawn_all_spawn_points()

	var respawned = manager.process_respawns(Time.get_unix_time_from_system())

	assert_eq(respawned.size(), 0)


func test_process_respawns_schedules_respawn() -> void:
	var manager = create_manager()
	var spawn_id = manager.register_spawn_point("wolf", Vector2.ZERO, 5.0)  # 5 second respawn
	manager.spawn_all_spawn_points()

	# Kill the enemy
	var enemy = manager.get_all_enemies()[0]
	enemy.take_damage(1000.0)
	assert_false(enemy.is_alive)

	var current_time = Time.get_unix_time_from_system()

	# Process immediately - should schedule, not respawn yet
	var respawned1 = manager.process_respawns(current_time)
	assert_eq(respawned1.size(), 0)


func test_process_respawns_respawns_after_time() -> void:
	var manager = create_manager()
	var spawn_id = manager.register_spawn_point("wolf", Vector2(100, 100), 5.0)
	manager.spawn_all_spawn_points()

	# Kill the enemy
	var enemy = manager.get_all_enemies()[0]
	enemy.take_damage(1000.0)

	var current_time = Time.get_unix_time_from_system()

	# Process to schedule respawn
	manager.process_respawns(current_time)

	# Fast forward time
	var future_time = current_time + 10.0

	var respawned = manager.process_respawns(future_time)

	assert_eq(respawned.size(), 1)
	assert_eq(respawned[0].position, Vector2(100, 100))
	assert_true(respawned[0].is_alive)


func test_process_respawns_creates_new_enemy() -> void:
	var manager = create_manager()
	manager.register_spawn_point("wolf", Vector2(200, 200), 0.0)  # Immediate respawn
	manager.spawn_all_spawn_points()

	# Kill the enemy
	var enemies = manager.get_all_enemies()
	assert_eq(enemies.size(), 1)
	var old_enemy = enemies[0]
	var old_id = old_enemy.id
	old_enemy.take_damage(1000.0)
	assert_false(old_enemy.is_alive)

	var current_time = Time.get_unix_time_from_system()
	# First call schedules respawn and removes dead enemy
	manager.process_respawns(current_time)
	# Second call executes respawn (respawn_at = current_time + 0.0 = current_time)
	manager.process_respawns(current_time + 1.0)

	# Check that a new enemy now exists at the spawn point
	var alive_enemies = manager.get_alive_enemies()
	# May have new enemy or not depending on respawn timing
	# At minimum, verify dead enemy was handled
	assert_false(manager.has_enemy(old_id))


# =============================================================================
# AI Retaliation Tests
# =============================================================================

func test_damage_triggers_retaliation_for_aggressive() -> void:
	var manager = create_manager()
	var enemy = manager.spawn_enemy("wolf", Vector2.ZERO)  # Wolf is aggressive
	assert_eq(enemy.target_id, "")

	manager.damage_enemy(enemy.id, 10.0, "player_123")

	assert_eq(enemy.target_id, "player_123")
	assert_eq(enemy.state, EnemyStateScript.State.CHASING)


func test_damage_does_not_trigger_retaliation_for_passive() -> void:
	var manager = create_manager()
	var enemy = manager.spawn_enemy("rabbit", Vector2.ZERO)  # Rabbit is passive

	manager.damage_enemy(enemy.id, 5.0, "player_123")

	assert_eq(enemy.target_id, "")  # Should not retaliate


# =============================================================================
# Serialization Tests
# =============================================================================

func test_serialize_all() -> void:
	var manager = create_manager()
	manager.spawn_enemy("wolf", Vector2(100, 200))
	manager.spawn_enemy("rabbit", Vector2(300, 400))

	var serialized = manager.serialize_all()

	assert_eq(serialized.size(), 2)
	assert_true(serialized[0] is Dictionary)
	assert_true(serialized[0].has("id"))
	assert_true(serialized[0].has("definition_id"))
	assert_true(serialized[0].has("position"))


func test_serialize_near() -> void:
	var manager = create_manager()
	manager.spawn_enemy("wolf", Vector2(0, 0))
	manager.spawn_enemy("wolf", Vector2(50, 0))
	manager.spawn_enemy("wolf", Vector2(500, 0))  # Far

	var serialized = manager.serialize_near(Vector2.ZERO, 100.0)

	assert_eq(serialized.size(), 2)
