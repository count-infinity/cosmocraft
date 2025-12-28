# Game Improvements Plan

## Overview
This plan covers several improvements to make the game feel more polished and Zelda-like.

## STATUS: ALL CORE TASKS COMPLETE ✓

---

## 1. WEAPON DAMAGE FIX (Priority: CRITICAL) ✓ COMPLETE

### Problem
Server never updates CombatComponent when equipment changes. The server always uses DEFAULT_ATTACK_DAMAGE (5.0) regardless of equipped weapon.

### Solution
- Add `_update_player_weapon_stats(player_id)` method to GameServer
- Call it in `_on_equip_requested()` after equipping
- Call it in `_on_unequip_requested()` after unequipping
- Read weapon stats from `_player_equipment[player_id]` and update `_player_combat_components[player_id]`

### Files Modified
- [x] `server/game_server.gd` - Added `_update_player_weapon_stats()` method

---

## 2. CORPSE SYSTEM (Priority: HIGH) ✓ PARTIAL

### Current State
- Enemies turn gray when dead but remain as "dead" visuals
- ✓ Corpse naming implemented
- Looting/butchering left for future work

### Changes Completed

#### 2.1 Enemy Corpse Naming ✓
- Modified `EnemyVisual` to change name label to "Corpse of {name}" on death

### Files Modified
- [x] `client/world/enemy_visual.gd` - Corpse naming on death

### Future Work (Not Implemented)
- [ ] Corpse decay/despawn with configurable duration
- [ ] Butchering system with loot tables
- [ ] Corpse interaction messages

---

## 3. TILE-BASED MOVEMENT BLOCKING (Priority: HIGH) ✓ COMPLETE

### Problem
Players can walk through trees, rocks, and any solid tile. No collision detection.

### Solution Implemented

#### 3.1 Server-Side Collision ✓
- Modified `Physics.tick()` to check `ChunkManager.is_passable()` before applying movement
- Blocks movement into solid tiles (tree trunks, rocks, cacti)
- Allows sliding along walls (checks X and Y movement separately)
- Uses player radius (12.0) for hitbox checking at 5 points (center + 4 corners)

### Files Modified
- [x] `server/simulation/physics.gd` - Added collision checking with wall sliding
- [x] `server/simulation/game_loop.gd` - Pass chunk_manager to physics tick
- [x] `server/game_server.gd` - Reordered initialization for chunk_manager availability

### Note on Cliffs
Cliff tiles were not implemented as steep elevation changes already use different biomes (mountains → tundra/ice) and tree/rock placement provides natural barriers.

---

## 4. WATER DEPTH SYSTEM (Priority: MEDIUM) ✓ COMPLETE

### Current State
- Single WATER tile type with 0.5 speed multiplier

### Solution Implemented

#### 4.1 Water Depth Tiles ✓
- `WATER_SHALLOW` (ID 19): near shores, 0.7 speed multiplier, lighter blocking
- `WATER_DEEP` (ID 20): far from shores, 0.4 speed multiplier, higher blocking

#### 4.2 Generation Logic ✓
- Uses elevation values from terrain generation:
  - Elevation > -0.4: Shallow water (near shores)
  - Elevation -0.4 to -0.6: Normal water
  - Elevation < -0.6: Deep water

### Files Modified
- [x] `shared/world/tile_types.gd` - Added WATER_SHALLOW, WATER_DEEP types
- [x] `shared/world/terrain_generator.gd` - Water depth based on elevation

---

## 5. LARGER BIOME SCALE (Priority: MEDIUM) ✓ COMPLETE

### Problem
Biomes change too quickly - crossing entire biomes in seconds.

### Solution Implemented
Reduced noise frequencies by 2.5x to create larger, more distinct biome regions:

```
# Previous (too small)
elevation_noise.frequency = 0.002
temperature_noise.frequency = 0.001
moisture_noise.frequency = 0.0015

# New (larger biomes)
elevation_noise.frequency = 0.0008   # 2.5x larger
temperature_noise.frequency = 0.0004 # 2.5x larger
moisture_noise.frequency = 0.0006    # 2.5x larger
```

### Files Modified
- [x] `shared/world/terrain_generator.gd` - Adjusted noise frequencies

---

## Implementation Summary

| Task | Status | Notes |
|------|--------|-------|
| Weapon Damage Fix | ✓ Complete | Server updates weapon stats on equip/unequip |
| Corpse Naming | ✓ Complete | Shows "Corpse of {name}" on death |
| Movement Blocking | ✓ Complete | Collision with solid tiles, wall sliding |
| Larger Biomes | ✓ Complete | 2.5x larger biome scale |
| Water Depth | ✓ Complete | Shallow/normal/deep based on elevation |
| Butchering System | ○ Future | Most complex, requires UI work |

---

## Testing Checklist

- [x] Equipping sword increases attack damage
- [x] Unequipping sword returns to unarmed damage
- [x] Cannot walk through tree trunks
- [x] Cannot walk through rocks
- [x] Dead enemies show "Corpse of {name}"
- [x] Biomes feel larger when exploring
- [x] Shallow water near shores, deep water far from shores
- [ ] Butchering corpses yields loot items (future work)

---

## All Tests Pass
939 tests passing after all changes.
