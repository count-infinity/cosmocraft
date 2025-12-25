# Cosmocraft - Development Notes

## Godot Executable Path
```
C:\develop\godot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64.exe
C:\develop\godot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe  # For CLI/headless
```

## Running the Game

### Start the Server
Option 1 - From Godot Editor:
1. Open project in Godot
2. Open `server/main.tscn`
3. Press F5 or click Play

Option 2 - Headless (CLI):
```bash
"C:\develop\godot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe" --headless --path "C:\develop\Cosmocraft" res://server/main.tscn
```

The server listens on port 9050 by default.

### Start the Client
Option 1 - From Godot Editor:
1. Open project in Godot
2. Open `client/main.tscn`
3. Press F6 (Run Current Scene) or set as main scene

Option 2 - With GUI:
```bash
"C:\develop\godot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64.exe" --path "C:\develop\Cosmocraft" res://client/main.tscn
```

### Multiplayer Testing
1. Start the server (headless recommended)
2. Start multiple client instances
3. Each client: enter name, connect to localhost:9050
4. Move with WASD, aim with mouse

## Running Tests (GUT)
```bash
"C:\develop\godot\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe" --headless --path "C:\develop\Cosmocraft" --script addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit
```

Or from within the Godot editor: use the GUT panel at the bottom.

GUT version: 9.5.1
Current test count: 134 tests

## Project Structure
```
Cosmocraft/
├── shared/                 # Code shared between client and server
│   ├── config/
│   │   └── game_constants.gd
│   ├── network/
│   │   ├── message_types.gd
│   │   └── serialization.gd
│   ├── player/
│   │   └── player_state.gd
│   └── world/              # Procedural world generation
│       ├── tile_types.gd   # Tile type enum and properties
│       ├── chunk.gd        # 32x32 tile chunk data structure
│       ├── terrain_generator.gd  # Noise-based terrain generation
│       └── chunk_manager.gd      # Chunk loading/unloading
├── server/                 # Authoritative game server (native PC)
│   ├── main.tscn          # Server entry point
│   ├── main.gd
│   ├── game_server.gd     # WebSocket server, connection handling
│   ├── game_state.gd      # Authoritative world state
│   ├── config/
│   │   └── server_config.gd
│   ├── network/
│   │   └── message_handler.gd
│   └── simulation/
│       ├── game_loop.gd   # Fixed 20 tick/second loop
│       └── physics.gd
├── client/                 # Browser client (HTML5 export)
│   ├── main.tscn          # Client entry point
│   ├── main.gd
│   ├── game_client.gd     # WebSocket client + chunk streaming
│   ├── config/
│   │   └── client_config.gd
│   ├── network/
│   │   └── message_handler.gd
│   ├── player/
│   │   ├── local_player.gd/.tscn   # Controlled player with prediction
│   │   ├── remote_player.gd/.tscn  # Other players with interpolation
│   │   ├── player_input.gd         # WASD + mouse input
│   │   └── prediction.gd           # Client-side prediction
│   ├── world/
│   │   ├── test_world.gd/.tscn
│   │   └── chunk_renderer.gd       # TileMap-based chunk rendering
│   └── ui/
│       ├── connect_screen.gd/.tscn
│       └── hud.gd/.tscn
├── tests/                  # GUT unit tests
│   ├── test_serialization.gd
│   ├── test_player_state.gd
│   ├── test_game_state.gd
│   ├── test_game_loop.gd
│   ├── test_physics.gd
│   ├── test_prediction.gd
│   ├── test_tile_types.gd
│   ├── test_chunk.gd
│   ├── test_terrain_generator.gd
│   └── test_chunk_manager.gd
├── addons/gut/            # GUT testing framework
├── milestones/            # Development milestone docs
└── plan.md                # Full game requirements
```

## Architecture

### Network
- WebSocket-based multiplayer (browser-compatible)
- JSON message protocol
- Server port: 9050 (configurable)

### Server
- Authoritative game state
- 20 tick/second fixed timestep
- Processes player inputs and broadcasts state deltas

### Client
- Client-side prediction for responsive movement
- Server reconciliation to correct mispredictions
- 100ms interpolation delay for smooth remote players
- 360° movement (WASD) with mouse aiming

### Message Types
Client → Server:
- `connect_request` - Join with player name
- `player_input` - Movement and aim (sequenced)
- `ping` - Latency measurement
- `disconnect` - Clean disconnect

Server → Client:
- `connect_response` - Success/failure with player ID
- `game_state` - Full snapshot (on join)
- `state_delta` - Per-tick updates
- `player_joined` / `player_left` - Player events
- `pong` - Ping response

## Controls
- **WASD** or **Arrow Keys** - Move
- **Mouse** - Aim direction

## Key Configuration
- `shared/config/game_constants.gd`:
  - `TICK_RATE`: 20 (ticks/second)
  - `PLAYER_SPEED`: 200 (pixels/second)
  - `WORLD_WIDTH/HEIGHT`: 1920x1080
  - `DEFAULT_PORT`: 9050
  - `INTERPOLATION_DELAY`: 0.1 (100ms)
