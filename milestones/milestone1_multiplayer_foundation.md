# Milestone 1: Multiplayer Foundation

## Goal
A browser client connects to a native server. Multiple players can join, see each other, and move around a test world with smooth 360° movement and mouse aiming. All movement is server-authoritative with client-side prediction.

---

## Success Criteria
- [ ] Server runs as native PC application
- [ ] Client runs in browser (HTML5 export)
- [ ] Multiple clients can connect to same server
- [ ] Players see each other in real-time
- [ ] Movement is smooth (client-side prediction)
- [ ] 360° movement with mouse aiming
- [ ] Player disconnection is handled gracefully
- [ ] Unit tests pass for core logic

---

## Architecture Overview

```
┌─────────────────┐         WebSocket          ┌─────────────────┐
│  Browser Client │◄──────────────────────────►│   Game Server   │
│    (HTML5)      │         JSON msgs          │   (Native PC)   │
└─────────────────┘                            └─────────────────┘
        │                                              │
        ▼                                              ▼
┌─────────────────┐                            ┌─────────────────┐
│ Client-side     │                            │ Authoritative   │
│ Prediction      │                            │ Game State      │
│ + Interpolation │                            │ + Validation    │
└─────────────────┘                            └─────────────────┘
```

---

## Network Protocol

### Message Format (JSON)
All messages follow this structure:
```json
{
  "type": "message_type",
  "data": { ... },
  "timestamp": 1234567890
}
```

### Client → Server Messages

#### `connect_request`
Sent when client wants to join.
```json
{
  "type": "connect_request",
  "data": {
    "player_name": "PlayerOne"
  }
}
```

#### `player_input`
Sent every frame with player's current input state.
```json
{
  "type": "player_input",
  "data": {
    "sequence": 12345,
    "move_direction": { "x": 0.707, "y": 0.707 },
    "aim_angle": 1.57,
    "actions": []
  }
}
```

#### `ping`
For latency measurement.
```json
{
  "type": "ping",
  "data": {
    "client_time": 1234567890
  }
}
```

### Server → Client Messages

#### `connect_response`
Response to connect request.
```json
{
  "type": "connect_response",
  "data": {
    "success": true,
    "player_id": "uuid-here",
    "server_tick": 1000,
    "tick_rate": 20
  }
}
```

#### `game_state`
Full state snapshot (sent periodically or on connect).
```json
{
  "type": "game_state",
  "data": {
    "tick": 1000,
    "players": {
      "uuid-1": {
        "id": "uuid-1",
        "name": "PlayerOne",
        "position": { "x": 100, "y": 200 },
        "velocity": { "x": 0, "y": 0 },
        "aim_angle": 1.57
      }
    }
  }
}
```

#### `state_delta`
Incremental update (sent every tick).
```json
{
  "type": "state_delta",
  "data": {
    "tick": 1001,
    "last_processed_input": 12345,
    "players": {
      "uuid-1": {
        "position": { "x": 105, "y": 205 },
        "velocity": { "x": 100, "y": 100 },
        "aim_angle": 1.57
      }
    }
  }
}
```

#### `player_joined`
Broadcast when new player connects.
```json
{
  "type": "player_joined",
  "data": {
    "player_id": "uuid-2",
    "name": "PlayerTwo",
    "position": { "x": 0, "y": 0 }
  }
}
```

#### `player_left`
Broadcast when player disconnects.
```json
{
  "type": "player_left",
  "data": {
    "player_id": "uuid-2"
  }
}
```

#### `pong`
Response to ping.
```json
{
  "type": "pong",
  "data": {
    "client_time": 1234567890,
    "server_time": 1234567895
  }
}
```

---

## Server Implementation

### Directory Structure
```
server/
├── main.gd                 # Entry point, starts server
├── game_server.gd          # WebSocket server, connection handling
├── game_state.gd           # Authoritative world state
├── player_state.gd         # Player data class
├── network/
│   ├── message_handler.gd  # Parse and route incoming messages
│   ├── message_types.gd    # Constants for message types
│   └── serialization.gd    # JSON encode/decode helpers
├── simulation/
│   ├── game_loop.gd        # Fixed timestep tick loop
│   └── physics.gd          # Movement physics calculations
└── config/
    └── server_config.gd    # Tick rate, port, etc.
```

### Core Components

#### GameServer (`game_server.gd`)
- Listens on configurable port (default 9050)
- Accepts WebSocket connections
- Assigns unique IDs to players
- Routes messages to handler
- Broadcasts state updates

#### GameState (`game_state.gd`)
- Dictionary of all players by ID
- Add/remove players
- Update player states
- Generate full snapshot or delta

#### GameLoop (`game_loop.gd`)
- Fixed 20 tick/second (50ms per tick)
- Process all pending player inputs
- Update physics/positions
- Broadcast state delta to all clients

#### Physics (`physics.gd`)
- Apply movement from input direction
- Clamp to world boundaries
- Calculate new positions
- Collision detection (future)

---

## Client Implementation

### Directory Structure
```
client/
├── main.gd                 # Entry point
├── game_client.gd          # WebSocket client, server communication
├── network/
│   ├── message_handler.gd  # Handle incoming server messages
│   ├── message_types.gd    # Constants (shared with server)
│   └── serialization.gd    # JSON helpers (shared with server)
├── player/
│   ├── local_player.gd     # Player we control
│   ├── remote_player.gd    # Other players (interpolated)
│   ├── player_input.gd     # Capture keyboard/mouse input
│   └── prediction.gd       # Client-side prediction logic
├── world/
│   └── test_world.gd       # Simple bounded test area
├── ui/
│   ├── connect_screen.gd   # Server address input, connect button
│   └── hud.gd              # Basic HUD (player count, ping)
└── config/
    └── client_config.gd    # Server address, etc.
```

### Core Components

#### GameClient (`game_client.gd`)
- Connect to server via WebSocket
- Send player input every frame
- Receive and apply state updates
- Handle connection/disconnection

#### LocalPlayer (`local_player.gd`)
- WASD movement input (normalized for 360°)
- Mouse position → aim angle
- Client-side prediction:
  - Apply input immediately (feels responsive)
  - Store input history with sequence numbers
  - On server update, reconcile: replay un-acked inputs

#### RemotePlayer (`remote_player.gd`)
- Interpolate between received positions
- Smooth movement (not teleporting)
- Show aim direction

#### Prediction (`prediction.gd`)
- Input buffer (sequence → input data)
- On server state received:
  - Discard inputs older than `last_processed_input`
  - If position mismatch, reset to server position
  - Replay newer inputs to get predicted position

---

## Client-Side Prediction Detail

### The Problem
Network latency causes delay between input and seeing result. Without prediction, movement feels sluggish.

### The Solution
1. **Apply input immediately** on client (optimistic)
2. **Send input to server** with sequence number
3. **Server processes input**, includes `last_processed_input` in response
4. **Client receives server state**:
   - If position matches prediction: great, do nothing
   - If mismatch: snap to server position, replay unprocessed inputs

### Implementation
```
Client Input Buffer: [seq:100, seq:101, seq:102, seq:103]
Server says: "I processed up to seq:101, position is (50, 50)"
Client:
  1. Remove seq:100, seq:101 from buffer
  2. Set position to (50, 50)
  3. Re-apply seq:102, seq:103 to get predicted position
```

---

## Interpolation for Remote Players

### The Problem
We receive updates 20 times/second, but render at 60fps. Without interpolation, remote players "teleport" between positions.

### The Solution
- Buffer last 2-3 server states for each remote player
- Render slightly in the past (e.g., 100ms behind)
- Interpolate smoothly between buffered positions

### Implementation
```
Buffer: [
  { tick: 100, pos: (0, 0) },
  { tick: 101, pos: (10, 10) },
  { tick: 102, pos: (20, 20) }
]
Render time: tick 101.5
Rendered position: lerp((10,10), (20,20), 0.5) = (15, 15)
```

---

## Test World

### Specifications
- Simple bounded rectangle (e.g., 1920x1080 pixels)
- Grid background for visual reference
- Visible boundary walls
- Spawn point at center

### Visual Elements
- Background: Dark space color with grid lines
- Boundaries: Visible colored lines
- Players: Colored circles with direction indicator (triangle for aim)

---

## Testing Plan

### Unit Tests (GUT Framework)

#### Serialization Tests (`test_serialization.gd`)
- [ ] `test_encode_player_input` - Input encodes to correct JSON
- [ ] `test_decode_player_input` - JSON decodes to correct input
- [ ] `test_encode_game_state` - State encodes correctly
- [ ] `test_decode_game_state` - State decodes correctly
- [ ] `test_invalid_json_handling` - Graceful error on bad JSON

#### Player State Tests (`test_player_state.gd`)
- [ ] `test_create_player` - New player has correct defaults
- [ ] `test_update_position` - Position updates correctly
- [ ] `test_apply_input` - Input changes velocity/position correctly
- [ ] `test_boundary_clamping` - Player stays in bounds

#### Game State Tests (`test_game_state.gd`)
- [ ] `test_add_player` - Player added to state
- [ ] `test_remove_player` - Player removed from state
- [ ] `test_get_snapshot` - Snapshot contains all players
- [ ] `test_get_delta` - Delta only contains changed data

#### Prediction Tests (`test_prediction.gd`)
- [ ] `test_input_buffer_add` - Inputs stored with sequence
- [ ] `test_input_buffer_clear_old` - Old inputs cleared on ack
- [ ] `test_reconciliation_match` - No correction when prediction correct
- [ ] `test_reconciliation_mismatch` - Correction applied when wrong

#### Physics Tests (`test_physics.gd`)
- [ ] `test_movement_calculation` - Direction + speed = correct velocity
- [ ] `test_position_integration` - Position updates by velocity * delta
- [ ] `test_boundary_collision` - Position clamped at boundaries

### Integration Tests

#### Connection Tests (`test_connection.gd`)
- [ ] `test_client_connects` - Client can connect to server
- [ ] `test_client_receives_id` - Client gets player ID on connect
- [ ] `test_client_disconnect_cleanup` - Server removes disconnected player
- [ ] `test_multiple_clients` - Multiple clients can connect

### Manual Testing Checklist
- [ ] Start server, connect with browser
- [ ] Move with WASD, aim with mouse
- [ ] Open second browser, see other player
- [ ] Movement appears smooth on both clients
- [ ] Disconnect one client, other sees them leave
- [ ] Reconnect, get new session

---

## File List (To Create)

### Shared (used by both client and server)
- [ ] `shared/network/message_types.gd`
- [ ] `shared/network/serialization.gd`
- [ ] `shared/player/player_state.gd`
- [ ] `shared/config/game_constants.gd`

### Server
- [ ] `server/main.tscn` - Server entry scene
- [ ] `server/main.gd`
- [ ] `server/game_server.gd`
- [ ] `server/game_state.gd`
- [ ] `server/network/message_handler.gd`
- [ ] `server/simulation/game_loop.gd`
- [ ] `server/simulation/physics.gd`
- [ ] `server/config/server_config.gd`

### Client
- [ ] `client/main.tscn` - Client entry scene
- [ ] `client/main.gd`
- [ ] `client/game_client.gd`
- [ ] `client/network/message_handler.gd`
- [ ] `client/player/local_player.tscn`
- [ ] `client/player/local_player.gd`
- [ ] `client/player/remote_player.tscn`
- [ ] `client/player/remote_player.gd`
- [ ] `client/player/player_input.gd`
- [ ] `client/player/prediction.gd`
- [ ] `client/world/test_world.tscn`
- [ ] `client/world/test_world.gd`
- [ ] `client/ui/connect_screen.tscn`
- [ ] `client/ui/connect_screen.gd`
- [ ] `client/ui/hud.tscn`
- [ ] `client/ui/hud.gd`
- [ ] `client/config/client_config.gd`

### Tests
- [ ] `tests/test_serialization.gd`
- [ ] `tests/test_player_state.gd`
- [ ] `tests/test_game_state.gd`
- [ ] `tests/test_prediction.gd`
- [ ] `tests/test_physics.gd`

---

## Implementation Order

### Phase 1: Project Setup
1. [ ] Install GUT testing framework
2. [ ] Create directory structure
3. [ ] Create shared constants and message types
4. [ ] Write serialization helpers with tests

### Phase 2: Server Core
5. [ ] Create server entry scene
6. [ ] Implement WebSocket server (accept connections)
7. [ ] Implement player state and game state
8. [ ] Implement game loop (fixed tick rate)
9. [ ] Implement message handler (receive and route)
10. [ ] Implement state broadcasting
11. [ ] Write server unit tests

### Phase 3: Client Core
12. [ ] Create client entry scene
13. [ ] Implement connect screen UI
14. [ ] Implement WebSocket client
15. [ ] Implement message handler
16. [ ] Implement basic local player (no prediction yet)
17. [ ] Implement remote player rendering
18. [ ] Create test world scene

### Phase 4: Smooth Movement
19. [ ] Implement player input capture (WASD + mouse)
20. [ ] Implement client-side prediction
21. [ ] Implement server reconciliation
22. [ ] Implement remote player interpolation
23. [ ] Write prediction unit tests

### Phase 5: Polish & Test
24. [ ] Add basic HUD (player count, ping display)
25. [ ] Handle edge cases (disconnect, reconnect)
26. [ ] Run all unit tests
27. [ ] Manual playtesting with multiple browsers
28. [ ] Performance check (stable 60fps client, 20 tick server)

---

## Configuration Defaults

```gdscript
# game_constants.gd
const TICK_RATE: int = 20  # Server ticks per second
const TICK_INTERVAL: float = 1.0 / TICK_RATE  # 50ms

const PLAYER_SPEED: float = 200.0  # Pixels per second
const WORLD_WIDTH: float = 1920.0
const WORLD_HEIGHT: float = 1080.0

const DEFAULT_PORT: int = 9050
const INTERPOLATION_DELAY: float = 0.1  # 100ms behind for smoothing
```

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| WebSocket not working in HTML5 | Test HTML5 export early in Phase 3 |
| Client-side prediction feels wrong | Tune reconciliation threshold, add smoothing |
| High latency causes issues | Test with artificial latency (Chrome DevTools) |
| GUT doesn't work in Godot 4.5 | Verify compatibility before starting |

---

## Done When
- [ ] Server runs on PC, accepts connections on port 9050
- [ ] Browser client connects and receives player ID
- [ ] Local player moves smoothly with WASD + mouse aim
- [ ] Second browser shows first player moving smoothly
- [ ] Disconnection is detected and handled
- [ ] All unit tests pass
- [ ] Movement feels responsive despite network latency
