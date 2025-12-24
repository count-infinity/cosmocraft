class_name ServerConfig
extends RefCounted

# Network settings
var port: int = GameConstants.DEFAULT_PORT
var max_players: int = 32

# Gameplay settings
var world_width: float = GameConstants.WORLD_WIDTH
var world_height: float = GameConstants.WORLD_HEIGHT

# Can be extended with command line parsing later
static func from_args() -> ServerConfig:
	var config := ServerConfig.new()

	var args := OS.get_cmdline_args()
	for i in range(args.size()):
		var arg := args[i]
		if arg == "--port" and i + 1 < args.size():
			config.port = int(args[i + 1])
		elif arg == "--max-players" and i + 1 < args.size():
			config.max_players = int(args[i + 1])

	return config
