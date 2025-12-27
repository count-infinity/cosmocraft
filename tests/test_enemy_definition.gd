extends GutTest
## Unit tests for the EnemyDefinition class.


const EnemyDefinitionScript = preload("res://shared/entities/enemy_definition.gd")


## Helper to create an EnemyDefinition instance
func _create_definition(id: String = "", display_name: String = "", max_hp: float = 10.0, damage: float = 5.0):
	return EnemyDefinitionScript.new(id, display_name, max_hp, damage)


# =============================================================================
# Creation Tests
# =============================================================================

func test_enemy_definition_creation_defaults() -> void:
	var def = _create_definition()

	assert_eq(def.id, "")
	assert_eq(def.display_name, "")
	assert_eq(def.max_hp, 10.0)
	assert_eq(def.damage, 5.0)
	assert_eq(def.behavior_type, EnemyDefinitionScript.BehaviorType.NEUTRAL)
	assert_eq(def.faction, 2)  # Enemy faction


func test_enemy_definition_creation_with_values() -> void:
	var def = _create_definition("wolf", "Wolf", 30.0, 8.0)

	assert_eq(def.id, "wolf")
	assert_eq(def.display_name, "Wolf")
	assert_eq(def.max_hp, 30.0)
	assert_eq(def.damage, 8.0)


func test_enemy_definition_full_configuration() -> void:
	var def = _create_definition("test_enemy", "Test Enemy", 100.0, 20.0)
	def.description = "A test enemy for unit tests."
	def.attack_range = 50.0
	def.attack_speed = 2.0
	def.move_speed = 150.0
	def.hitbox_radius = 24.0
	def.behavior_type = EnemyDefinitionScript.BehaviorType.AGGRESSIVE
	def.aggro_range = 300.0
	def.leash_range = 500.0
	def.loot_table_id = "loot_test"
	def.xp_reward = 50
	def.tier = 3

	assert_eq(def.attack_range, 50.0)
	assert_eq(def.attack_speed, 2.0)
	assert_eq(def.move_speed, 150.0)
	assert_eq(def.hitbox_radius, 24.0)
	assert_eq(def.behavior_type, EnemyDefinitionScript.BehaviorType.AGGRESSIVE)
	assert_eq(def.aggro_range, 300.0)
	assert_eq(def.leash_range, 500.0)
	assert_eq(def.loot_table_id, "loot_test")
	assert_eq(def.xp_reward, 50)
	assert_eq(def.tier, 3)


# =============================================================================
# Behavior Tests
# =============================================================================

func test_is_aggressive() -> void:
	var aggressive = _create_definition("agg", "Aggressive", 10.0, 5.0)
	aggressive.behavior_type = EnemyDefinitionScript.BehaviorType.AGGRESSIVE

	var passive = _create_definition("pas", "Passive", 10.0, 5.0)
	passive.behavior_type = EnemyDefinitionScript.BehaviorType.PASSIVE

	var neutral = _create_definition("neu", "Neutral", 10.0, 5.0)
	neutral.behavior_type = EnemyDefinitionScript.BehaviorType.NEUTRAL

	assert_true(aggressive.is_aggressive())
	assert_false(passive.is_aggressive())
	assert_false(neutral.is_aggressive())


func test_is_passive() -> void:
	var aggressive = _create_definition("agg", "Aggressive", 10.0, 5.0)
	aggressive.behavior_type = EnemyDefinitionScript.BehaviorType.AGGRESSIVE

	var passive = _create_definition("pas", "Passive", 10.0, 5.0)
	passive.behavior_type = EnemyDefinitionScript.BehaviorType.PASSIVE

	assert_false(aggressive.is_passive())
	assert_true(passive.is_passive())


func test_will_retaliate() -> void:
	var aggressive = _create_definition("agg", "Aggressive", 10.0, 5.0)
	aggressive.behavior_type = EnemyDefinitionScript.BehaviorType.AGGRESSIVE

	var passive = _create_definition("pas", "Passive", 10.0, 5.0)
	passive.behavior_type = EnemyDefinitionScript.BehaviorType.PASSIVE

	var neutral = _create_definition("neu", "Neutral", 10.0, 5.0)
	neutral.behavior_type = EnemyDefinitionScript.BehaviorType.NEUTRAL

	assert_true(aggressive.will_retaliate())
	assert_false(passive.will_retaliate())
	assert_true(neutral.will_retaliate())


# =============================================================================
# Attack Cooldown Tests
# =============================================================================

func test_get_attack_cooldown_normal() -> void:
	var def = _create_definition()
	def.attack_speed = 2.0  # 2 attacks per second

	assert_almost_eq(def.get_attack_cooldown(), 0.5, 0.001)


func test_get_attack_cooldown_slow() -> void:
	var def = _create_definition()
	def.attack_speed = 0.5  # 0.5 attacks per second

	assert_almost_eq(def.get_attack_cooldown(), 2.0, 0.001)


func test_get_attack_cooldown_zero_speed() -> void:
	var def = _create_definition()
	def.attack_speed = 0.0

	assert_eq(def.get_attack_cooldown(), 1.0)  # Default fallback


# =============================================================================
# Serialization Tests
# =============================================================================

func test_to_dict() -> void:
	var def = _create_definition("wolf", "Wolf", 30.0, 8.0)
	def.attack_range = 32.0
	def.attack_speed = 1.2
	def.behavior_type = EnemyDefinitionScript.BehaviorType.AGGRESSIVE
	def.xp_reward = 25

	var dict := def.to_dict()

	assert_eq(dict["id"], "wolf")
	assert_eq(dict["display_name"], "Wolf")
	assert_eq(dict["max_hp"], 30.0)
	assert_eq(dict["damage"], 8.0)
	assert_eq(dict["attack_range"], 32.0)
	assert_eq(dict["attack_speed"], 1.2)
	assert_eq(dict["behavior_type"], EnemyDefinitionScript.BehaviorType.AGGRESSIVE)
	assert_eq(dict["xp_reward"], 25)


func test_from_dict() -> void:
	var data := {
		"id": "spider",
		"display_name": "Giant Spider",
		"max_hp": 20.0,
		"damage": 5.0,
		"attack_range": 24.0,
		"attack_speed": 2.0,
		"move_speed": 100.0,
		"hitbox_radius": 10.0,
		"behavior_type": EnemyDefinitionScript.BehaviorType.AGGRESSIVE,
		"faction": 2,
		"aggro_range": 150.0,
		"leash_range": 300.0,
		"xp_reward": 15,
		"tier": 1
	}

	var def = EnemyDefinitionScript.from_dict(data)

	assert_eq(def.id, "spider")
	assert_eq(def.display_name, "Giant Spider")
	assert_eq(def.max_hp, 20.0)
	assert_eq(def.damage, 5.0)
	assert_eq(def.attack_range, 24.0)
	assert_eq(def.attack_speed, 2.0)
	assert_eq(def.move_speed, 100.0)
	assert_eq(def.hitbox_radius, 10.0)
	assert_eq(def.behavior_type, EnemyDefinitionScript.BehaviorType.AGGRESSIVE)
	assert_eq(def.aggro_range, 150.0)
	assert_eq(def.leash_range, 300.0)
	assert_eq(def.xp_reward, 15)
	assert_eq(def.tier, 1)


func test_round_trip_serialization() -> void:
	var original = _create_definition("test", "Test Enemy", 50.0, 10.0)
	original.attack_range = 40.0
	original.attack_speed = 1.5
	original.move_speed = 120.0
	original.hitbox_radius = 18.0
	original.behavior_type = EnemyDefinitionScript.BehaviorType.NEUTRAL
	original.aggro_range = 180.0
	original.leash_range = 350.0
	original.loot_table_id = "loot_test"
	original.xp_reward = 30
	original.tier = 2

	var dict := original.to_dict()
	var restored = EnemyDefinitionScript.from_dict(dict)

	assert_eq(restored.id, original.id)
	assert_eq(restored.display_name, original.display_name)
	assert_eq(restored.max_hp, original.max_hp)
	assert_eq(restored.damage, original.damage)
	assert_eq(restored.attack_range, original.attack_range)
	assert_eq(restored.attack_speed, original.attack_speed)
	assert_eq(restored.move_speed, original.move_speed)
	assert_eq(restored.hitbox_radius, original.hitbox_radius)
	assert_eq(restored.behavior_type, original.behavior_type)
	assert_eq(restored.aggro_range, original.aggro_range)
	assert_eq(restored.leash_range, original.leash_range)
	assert_eq(restored.loot_table_id, original.loot_table_id)
	assert_eq(restored.xp_reward, original.xp_reward)
	assert_eq(restored.tier, original.tier)
