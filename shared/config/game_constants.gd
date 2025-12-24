class_name GameConstants
extends RefCounted

# Network
const TICK_RATE: int = 20  # Server ticks per second
const TICK_INTERVAL: float = 1.0 / TICK_RATE  # 50ms per tick
const DEFAULT_PORT: int = 9050

# Movement
const PLAYER_SPEED: float = 200.0  # Pixels per second

# World bounds (test world)
const WORLD_WIDTH: float = 1920.0
const WORLD_HEIGHT: float = 1080.0

# Client-side prediction
const INTERPOLATION_DELAY: float = 0.1  # 100ms behind for smooth remote players
const MAX_INPUT_BUFFER_SIZE: int = 64  # Max stored inputs for reconciliation
const RECONCILIATION_THRESHOLD: float = 1.0  # Pixels - snap if off by more than this
