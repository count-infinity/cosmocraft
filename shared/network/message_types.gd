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

# ===== Ground Item Messages =====

# Server -> Client
const GROUND_ITEM_SPAWNED: String = "ground_item_spawned"  # New item appeared on ground
const GROUND_ITEM_REMOVED: String = "ground_item_removed"  # Item picked up or despawned
const GROUND_ITEMS_SYNC: String = "ground_items_sync"  # Full sync of nearby ground items

# ===== Crafting Messages =====

# Client -> Server
const CRAFT_REQUEST: String = "craft_request"  # Request to craft a recipe

# Server -> Client
const CRAFT_RESPONSE: String = "craft_response"  # Crafting result (success/failure)

# ===== Combat Messages =====

# Server -> Client (all combat is server-authoritative)
const PLAYER_DIED: String = "player_died"  # Player death notification
const PLAYER_RESPAWN: String = "player_respawn"  # Player respawn notification
const CORPSE_SPAWNED: String = "corpse_spawned"  # New player corpse appeared
const CORPSE_RECOVERED: String = "corpse_recovered"  # Player recovered their corpse
const CORPSE_EXPIRED: String = "corpse_expired"  # Corpse despawned (timer ran out)
const HEALTH_UPDATE: String = "health_update"  # Player HP changed

# Client -> Server
const CORPSE_RECOVER_REQUEST: String = "corpse_recover_request"  # Request to recover corpse items
const ATTACK_REQUEST: String = "attack_request"  # Request to attack in aim direction

# Server -> Client (attack responses)
const ATTACK_RESULT: String = "attack_result"  # Server confirms attack hit/miss/damage
const ENTITY_DAMAGED: String = "entity_damaged"  # Broadcast damage to entity (player or enemy)
const ENTITY_DIED: String = "entity_died"  # Broadcast entity death

# ===== Enemy Messages =====

# Server -> Client
const ENEMY_SPAWN: String = "enemy_spawn"  # Server tells client about new enemy
const ENEMY_UPDATE: String = "enemy_update"  # Server sends enemy state changes
const ENEMY_DEATH: String = "enemy_death"  # Server tells client enemy died
const ENEMY_DESPAWN: String = "enemy_despawn"  # Server removes enemy from world
