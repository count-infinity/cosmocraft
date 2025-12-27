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

# Hitbox sizes
const PLAYER_HITBOX_RADIUS: float = 16.0  # Player collision radius (half of PLAYER_SIZE)
const DEFAULT_ENEMY_HITBOX_RADIUS: float = 16.0  # Default enemy collision radius

# Factions (matches TargetData.Faction enum)
const FACTION_NEUTRAL: int = 0
const FACTION_PLAYER: int = 1
const FACTION_ENEMY: int = 2

# Loot System
const LOOT_PROTECTION_DURATION: float = 30.0  # Seconds only owner can pick up
const LOOT_DESPAWN_TIME: float = 300.0  # 5 minutes
const LOOT_PICKUP_RADIUS: float = 48.0  # Pixels
const LOOT_DROP_SPREAD_RADIUS: float = 32.0  # Pixels between multiple drops
const LOOT_MIN_DROP_SPACING: float = 16.0  # Minimum spacing for variance
const LOOT_DESPAWN_CHECK_INTERVAL: float = 10.0  # How often to check for despawns

# Quality System
const QUALITY_MIN: float = 0.6  # Minimum item quality (Poor)
const QUALITY_MAX: float = 1.25  # Maximum item quality (Legendary)
const QUALITY_NORMAL: float = 1.0  # Standard item quality
