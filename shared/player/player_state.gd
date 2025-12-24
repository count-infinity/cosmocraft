class_name PlayerState
extends RefCounted

var id: String = ""
var name: String = ""
var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var aim_angle: float = 0.0

func _init(player_id: String = "", player_name: String = "") -> void:
	id = player_id
	name = player_name

func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"position": {"x": position.x, "y": position.y},
		"velocity": {"x": velocity.x, "y": velocity.y},
		"aim_angle": aim_angle
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
	return state

func clone() -> PlayerState:
	var new_state := PlayerState.new(id, name)
	new_state.position = position
	new_state.velocity = velocity
	new_state.aim_angle = aim_angle
	return new_state

func apply_input(move_direction: Vector2, aim: float, delta: float) -> void:
	aim_angle = aim
	velocity = move_direction.normalized() * GameConstants.PLAYER_SPEED
	position += velocity * delta
	_clamp_to_world_bounds()

func _clamp_to_world_bounds() -> void:
	position.x = clampf(position.x, 0.0, GameConstants.WORLD_WIDTH)
	position.y = clampf(position.y, 0.0, GameConstants.WORLD_HEIGHT)
