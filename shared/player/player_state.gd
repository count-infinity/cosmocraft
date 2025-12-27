class_name PlayerState
extends RefCounted

var id: String = ""
var name: String = ""
var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var aim_angle: float = 0.0

# Inventory and equipment data (serialized form)
var inventory: Dictionary = {}
var equipment: Dictionary = {}
var hotbar: Dictionary = {}
var stats: Dictionary = {}
var skills: Dictionary = {}

# Combat state
var current_hp: float = 100.0
var max_hp: float = 100.0
var is_dead: bool = false
var last_damage_time: float = 0.0
var invulnerable_until: float = 0.0

func _init(player_id: String = "", player_name: String = "") -> void:
	id = player_id
	name = player_name

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"position": {"x": position.x, "y": position.y},
		"velocity": {"x": velocity.x, "y": velocity.y},
		"aim_angle": aim_angle,
		"inventory": inventory,
		"equipment": equipment,
		"hotbar": hotbar,
		"stats": stats,
		"skills": skills,
		"current_hp": current_hp,
		"max_hp": max_hp,
		"is_dead": is_dead,
		"last_damage_time": last_damage_time,
		"invulnerable_until": invulnerable_until
	}

static func from_dict(data: Dictionary) -> PlayerState:
	var state := PlayerState.new()
	state.id = data.get("id", "")
	state.name = data.get("name", "")

	var pos = data.get("position", {})
	state.position = Vector2(pos.get("x", 0.0), pos.get("y", 0.0))

	var vel = data.get("velocity", {})
	state.velocity = Vector2(vel.get("x", 0.0), vel.get("y", 0.0))

	state.aim_angle = data.get("aim_angle", 0.0)

	# Load inventory data (backwards compatible - missing fields default to empty)
	state.inventory = data.get("inventory", {})
	state.equipment = data.get("equipment", {})
	state.hotbar = data.get("hotbar", {})
	state.stats = data.get("stats", {})
	state.skills = data.get("skills", {})

	# Load combat state (backwards compatible - missing fields use defaults)
	state.current_hp = float(data.get("current_hp", 100.0))
	state.max_hp = float(data.get("max_hp", 100.0))
	state.is_dead = data.get("is_dead", false)
	state.last_damage_time = float(data.get("last_damage_time", 0.0))
	state.invulnerable_until = float(data.get("invulnerable_until", 0.0))

	return state

func clone() -> PlayerState:
	var new_state := PlayerState.new(id, name)
	new_state.position = position
	new_state.velocity = velocity
	new_state.aim_angle = aim_angle
	# Deep copy inventory data
	new_state.inventory = inventory.duplicate(true)
	new_state.equipment = equipment.duplicate(true)
	new_state.hotbar = hotbar.duplicate(true)
	new_state.stats = stats.duplicate(true)
	new_state.skills = skills.duplicate(true)
	# Copy combat state
	new_state.current_hp = current_hp
	new_state.max_hp = max_hp
	new_state.is_dead = is_dead
	new_state.last_damage_time = last_damage_time
	new_state.invulnerable_until = invulnerable_until
	return new_state

func apply_input(move_direction: Vector2, aim: float, delta: float) -> void:
	aim_angle = aim
	velocity = move_direction.normalized() * GameConstants.PLAYER_SPEED
	position += velocity * delta
	_clamp_to_world_bounds()

func _clamp_to_world_bounds() -> void:
	position.x = clampf(position.x, 0.0, GameConstants.WORLD_WIDTH)
	position.y = clampf(position.y, 0.0, GameConstants.WORLD_HEIGHT)
