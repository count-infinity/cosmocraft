class_name EnemyState
extends RefCounted
## Runtime state of an enemy instance.
## Contains mutable data that changes during gameplay.
## Emits signals for damage/death to decouple from AI behavior.


## Signal emitted when the enemy takes damage
## Note: Signals work on RefCounted but listeners must keep a reference
signal damaged(amount: float, attacker_id: String)

## Signal emitted when the enemy dies
signal died()


## AI states for enemy behavior
enum State {
	IDLE = 0,        ## Standing still, waiting
	ROAMING = 1,     ## Wandering randomly near spawn point
	CHASING = 2,     ## Pursuing a target
	ATTACKING = 3,   ## Actively attacking a target
	RETURNING = 4,   ## Returning to spawn point (leash)
	DEAD = 5         ## Dead, awaiting despawn
}


## Unique instance ID (e.g., "enemy_12345")
var id: String = ""

## Reference to the EnemyDefinition id
var definition_id: String = ""

## Current world position
var position: Vector2 = Vector2.ZERO

## Current velocity
var velocity: Vector2 = Vector2.ZERO

## Current hit points
var current_hp: float = 10.0

## Maximum hit points (copied from definition, can be modified by buffs)
var max_hp: float = 10.0

## Whether the enemy is alive
var is_alive: bool = true

## Position where this enemy spawned (for respawning and leash)
var spawn_point: Vector2 = Vector2.ZERO

## ID of the current target (player or other entity), empty if none
var target_id: String = ""

## Current AI state
var state: State = State.IDLE

## Time when the enemy died (for respawn timing)
var death_time: float = 0.0

## Time of last attack (for cooldown)
var last_attack_time: float = 0.0

## Direction the enemy is facing (for animations)
var facing_direction: Vector2 = Vector2.RIGHT

## ID of the last entity that damaged this enemy (for kill attribution)
var last_attacker_id: String = ""


func _init(
	p_id: String = "",
	p_definition_id: String = "",
	p_spawn_point: Vector2 = Vector2.ZERO,
	p_max_hp: float = 10.0
) -> void:
	id = p_id
	definition_id = p_definition_id
	spawn_point = p_spawn_point
	position = p_spawn_point
	max_hp = p_max_hp
	current_hp = p_max_hp


## Create from an EnemyDefinition
## Note: Uses Resource type for headless mode compatibility
static func create_from_definition(
	instance_id: String,
	definition: Resource,
	spawn_pos: Vector2
) -> RefCounted:
	var script: GDScript = load("res://shared/entities/enemy_state.gd")
	var enemy: RefCounted = script.new(
		instance_id,
		definition.id,
		spawn_pos,
		definition.max_hp
	)
	return enemy


## Check if the enemy can attack (cooldown check)
func can_attack(attack_cooldown: float, current_time: float) -> bool:
	return is_alive and (current_time - last_attack_time) >= attack_cooldown


## Record an attack
func record_attack(current_time: float) -> void:
	last_attack_time = current_time


## Take damage from an attacker
## Returns actual damage taken
## Emits damaged signal for AI systems to react to
func take_damage(amount: float, attacker_id: String = "") -> float:
	if not is_alive or amount <= 0.0:
		return 0.0

	var actual_damage := minf(amount, current_hp)
	current_hp -= actual_damage

	# Track last attacker for kill attribution
	if not attacker_id.is_empty():
		last_attacker_id = attacker_id

	# Emit damage signal for AI controllers to handle retaliation
	damaged.emit(actual_damage, attacker_id)

	if current_hp <= 0.0:
		current_hp = 0.0
		is_alive = false
		state = State.DEAD
		death_time = Time.get_unix_time_from_system()
		died.emit()

	return actual_damage


## Handle retaliation when damaged (called by AI controller via signal)
## This separates AI behavior from damage calculation
func handle_retaliation(attacker_id: String) -> void:
	if not is_alive:
		return
	# Set target if we don't have one
	if target_id.is_empty() and not attacker_id.is_empty():
		target_id = attacker_id
		if state == State.IDLE or state == State.ROAMING:
			state = State.CHASING


## Heal the enemy
## Returns actual amount healed
func heal(amount: float) -> float:
	if not is_alive or amount <= 0.0:
		return 0.0

	var actual_heal := minf(amount, max_hp - current_hp)
	current_hp += actual_heal
	return actual_heal


## Get HP as a percentage (0.0 to 1.0)
func get_hp_percent() -> float:
	if max_hp <= 0.0:
		return 0.0
	return current_hp / max_hp


## Check if the enemy is at full health
func is_full_health() -> bool:
	return current_hp >= max_hp


## Reset the enemy to full health (for respawn)
func revive() -> void:
	current_hp = max_hp
	is_alive = true
	state = State.IDLE
	target_id = ""
	velocity = Vector2.ZERO
	position = spawn_point
	death_time = 0.0
	last_attack_time = 0.0
	last_attacker_id = ""


## Set the current target
func set_target(new_target_id: String) -> void:
	target_id = new_target_id
	if not target_id.is_empty():
		state = State.CHASING
	else:
		state = State.IDLE


## Clear the current target
func clear_target() -> void:
	target_id = ""
	state = State.IDLE


## Check if the enemy is too far from spawn (should leash)
func is_beyond_leash_range(leash_range: float) -> bool:
	return position.distance_to(spawn_point) > leash_range


## Check if the enemy has returned to spawn point
func is_near_spawn(threshold: float = 16.0) -> bool:
	return position.distance_to(spawn_point) <= threshold


## Serialize to dictionary for network transfer
func to_dict() -> Dictionary:
	return {
		"id": id,
		"definition_id": definition_id,
		"position": {"x": position.x, "y": position.y},
		"velocity": {"x": velocity.x, "y": velocity.y},
		"current_hp": current_hp,
		"max_hp": max_hp,
		"is_alive": is_alive,
		"spawn_point": {"x": spawn_point.x, "y": spawn_point.y},
		"target_id": target_id,
		"state": state,
		"facing_direction": {"x": facing_direction.x, "y": facing_direction.y},
		"last_attacker_id": last_attacker_id
	}


## Create from dictionary (network deserialization)
static func from_dict(data: Dictionary) -> RefCounted:
	var script: GDScript = load("res://shared/entities/enemy_state.gd")
	var enemy: RefCounted = script.new()

	enemy.id = data.get("id", "")
	enemy.definition_id = data.get("definition_id", "")

	var pos_data: Dictionary = data.get("position", {})
	enemy.position = Vector2(
		float(pos_data.get("x", 0.0)),
		float(pos_data.get("y", 0.0))
	)

	var vel_data: Dictionary = data.get("velocity", {})
	enemy.velocity = Vector2(
		float(vel_data.get("x", 0.0)),
		float(vel_data.get("y", 0.0))
	)

	enemy.current_hp = float(data.get("current_hp", 10.0))
	enemy.max_hp = float(data.get("max_hp", 10.0))
	enemy.is_alive = data.get("is_alive", true)

	var spawn_data: Dictionary = data.get("spawn_point", {})
	enemy.spawn_point = Vector2(
		float(spawn_data.get("x", 0.0)),
		float(spawn_data.get("y", 0.0))
	)

	enemy.target_id = data.get("target_id", "")
	enemy.state = int(data.get("state", State.IDLE)) as State

	var facing_data: Dictionary = data.get("facing_direction", {})
	enemy.facing_direction = Vector2(
		float(facing_data.get("x", 1.0)),
		float(facing_data.get("y", 0.0))
	)

	enemy.last_attacker_id = data.get("last_attacker_id", "")

	return enemy
