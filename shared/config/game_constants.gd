class_name GameConstants
extends RefCounted

# Network
const TICK_RATE: int = 20  # Server ticks per second
const TICK_INTERVAL: float = 1.0 / TICK_RATE  # 50ms per tick
const DEFAULT_PORT: int = 9050

# World
const TILE_SIZE: int = 32  # Tile size in pixels
const PLANET_SIZE_TILES: int = 8000  # Planet size in tiles (8000x8000)
const WORLD_WIDTH: float = PLANET_SIZE_TILES * TILE_SIZE  # 256000 pixels
const WORLD_HEIGHT: float = PLANET_SIZE_TILES * TILE_SIZE  # 256000 pixels

# Player
const PLAYER_SIZE: float = 32.0  # Player avatar size in pixels (1 tile)
const PLAYER_SPEED: float = 200.0  # Pixels per second
const PLAYER_SPAWN_X: float = 512.0  # Spawn position (chunk 0,0 area - 16 tiles in)
const PLAYER_SPAWN_Y: float = 512.0

# Client-side prediction
const INTERPOLATION_DELAY: float = 0.1  # 100ms behind for smooth remote players
const MAX_INPUT_BUFFER_SIZE: int = 64  # Max stored inputs for reconciliation
const RECONCILIATION_THRESHOLD: float = 1.0  # Pixels - snap if off by more than this
