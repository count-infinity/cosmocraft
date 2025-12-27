class_name HealthComponent
extends RefCounted
## Reusable health component for players and enemies.
## Handles HP, damage, healing, death state, and out-of-combat regeneration.


## Emitted when damage is taken
signal damaged(amount: float, source_id: String)

## Emitted when healing is received
signal healed(amount: float)

## Emitted when HP reaches zero
signal died(killer_id: String)

## Emitted when revived from death
signal revived


## Current health points
var current_hp: float = 100.0

## Maximum health points
var max_hp: float = 100.0

## Whether this entity is dead
var is_dead: bool = false

## Server time when last damage was taken (for out-of-combat detection)
var last_damage_time: float = 0.0

## Server time until which this entity is invulnerable
var invulnerable_until: float = 0.0


## Delay in seconds after last damage before regen starts
const OUT_OF_COMBAT_DELAY: float = 5.0


func _init(initial_max_hp: float = 100.0) -> void:
	max_hp = initial_max_hp
	current_hp = max_hp


## Take damage from a source. Returns actual damage taken.
## Will not deal damage if dead or invulnerable.
func take_damage(amount: float, current_time: float, source_id: String = "") -> float:
	if is_dead:
		return 0.0

	if is_invulnerable(current_time):
		return 0.0

	if amount <= 0.0:
		return 0.0

	var actual_damage := minf(amount, current_hp)
	current_hp -= actual_damage
	last_damage_time = current_time

	damaged.emit(actual_damage, source_id)

	if current_hp <= 0.0:
		current_hp = 0.0
		is_dead = true
		died.emit(source_id)

	return actual_damage


## Heal for an amount. Returns actual healing done.
## Will not heal if dead.
func heal(amount: float) -> float:
	if is_dead:
		return 0.0

	if amount <= 0.0:
		return 0.0

	var missing_hp := max_hp - current_hp
	var actual_heal := minf(amount, missing_hp)
	current_hp += actual_heal

	if actual_heal > 0.0:
		healed.emit(actual_heal)

	return actual_heal


## Process regeneration tick. Only regenerates when out of combat.
## regen_rate is HP per second.
func tick_regen(delta: float, regen_rate: float, current_time: float) -> void:
	if is_dead:
		return

	if not is_out_of_combat(current_time):
		return

	if regen_rate <= 0.0:
		return

	var regen_amount := regen_rate * delta
	heal(regen_amount)


## Check if enough time has passed since last damage for regen to start
func is_out_of_combat(current_time: float) -> bool:
	return current_time >= last_damage_time + OUT_OF_COMBAT_DELAY


## Set invulnerability for a duration
func set_invulnerable(duration: float, current_time: float) -> void:
	invulnerable_until = current_time + duration


## Check if currently invulnerable
func is_invulnerable(current_time: float) -> bool:
	return current_time < invulnerable_until


## Get HP as a percentage (0.0 to 1.0)
func get_hp_percent() -> float:
	if max_hp <= 0.0:
		return 0.0
	return current_hp / max_hp


## Revive from death with optional HP amount (default: full HP)
func revive(hp_amount: float = -1.0) -> void:
	if not is_dead:
		return

	is_dead = false
	if hp_amount < 0.0:
		current_hp = max_hp
	else:
		current_hp = clampf(hp_amount, 1.0, max_hp)

	revived.emit()


## Reset to full health (not for reviving - use revive() for that)
func reset() -> void:
	current_hp = max_hp
	is_dead = false
	last_damage_time = 0.0
	invulnerable_until = 0.0


## Set max HP and optionally adjust current HP proportionally
func set_max_hp(new_max: float, scale_current: bool = true) -> void:
	if new_max <= 0.0:
		new_max = 1.0

	if scale_current and max_hp > 0.0:
		var ratio := current_hp / max_hp
		max_hp = new_max
		current_hp = max_hp * ratio
	else:
		max_hp = new_max
		current_hp = minf(current_hp, max_hp)


## Serialize to dictionary
func to_dict() -> Dictionary:
	return {
		"current_hp": current_hp,
		"max_hp": max_hp,
		"is_dead": is_dead,
		"last_damage_time": last_damage_time,
		"invulnerable_until": invulnerable_until
	}


## Deserialize from dictionary
static func from_dict(data: Dictionary) -> RefCounted:
	var component: RefCounted = (load("res://shared/components/health_component.gd") as GDScript).new()
	component.current_hp = float(data.get("current_hp", 100.0))
	component.max_hp = float(data.get("max_hp", 100.0))
	component.is_dead = data.get("is_dead", false)
	component.last_damage_time = float(data.get("last_damage_time", 0.0))
	component.invulnerable_until = float(data.get("invulnerable_until", 0.0))
	return component


## Create a copy
func clone() -> RefCounted:
	var script: GDScript = load("res://shared/components/health_component.gd")
	var copy: RefCounted = script.new(max_hp)
	copy.current_hp = current_hp
	copy.is_dead = is_dead
	copy.last_damage_time = last_damage_time
	copy.invulnerable_until = invulnerable_until
	return copy
