class_name PlayerInput
extends RefCounted

var sequence: int = 0

# Get current input state from keyboard/mouse
func capture(viewport: Viewport) -> Dictionary:
	sequence += 1

	# Get movement direction from WASD
	var move_direction := Vector2.ZERO
	if Input.is_action_pressed("move_up"):
		move_direction.y -= 1
	if Input.is_action_pressed("move_down"):
		move_direction.y += 1
	if Input.is_action_pressed("move_left"):
		move_direction.x -= 1
	if Input.is_action_pressed("move_right"):
		move_direction.x += 1

	# Normalize diagonal movement
	if move_direction.length() > 0:
		move_direction = move_direction.normalized()

	# Get aim angle from mouse position relative to screen center
	var mouse_pos := viewport.get_mouse_position()
	var screen_center := viewport.get_visible_rect().size / 2.0
	var aim_vector := mouse_pos - screen_center
	var aim_angle := aim_vector.angle() if aim_vector.length() > 0 else 0.0

	# Collect actions (future: shooting, abilities, etc.)
	var actions: Array = []

	return {
		"sequence": sequence,
		"move_direction": move_direction,
		"aim_angle": aim_angle,
		"actions": actions
	}

func get_current_sequence() -> int:
	return sequence
