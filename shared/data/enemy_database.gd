class_name EnemyDatabase
extends RefCounted
## Shared enemy database containing all enemy definitions.
## This is the single source of truth for enemy data, used by both server and client.


## Register all enemies into the provided registry
## Uses RefCounted type for headless mode compatibility
static func register_all_enemies(registry: RefCounted) -> void:
	var EnemyDefinitionScript: GDScript = load("res://shared/entities/enemy_definition.gd")
	_register_passive_creatures(registry, EnemyDefinitionScript)
	_register_aggressive_creatures(registry, EnemyDefinitionScript)


## Register passive creatures (non-threatening wildlife)
static func _register_passive_creatures(registry: RefCounted, EnemyDef: GDScript) -> void:
	# Rabbit - small, fast, passive creature
	var rabbit = EnemyDef.new("rabbit", "Rabbit", 10.0, 2.0)
	rabbit.description = "A small, timid creature that flees when threatened."
	rabbit.attack_range = 16.0
	rabbit.attack_speed = 0.5
	rabbit.move_speed = 150.0  # Fast!
	rabbit.hitbox_radius = 8.0  # Small
	rabbit.behavior_type = EnemyDef.BehaviorType.PASSIVE
	rabbit.aggro_range = 0.0  # Never aggros
	rabbit.leash_range = 300.0
	rabbit.loot_table_id = "loot_rabbit"
	rabbit.xp_reward = 5
	rabbit.tier = 1
	registry.register_definition(rabbit)


## Register aggressive creatures (hostile enemies)
static func _register_aggressive_creatures(registry: RefCounted, EnemyDef: GDScript) -> void:
	# Wolf - medium-sized aggressive pack hunter
	var wolf = EnemyDef.new("wolf", "Wolf", 30.0, 8.0)
	wolf.description = "A fierce predator that hunts in packs. Attacks on sight."
	wolf.attack_range = 32.0
	wolf.attack_speed = 1.2
	wolf.move_speed = 120.0
	wolf.hitbox_radius = 12.0  # Medium
	wolf.behavior_type = EnemyDef.BehaviorType.AGGRESSIVE
	wolf.aggro_range = 250.0
	wolf.leash_range = 400.0
	wolf.loot_table_id = "loot_wolf"
	wolf.xp_reward = 25
	wolf.tier = 1
	registry.register_definition(wolf)

	# Spider - smaller aggressive enemy with faster attacks
	var spider = EnemyDef.new("spider", "Giant Spider", 20.0, 5.0)
	spider.description = "A venomous arachnid that lurks in dark places."
	spider.attack_range = 24.0
	spider.attack_speed = 2.0  # Fast attacks
	spider.move_speed = 100.0
	spider.hitbox_radius = 10.0
	spider.behavior_type = EnemyDef.BehaviorType.AGGRESSIVE
	spider.aggro_range = 150.0
	spider.leash_range = 300.0
	spider.loot_table_id = "loot_spider"
	spider.xp_reward = 15
	spider.tier = 1
	registry.register_definition(spider)

	# Boar - neutral until attacked, then aggressive
	var boar = EnemyDef.new("boar", "Wild Boar", 50.0, 12.0)
	boar.description = "A sturdy beast that charges when provoked."
	boar.attack_range = 28.0
	boar.attack_speed = 0.8
	boar.move_speed = 130.0
	boar.hitbox_radius = 14.0
	boar.behavior_type = EnemyDef.BehaviorType.NEUTRAL
	boar.aggro_range = 100.0  # Only aggros if very close or attacked
	boar.leash_range = 350.0
	boar.loot_table_id = "loot_boar"
	boar.xp_reward = 35
	boar.tier = 2
	registry.register_definition(boar)


## Get the count of enemies that will be registered
static func get_enemy_count() -> int:
	return 4  # rabbit, wolf, spider, boar
