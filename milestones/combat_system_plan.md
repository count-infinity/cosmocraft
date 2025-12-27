# Overworld Combat System Plan

## Overview
Implement a complete combat system with melee and ranged weapons, enemy AI with pack behavior (Diablo-style), and individual player loot drops.

## Design Goals
- **Server-authoritative**: All combat calculations happen server-side
- **Responsive feel**: Client-side attack animations with server validation
- **Pack spawning**: Enemies spawn in groups with coordinated behavior
- **Individual loot**: Each player sees their own loot drops from kills
- **Scalable**: Architecture supports adding more enemy types easily
- **Underground-ready**: Entity system works for future cave/dungeon modes

---

## Open Design Questions

### Q1: Attack Targeting - Click-to-Attack vs Aim-Direction?
**Options:**
- A) **Click on enemy** - Must click directly on target (like Diablo)
- B) **Aim direction** - Attack in mouse direction, hit anything in path (like twin-stick shooter)
- C) **Hybrid** - Melee uses aim direction arc, ranged requires click-target or aim

**Recommendation:** Option C (Hybrid) - feels natural for both weapon types
**Decision:** Option C

### Q2: Attack While Moving?
**Options:**
- A) **Full mobility** - Can attack and move simultaneously
- B) **Attack stops movement** - Brief pause during attack animation
- C) **Move speed reduction** - Slower while attacking

**Recommendation:** Option A for ranged, Option B for melee (swing commitment)
**Decision:** Go with recommendation

### Q3: Auto-Attack / Hold-to-Attack?
**Options:**
- A) **Click per attack** - Each attack requires a click
- B) **Hold to attack** - Holding mouse button auto-attacks at weapon speed
- C) **Toggle auto-attack** - Click once to start, click again to stop

**Recommendation:** Option B (hold to attack) - less RSI, Diablo-style
**Decision:** Option B

### Q4: Enemy Collision with Players?
**Options:**
- A) **Enemies block players** - Physical collision, can be trapped
- B) **Enemies pass through** - No collision, just hitboxes for combat
- C) **Soft collision** - Push each other but can overlap

**Recommendation:** Option C (soft collision) - prevents stuck situations but feels physical
**Decision:** Option C

### Q5: Enemy Collision with Each Other?
**Options:**
- A) **No collision** - Enemies can stack on same position
- B) **Collision + separation** - Enemies push apart (prevents stacking)
- C) **Collision + pathfinding** - Enemies navigate around each other

**Recommendation:** Option B - simple separation force prevents ugly stacking
**Decision:** Option B

### Q6: Death Penalty?
**Options:**
- A) **No penalty** - Just respawn
- B) **Durability loss** - Equipment takes damage on death
- C) **XP loss** - Lose percentage of current level XP
- D) **Drop items** - Drop some/all inventory (hardcore)
- E) **Corpse run** - Must return to body to recover items

**Recommendation:** Option B (durability loss) - meaningful but not punishing
**Decision:** I think this was E, corpse run, but configurable.

### Q7: Respawn Location?
**Options:**
- A) **Fixed spawn point** - Always respawn at world spawn
- B) **Nearest safe zone** - Respawn at closest town/checkpoint
- C) **Where you died** - Respawn in place (with invuln)

**Recommendation:** Option B - encourages exploration of safe zones
**Decision:** Option B

### Q8: Damage Numbers Style?
**Options:**
- A) **Single number** - Just show final damage
- B) **Stacking numbers** - Multiple hits stack visually
- C) **Detailed breakdown** - Show base + crit + bonuses
- D) **No numbers** - Just health bar changes

**Recommendation:** Option A with crit indicator - clean but informative
**Decision:** Yes, Option A with crit indicator

### Q9: Enemy Health Bar Visibility?
**Options:**
- A) **Always visible** - All enemies show health bars
- B) **On hover/target** - Only selected enemy shows health
- C) **On damage** - Health bar appears when damaged, fades after
- D) **Above head always** - Small bar above each enemy

**Recommendation:** Option C - cleaner screen, still informative
**Decision:** Yes Option C

### Q10: Loot Participation Threshold?
For individual loot, how much damage must you deal to qualify?
**Options:**
- A) **Any damage** - 1 damage = full loot chance
- B) **Percentage threshold** - Must deal X% of enemy max HP
- C) **Damage-weighted** - Loot quality scales with contribution

**Recommendation:** Option A (any damage) - simpler, more generous
**Decision:** Option A

### Q11: Underground Combat - Same System or Different?
**Options:**
- A) **Same system** - Enemies work identically in caves
- B) **Modified behaviors** - Cave enemies have different AI (ambush, etc.)
- C) **Completely separate** - Underground is a different combat system

**Recommendation:** Option B - same core but cave-specific behaviors
**Decision:** Option B

### Q12: Entity System - Unified or Separate?
Should players and enemies share a base entity class?
**Options:**
- A) **Unified EntityBase** - Players and enemies inherit from same base
- B) **Separate hierarchies** - PlayerState and EntityBase are independent
- C) **Composition** - Both use CombatComponent, MovementComponent, etc.

**Recommendation:** Option C (composition) - most flexible for underground modes
**Decision:** Option C

### Q13: Ranged Attack - Hitscan vs Projectile?
**Options:**
- A) **Hitscan** - Instant hit, raycast to target
- B) **Projectile** - Visible projectile with travel time
- C) **Hybrid** - Fast weapons hitscan, slow weapons projectile

**Recommendation:** Option A for now (simpler), add projectiles later
**Decision:** Sure, Option A for now.  Likely C later. 

### Q14: Melee Attack Shape?
**Options:**
- A) **Arc/Cone** - 90-degree swing in front
- B) **Circle** - Hits all around player
- C) **Line/Thrust** - Narrow line in aim direction
- D) **Weapon-specific** - Swords arc, spears thrust, etc.

**Recommendation:** Option D - more weapon variety
**Decision:** D

### Q15: Can Enemies Drop Equipment?
**Options:**
- A) **Materials only** - Enemies drop crafting materials
- B) **Full loot tables** - Can drop weapons, armor, etc.
- C) **Rare equipment** - Mostly materials, rare chance for gear

**Recommendation:** Option C - gear is exciting but crafting stays relevant
**Decision:** C

---

## Phase 1: Player Health & Combat State (3-4 hours)

### 1.1 Extend PlayerState with Combat Data
- [ ] Add to `shared/player/player_state.gd`:
  - [ ] `current_hp: float` - Current health points
  - [ ] `max_hp: float` - Maximum health (from stats)
  - [ ] `is_dead: bool` - Death state flag
  - [ ] `last_damage_time: float` - For damage cooldown/regen
  - [ ] `attack_cooldown: float` - Time until next attack allowed
  - [ ] Update `to_dict()` / `from_dict()` for new fields

### 1.2 Health Regeneration
- [ ] Server-side HP regen tick (uses HP_REGEN stat)
- [ ] Only regen when out of combat (5 seconds since last damage)
- [ ] Clamp to max_hp

### 1.3 Death & Corpse Run System
- [ ] On death: Create player corpse at death location
- [ ] Player corpse contains all inventory items (not equipped gear)
- [ ] Respawn at nearest safe zone (checkpoint/town)
- [ ] Brief invulnerability after respawn (2 seconds)
- [ ] Must return to corpse to recover items (configurable timeout)
- [ ] Corpse despawn timer (e.g., 10 minutes) - items lost if not recovered
- [ ] Option: Equipped gear takes durability hit instead of dropping

### 1.4 Player Corpse Entity
- [ ] Create `shared/entities/player_corpse.gd`:
  - [ ] `player_id: String` - Who died
  - [ ] `position: Vector2` - Death location
  - [ ] `inventory_data: Dictionary` - Serialized inventory
  - [ ] `death_time: float` - For despawn timer
  - [ ] `recovered: bool` - Has owner retrieved items
- [ ] Server tracks active corpses per player (max 1 at a time?)
- [ ] Client renders corpse marker on map/world

---

## Phase 2: Attack Input & Network Messages (4-5 hours)

### 2.1 Client Attack Input
- [ ] Modify `client/player/player_input.gd`:
  - [ ] Left-click = primary attack (melee or ranged based on weapon)
  - [ ] Track mouse button state for held attacks
  - [ ] Attack cooldown display on HUD

### 2.2 New Message Types
- [ ] Add to `shared/network/message_types.gd`:
  ```
  ATTACK_REQUEST = 30      # Client requests attack
  ATTACK_RESULT = 31       # Server confirms hit/miss/damage
  ENTITY_DAMAGED = 32      # Broadcast damage to entity
  ENTITY_DIED = 33         # Broadcast entity death
  ENTITY_SPAWN = 34        # New entity spawned
  ENTITY_DESPAWN = 35      # Entity removed
  ENTITY_UPDATE = 36       # Entity state update (position, hp, etc.)
  PLAYER_DIED = 37         # Player death notification
  PLAYER_RESPAWN = 38      # Player respawn notification
  ```

### 2.3 Serialization Helpers
- [ ] Add to `shared/network/serialization.gd`:
  - [ ] `encode_attack_request(target_id, attack_type, aim_position)`
  - [ ] `encode_attack_result(success, target_id, damage, is_crit, target_hp)`
  - [ ] `encode_entity_spawn(entity_data)`
  - [ ] `encode_entity_update(entity_id, position, hp, state)`
  - [ ] `encode_entity_died(entity_id, killer_id, loot_data)`

---

## Phase 3: Enemy Entity System (6-8 hours)

### 3.1 Base Enemy Class
- [ ] Create `shared/entities/entity_base.gd`:
  ```gdscript
  class_name EntityBase
  extends RefCounted

  var id: String
  var entity_type: String  # "rabbit", "wolf", etc.
  var position: Vector2
  var velocity: Vector2
  var current_hp: float
  var max_hp: float
  var is_dead: bool
  var facing_angle: float

  # Combat stats
  var base_damage: float
  var attack_range: float
  var attack_cooldown: float
  var move_speed: float
  var aggro_range: float
  var leash_range: float  # Max distance from spawn before reset

  # Loot table reference
  var loot_table_id: String

  func to_dict() -> Dictionary
  static func from_dict(data: Dictionary) -> EntityBase
  ```

### 3.2 Enemy Definition Registry
- [ ] Create `shared/entities/enemy_definition.gd`:
  ```gdscript
  class_name EnemyDefinition
  extends RefCounted

  var id: String              # "rabbit", "wolf"
  var display_name: String    # "Forest Rabbit"
  var max_hp: float
  var base_damage: float
  var attack_range: float     # Melee range
  var attack_cooldown: float  # Seconds between attacks
  var move_speed: float
  var aggro_range: float      # Distance to detect players
  var leash_range: float      # Distance before reset to spawn
  var xp_reward: int
  var loot_table_id: String
  var pack_size_min: int      # Min enemies in pack
  var pack_size_max: int      # Max enemies in pack
  var behavior_type: String   # "passive", "aggressive", "territorial"
  ```

### 3.3 Enemy Registry
- [ ] Create `shared/entities/enemy_registry.gd`:
  - [ ] Register enemy definitions
  - [ ] Get definition by ID
  - [ ] Create entity instance from definition

### 3.4 Starter Enemies
- [ ] Create `shared/data/enemy_database.gd`:
  ```gdscript
  # Rabbit - passive, flees when attacked
  - id: "rabbit"
  - display_name: "Forest Rabbit"
  - max_hp: 15
  - base_damage: 2
  - attack_range: 20
  - move_speed: 120
  - aggro_range: 0 (passive)
  - leash_range: 200
  - xp_reward: 5
  - pack_size: 2-4
  - behavior: "passive"  # Runs away when hit

  # Wolf - aggressive, pack hunter
  - id: "wolf"
  - display_name: "Timber Wolf"
  - max_hp: 40
  - base_damage: 8
  - attack_range: 30
  - move_speed: 150
  - aggro_range: 150
  - leash_range: 300
  - xp_reward: 20
  - pack_size: 3-5
  - behavior: "aggressive"  # Attacks on sight
  ```

---

## Phase 4: Server Enemy Management (6-8 hours)

### 4.1 Enemy Manager
- [ ] Create `server/entities/enemy_manager.gd`:
  ```gdscript
  var active_enemies: Dictionary  # id -> EntityBase
  var spawn_points: Array[SpawnPoint]
  var enemy_registry: EnemyRegistry

  func spawn_enemy(definition_id: String, position: Vector2) -> EntityBase
  func spawn_pack(definition_id: String, center: Vector2) -> Array[EntityBase]
  func despawn_enemy(enemy_id: String, reason: String)
  func get_enemies_in_range(position: Vector2, radius: float) -> Array
  func tick(delta: float)  # AI updates
  ```

### 4.2 Spawn System
- [ ] Create `server/entities/spawn_point.gd`:
  ```gdscript
  var position: Vector2
  var enemy_type: String
  var pack_size_min: int
  var pack_size_max: int
  var respawn_time: float      # Seconds until respawn
  var current_enemies: Array   # Currently spawned from this point
  var last_clear_time: float   # When pack was fully killed
  ```

### 4.3 Pack Spawning Logic
- [ ] Spawn enemies in cluster around spawn point
- [ ] Random offset within radius (e.g., 50-100 pixels)
- [ ] Track pack membership for coordinated behavior
- [ ] Respawn full pack when all members dead + timer elapsed

### 4.4 Enemy State Sync
- [ ] Broadcast enemy spawns to nearby players
- [ ] Broadcast position/state updates (throttled, ~10/sec)
- [ ] Broadcast deaths and despawns
- [ ] Send full enemy list on player connect/chunk load

---

## Phase 5: Enemy AI & Behavior (6-8 hours)

### 5.1 AI State Machine
- [ ] Create `server/entities/enemy_ai.gd`:
  ```gdscript
  enum State { IDLE, PATROL, CHASE, ATTACK, FLEE, RESET, DEAD }

  var current_state: State
  var target_player_id: String
  var spawn_position: Vector2
  var last_attack_time: float
  ```

### 5.2 Behavior Types

#### Passive (Rabbit)
- [ ] IDLE: Wander randomly near spawn
- [ ] On damage: Switch to FLEE state
- [ ] FLEE: Run away from attacker for 3 seconds
- [ ] After flee: Return to spawn area

#### Aggressive (Wolf)
- [ ] IDLE: Patrol near spawn
- [ ] Player enters aggro_range: Switch to CHASE
- [ ] CHASE: Move toward target player
- [ ] In attack_range: Switch to ATTACK
- [ ] ATTACK: Deal damage on cooldown
- [ ] Target dies or leaves leash_range: RESET
- [ ] RESET: Return to spawn, heal to full

### 5.3 Pack Coordination
- [ ] When one pack member aggros, alert others
- [ ] Pack members share target
- [ ] Spread out during combat (avoid stacking)

### 5.4 Leashing
- [ ] Track distance from spawn point
- [ ] If exceeds leash_range, reset to spawn
- [ ] Heal to full on reset
- [ ] Clear aggro table

---

## Phase 6: Server Combat Processing (5-6 hours)

### 6.1 Attack Handler
- [ ] Modify `server/game_server.gd`:
  ```gdscript
  func _handle_attack_request(peer_id: int, data: Dictionary):
      # Validate player can attack (not dead, cooldown ready)
      # Get equipped weapon
      # Determine attack type (melee/ranged)
      # Find valid targets in range/cone
      # Calculate damage using CombatCalculator
      # Apply damage to targets
      # Send results to attacker
      # Broadcast damage to all players
  ```

### 6.2 Melee Attack Logic
- [ ] Check attack_range (weapon range + player hitbox)
- [ ] Cone-shaped hitbox in facing direction (90 degrees)
- [ ] Can hit multiple enemies in swing
- [ ] Use weapon's attack_speed for cooldown

### 6.3 Ranged Attack Logic
- [ ] Raycast from player toward aim_position
- [ ] Check max range (weapon dependent)
- [ ] First entity hit takes damage
- [ ] Future: Projectile travel time (for now, hitscan)

### 6.4 Damage Application
- [ ] Call `CombatCalculator.calculate_melee_damage()` or ranged
- [ ] Apply final_damage to target HP
- [ ] Check for death
- [ ] Use weapon durability
- [ ] Grant XP on kill

---

## Phase 7: Loot System (4-5 hours)

### 7.1 Loot Tables
- [ ] Create `shared/loot/loot_table.gd`:
  ```gdscript
  class_name LootTable

  var id: String
  var entries: Array[LootEntry]

  class LootEntry:
      var item_id: String
      var min_count: int
      var max_count: int
      var weight: float      # Relative probability
      var quality_min: float
      var quality_max: float

  func roll(luck_bonus: float) -> Array[ItemStack]
  ```

### 7.2 Individual Loot (Instanced)
- [ ] Each player who dealt damage gets their own loot roll
- [ ] Loot is instanced per-player (only they can see/pickup)
- [ ] Modify `WorldItem`:
  - [ ] Add `visible_to_players: Array[String]` (empty = visible to all)
- [ ] Server tracks damage contribution per player

### 7.3 Loot Drop Flow
- [ ] On enemy death:
  1. Get all players who damaged this enemy
  2. For each player: Roll loot table (modified by LUCK stat)
  3. Spawn WorldItems visible only to that player
  4. Items have standard despawn timer (5 minutes)

### 7.4 Starter Loot Tables
```gdscript
# Rabbit
- 80%: Nothing
- 15%: Raw Meat x1
- 5%: Rabbit Fur x1

# Wolf
- 60%: Nothing
- 25%: Raw Meat x1-2
- 10%: Wolf Pelt x1
- 5%: Wolf Fang x1
```

---

## Phase 8: Client Combat Visuals (5-6 hours)

### 8.1 Enemy Rendering
- [ ] Create `client/entities/enemy_visual.gd`:
  - [ ] Sprite (colored rectangle placeholder)
  - [ ] Health bar above enemy
  - [ ] Facing direction indicator
  - [ ] Death animation (fade out)

### 8.2 Attack Animations
- [ ] Create `client/player/attack_visual.gd`:
  - [ ] Melee: Swing arc effect
  - [ ] Ranged: Muzzle flash + beam/tracer
  - [ ] Hit confirmation: Damage number popup

### 8.3 Damage Numbers
- [ ] Create `client/ui/damage_number.gd`:
  - [ ] Float upward and fade
  - [ ] Color by damage type (white normal, yellow crit, red player damage)
  - [ ] Scale by damage amount

### 8.4 Player Health UI
- [ ] Add health bar to HUD
- [ ] Show current/max HP
- [ ] Flash red on damage
- [ ] Death overlay with respawn timer

### 8.5 Combat Feedback
- [ ] Screen shake on hit (small)
- [ ] Screen flash on taking damage
- [ ] Audio hooks (placeholder for sound system)

---

## Phase 9: Weapons Integration (3-4 hours)

### 9.1 Weapon Types
- [ ] Add weapon_type to ItemDefinition:
  ```gdscript
  enum WeaponType { MELEE, RANGED }
  var weapon_type: WeaponType
  var projectile_speed: float  # 0 = hitscan
  var attack_arc: float        # Melee swing angle (degrees)
  ```

### 9.2 Starter Weapons
- [ ] Update `shared/data/item_database.gd`:
  ```gdscript
  # Basic Sword (existing, add weapon_type)
  - weapon_type: MELEE
  - attack_arc: 90
  - base_damage: 10
  - attack_speed: 1.0

  # Basic Raygun (new)
  - id: "basic_raygun"
  - name: "Basic Raygun"
  - type: WEAPON
  - weapon_type: RANGED
  - base_damage: 8
  - attack_speed: 1.5
  - attack_range: 400
  - projectile_speed: 0 (hitscan)
  ```

### 9.3 Weapon Switching
- [ ] Hotbar weapon = current weapon
- [ ] Attack uses selected hotbar slot's weapon
- [ ] No weapon = unarmed (low damage, melee only)

---

## Phase 10: Testing & Polish (4-5 hours)

### 10.1 Unit Tests
- [ ] Test enemy spawning/despawning
- [ ] Test damage calculations with enemies
- [ ] Test loot table rolling
- [ ] Test pack behavior
- [ ] Test leashing and reset

### 10.2 Integration Tests
- [ ] Full combat flow: attack -> damage -> death -> loot
- [ ] Multiple players attacking same enemy
- [ ] Individual loot verification
- [ ] Respawn timer verification

### 10.3 Balance Tuning
- [ ] Enemy HP vs player damage
- [ ] Attack cooldowns feel good
- [ ] Pack sizes appropriate
- [ ] Loot drop rates satisfying

---

## Network Message Flow

### Player Attacks Enemy
```
1. Client: Left-click detected
2. Client: Send ATTACK_REQUEST(target_pos, attack_type)
3. Server: Validate attack (cooldown, range, weapon)
4. Server: Find entities in attack hitbox
5. Server: Calculate damage for each hit
6. Server: Apply damage, check deaths
7. Server: Send ATTACK_RESULT to attacker
8. Server: Broadcast ENTITY_DAMAGED to all nearby
9. If killed: Broadcast ENTITY_DIED, spawn loot
10. Client: Play attack animation
11. Client: Show damage numbers
```

### Enemy Attacks Player
```
1. Server: Enemy AI tick - in ATTACK state
2. Server: Check attack cooldown
3. Server: Calculate damage using CombatCalculator
4. Server: Apply damage to player HP
5. Server: Broadcast ENTITY_DAMAGED (player)
6. If killed: Broadcast PLAYER_DIED
7. Client: Flash screen, show damage
8. If dead: Show death overlay, respawn timer
```

---

## File Structure

```
shared/
├── components/                    # Composition-based entity system (Q12)
│   ├── health_component.gd        # HP, damage, death - used by players AND enemies
│   ├── combat_component.gd        # Attack stats, cooldowns, damage dealing
│   ├── movement_component.gd      # Position, velocity, collision
│   └── loot_component.gd          # Loot table reference, drop logic
├── entities/
│   ├── entity_base.gd             # Minimal base with ID + components
│   ├── enemy_definition.gd        # Static enemy type data
│   ├── enemy_registry.gd
│   └── player_corpse.gd           # Corpse run system (Q6)
├── loot/
│   ├── loot_table.gd
│   └── loot_entry.gd
├── data/
│   ├── enemy_database.gd
│   └── loot_database.gd
└── combat/
    ├── combat_calculator.gd (existing)
    └── tool_calculator.gd (existing)

server/
├── entities/
│   ├── enemy_manager.gd
│   ├── enemy_ai.gd
│   ├── spawn_point.gd
│   └── corpse_manager.gd          # Track player corpses
└── combat/
    └── combat_handler.gd

client/
├── entities/
│   ├── enemy_visual.gd
│   └── corpse_visual.gd           # Render player corpses
├── player/
│   └── attack_visual.gd
└── ui/
    ├── damage_number.gd
    ├── health_bar.gd
    └── corpse_marker.gd           # Map/minimap corpse indicator
```

---

## Estimated Timeline

| Phase | Hours | Description |
|-------|-------|-------------|
| 1. Player Health & Combat State | 3-4 | HP, death, respawn |
| 2. Attack Input & Messages | 4-5 | Input, network protocol |
| 3. Enemy Entity System | 6-8 | Base classes, definitions |
| 4. Server Enemy Management | 6-8 | Spawning, sync, packs |
| 5. Enemy AI & Behavior | 6-8 | State machine, behaviors |
| 6. Server Combat Processing | 5-6 | Attack validation, damage |
| 7. Loot System | 4-5 | Tables, individual loot |
| 8. Client Combat Visuals | 5-6 | Rendering, feedback |
| 9. Weapons Integration | 3-4 | Melee/ranged, raygun |
| 10. Testing & Polish | 4-5 | Tests, balance |
| **Total** | **46-59** | |

---

## Success Criteria

- [ ] Player can left-click to attack with equipped weapon
- [ ] Melee attacks hit enemies in arc in front of player
- [ ] Ranged attacks hit first enemy in aim direction
- [ ] Rabbits spawn in packs, flee when attacked
- [ ] Wolves spawn in packs, aggressively hunt players
- [ ] Enemies deal damage to players
- [ ] Players can die and respawn
- [ ] Killed enemies drop loot visible only to killer
- [ ] Each player gets individual loot rolls
- [ ] Enemies respawn after timer when pack is cleared
- [ ] All combat is server-authoritative
- [ ] 50+ new tests covering combat system

---

## Future Considerations (Not in Scope)

- Projectile-based ranged (vs hitscan)
- Boss enemies with special attacks
- Status effects (poison, stun, slow)
- Knockback physics
- PvP combat
- Threat/aggro table for MMO-style tanking
- Enemy abilities and special attacks
- Companion/pet system
