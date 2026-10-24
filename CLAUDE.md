# Cosmocraft - Development Notes

## Direction (October 2026)
Cosmocraft is being rebuilt as a single-player arcade game: claim polygon regions of space by surviving waves inside them, then land on planets, build bases, and research tech. The vision lives in `design/game_vision.md`.

New code goes in `game/`. The old networked survival RPG in `client/`, `server/` and `shared/` is legacy: keep it working, but treat it as a parts bin to port from (terrain generator, combat math, enemy AI, loot tables) rather than a foundation.

## Godot Executable Path
```
C:\develop\godot\godot_4_6\Godot_v4.6.1-stable_win64.exe
C:\develop\godot\godot_4_6\Godot_v4.6.1-stable_win64_console.exe  # For CLI/headless
```
Godot 4.7.2 is also installed under `C:\develop\godot\godot_4_7\`; the project is on 4.6.

**After adding or renaming a `class_name`,** refresh the class cache before running from the CLI, or the new names won't resolve:
```bash
"C:\develop\godot\godot_4_6\Godot_v4.6.1-stable_win64_console.exe" --headless --path "C:\develop\Cosmocraft" --import
```

## Running the Claim Prototype (game/)
- Editor: open `game/main.tscn` and press F6.
- Double-click `run_claim.bat`, or:
```bash
"C:\develop\godot\godot_4_6\Godot_v4.6.1-stable_win64.exe" --path "C:\develop\Cosmocraft" res://game/main.tscn
```
- Options go after `--` (documented at the top of `game/space/space_game.gd`): `--seed=N`, `--autoplay`, `--god`, `--debug`, `--claim-speed=X`, `--capture=DIR --shots=3,20`, `--shot-on-ignite`, `--map-at=T`, `--log-fps`.
- Headless smoke test (fixed 60 fps, so 3600 frames is one game-minute):
```bash
"...console.exe" --headless --fixed-fps 60 --quit-after 3600 --path "C:\develop\Cosmocraft" res://game/main.tscn -- --autoplay --seed=42
```
- Screenshots for visual checks need the GUI exe (headless has no renderer): `-- --autoplay --capture=DIR --shots=5,30 --shot-on-ignite`. Captures are converted from linear (HDR 2D) to sRGB so they match the screen.

### game/ conventions
- Entities are `Node2D`s drawn with `_draw()`. Collisions are manual (circle and swept-segment tests through `SpatialGrid`), and the simulation runs in `_process` under SpaceGame's own time scale (used for hitstop). No physics engine.
- HDR 2D is on, so colors above 1.0 glow. In shaders, put colors in `source_color` uniforms; raw constants are treated as linear and come out darker than expected.
- Input actions beyond `move_*` are registered at runtime in `SpaceGame._register_input()`, so `project.godot` stays untouched.
- Every tunable number lives in `SpaceTuning` (`game/space/space_tuning.gd`).
- Pure logic (sector generation, claims, wave director, grid) has GUT tests in `tests/game/`.

```
game/
├── main.tscn                  # Entry point: SpaceGame
├── space/
│   ├── space_game.gd          # Orchestrator: frame loop, claims, spawning, ignition, HUD wiring
│   ├── space_tuning.gd        # Every tunable number
│   ├── sector_generator.gd    # Voronoi regions clipped to a ragged boundary
│   ├── sector_data.gd, region_data.gd
│   ├── claim.gd               # Claim state machine
│   ├── wave_director.gd       # Credit-based spawner
│   ├── spatial_grid.gd        # Broadphase for collisions
│   ├── ship.gd, ship_input.gd
│   ├── gloom_enemy.gd         # mite, dart, spitter, snuffer
│   ├── projectiles.gd, pickups.gd, kindle_spark.gd
│   ├── region_layer.gd, region.gdshader   # Fog, claim light, ignition wave
│   ├── border_layer.gd        # Borders, beacons, map labels
│   ├── starfield.gd, far_stars.gd, fx_layer.gd, game_camera.gd
│   └── sfx.gd                 # Procedurally synthesized sound effects
├── ui/                        # space_hud.gd, hud_canvas.gd
└── debug/autopilot.gd         # Bot pilot for --autoplay
```

## Running Tests (GUT)
```bash
"C:\develop\godot\godot_4_6\Godot_v4.6.1-stable_win64_console.exe" --headless --path "C:\develop\Cosmocraft" --script addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit
```
Subdirectories are included via `.gutconfig.json`. Use `-gdir=res://tests/game/` for just the new code.

Or from within the Godot editor: use the GUT panel at the bottom.

GUT version: 9.5.1
Current test count: 969 tests (38 test scripts)

Known issues under Godot 4.6:
- `tests/test_serialization.gd` (legacy) fails to parse because `var x :=` from a Variant-returning call is an error now, so its tests silently don't run.
- GUT prints `SCRIPT ERROR ... gut_loader.gd:35` at startup (a 4.6 project setting it reads no longer exists). Harmless.

---

## Legacy: Networked RPG (client/server/shared)

### Start the Server
Option 1 - From Godot Editor:
1. Open project in Godot
2. Open `server/main.tscn`
3. Press F5 or click Play

Option 2 - Headless (CLI):
```bash
"C:\develop\godot\godot_4_6\Godot_v4.6.1-stable_win64_console.exe" --headless --path "C:\develop\Cosmocraft" res://server/main.tscn
```

The server listens on port 9050 by default.

### Start the Client
Option 1 - From Godot Editor:
1. Open project in Godot
2. Open `client/main.tscn`
3. Press F6 (Run Current Scene) or set as main scene

Option 2 - With GUI:
```bash
"C:\develop\godot\godot_4_6\Godot_v4.6.1-stable_win64.exe" --path "C:\develop\Cosmocraft" res://client/main.tscn
```

### Multiplayer Testing
1. Start the server (headless recommended)
2. Start multiple client instances
3. Each client: enter name, connect to localhost:9050
4. Move with WASD, aim with mouse

### Project Structure
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
├── tests/                  # GUT unit tests (tests/game/ covers the new code)
├── addons/gut/            # GUT testing framework
├── milestones/            # Development milestone docs
└── plan.md                # Original game requirements (superseded by design/game_vision.md)
```

### Architecture

#### Network
- WebSocket-based multiplayer (browser-compatible)
- JSON message protocol
- Server port: 9050 (configurable)

#### Server
- Authoritative game state
- 20 tick/second fixed timestep
- Processes player inputs and broadcasts state deltas

#### Client
- Client-side prediction for responsive movement
- Server reconciliation to correct mispredictions
- 100ms interpolation delay for smooth remote players
- 360° movement (WASD) with mouse aiming

#### Message Types
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

### Controls
- **WASD** or **Arrow Keys** - Move
- **Mouse** - Aim direction

### Key Configuration
- `shared/config/game_constants.gd`:
  - `TICK_RATE`: 20 (ticks/second)
  - `PLAYER_SPEED`: 200 (pixels/second)
  - `WORLD_WIDTH/HEIGHT`: 1920x1080
  - `DEFAULT_PORT`: 9050
  - `INTERPOLATION_DELAY`: 0.1 (100ms)
