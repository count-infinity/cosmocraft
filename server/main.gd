extends Node

var game_server: GameServer

func _ready() -> void:
	print("=== Cosmocraft Server ===")
	print("Starting server...")

	game_server = GameServer.new()
	add_child(game_server)

	game_server.server_started.connect(_on_server_started)
	game_server.server_stopped.connect(_on_server_stopped)
	game_server.player_connected.connect(_on_player_connected)
	game_server.player_disconnected.connect(_on_player_disconnected)

func _on_server_started(port: int) -> void:
	print("Server listening on port %d" % port)
	print("Tick rate: %d ticks/second" % GameConstants.TICK_RATE)
	print("Waiting for connections...")

func _on_server_stopped() -> void:
	print("Server stopped.")

func _on_player_connected(player_id: String, player_name: String) -> void:
	print("+ Player joined: %s (%s)" % [player_name, player_id])
	print("  Total players: %d" % game_server.game_state.get_player_count())

func _on_player_disconnected(player_id: String) -> void:
	print("- Player left: %s" % player_id)
	print("  Total players: %d" % game_server.game_state.get_player_count())

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("Shutting down server...")
		if game_server:
			game_server.stop_server()
		get_tree().quit()
