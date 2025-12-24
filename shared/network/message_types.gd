class_name MessageTypes
extends RefCounted

# Client -> Server
const CONNECT_REQUEST: String = "connect_request"
const PLAYER_INPUT: String = "player_input"
const PING: String = "ping"
const DISCONNECT: String = "disconnect"

# Server -> Client
const CONNECT_RESPONSE: String = "connect_response"
const GAME_STATE: String = "game_state"
const STATE_DELTA: String = "state_delta"
const PLAYER_JOINED: String = "player_joined"
const PLAYER_LEFT: String = "player_left"
const PONG: String = "pong"
const ERROR: String = "error"
