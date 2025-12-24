class_name LocalPlayer
extends Node2D

signal input_generated(input_data: Dictionary)

var player_id: String = ""
var player_name: String = ""

var player_input: PlayerInput
var prediction: ClientPrediction

# Visual elements
var body: ColorRect
var aim_indicator: Polygon2D

# Current state
var current_position: Vector2 = Vector2.ZERO
var current_aim_angle: float = 0.0

func _ready() -> void:
	player_input = PlayerInput.new()
	prediction = ClientPrediction.new()
	_create_visuals()

func _create_visuals() -> void:
	# Body - blue square
	body = ColorRect.new()
	body.size = Vector2(32, 32)
	body.position = Vector2(-16, -16)  # Center it
	body.color = Color(0.2, 0.4, 0.9)  # Blue
	add_child(body)

	# Aim indicator - triangle pointing in aim direction
	aim_indicator = Polygon2D.new()
	aim_indicator.polygon = PackedVector2Array([
		Vector2(20, 0),
		Vector2(10, -6),
		Vector2(10, 6)
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

	# Update visuals
	position = current_position
	aim_indicator.rotation = current_aim_angle

func _apply_input_locally(input_data: Dictionary, delta: float) -> void:
	var move_dir: Vector2 = input_data.get("move_direction", Vector2.ZERO)
	current_aim_angle = input_data.get("aim_angle", 0.0)

	if move_dir.length() > 0:
		var velocity := move_dir.normalized() * GameConstants.PLAYER_SPEED
		current_position += velocity * delta
		_clamp_position()

func _clamp_position() -> void:
	current_position.x = clampf(current_position.x, 0.0, GameConstants.WORLD_WIDTH)
	current_position.y = clampf(current_position.y, 0.0, GameConstants.WORLD_HEIGHT)

func apply_server_state(server_position: Vector2, server_aim: float, last_processed_input: int, delta: float) -> void:
	# Reconcile with server
	current_position = prediction.reconcile(server_position, last_processed_input, delta)
	# Note: We keep our local aim angle since it's purely visual
