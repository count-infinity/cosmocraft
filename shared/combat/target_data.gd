class_name TargetData
extends RefCounted
## Represents a potential target for attacks.
## Used by both players and enemies in the combat system.


## Faction constants for distinguishing entity types
enum Faction {
	NEUTRAL = 0,
	PLAYER = 1,
	ENEMY = 2
}


## Unique identifier for this entity
var id: String

## World position of the target
var position: Vector2

## Radius of the target's hitbox in pixels
var hitbox_radius: float

## Faction of the target (used for friendly-fire checks, etc.)
var faction: int


func _init(
	p_id: String = "",
	p_position: Vector2 = Vector2.ZERO,
	p_hitbox_radius: float = 16.0,
	p_faction: int = Faction.NEUTRAL
) -> void:
	id = p_id
	position = p_position
	hitbox_radius = p_hitbox_radius
	faction = p_faction


## Check if this target is a player
func is_player() -> bool:
	return faction == Faction.PLAYER


## Check if this target is an enemy
func is_enemy() -> bool:
	return faction == Faction.ENEMY


## Check if this target is hostile to a given faction
func is_hostile_to(other_faction: int) -> bool:
	# Neutral is hostile to no one
	if faction == Faction.NEUTRAL or other_faction == Faction.NEUTRAL:
		return false
	# Different factions are hostile to each other
	return faction != other_faction


## Create from a dictionary with position data
static func from_dict(data: Dictionary, radius: float = 16.0) -> RefCounted:
	var pos: Vector2 = Vector2.ZERO
	if data.has("position"):
		var pos_data: Dictionary = data["position"]
		pos = Vector2(float(pos_data.get("x", 0.0)), float(pos_data.get("y", 0.0)))
	elif data.has("x") and data.has("y"):
		pos = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))

	var script: GDScript = load("res://shared/combat/target_data.gd")
	return script.new(
		data.get("id", ""),
		pos,
		float(data.get("hitbox_radius", radius)),
		int(data.get("faction", Faction.NEUTRAL))
	)


## Create a TargetData from a player
## Players have a hitbox radius of 16 pixels (half of PLAYER_SIZE)
static func from_player(player_id: String, player_position: Vector2) -> RefCounted:
	var script: GDScript = load("res://shared/combat/target_data.gd")
	return script.new(player_id, player_position, 16.0, Faction.PLAYER)


## Create a TargetData from an enemy
static func from_enemy(enemy_id: String, enemy_position: Vector2, enemy_hitbox_radius: float) -> RefCounted:
	var script: GDScript = load("res://shared/combat/target_data.gd")
	return script.new(enemy_id, enemy_position, enemy_hitbox_radius, Faction.ENEMY)


## Serialize to dictionary
func to_dict() -> Dictionary:
	return {
		"id": id,
		"position": {"x": position.x, "y": position.y},
		"hitbox_radius": hitbox_radius,
		"faction": faction
	}
