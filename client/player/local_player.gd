class_name LocalPlayer
extends Node2D

const AttackControllerScript = preload("res://client/player/attack_controller.gd")

signal input_generated(input_data: Dictionary)
signal attack_requested(aim_position: Vector2, attack_type: int)

var player_id: String = ""
var player_name: String = ""

var player_input: PlayerInput
var prediction: ClientPrediction
var attack_controller: AttackControllerScript

# Reference to chunk manager for collision prediction
var chunk_manager: ChunkManager = null

# Visual elements
var body: ColorRect
var aim_indicator: Polygon2D

# Current state
var current_position: Vector2 = Vector2.ZERO
var current_aim_angle: float = 0.0
var current_aim_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	player_input = PlayerInput.new()
	prediction = ClientPrediction.new()
	attack_controller = AttackControllerScript.new()
	_create_visuals()

	# Connect attack controller signals
	attack_controller.attack_requested.connect(_on_attack_requested)

func _create_visuals() -> void:
	var size := GameConstants.PLAYER_SIZE
	var half_size := size / 2.0

	# Body - blue square
	body = ColorRect.new()
	body.size = Vector2(size, size)
	body.position = Vector2(-half_size, -half_size)  # Center it
	body.color = Color(0.2, 0.4, 0.9)  # Blue
	add_child(body)

	# Aim indicator - triangle pointing in aim direction (scaled to player size)
	var indicator_length := size * 0.75
	var indicator_base := size * 0.25
	aim_indicator = Polygon2D.new()
	aim_indicator.polygon = PackedVector2Array([
		Vector2(indicator_length, 0),
		Vector2(indicator_length * 0.5, -indicator_base),
		Vector2(indicator_length * 0.5, indicator_base)
	])
	aim_indicator.color = Color(0.9, 0.9, 0.2)  # Yellow
	add_child(aim_indicator)

func initialize(id: String, name: String, pos: Vector2) -> void:
	player_id = id
	player_name = name
	current_position = pos
	position = pos

func _process(delta: float) -> void:
	# Capture and send input
	var input_data := player_input.capture(get_viewport())

	# Apply input locally for prediction
	_apply_input_locally(input_data, delta)

	# Store for reconciliation
	prediction.store_input(input_data["sequence"], input_data, current_position)

	# Emit for network send
	input_generated.emit(input_data)

	# Update attack controller with current aim position
	current_aim_position = _get_world_aim_position()
	attack_controller.update(delta, current_aim_position)

	# Update visuals
	position = current_position
	aim_indicator.rotation = current_aim_angle


func _unhandled_input(event: InputEvent) -> void:
	# Pass input events to attack controller
	if attack_controller.handle_input(event):
		get_viewport().set_input_as_handled()


## Get the world position the player is aiming at
func _get_world_aim_position() -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return current_position + Vector2.RIGHT * 100.0

	var mouse_pos := viewport.get_mouse_position()
	var camera := viewport.get_camera_2d()
	if camera != null:
		# Convert screen position to world position
		var camera_offset := camera.get_screen_center_position() - viewport.get_visible_rect().size / 2.0
		return mouse_pos + camera_offset
	else:
		# No camera, assume mouse position is world position offset from player
		return current_position + (mouse_pos - viewport.get_visible_rect().size / 2.0)


## Called when attack controller wants to send an attack request
func _on_attack_requested(aim_position: Vector2, attack_type: int) -> void:
	attack_requested.emit(aim_position, attack_type)

func _apply_input_locally(input_data: Dictionary, delta: float) -> void:
	var move_dir: Vector2 = input_data.get("move_direction", Vector2.ZERO)
	current_aim_angle = input_data.get("aim_angle", 0.0)

	if move_dir.length() > 0:
		var velocity := move_dir.normalized() * GameConstants.PLAYER_SPEED
		var movement := velocity * delta

		# Apply movement with collision checking if chunk manager available
		if chunk_manager != null:
			current_position = CollisionHelper.apply_movement_with_collision(
				current_position, movement, chunk_manager
			)
		else:
			current_position += movement

		_clamp_position()

func _clamp_position() -> void:
	current_position.x = clampf(current_position.x, 0.0, GameConstants.WORLD_WIDTH)
	current_position.y = clampf(current_position.y, 0.0, GameConstants.WORLD_HEIGHT)

func apply_server_state(server_position: Vector2, server_aim: float, last_processed_input: int, delta: float) -> void:
	# Reconcile with server
	current_position = prediction.reconcile(server_position, last_processed_input, delta)
	# Note: We keep our local aim angle since it's purely visual
