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
