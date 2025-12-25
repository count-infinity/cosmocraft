extends Node

var game_client: GameClient
var connect_screen: ConnectScreen
var hud: HUD
var camera: Camera2D
var pause_menu: PauseMenu

var ConnectScreenScene: PackedScene = preload("res://client/ui/connect_screen.tscn")
var HUDScene: PackedScene = preload("res://client/ui/hud.tscn")
var PauseMenuScene: PackedScene = preload("res://client/ui/pause_menu.tscn")

func _ready() -> void:
	print("=== Cosmocraft Client ===")

	# Create game client
	game_client = GameClient.new()
	add_child(game_client)

	game_client.connected.connect(_on_connected)
	game_client.disconnected.connect(_on_disconnected)
	game_client.connection_failed.connect(_on_connection_failed)
	game_client.chunk_manager_ready.connect(_on_chunk_manager_ready)

	# Show connect screen
	_show_connect_screen()

func _show_connect_screen() -> void:
	connect_screen = ConnectScreenScene.instantiate()
	connect_screen.connect_requested.connect(_on_connect_requested)
	add_child(connect_screen)

func _on_connect_requested(address: String, port: int, player_name: String) -> void:
	game_client.connect_to_server(address, port, player_name)

func _on_connected(_player_id: String) -> void:
	# Hide connect screen
	if connect_screen:
		connect_screen.queue_free()
		connect_screen = null

	# Create camera that follows local player
	camera = Camera2D.new()
	camera.position = Vector2(GameConstants.PLAYER_SPAWN_X, GameConstants.PLAYER_SPAWN_Y)
	add_child(camera)
	camera.make_current()

	# Show HUD
	hud = HUDScene.instantiate()
	add_child(hud)

func _on_disconnected() -> void:
	print("Disconnected from server")
	_cleanup()
	_show_connect_screen()
	connect_screen.set_status("Disconnected from server")
	connect_screen.enable_connect()

func _on_connection_failed(reason: String) -> void:
	print("Connection failed: %s" % reason)
	connect_screen.set_status("Failed: %s" % reason)
	connect_screen.enable_connect()

func _cleanup() -> void:
	if pause_menu:
		pause_menu.queue_free()
		pause_menu = null

	if hud:
		hud.queue_free()
		hud = null

	if camera:
		camera.queue_free()
		camera = null

func _process(_delta: float) -> void:
	if game_client and game_client.is_connected_to_server():
		# Update camera to follow local player
		if game_client.local_player and camera:
			camera.position = game_client.local_player.position

		# Update HUD
		if hud:
			var player_count := 1 + game_client.remote_players.size()
			hud.update_player_count(player_count)

			if game_client.local_player:
				hud.update_position(game_client.local_player.position)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if game_client:
			game_client.disconnect_from_server()
		get_tree().quit()


func _input(event: InputEvent) -> void:
	# Only handle ESC when connected and not already paused
	if event.is_action_pressed("ui_cancel"):
		if game_client and game_client.is_connected_to_server() and pause_menu == null:
			_show_pause_menu()
			get_viewport().set_input_as_handled()


func _show_pause_menu() -> void:
	pause_menu = PauseMenuScene.instantiate()
	pause_menu.resume_requested.connect(_on_resume)
	pause_menu.quit_requested.connect(_on_quit)
	add_child(pause_menu)
	get_tree().paused = true


func _on_resume() -> void:
	get_tree().paused = false
	if pause_menu:
		pause_menu.queue_free()
		pause_menu = null


func _on_quit() -> void:
	get_tree().paused = false
	if game_client:
		game_client.disconnect_from_server()
	get_tree().quit()


func _on_chunk_manager_ready(chunk_manager: ChunkManager) -> void:
	if hud:
		hud.initialize_minimap(chunk_manager)
