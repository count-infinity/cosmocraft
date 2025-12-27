class_name PlayerCorpse
extends RefCounted
## Lightweight player corpse for corpse run death penalty.
## Tracks the location and inventory of a player's death for recovery.


## Unique corpse ID
var id: String = ""

## ID of the player who died
var player_id: String = ""

## Display name of the player
var player_name: String = ""

## World position where the player died
var position: Vector2 = Vector2.ZERO

## Serialized inventory data dropped on death
var inventory_data: Dictionary = {}

## Server time when the corpse was created
var death_time: float = 0.0

## Whether the corpse has been recovered by the player
var recovered: bool = false


## Time in seconds before corpse despawns (10 minutes)
const DESPAWN_TIME: float = 600.0


func _init() -> void:
	id = _generate_id()


## Generate a unique corpse ID
func _generate_id() -> String:
	return "pc_%d_%d" % [int(Time.get_unix_time_from_system() * 1000) % 1000000, randi() % 10000]


## Initialize from player death
func init_from_death(
	p_player_id: String,
	p_player_name: String,
	death_position: Vector2,
	p_inventory_data: Dictionary,
	server_time: float
) -> void:
	player_id = p_player_id
	player_name = p_player_name
	position = death_position
	inventory_data = p_inventory_data.duplicate(true)
	death_time = server_time
	recovered = false


## Check if the corpse has expired (exceeded despawn time)
func is_expired(current_time: float) -> bool:
	return current_time >= death_time + DESPAWN_TIME


## Get time remaining before expiration in seconds
func get_time_remaining(current_time: float) -> float:
	var remaining := (death_time + DESPAWN_TIME) - current_time
	return maxf(0.0, remaining)


## Get formatted time remaining string (MM:SS)
func get_time_remaining_text(current_time: float) -> String:
	var remaining := get_time_remaining(current_time)
	if remaining <= 0.0:
		return "Expired"

	var minutes := int(remaining / 60.0)
	var seconds := int(remaining) % 60
	return "%d:%02d" % [minutes, seconds]


## Check if the corpse is empty (no items to recover)
func is_empty() -> bool:
	return inventory_data.is_empty()


## Mark the corpse as recovered
func mark_recovered() -> void:
	recovered = true
	inventory_data.clear()


## Serialize to dictionary for network transmission
func to_dict() -> Dictionary:
	return {
		"id": id,
		"player_id": player_id,
		"player_name": player_name,
		"position": {"x": position.x, "y": position.y},
		"inventory_data": inventory_data,
		"death_time": death_time,
		"recovered": recovered
	}


## Deserialize from dictionary
static func from_dict(data: Dictionary) -> RefCounted:
	var corpse: RefCounted = (load("res://shared/entities/player_corpse.gd") as GDScript).new()
	corpse.id = data.get("id", corpse.id)
	corpse.player_id = data.get("player_id", "")
	corpse.player_name = data.get("player_name", "")

	var pos_data: Dictionary = data.get("position", {})
	corpse.position = Vector2(
		float(pos_data.get("x", 0.0)),
		float(pos_data.get("y", 0.0))
	)

	corpse.inventory_data = data.get("inventory_data", {})
	corpse.death_time = float(data.get("death_time", 0.0))
	corpse.recovered = data.get("recovered", false)

	return corpse


## Create a copy
func clone() -> RefCounted:
	var script: GDScript = load("res://shared/entities/player_corpse.gd")
	var copy: RefCounted = script.new()
	copy.id = id
	copy.player_id = player_id
	copy.player_name = player_name
	copy.position = position
	copy.inventory_data = inventory_data.duplicate(true)
	copy.death_time = death_time
	copy.recovered = recovered
	return copy
