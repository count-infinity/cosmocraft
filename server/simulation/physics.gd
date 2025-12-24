class_name ServerPhysics
extends RefCounted

# Apply input to a player and update their state
static func apply_player_input(player: PlayerState, move_direction: Vector2, aim_angle: float, delta: float) -> void:
	player.apply_input(move_direction, aim_angle, delta)

# Process all players for a single tick
static func tick(game_state: GameState, pending_inputs: Dictionary, delta: float) -> void:
	for player_id in game_state.players:
		var player: PlayerState = game_state.players[player_id]

		# Get pending input for this player, if any
		if pending_inputs.has(player_id):
			var input: Dictionary = pending_inputs[player_id]
			var move_dir: Vector2 = input.get("move_direction", Vector2.ZERO)
			var aim: float = input.get("aim_angle", 0.0)
			apply_player_input(player, move_dir, aim, delta)
		else:
			# No input this tick - player stops (or could add momentum here)
			player.velocity = Vector2.ZERO
