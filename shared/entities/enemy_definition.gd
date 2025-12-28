class_name EnemyDefinition
extends Resource
## Static definition of an enemy type.
## This is the "template" - EnemyState is the actual enemy instance in the world.


## Behavior types determining how enemies react to players
enum BehaviorType {
	PASSIVE = 0,      ## Never attacks, flees when damaged
	NEUTRAL = 1,      ## Only attacks when attacked first
	AGGRESSIVE = 2    ## Attacks players on sight within aggro range
}


## Unique identifier for this enemy type (e.g., "rabbit", "wolf")
@export var id: String = ""

## Display name shown in UI
@export var display_name: String = ""

## Description shown in tooltips/bestiary
@export_multiline var description: String = ""

## Maximum hit points
@export var max_hp: float = 10.0

## Base damage per attack
@export var damage: float = 5.0

## Attack range in pixels
@export var attack_range: float = 32.0

## Attacks per second
@export var attack_speed: float = 1.0

## Movement speed in pixels per second
@export var move_speed: float = 100.0

## Hitbox radius in pixels (for collision and hit detection)
@export var hitbox_radius: float = 16.0

## Behavior type determining aggression
@export var behavior_type: BehaviorType = BehaviorType.NEUTRAL

## Faction (always FACTION_ENEMY for enemies, see GameConstants)
## Note: Using literal 2 instead of GameConstants.FACTION_ENEMY for headless compatibility
@export var faction: int = 2  # GameConstants.FACTION_ENEMY

## Range at which aggressive enemies detect players (in pixels)
@export var aggro_range: float = 200.0

## Maximum distance from spawn point before returning (in pixels)
@export var leash_range: float = 400.0

## ID of the loot table for drops (empty = no drops)
@export var loot_table_id: String = ""

## Experience points granted on death
@export var xp_reward: int = 10

## Tier/level of the enemy (1-5)
@export_range(1, 5) var tier: int = 1

## Optional sprite/icon path
@export var sprite_path: String = ""


func _init(
	p_id: String = "",
	p_display_name: String = "",
	p_max_hp: float = 10.0,
	p_damage: float = 5.0
) -> void:
	id = p_id
	display_name = p_display_name
	max_hp = p_max_hp
	damage = p_damage


## Check if this enemy type is aggressive
func is_aggressive() -> bool:
	return behavior_type == BehaviorType.AGGRESSIVE


## Check if this enemy type is passive
func is_passive() -> bool:
	return behavior_type == BehaviorType.PASSIVE


## Check if this enemy type will fight back when attacked
func will_retaliate() -> bool:
	return behavior_type != BehaviorType.PASSIVE


## Get attack cooldown in seconds
func get_attack_cooldown() -> float:
	if attack_speed <= 0.0:
		return 1.0
	return 1.0 / attack_speed


## Serialize to dictionary for network/save
func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"description": description,
		"max_hp": max_hp,
		"damage": damage,
		"attack_range": attack_range,
		"attack_speed": attack_speed,
		"move_speed": move_speed,
		"hitbox_radius": hitbox_radius,
		"behavior_type": behavior_type,
		"faction": faction,
		"aggro_range": aggro_range,
		"leash_range": leash_range,
		"loot_table_id": loot_table_id,
		"xp_reward": xp_reward,
		"tier": tier,
		"sprite_path": sprite_path
	}


## Create from dictionary
static func from_dict(data: Dictionary) -> Resource:
	var script: GDScript = load("res://shared/entities/enemy_definition.gd")
	var def: Resource = script.new()
	def.id = data.get("id", "")
	def.display_name = data.get("display_name", "")
	def.description = data.get("description", "")
	def.max_hp = float(data.get("max_hp", 10.0))
	def.damage = float(data.get("damage", 5.0))
	def.attack_range = float(data.get("attack_range", 32.0))
	def.attack_speed = float(data.get("attack_speed", 1.0))
	def.move_speed = float(data.get("move_speed", 100.0))
	def.hitbox_radius = float(data.get("hitbox_radius", 16.0))
	def.behavior_type = int(data.get("behavior_type", BehaviorType.NEUTRAL)) as BehaviorType
	def.faction = int(data.get("faction", 2))
	def.aggro_range = float(data.get("aggro_range", 200.0))
	def.leash_range = float(data.get("leash_range", 400.0))
	def.loot_table_id = data.get("loot_table_id", "")
	def.xp_reward = int(data.get("xp_reward", 10))
	def.tier = int(data.get("tier", 1))
	def.sprite_path = data.get("sprite_path", "")
	return def
