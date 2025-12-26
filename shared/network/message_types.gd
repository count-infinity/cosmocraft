class_name MessageTypes
extends RefCounted

# Client -> Server
const CONNECT_REQUEST: String = "connect_request"
const PLAYER_INPUT: String = "player_input"
const PING: String = "ping"
const DISCONNECT: String = "disconnect"
const CHUNK_REQUEST: String = "chunk_request"  # Request chunks around position
const TILE_MODIFY: String = "tile_modify"  # Request to modify a tile

# Server -> Client
const CONNECT_RESPONSE: String = "connect_response"
const GAME_STATE: String = "game_state"
const STATE_DELTA: String = "state_delta"
const PLAYER_JOINED: String = "player_joined"
const PLAYER_LEFT: String = "player_left"
const PONG: String = "pong"
const ERROR: String = "error"
const CHUNK_DATA: String = "chunk_data"  # Full chunk data
const CHUNK_DELTA: String = "chunk_delta"  # Tile changes within a chunk
const PLANET_INFO: String = "planet_info"  # Planet seed and size info

# ===== Inventory Messages =====

# Client -> Server
const ITEM_PICKUP_REQUEST: String = "item_pickup_request"  # Request to pick up item
const ITEM_DROP_REQUEST: String = "item_drop_request"  # Request to drop item
const ITEM_USE_REQUEST: String = "item_use_request"  # Use consumable/tool
const EQUIP_REQUEST: String = "equip_request"  # Equip item from inventory
const UNEQUIP_REQUEST: String = "unequip_request"  # Unequip item to inventory

# Server -> Client
const INVENTORY_SYNC: String = "inventory_sync"  # Full inventory state (on join)
const INVENTORY_UPDATE: String = "inventory_update"  # Delta changes to inventory
const EQUIPMENT_UPDATE: String = "equipment_update"  # Equipment slot changes
const ITEM_PICKUP_RESPONSE: String = "item_pickup_response"  # Server confirms/denies pickup
const ITEM_DROP_RESPONSE: String = "item_drop_response"  # Server confirms drop
const STATS_UPDATE: String = "stats_update"  # Player stats changed
