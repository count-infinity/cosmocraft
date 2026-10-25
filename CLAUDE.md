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

## Running the Game (game/)
- Editor: open `game/main.tscn` and press F6. Double-click `run_claim.bat`, or:
```bash
"C:\develop\godot\godot_4_6\Godot_v4.6.1-stable_win64.exe" --path "C:\develop\Cosmocraft" res://game/main.tscn
```
- `main.tscn` runs `GameFlow`: the walkable homeworld (`Homeworld`) between runs, a `SpaceGame` per run (which can push on through several galaxy sectors), and for each planet landing an `AssaultMission` (side-scrolling) followed by a `SurfaceMission` (space is frozen with `set_active(false)` meanwhile). Progress saves to `user://cosmocraft_save.json`. Autoplay and capture runs never touch it.
- Options go after `--`.
  - Run flags (top of `game/space/space_game.gd`): `--seed=N`, `--autoplay`, `--god`, `--debug`, `--claim-speed=X`, `--shot-on-ignite`, `--map-at=T`, `--log-fps`, `--visit=asteroids|nebula|nest|rich|heart|planet`, `--show=loot|refit`.
  - Flow flags (`game/game_flow.gd`): `--capture=DIR --shots=3,20` (also turns vsync off, which otherwise stalls the window when the display sleeps), `--show=home` with optional `--panel=none|launch|shipyard|lab|relay|hearth`, `--skip-home`, `--land` (wake the first planet and land on it straight away), `--skip-assault` (land without the assault), `--darkness=N` (force a difficulty level, 0 = Twilight, 1 = Dusk...).
  - Surface flags (`game/surface/surface_mission.gd`): `--surface-start=vein`. `--autoplay` and `--god` apply there too.
- Surface smoke test: `-- --autoplay --land --seed=1234` with `--fixed-fps 60 --quit-after 9000`. Under autoplay the mission prints a progress line every 10 seconds (health, haul, awake Gloom, fps). The surface autopilot aims with deliberate wobble and only "sees" about as far as a player, so its runs say something about balance.
- Headless smoke test (fixed 60 fps, so 3600 frames is one game-minute):
```bash
"...console.exe" --headless --fixed-fps 60 --quit-after 3600 --path "C:\develop\Cosmocraft" res://game/main.tscn -- --autoplay --seed=42
```
- Screenshots for visual checks need the GUI exe (headless has no renderer): `-- --autoplay --capture=DIR --shots=5,30 --shot-on-ignite`, or `-- --show=refit --capture=DIR --shots=1.5`. `ScreenCapture` converts from linear (HDR 2D) to sRGB, so captures match the screen.

### game/ conventions
- Entities are `Node2D`s drawn with `_draw()`, and UI screens are custom-drawn `Control`s. Collisions are manual (circle and swept-segment tests through `SpatialGrid`), and the simulation runs in `_process` under SpaceGame's own time scale (used for hitstop). No physics engine.
- HDR 2D is on, so colors above 1.0 glow. In shaders, put colors in `source_color` uniforms; raw constants are treated as linear and come out darker than expected.
- Full-screen Controls created at runtime need `set_anchors_and_offsets_preset()`. Plain `set_anchors_preset()` after joining the tree keeps the old zero size.
- Input actions beyond `move_*` are registered at runtime by `InputSetup.register()` (`game/core/input_setup.gd`), so `project.godot` stays untouched.
- Combat lives in `Battle` (`game/combat/battle.gd`), which both SpaceGame and SurfaceMission own. Each mode is the "host" GloomEnemy and WeaponSystem call back into: `target_position()`, `has_objective()`, `objective_position()`, `route_to()` (waypoints around obstacles), `nests_awake()`, `spawn_enemy_shot()`, `spawn_minions()`, `fire_volley()`, `nearest_enemy_within()`, `on_snuffer_reached()`. Drops are decided by listening to `Battle.enemy_killed`.
- `Glow.ensure()` (`game/core/glow.gd`) sets up HDR 2D and the one shared WorldEnvironment; every mode calls it.
- Real-time features (research, outposts) take a `now` parameter so tests control the clock.
- Check new `class_name`s against the legacy code first. `grep -rh "^class_name" --include=*.gd . | sort | uniq -d` must print nothing. A clash (we hit one with `LootTable`) silently breaks the legacy tests.
- Pure logic has GUT tests in `tests/game/`, and `test_space_game.gd` drives the real game headlessly through run flows.

```
game/
├── main.tscn                  # Entry point: GameFlow
├── game_flow.gd               # Homeworld <-> runs <-> planet surfaces, banking, saving
├── core/                      # glow.gd (shared HDR look), input_setup.gd
├── combat/battle.gd           # Shared combat: Gloom, shots, hits, blasts, armor, homing
├── galaxy/galaxy_data.gd      # The conquest map: systems of sectors, lanes, tiers, themes
├── assault/                   # The side-scrolling planet assault
│   ├── assault_mission.gd     # Scroll, ground defenses, skimmer waves, the bastion, suppression
│   ├── assault_terrain.gd, assault_sky.gd   # Side-view ground and parallax sky
│   └── assault_autopilot.gd   # --autoplay for the assault
├── space/
│   ├── space_game.gd          # One run: frame loop, claims, combat, ignition, loot, refit, run end
│   ├── space_tuning.gd        # Every tunable number for sectors, claims, sparks, waves, ship
│   ├── sector_generator.gd    # Voronoi cells merged into regions, the heart, modifiers, planets, asteroids
│   ├── sector_data.gd, region_data.gd, planet_data.gd
│   ├── planet_layer.gd, planet.gdshader   # Planets, orbit rings, wake/kindle states
│   ├── claim.gd               # Claim state machine
│   ├── wave_director.gd       # Credit-based spawner
│   ├── spatial_grid.gd        # Broadphase for collisions
│   ├── ship.gd, ship_input.gd, weapon_system.gd
│   ├── gloom_enemy.gd         # mite, dart, spitter, snuffer, carapace, brood, lancer, heart, nest
│   ├── projectiles.gd, pickups.gd, kindle_spark.gd
│   ├── region_layer.gd, region.gdshader   # Fog, modifier tints, claim light, ignition wave
│   ├── border_layer.gd        # Borders, beacons, heart marker, map labels
│   ├── asteroid_layer.gd, nebula_veil.gd
│   ├── starfield.gd, far_stars.gd, fx_layer.gd, game_camera.gd
│   └── sfx.gd                 # Procedurally synthesized sound effects
├── fitting/                   # The ship grid (Stars Without Number-style budgets)
│   ├── component_def.gd, component_library.gd   # Every part
│   ├── hull_def.gd            # Skiff, Corvette grids
│   ├── loadout.gd             # Placement rules, power, adjacency, marks, stats
│   └── ship_stats.gd, weapon_spec.gd
├── surface/                   # Landfall: a planet's surface on foot
│   ├── surface_mission.gd     # Explore, plant the pylon, ground siege, kindle, lift off
│   ├── surface_map.gd         # Generator: lander, vein, rocks, hazards, deposits, nests, caches, packs, paths
│   ├── surface_tuning.gd      # Pilot and siege numbers (extends SpaceTuning for Claim/WaveDirector)
│   ├── pilot.gd               # The lamplighter on foot: roll, barrier, lantern
│   ├── lantern_veil.gd        # The dark, with up to 24 lights
│   ├── surface_glints.gd      # Eyes and twinkles drawn above the dark
│   ├── surface_terrain.gd, surface_ground.gdshader, surface_props.gd
│   └── surface_autopilot.gd   # --autoplay on foot
├── home/                      # Hearthhold, the walkable hub between runs
│   ├── homeworld.gd           # Buildings, walking, research ticking
│   ├── home_buildings.gd      # Hearth, Launch Pad, Shipyard, Lab, Outpost Relay
│   └── home_panel.gd          # Shipyard / Lab / Relay / Hearth windows
├── run/
│   ├── run_state.gd           # One run's ship, sparks, resources, outposts, outcome
│   ├── loot_picks.gd          # Pick-1-of-3 rolls and applying them
│   ├── research.gd            # Lab projects (resources + real time)
│   ├── difficulty.gd          # Darkness levels (Twilight... Void N) plus sector tier scaling
│   ├── hearth_ranks.gd        # Hearth levels: endless paragon-style points from banked sparks
│   ├── pilot_ranks.gd         # Pilot levels and stats, earned on planets
│   └── level_curve.gd         # The experience curve both use
│   └── meta_progress.gd, meta_upgrades.gd   # Banked sparks/resources, upgrades, blueprints, research, outposts, save
├── ui/                        # space_hud, hud_canvas, loot_screen, refit_screen, sector_choice_screen
└── debug/                     # autopilot.gd (--autoplay), screen_capture.gd (--capture)
```

## Running Tests (GUT)
```bash
"C:\develop\godot\godot_4_6\Godot_v4.6.1-stable_win64_console.exe" --headless --path "C:\develop\Cosmocraft" --script addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit
```
Subdirectories are included via `.gutconfig.json`. Use `-gdir=res://tests/game/` for just the new code.

Or from within the Godot editor: use the GUT panel at the bottom.

GUT version: 9.5.1
Current test count: 1102 tests (46 test scripts)

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
