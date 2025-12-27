class_name AttackController
extends RefCounted
## Handles attack input, cooldown tracking, and attack requests.
## Uses hold-to-attack mechanic: holding mouse button auto-attacks at weapon speed.


const CombatComponentScript = preload("res://shared/components/combat_component.gd")


## Emitted when an attack request should be sent to the server
signal attack_requested(aim_position: Vector2, attack_type: int)

## Emitted when attack state changes (for UI feedback)
signal attack_state_changed(is_attacking: bool, cooldown_percent: float)


## Local combat component for tracking cooldowns
var combat_component: CombatComponentScript

## Whether the attack button is currently held
var is_attack_held: bool = false

## Current aim position in world coordinates
var aim_position: Vector2 = Vector2.ZERO

## Whether attacks are currently enabled
var attacks_enabled: bool = true

## Current weapon type (for visual effects)
var current_weapon_type: int = ItemEnums.WeaponType.NONE

## Unarmed/default combat stats constants
const UNARMED_DAMAGE: float = 5.0
const UNARMED_SPEED: float = 1.0
const UNARMED_RANGE: float = 50.0
const UNARMED_ARC: float = 90.0


func _init() -> void:
	# Create with default unarmed stats
	combat_component = CombatComponentScript.new(
		UNARMED_DAMAGE,
		UNARMED_SPEED,
		UNARMED_RANGE,
		UNARMED_ARC
	)


## Process input event for attack detection
## Returns true if the event was consumed
func handle_input(event: InputEvent) -> bool:
	if not attacks_enabled:
		return false

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_attack_held = event.pressed
			return true

	return false


## Update each frame - handles hold-to-attack logic
func update(delta: float, current_aim_position: Vector2) -> void:
	aim_position = current_aim_position

	# Update cooldown
	combat_component.tick(delta)

	# Hold-to-attack: continuously attack while held and off cooldown
	if is_attack_held and combat_component.can_attack() and attacks_enabled:
		_request_attack()

	# Emit state change for UI
	attack_state_changed.emit(
		combat_component.is_attacking,
		combat_component.get_cooldown_percent()
	)


## Request an attack to be sent to the server
func _request_attack() -> void:
	var attack_type: int = combat_component.current_attack_type

	# Start local attack (for cooldown tracking)
	if combat_component.start_attack(attack_type, aim_position.normalized()):
		# Immediately complete the attack locally (server handles actual hit detection)
		combat_component.complete_attack()

		# Signal to send request to server
		attack_requested.emit(aim_position, attack_type)


## Configure weapon stats (called when weapon changes)
func configure_weapon(
	damage: float,
	speed: float,
	weapon_range: float,
	arc: float,
	attack_type: int,
	weapon_type: int = ItemEnums.WeaponType.NONE
) -> void:
	current_weapon_type = weapon_type

	# Map AttackTypes.Type (3 values) to CombatComponent.AttackType (2 values)
	# MELEE_ARC and MELEE_THRUST both map to MELEE, RANGED maps to RANGED
	var combat_attack_type: int
	if AttackTypes.is_ranged(attack_type):
		combat_attack_type = CombatComponentScript.AttackType.RANGED
	else:
		combat_attack_type = CombatComponentScript.AttackType.MELEE

	combat_component.configure_from_weapon(
		damage,
		speed,
		weapon_range,
		arc,
		combat_attack_type as CombatComponentScript.AttackType
	)


## Configure from an ItemDefinition
func configure_from_item(item: ItemDefinition) -> void:
	if item == null:
		# Reset to unarmed/default
		configure_weapon(
			UNARMED_DAMAGE,
			UNARMED_SPEED,
			UNARMED_RANGE,
			UNARMED_ARC,
			AttackTypes.Type.MELEE_ARC,
			ItemEnums.WeaponType.NONE
		)
		return

	var attack_type: int = AttackTypes.from_weapon_type(item.weapon_type)
	var weapon_range: float = item.attack_range if item.attack_range > 0 else UNARMED_RANGE
	var arc: float = item.attack_arc if item.attack_arc > 0 else UNARMED_ARC

	configure_weapon(
		float(item.base_damage),
		item.attack_speed,
		weapon_range,
		arc,
		attack_type,
		item.weapon_type
	)


## Get the effect type string for the current weapon (used by AttackEffect)
func get_effect_type() -> String:
	return AttackTypes.get_effect_type_for_weapon(current_weapon_type)


## Apply server-confirmed cooldown (for synchronization)
func apply_server_cooldown(cooldown: float) -> void:
	combat_component.attack_cooldown = cooldown


## Get current cooldown percentage for UI display
func get_cooldown_percent() -> float:
	return combat_component.get_cooldown_percent()


## Get remaining cooldown time in seconds
func get_cooldown_remaining() -> float:
	return combat_component.get_cooldown_remaining()


## Check if an attack can be performed
func can_attack() -> bool:
	return combat_component.can_attack() and attacks_enabled


## Check if movement should be paused (melee attack commitment)
func should_pause_movement() -> bool:
	return combat_component.should_pause_movement()


## Enable/disable attacks (e.g., when dead or in menu)
func set_attacks_enabled(enabled: bool) -> void:
	attacks_enabled = enabled
	if not enabled:
		is_attack_held = false


## Reset attack state (e.g., on respawn)
func reset() -> void:
	is_attack_held = false
	combat_component.reset()


## Check if attack is currently held
func is_holding_attack() -> bool:
	return is_attack_held
