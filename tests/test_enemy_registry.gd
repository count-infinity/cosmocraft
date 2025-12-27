extends GutTest
## Unit tests for the EnemyRegistry class.

const EnemyRegistryScript = preload("res://shared/entities/enemy_registry.gd")
const EnemyDefinitionScript = preload("res://shared/entities/enemy_definition.gd")
const EnemyDatabaseScript = preload("res://shared/data/enemy_database.gd")


# =============================================================================
# Helper Methods
# =============================================================================

func create_wolf_definition():
	var def = EnemyDefinitionScript.new("wolf", "Wolf", 30.0, 8.0)
	def.behavior_type = EnemyDefinitionScript.BehaviorType.AGGRESSIVE
	def.tier = 1
	return def


func create_rabbit_definition():
	var def = EnemyDefinitionScript.new("rabbit", "Rabbit", 10.0, 2.0)
	def.behavior_type = EnemyDefinitionScript.BehaviorType.PASSIVE
	def.tier = 1
	return def


func create_boar_definition():
	var def = EnemyDefinitionScript.new("boar", "Wild Boar", 50.0, 12.0)
	def.behavior_type = EnemyDefinitionScript.BehaviorType.NEUTRAL
	def.tier = 2
	return def


# =============================================================================
# Registration Tests
# =============================================================================

func test_register_definition() -> void:
	var registry = EnemyRegistryScript.new()
	var wolf = create_wolf_definition()

	registry.register_definition(wolf)

	assert_true(registry.has_definition("wolf"))
	assert_eq(registry.get_definition_count(), 1)


func test_register_multiple_definitions() -> void:
	var registry = EnemyRegistryScript.new()

	registry.register_definition(create_wolf_definition())
	registry.register_definition(create_rabbit_definition())
	registry.register_definition(create_boar_definition())

	assert_eq(registry.get_definition_count(), 3)


func test_register_definition_empty_id_warning() -> void:
	var registry = EnemyRegistryScript.new()
	var empty_def = EnemyDefinitionScript.new()  # Empty ID

	registry.register_definition(empty_def)

	# Should not be registered
	assert_eq(registry.get_definition_count(), 0)


func test_register_overwrites_existing() -> void:
	var registry = EnemyRegistryScript.new()
	var wolf1 = create_wolf_definition()
	wolf1.max_hp = 30.0

	var wolf2 = create_wolf_definition()
	wolf2.max_hp = 50.0

	registry.register_definition(wolf1)
	registry.register_definition(wolf2)

	var result = registry.get_definition("wolf")
	assert_eq(result.max_hp, 50.0)  # Second registration wins
	assert_eq(registry.get_definition_count(), 1)


# =============================================================================
# Retrieval Tests
# =============================================================================

func test_get_definition_exists() -> void:
	var registry = EnemyRegistryScript.new()
	var wolf = create_wolf_definition()
	registry.register_definition(wolf)

	var result = registry.get_definition("wolf")

	assert_not_null(result)
	assert_eq(result.id, "wolf")
	assert_eq(result.display_name, "Wolf")


func test_get_definition_not_exists() -> void:
	var registry = EnemyRegistryScript.new()

	var result = registry.get_definition("nonexistent")

	assert_null(result)


func test_has_definition() -> void:
	var registry = EnemyRegistryScript.new()
	registry.register_definition(create_wolf_definition())

	assert_true(registry.has_definition("wolf"))
	assert_false(registry.has_definition("dragon"))


func test_get_all_ids() -> void:
	var registry = EnemyRegistryScript.new()
	registry.register_definition(create_wolf_definition())
	registry.register_definition(create_rabbit_definition())

	var ids = registry.get_all_ids()

	assert_eq(ids.size(), 2)
	assert_true("wolf" in ids)
	assert_true("rabbit" in ids)


func test_get_all_definitions() -> void:
	var registry = EnemyRegistryScript.new()
	registry.register_definition(create_wolf_definition())
	registry.register_definition(create_rabbit_definition())

	var defs = registry.get_all_definitions()

	assert_eq(defs.size(), 2)


# =============================================================================
# Filter Tests
# =============================================================================

func test_get_definitions_by_behavior_aggressive() -> void:
	var registry = EnemyRegistryScript.new()
	registry.register_definition(create_wolf_definition())
	registry.register_definition(create_rabbit_definition())
	registry.register_definition(create_boar_definition())

	var aggressive = registry.get_definitions_by_behavior(EnemyDefinitionScript.BehaviorType.AGGRESSIVE)

	assert_eq(aggressive.size(), 1)
	assert_eq(aggressive[0].id, "wolf")


func test_get_definitions_by_behavior_passive() -> void:
	var registry = EnemyRegistryScript.new()
	registry.register_definition(create_wolf_definition())
	registry.register_definition(create_rabbit_definition())

	var passive = registry.get_definitions_by_behavior(EnemyDefinitionScript.BehaviorType.PASSIVE)

	assert_eq(passive.size(), 1)
	assert_eq(passive[0].id, "rabbit")


func test_get_definitions_by_tier() -> void:
	var registry = EnemyRegistryScript.new()
	registry.register_definition(create_wolf_definition())
	registry.register_definition(create_rabbit_definition())
	registry.register_definition(create_boar_definition())

	var tier1 = registry.get_definitions_by_tier(1)
	var tier2 = registry.get_definitions_by_tier(2)

	assert_eq(tier1.size(), 2)  # wolf and rabbit
	assert_eq(tier2.size(), 1)  # boar


func test_get_definitions_by_tier_none() -> void:
	var registry = EnemyRegistryScript.new()
	registry.register_definition(create_wolf_definition())

	var tier5 = registry.get_definitions_by_tier(5)

	assert_eq(tier5.size(), 0)


# =============================================================================
# Removal Tests
# =============================================================================

func test_unregister_definition() -> void:
	var registry = EnemyRegistryScript.new()
	registry.register_definition(create_wolf_definition())

	var result = registry.unregister_definition("wolf")

	assert_true(result)
	assert_false(registry.has_definition("wolf"))
	assert_eq(registry.get_definition_count(), 0)


func test_unregister_definition_not_exists() -> void:
	var registry = EnemyRegistryScript.new()

	var result = registry.unregister_definition("nonexistent")

	assert_false(result)


func test_clear() -> void:
	var registry = EnemyRegistryScript.new()
	registry.register_definition(create_wolf_definition())
	registry.register_definition(create_rabbit_definition())

	registry.clear()

	assert_eq(registry.get_definition_count(), 0)


# =============================================================================
# Factory Tests
# =============================================================================

func test_create_enemy_state() -> void:
	var registry = EnemyRegistryScript.new()
	registry.register_definition(create_wolf_definition())

	var state = registry.create_enemy_state("wolf", "enemy_001", Vector2(100, 200))

	assert_not_null(state)
	assert_eq(state.id, "enemy_001")
	assert_eq(state.definition_id, "wolf")
	assert_eq(state.spawn_point, Vector2(100, 200))
	assert_eq(state.position, Vector2(100, 200))
	assert_eq(state.max_hp, 30.0)  # From wolf definition


func test_create_enemy_state_unknown_definition() -> void:
	var registry = EnemyRegistryScript.new()

	var state = registry.create_enemy_state("dragon", "enemy_001", Vector2.ZERO)

	assert_null(state)


# =============================================================================
# Database Integration Tests
# =============================================================================

func test_enemy_database_registration() -> void:
	var registry = EnemyRegistryScript.new()

	EnemyDatabaseScript.register_all_enemies(registry)

	assert_eq(registry.get_definition_count(), EnemyDatabaseScript.get_enemy_count())
	assert_true(registry.has_definition("rabbit"))
	assert_true(registry.has_definition("wolf"))


func test_enemy_database_rabbit_definition() -> void:
	var registry = EnemyRegistryScript.new()
	EnemyDatabaseScript.register_all_enemies(registry)

	var rabbit = registry.get_definition("rabbit")

	assert_not_null(rabbit)
	assert_eq(rabbit.display_name, "Rabbit")
	assert_eq(rabbit.max_hp, 10.0)
	assert_eq(rabbit.behavior_type, EnemyDefinitionScript.BehaviorType.PASSIVE)
	assert_eq(rabbit.hitbox_radius, 8.0)


func test_enemy_database_wolf_definition() -> void:
	var registry = EnemyRegistryScript.new()
	EnemyDatabaseScript.register_all_enemies(registry)

	var wolf = registry.get_definition("wolf")

	assert_not_null(wolf)
	assert_eq(wolf.display_name, "Wolf")
	assert_eq(wolf.max_hp, 30.0)
	assert_eq(wolf.damage, 8.0)
	assert_eq(wolf.behavior_type, EnemyDefinitionScript.BehaviorType.AGGRESSIVE)
	assert_eq(wolf.hitbox_radius, 12.0)
