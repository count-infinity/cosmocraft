class_name ClientConfig
extends RefCounted

var server_address: String = "localhost"
var server_port: int = GameConstants.DEFAULT_PORT
var player_name: String = "Player"

func get_websocket_url() -> String:
	return "ws://%s:%d" % [server_address, server_port]
