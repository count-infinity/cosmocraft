class_name CombatComponent
extends RefCounted
## Handles attack cooldowns, damage dealing, and attack state.
## This component is designed for composition with both players and enemies.


## Attack type enumeration
enum AttackType {
	MELEE = 0,
	RANGED = 1
}


## Emitted when an attack begins
signal attack_started(attack_type: AttackType, aim_direction: Vector2)

## Emitted when an attack animation/action completes
signal attack_completed()

## Emitted when attack cooldown reaches zero
signal cooldown_ready()


## Time remaining until next attack allowed (seconds)
var attack_cooldown: float = 0.0

## Whether currently performing an attack
var is_attacking: bool = false

## The type of attack currently being performed
var current_attack_type: AttackType = AttackType.MELEE


# Weapon stats (populated from equipped weapon)

## Base damage dealt per hit
var base_damage: float = 5.0

## Attacks per second (determines cooldown duration)
var attack_speed: float = 1.0

## Melee range or maximum ranged distance in pixels
var attack_range: float = 50.0

## Melee swing arc in degrees (0 = thrust/line attack, 90+ = arc swing)
var attack_arc: float = 90.0


## Duration of melee attack pause (brief stop during swing)
const MELEE_PAUSE_DURATION: float = 0.15


func _init(
	damage: float = 5.0,
	speed: float = 1.0,
	attack_range_val: float = 50.0,
	arc: float = 90.0
) -> void:
	base_damage = damage
	attack_speed = speed
	attack_range = attack_range_val
	attack_arc = arc


## Check if an attack can be started (not on cooldown)
func can_attack() -> bool:
	return attack_cooldown <= 0.0 and not is_attacking


## Attempt to start an attack. Returns true if attack started.
func start_attack(attack_type: AttackType, aim_direction: Vector2 = Vector2.RIGHT) -> bool:
	if not can_attack():
		return false

	is_attacking = true
	current_attack_type = attack_type

	# Set cooldown based on attack speed
	if attack_speed > 0.0:
		attack_cooldown = 1.0 / attack_speed
	else:
		attack_cooldown = 1.0  # Default 1 second if speed is invalid

	attack_started.emit(attack_type, aim_direction)
	return true


## Complete the current attack (called when animation finishes or immediately for instant attacks)
func complete_attack() -> void:
	if is_attacking:
		is_attacking = false
		attack_completed.emit()


## Update cooldowns each frame. Call this in _process or physics tick.
func tick(delta: float) -> void:
	if attack_cooldown > 0.0:
		var was_on_cooldown := attack_cooldown > 0.0
		attack_cooldown -= delta

		if attack_cooldown <= 0.0:
			attack_cooldown = 0.0
			if was_on_cooldown:
				cooldown_ready.emit()

	# Auto-complete attacks after a brief period (for instant attacks)
	# This can be overridden by explicit complete_attack() calls
	if is_attacking and attack_cooldown <= 0.0:
		complete_attack()


## Get remaining cooldown time in seconds
func get_cooldown_remaining() -> float:
	return maxf(attack_cooldown, 0.0)


## Get cooldown as a percentage (0.0 = ready, 1.0 = just started cooldown)
func get_cooldown_percent() -> float:
	if attack_speed <= 0.0:
		return 0.0

	var cooldown_duration: float = 1.0 / attack_speed
	if cooldown_duration <= 0.0:
		return 0.0

	return clampf(attack_cooldown / cooldown_duration, 0.0, 1.0)


## Check if this is a melee-type attack
func is_melee() -> bool:
	return current_attack_type == AttackType.MELEE


## Check if this is a ranged-type attack
func is_ranged() -> bool:
	return current_attack_type == AttackType.RANGED


## Check if movement should be paused (melee attack commitment)
func should_pause_movement() -> bool:
	# Only melee attacks pause movement, and only during the initial attack phase
	if not is_attacking:
		return false

	if current_attack_type != AttackType.MELEE:
		return false

	# Pause during the first part of the attack
	return attack_cooldown > (1.0 / attack_speed) - MELEE_PAUSE_DURATION


## Configure weapon stats from a weapon definition
func configure_from_weapon(
	damage: float,
	speed: float,
	weapon_range: float,
	arc: float,
	weapon_type: AttackType
) -> void:
	base_damage = damage
	attack_speed = speed
	attack_range = weapon_range
	attack_arc = arc
	current_attack_type = weapon_type


## Reset cooldown and attack state
func reset() -> void:
	attack_cooldown = 0.0
	is_attacking = false


## Serialize to dictionary for network transmission
func to_dict() -> Dictionary:
	return {
		"attack_cooldown": attack_cooldown,
		"is_attacking": is_attacking,
		"current_attack_type": current_attack_type,
		"base_damage": base_damage,
		"attack_speed": attack_speed,
		"attack_range": attack_range,
		"attack_arc": attack_arc
	}


## Deserialize from dictionary
static func from_dict(data: Dictionary) -> RefCounted:
	var CombatComponentScript: GDScript = load("res://shared/components/combat_component.gd")
	var component: RefCounted = CombatComponentScript.new()
	component.attack_cooldown = float(data.get("attack_cooldown", 0.0))
	component.is_attacking = data.get("is_attacking", false)
	component.current_attack_type = int(data.get("current_attack_type", AttackType.MELEE)) as AttackType
	component.base_damage = float(data.get("base_damage", 5.0))
	component.attack_speed = float(data.get("attack_speed", 1.0))
	component.attack_range = float(data.get("attack_range", 50.0))
	component.attack_arc = float(data.get("attack_arc", 90.0))
	return component


## Create a deep copy
func clone() -> RefCounted:
	var CombatComponentScript: GDScript = load("res://shared/components/combat_component.gd")
	var copy: RefCounted = CombatComponentScript.new(
		base_damage, attack_speed, attack_range, attack_arc
	)
	copy.attack_cooldown = attack_cooldown
	copy.is_attacking = is_attacking
	copy.current_attack_type = current_attack_type
	return copy
