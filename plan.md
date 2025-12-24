# Cosmocraft - Game Requirements & Plan

## Overview

**Cosmocraft** is a 2D top-down sci-fi RPG combining space exploration, planet exploration, crafting, base building, and player scripting. Think Terraria meets No Man's Sky meets a MUSH, playable in a browser with friends.

---

## Core Vision

- **Genre**: 2D top-down space exploration/survival/crafting RPG
- **Inspiration**: Terraria, Minecraft, No Man's Sky, Melvor Idle (progression), MUSHes (scripting/building)
- **Platform**: Web browser (HTML5) client, native PC authoritative server
- **Multiplayer**: Co-op PvE, small groups, anyone can host a server
- **Difficulty**: Accessible, not punishing - fun over frustration

---

## Technical Foundation

### Platform & Architecture
- [ ] Godot 4.5 with GDScript
- [ ] HTML5 export for browser-based client
- [ ] Native PC authoritative server
- [ ] WebSocket-based client-server communication
- [ ] Server validates all game state (anti-cheat by design)

### Multiplayer (Priority #1 - Build First)
- [ ] Authoritative server model (like Terraria - anyone can host)
- [ ] WebSocket networking for browser clients
- [ ] Player authentication/session management
- [ ] State synchronization across clients
- [ ] Players can be in different locations simultaneously (different planets, space, etc.)
- [ ] Individual player progression (not shared unlocks)
- [ ] Each player has their own home base

---

## Universe & World Generation

### Galaxy Structure
- [ ] Procedurally generated galaxy (entire galaxy explorable)
- [ ] Multiple solar systems with multiple planets each
- [ ] Seed-based generation (only save player changes/diffs)
- [ ] Deterministic generation from coordinates

### Planets
- [ ] Full 2D explorable worlds (Terraria-style)
- [ ] Procedurally generated terrain and biomes
- [ ] Multiple biome types:
  - [ ] Jungle
  - [ ] Desert
  - [ ] Ice/Tundra
  - [ ] Volcanic
  - [ ] Ocean
  - [ ] Alien/Weird
  - [ ] Forest
  - [ ] Swamp
  - [ ] And more...
- [ ] Day/night cycle
- [ ] Weather systems

### Space
- [ ] Real-time space flight between planets
- [ ] Top-down space shooter mechanics
- [ ] Asteroids, debris, space stations
- [ ] Nebulae and other space phenomena

---

## Player Character

### Character System
- [ ] Customizable appearance
- [ ] Stats system (STR affects carry weight, etc.)
- [ ] Skill trees
- [ ] Level progression (Melvor Idle style - 92 is halfway to 99)
- [ ] Multiple combat styles:
  - [ ] Melee
  - [ ] Ranged/guns
  - [ ] Abilities/magic

### Inventory
- [ ] Weight-based (tied to STR stat)
- [ ] Limited slots with stackable items
- [ ] Material categories (e.g., any "wood" type works for wood recipes)

### Death & Respawn
- [ ] Configurable death penalty
- [ ] Default: respawn at home base
- [ ] Options for item drop, etc.

---

## Ships & Space Travel

### Ship System
- [ ] Multiple ships per player (own a fleet)
- [ ] Ship customization and upgrades
- [ ] Ship crafting/building
- [ ] Ships park on planets when landed

### Space Combat
- [ ] Top-down shooter style
- [ ] Turrets
- [ ] Missiles
- [ ] Lasers
- [ ] Potential for ramming, boarding

### Travel
- [ ] Real-time flying in space
- [ ] Warp drives for fast travel between systems
- [ ] Landing/takeoff from planets

---

## Base Building

### Construction
- [ ] Build on any planet
- [ ] Tile/block-based building
- [ ] Multiple structure types
- [ ] Aesthetic variety (different wood types look different but function same)

### Base Contents
- [ ] Storage containers
- [ ] Crafting stations
- [ ] Defensive structures (turrets, walls)
- [ ] NPC housing
- [ ] Farms
- [ ] Factories/automation

### Base Mechanics
- [ ] Each player has a home base
- [ ] Bases can be attacked (configurable - toggle "roving raiders")
- [ ] Teleporters for fast travel between bases

---

## Crafting & Resources

### Resource System
- [ ] Many material types
- [ ] Processing chains (ore → ingot → component → device)
- [ ] Material equivalency (birch OR oak = "wood" in recipes)
- [ ] Resources appropriate to player level (not obnoxiously rare)
- [ ] Biome-specific resources

### Crafting System
- [ ] Recipe-based (discover/unlock)
- [ ] Tech/research tree for unlocking recipes
- [ ] Craftable items:
  - [ ] Weapons (melee, ranged)
  - [ ] Tools
  - [ ] Armor
  - [ ] Ships and ship parts
  - [ ] Building materials
  - [ ] Consumables
  - [ ] Machines/automation
  - [ ] Decorations

---

## Combat & Enemies

### Enemy Types
- [ ] Organic aliens
- [ ] Robots/machines
- [ ] Pirates (space and ground)
- [ ] Environmental hazards
- [ ] Player-created enemies (via scripting)

### Boss Fights
- [ ] Unique boss encounters
- [ ] Boss-specific loot/rewards

### Combat Mechanics
- [ ] Ground combat (on planets)
- [ ] Space combat (ship-based)
- [ ] Variety of weapons and abilities

---

## NPCs & Economy

### NPCs
- [ ] Traders/shops
- [ ] Quest givers
- [ ] Recruitable NPCs for bases
- [ ] NPC behaviors and schedules

### Economy
- [ ] NPC-driven trading
- [ ] Multiple currencies or trade goods
- [ ] Supply and demand (optional complexity)

---

## Quests & Progression

### Quest System
- [ ] Story elements
- [ ] Side quests
- [ ] Procedural quests (optional)

### Progression
- [ ] Character levels and stats
- [ ] Skill trees
- [ ] Tech/research unlocks
- [ ] Recipe discovery
- [ ] Gear tiers

---

## Scripting System (MUSH-Inspired)

### Core Scripting
- [ ] Simple command-list syntax (e.g., `on_enter() { fire_arrow }`)
- [ ] Event-driven triggers:
  - [ ] Player enters area
  - [ ] Timer/interval
  - [ ] Combat events
  - [ ] Item used
  - [ ] Day/night cycle
  - [ ] Custom signals
  - [ ] Generic state_change (like Minecraft observer)

### Script Capabilities
- [ ] Spawn items
- [ ] Change tiles/world
- [ ] Open doors, activate mechanisms
- [ ] Create/control NPCs
- [ ] Ship autopilot
- [ ] Drone control
- [ ] Turret behavior
- [ ] Base automation

### Script Examples
- [ ] Traps
- [ ] Slot machines
- [ ] Random-walk butterflies
- [ ] Automated farms
- [ ] Custom enemies

### Permissions & Safety
- [ ] Fine-grained permission levels (Builder vs Wizard)
- [ ] Infinite loop prevention
- [ ] Spawn limits
- [ ] Sandboxed execution
- [ ] Resource usage limits

### Import/Export
- [ ] Export scripts to files
- [ ] Import scripts from files
- [ ] Share creations between worlds/servers

---

## Quality of Life

### Fast Travel
- [ ] Teleporters between player-built bases
- [ ] Warp drives for ship travel
- [ ] "Do tedious things once" philosophy
- [ ] Auto-navigation for previously traveled routes (skip the maze)

### Configurability
- [ ] Server-side toggles:
  - [ ] Roving raiders on/off
  - [ ] Death penalty options
  - [ ] Difficulty settings
  - [ ] PvP toggle (even if not focus)

### UI/UX
- [ ] Clear crafting interface
- [ ] Map/galaxy navigation
- [ ] Quest tracking
- [ ] Inventory management

---

## Modding & Custom Content

### Player Creation
- [ ] Custom sprites/art import
- [ ] Custom enemy creation via scripting
- [ ] Custom items (within scripting system)

### Sharing
- [ ] Export creations to files
- [ ] Import to other worlds/servers
- [ ] Blueprint system for buildings

---

## Development Milestones

### Milestone 1: Multiplayer Foundation
- [ ] Basic server that accepts WebSocket connections
- [ ] Browser client connects to server
- [ ] Player can join, see other players
- [ ] Basic movement synchronized across clients
- [ ] Simple test world (flat plane)

### Milestone 2: Space Flight
- [ ] Top-down ship movement in space
- [ ] Ship controls (thrust, rotation)
- [ ] Basic starfield background
- [ ] Camera following ship

### Milestone 3: Planet Landing
- [ ] Transition from space to planet
- [ ] Basic procedural planet generation
- [ ] Character movement on planet
- [ ] Ship parked at landing site

### Milestone 4: Resource Gathering
- [ ] Tiles/blocks can be harvested
- [ ] Inventory system
- [ ] Basic resources (ore, wood, etc.)
- [ ] Tool usage

### Milestone 5: Crafting Basics
- [ ] Crafting UI
- [ ] Basic recipes
- [ ] Crafting stations
- [ ] Item creation

### Milestone 6: Combat Basics
- [ ] Melee attack
- [ ] Ranged attack
- [ ] Basic enemy AI
- [ ] Health/damage system

### Milestone 7: Base Building
- [ ] Place blocks/tiles
- [ ] Structure building
- [ ] Storage containers
- [ ] Crafting stations placement

### Milestone 8: Scripting Foundation
- [ ] Script parser
- [ ] Basic triggers (on_enter, timer)
- [ ] Basic actions (spawn, message)
- [ ] Permission system

### Milestone 9: Galaxy & Persistence
- [ ] Procedural galaxy generation
- [ ] Multiple solar systems
- [ ] Planet variety
- [ ] Save/load player changes only

### Milestone 10: Polish & Systems
- [ ] Quest system
- [ ] NPC traders
- [ ] Tech tree
- [ ] Boss encounters
- [ ] Full progression system

---

## Open Questions / Future Considerations

- Exact scripting language syntax
- Art style direction
- Sound design
- Specific skill tree design
- Balancing resource rarity
- Server browser vs direct connect
- Account system vs anonymous play
