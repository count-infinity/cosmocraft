class_name GameLoop
extends RefCounted

signal tick_completed(tick: int)

var game_state: GameState
var tick_interval: float = GameConstants.TICK_INTERVAL
var accumulated_time: float = 0.0

# Pending inputs per player (cleared after each tick)
var pending_inputs: Dictionary = {}

func _init(state: GameState) -> void:
	game_state = state

# Queue an input to be processed on the next tick
func queue_input(player_id: String, input_data: Dictionary) -> void:
	# Store the latest input for this player (overwrites previous if multiple per tick)
	pending_inputs[player_id] = input_data

# Called every frame with delta time
# Returns true if a tick was processed
func update(delta: float) -> bool:
	accumulated_time += delta

	var ticked := false
	while accumulated_time >= tick_interval:
		_process_tick()
		accumulated_time -= tick_interval
		ticked = true

	return ticked

func _process_tick() -> void:
	# Process physics for all players
	ServerPhysics.tick(game_state, pending_inputs, tick_interval)

	# Clear pending inputs
	pending_inputs.clear()

	# Increment tick counter
	game_state.increment_tick()

	# Emit signal for broadcasting
	tick_completed.emit(game_state.current_tick)

# Force process a tick immediately (for testing)
func force_tick() -> void:
	_process_tick()
