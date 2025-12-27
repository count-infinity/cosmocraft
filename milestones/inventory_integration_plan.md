# Inventory System Integration Plan

## Overview
Connect the existing inventory/equipment/crafting systems (6,000+ lines, 425 tests) to the actual game client/server.

## Current State
- All shared systems built and tested (items, inventory, equipment, crafting, skills, enchantments, trade, corpse)
- **431 tests passing**
- Phases 1-5 complete: Network protocol, PlayerState extension, server initialization, client sync, basic UI
- Client receives inventory data on connect and displays it in UI
- Hotbar, inventory panel, equipment panel, and item tooltips functional

---

## Phase 1: Network Protocol (4-6 hours)

### 1.1 Message Types
- [x] Add to `shared/network/message_types.gd`:
  - [x] INVENTORY_SYNC - Full inventory state (on join)
  - [x] INVENTORY_UPDATE - Delta changes to inventory
  - [x] EQUIPMENT_UPDATE - Equipment slot changes
  - [x] ITEM_PICKUP_REQUEST - Client requests to pick up item
  - [x] ITEM_PICKUP_RESPONSE - Server confirms/denies pickup
  - [x] ITEM_DROP_REQUEST - Client requests to drop item
  - [x] ITEM_DROP_RESPONSE - Server confirms drop
  - [x] ITEM_USE_REQUEST - Use consumable/tool
  - [x] EQUIP_REQUEST - Equip item from inventory
  - [x] UNEQUIP_REQUEST - Unequip item to inventory
  - [x] STATS_UPDATE - Player stats changed

### 1.2 Serialization Helpers
- [x] Add to `shared/network/serialization.gd`:
  - [x] `encode_inventory_sync(player_id, inventory, equipment, hotbar)`
  - [x] `encode_inventory_update(player_id, changes)`
  - [x] `encode_equipment_update(player_id, slot, item_data)`
  - [x] `encode_item_pickup_request(item_id, world_position)`
  - [x] `encode_item_drop_request(inventory_slot, count)`
  - [x] `encode_stats_update(player_id, stats)`
  - [x] `parse_inventory_sync(data)`
  - [x] `parse_inventory_update(data)`
  - [x] `parse_equipment_update(data)`

---

## Phase 2: PlayerState Extension (2-3 hours)

### 2.1 Extend PlayerState
- [x] Modify `shared/player/player_state.gd`:
  - [x] Add `inventory: Dictionary` field (serialized inventory data)
  - [x] Add `equipment: Dictionary` field (serialized equipment data)
  - [x] Add `hotbar: Dictionary` field (serialized hotbar data)
  - [x] Add `stats: Dictionary` field (calculated stats)
  - [x] Add `skills: Dictionary` field (skill levels/xp)
  - [x] Update `to_dict()` to include new fields
  - [x] Update `from_dict()` to restore new fields
  - [x] Update `clone()` to copy new fields

### 2.2 Tests
- [x] Add tests for extended PlayerState serialization
- [x] Verify backwards compatibility (old data without inventory)

---

## Phase 3: Server Initialization (2-3 hours)

### 3.1 Registry Setup
- [x] Create `server/data/server_registries.gd`:
  - [x] ItemRegistry singleton with base items
  - [x] EnchantmentRegistry singleton
  - [x] EquipmentSet.Registry singleton
  - [x] CraftingSystem singleton with recipes

### 3.2 Starter Items
- [x] Define starter item definitions:
  - [x] Basic Pickaxe (tool)
  - [x] Basic Axe (tool)
  - [x] Basic Sword (weapon)
  - [x] Health Potion x3 (consumable)
  - [x] Cloth Shirt (armor)
  - [x] Cloth Pants (armor)

### 3.3 Player Initialization
- [x] Modify `server/game_server.gd`:
  - [x] In `add_player()`: Create Inventory, EquipmentSlots, Hotbar, PlayerSkills
  - [x] Give starting items to new players
  - [x] Store live inventory objects (not just serialized data)
  - [x] Serialize to PlayerState for network sync

### 3.4 Server Message Handlers
- [x] Modify `server/network/message_handler.gd`:
  - [x] Handle EQUIP_REQUEST
  - [x] Handle UNEQUIP_REQUEST
  - [x] Handle ITEM_DROP_REQUEST
  - [x] Handle ITEM_USE_REQUEST
  - [x] Broadcast inventory/equipment changes to client

---

## Phase 4: Client Sync (3-4 hours)

### 4.1 Client State
- [x] Modify `client/game_client.gd`:
  - [x] Add `local_inventory: Inventory`
  - [x] Add `local_equipment: EquipmentSlots`
  - [x] Add `local_hotbar: Hotbar`
  - [x] Add `local_stats: PlayerStats`
  - [x] Add `item_registry: ItemRegistry` (loaded from shared data)

### 4.2 Client Message Handlers
- [x] Modify `client/network/message_handler.gd`:
  - [x] Add signal `inventory_sync_received`
  - [x] Add signal `inventory_update_received`
  - [x] Add signal `equipment_update_received`
  - [x] Add signal `stats_update_received`
  - [x] Parse incoming inventory messages

### 4.3 Sync on Join
- [x] On CONNECT_RESPONSE success:
  - [x] Request full inventory sync
  - [x] Initialize local inventory from server data
  - [x] Initialize local equipment from server data

---

## Phase 5: Basic Inventory UI (6-8 hours)

### 5.1 Inventory Panel
- [x] Create `client/ui/inventory_panel.gd` and `.tscn`:
  - [x] Grid layout for inventory slots (e.g., 8x5 = 40 slots)
  - [x] Show item icon, count, durability indicator
  - [x] Click to select item
  - [x] Right-click context menu (Use, Equip, Drop, Split)
  - [x] Drag-drop between slots
  - [x] Weight display (current/max)

### 5.2 Equipment Panel
- [x] Create `client/ui/equipment_panel.gd` and `.tscn`:
  - [x] Slot icons for each equipment slot (head, chest, etc.)
  - [x] Show equipped item in each slot
  - [x] Click to unequip
  - [x] Drag from inventory to equip

### 5.3 Hotbar
- [x] Create `client/ui/hotbar_ui.gd` and `.tscn`:
  - [x] 8 horizontal slots (keys 1-8)
  - [x] Show item icon and count
  - [x] Highlight selected slot
  - [x] Number keys to use/select

### 5.4 Item Tooltip
- [x] Create `client/ui/item_tooltip.gd` and `.tscn`:
  - [x] Show on hover over any item
  - [x] Display: name, type, stats, durability, quality, description
  - [x] Color-code by quality/rarity

### 5.5 Integration
- [x] Modify `client/ui/hud.gd`:
  - [x] Add hotbar to bottom of screen
  - [x] Toggle inventory panel with 'I' or 'Tab'
  - [x] Toggle equipment panel with 'C'

---

## Phase 6: Ground Items & Pickup (8-10 hours) - COMPLETE

### 6.1 WorldItem Entity
- [x] Create `shared/world/world_item.gd`:
  - [x] Unique ID
  - [x] ItemStack data
  - [x] World position
  - [x] Spawn time (for despawn timer)
  - [x] Owner ID (for loot protection)
  - [x] to_dict() / from_dict()

### 6.2 Server Ground Item Management
- [x] Modify `server/game_state.gd`:
  - [x] Add `ground_items: Dictionary` (id -> WorldItem)
  - [x] Add `spawn_item(item_stack, position, owner_id)`
  - [x] Add `remove_item(item_id)`
  - [x] Add despawn timer (5 minutes)
  - [x] Broadcast new items to nearby players

### 6.3 Item Drop Flow
- [x] Server: On ITEM_DROP_REQUEST:
  - [x] Validate player has item
  - [x] Remove from player inventory
  - [x] Spawn WorldItem at player position
  - [x] Broadcast to nearby players

### 6.4 Item Pickup Flow
- [x] Client: Detect nearby items (E or F key press)
- [x] Client: Send ITEM_PICKUP_REQUEST
- [x] Server: Validate item exists and player in range
- [x] Server: Check inventory space/weight
- [x] Server: Add to player inventory, remove from world
- [x] Server: Send ITEM_PICKUP_RESPONSE

### 6.5 Client Ground Item Rendering
- [x] Create `client/world/world_item_visual.gd`:
  - [x] Colored rectangle sprite (placeholder)
  - [x] Bobbing animation
  - [x] Glow based on quality/tier
  - [x] Label with item name

---

## Phase 7: Crafting UI (6-8 hours) - COMPLETE

### 7.1 Crafting Panel
- [x] Create `client/ui/crafting_panel.gd` and `.tscn`:
  - [x] List of available recipes (discovered only)
  - [x] Filter by category
  - [x] Search by name
  - [x] Show recipe details on select

### 7.2 Recipe Display
- [x] Show required materials with have/need counts
- [x] Show required station (if any)
- [x] Show required skill level
- [x] Show output item(s) with quality preview
- [x] Craft button (disabled if can't craft)

### 7.3 Crafting Flow
- [x] Client: Send CRAFT_REQUEST(recipe_id)
- [x] Server: Validate materials, station, skill
- [x] Server: Consume materials
- [x] Server: Calculate quality
- [x] Server: Create output items
- [x] Server: Add to inventory
- [x] Server: Grant XP
- [x] Server: Send CRAFT_RESPONSE

---

## Phase 8: Stats & Combat Integration (4-5 hours) - COMPLETE

### 8.1 Stats Display
- [x] Create `client/ui/stats_panel.gd`:
  - [x] Show all stat values organized by category (Core, Attributes, Combat, Resistances)
  - [x] Show base + bonus breakdown with color coding
  - [x] Update on equipment/skill changes
  - [x] Toggle with 'P' key via HUD

### 8.2 Combat Integration
- [x] Create `shared/combat/combat_calculator.gd`:
  - [x] `calculate_melee_damage()` - Uses STRENGTH stat for damage bonus
  - [x] `calculate_ranged_damage()` - Uses PRECISION stat for damage bonus
  - [x] `calculate_damage_reduction()` - Uses FORTITUDE stat with diminishing returns
  - [x] `calculate_crit()` - Uses CRIT_CHANCE and CRIT_DAMAGE stats
  - [x] `calculate_attack_speed()` - Combines weapon and stat speed
  - [x] `calculate_environmental_damage()` - Uses resistance stats

### 8.3 Tool Efficiency Integration
- [x] Create `shared/combat/tool_calculator.gd`:
  - [x] `calculate_gathering_efficiency()` - Uses EFFICIENCY stat for bonus
  - [x] `calculate_durability_use()` - EFFICIENCY reduces durability consumption
  - [x] `can_harvest_tier()` - Check if tool can harvest material tier
  - [x] `calculate_gather_time()` - Time based on efficiency
  - [x] `calculate_bonus_drops()` - Uses LUCK stat for bonus drops
  - [x] `get_mode_modifiers()` - Tool mode efficiency/durability tradeoffs

### 8.4 Tests
- [x] Create `tests/test_combat_calculator.gd` - Full test coverage for combat calculations
- [x] Create `tests/test_tool_calculator.gd` - Full test coverage for tool calculations

---

## Testing Checkpoints

### After Phase 3
- [ ] Server starts without errors
- [ ] New player gets starting inventory (verify in server logs)
- [ ] PlayerState includes inventory data in to_dict()

### After Phase 4
- [ ] Client receives inventory on connect
- [ ] Client can deserialize inventory data
- [ ] Local inventory object populated

### After Phase 5
- [ ] Can open/close inventory with 'I'
- [ ] Items display in grid
- [ ] Can drag items between slots
- [ ] Hotbar shows and responds to number keys

### After Phase 6
- [ ] Dropping item spawns WorldItem
- [ ] WorldItem visible to all nearby players
- [ ] Can pick up items
- [ ] Items despawn after timeout

### After Phase 7
- [ ] Crafting panel shows recipes
- [ ] Can craft items when materials available
- [ ] Quality calculated correctly
- [ ] XP granted on craft

---

## Estimated Total: 50-70 hours

| Phase | Hours | Status |
|-------|-------|--------|
| 1. Network Protocol | 4-6 | Complete |
| 2. PlayerState Extension | 2-3 | Complete |
| 3. Server Initialization | 2-3 | Complete |
| 4. Client Sync | 3-4 | Complete |
| 5. Basic Inventory UI | 6-8 | Complete |
| 6. Ground Items & Pickup | 8-10 | Complete |
| 7. Crafting UI | 6-8 | Complete |
| 8. Stats & Combat | 4-5 | Complete |

---

## Notes

- All inventory operations are **server-authoritative** (anti-cheat)
- Client predicts locally but server validates and can reject
- ItemRegistry must be identical on client and server
- Consider item definition files that both load (JSON or .tres)
