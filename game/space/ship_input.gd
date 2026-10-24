class_name ShipInput
extends RefCounted
## Where a ship's controls come from. This one reads the keyboard and mouse;
## the autopilot overrides it.

var _world: Node2D


func _init(world: Node2D) -> void:
	_world = world


func get_move() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func get_aim_point() -> Vector2:
	return _world.get_global_mouse_position()


func is_firing() -> bool:
	return Input.is_action_pressed("fire")


func consume_dash() -> bool:
	return Input.is_action_just_pressed("dash")


func consume_kindle() -> bool:
	return Input.is_action_just_pressed("kindle")
