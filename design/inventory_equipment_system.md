# Inventory, Equipment & Progression System Design

## Overview

A deep but accessible progression system with multiple viable paths. Players advance through material tiers, skill development, and equipment crafting. Combat is one option among many - crafters, explorers, and fighters all have meaningful progression.

**Core Philosophy:**
- Material tier = power (no RNG rarity)
- Skills level by doing
- Death is punishing but not devastating (corpse run, fully retrievable)
- Crafters can make things fighters can't get, and vice versa
- Heavy skill system with meaningful choices
- **NO PERMANENT PROGRESSION BLOCKS** (see below)

---

## No Dead Ends Design Principle

**Critical Rule: Players must never be permanently stuck.**

If a player encounters content too difficult for their current build, they can ALWAYS:

### Alternative Progression Paths

| Blocked By | Escape Routes |
|------------|---------------|
| Monster too strong | Mine better materials → craft better gear |
| Can't mine ore (need better pick) | Kill enemies that drop ore/ingots |
| Can't craft item (low skill) | Trade with other players, buy from NPCs |
| Hazard zone inaccessible | Craft/buy resistance gear, level Survival skill |
| Boss too hard | Grind any skill to get stat bonuses, craft consumables |

### Guaranteed Fallbacks

1. **Basic resources always available:** Stone, Copper, Fiber spawn in safe zones infinitely
2. **Starter gear craftable by anyone:** No skill requirements for Tier 1 items
3. **NPCs sell essentials:** Basic tools, food, potions always purchasable
4. **No exclusive class locks:** Any player can learn any skill eventually
5. **Trading always possible:** Combat-focused players can buy crafted gear
6. **Skill XP from multiple sources:** Mining gives Smithing XP bonus, etc.

### Stat Bonuses from Skills

Every skill grants passive stat bonuses, meaning ANY focused grinding improves combat:

| Skill Level | Bonus |
|-------------|-------|
| 25 | +2 to related primary stat |
| 50 | +5 to related primary stat |
| 75 | +8 to related primary stat |
| 99 | +12 to related primary stat, +2 all stats |

**Examples:**
- Mining 50 → +5 Strength → Better melee damage
- Cooking 50 → +5 Vitality → More HP
- Smithing 50 → +5 Efficiency → But also +5 Fortitude (crafted items tougher)

This means a pure crafter who never fights still gets stronger over time.

---

## Material Tiers

Materials gate progression. Higher tier = better base stats, access to new recipes.

| Tier | Materials | Found In | Tool Required |
|------|-----------|----------|---------------|
| 1 - Primitive | Stone, Copper, Fiber, Wood | Surface, safe zones | Bare hands / Stone tools |
| 2 - Basic | Iron, Leather, Glass, Coal | Shallow caves, common enemies | Copper tools |
| 3 - Intermediate | Steel, Silver, Titanium, Crystals | Deep caves, dangerous biomes | Iron tools |
| 4 - Advanced | Plasma Cores, Nanofiber, Alloys, Circuits | Hazard zones, bosses | Steel/Titanium tools |
| 5 - Exotic | Void Shards, Quantum Dust, Living Metal | Rare spawns, raids, deep space | Advanced tech tools |

### Material Properties

Each material has inherent properties affecting crafted items:

```
Material:
  - id: "iron"
  - name: "Iron"
  - tier: 2
  - weight_per_unit: 0.5
  - base_durability: 100
  - base_damage: 10
  - base_armor: 5
  - special_properties: []

Material:
  - id: "nanofiber"
  - name: "Nanofiber"
  - tier: 4
  - weight_per_unit: 0.1
  - base_durability: 300
  - base_damage: 5
  - base_armor: 25
  - special_properties: ["lightweight", "flexible"]
```

---

## Equipment System

### Equipment Slots (8 total)

```
        [Head]              [Accessory 1]
        [Chest]             [Accessory 2]
        [Legs]
        [Boots]

[Main Hand]    [Off Hand]
```

| Slot | Purpose | Example Items |
|------|---------|---------------|
| Head | Protection, sensors | Helmets, Goggles, Scanner Visor |
| Chest | Main armor, life support | Chestplates, Suits, Robes |
| Legs | Protection, mobility | Leggings, Cargo Pants |
| Boots | Protection, movement | Boots, Rocket Boots, Flippers |
| Main Hand | Primary tool/weapon | Pickaxe, Sword, Rifle, Staff |
| Off Hand | Secondary/utility | Shield, Lantern, Scanner, Dagger |
| Accessory 1-2 | Utility bonuses | Jetpack, O2 Tank, Lucky Charm, Belt |

### Hotbar (8 slots)

Quick-access bar for frequently used items:
- Tools and weapons (can equip to main hand from here)
- Consumables (food, potions, bandages)
- Placeable items (torches, blocks)
- Number keys 1-8 to select

---

## Item Structure

### Base Item Definition

```gdscript
class_name ItemDefinition
extends Resource

enum ItemType {
    MATERIAL,
    TOOL,
    WEAPON,
    ARMOR,
    ACCESSORY,
    CONSUMABLE,
    PLACEABLE,
    BLUEPRINT,
    ENCHANT_CORE
}

enum EquipSlot {
    NONE,
    HEAD,
    CHEST,
    LEGS,
    BOOTS,
    MAIN_HAND,
    OFF_HAND,
    ACCESSORY
}

@export var id: String
@export var name: String
@export var description: String
@export var type: ItemType
@export var equip_slot: EquipSlot
@export var tier: int = 1
@export var max_stack: int = 1  # 1 for equipment, 99 for materials
@export var weight: float = 1.0
@export var base_durability: int = 100  # 0 = no durability
@export var base_stats: Dictionary = {}  # stat_name -> value
@export var socket_count: int = 0
@export var set_id: String = ""  # For set bonuses
@export var icon_path: String
```

### Item Instance (runtime)

```gdscript
class_name ItemInstance
extends RefCounted

var definition: ItemDefinition
var instance_id: String  # Unique ID for this specific item
var current_durability: int
var enchantments: Array[Enchantment] = []
var socketed_gems: Array[Gem] = []
var crafted_by: String = ""  # Player ID who crafted it
var quality: float = 1.0  # Crafting skill affects this (0.8 - 1.2)

func get_effective_stats() -> Dictionary:
    var stats := definition.base_stats.duplicate()

    # Apply quality modifier
    for stat in stats:
        stats[stat] = int(stats[stat] * quality)

    # Apply enchantment bonuses
    for enchant in enchantments:
        for stat in enchant.stat_bonuses:
            stats[stat] = stats.get(stat, 0) + enchant.stat_bonuses[stat]

    # Apply gem bonuses
    for gem in socketed_gems:
        for stat in gem.stat_bonuses:
            stats[stat] = stats.get(stat, 0) + gem.stat_bonuses[stat]

    return stats

func get_display_name() -> String:
    var prefix := ""
    if enchantments.size() > 0:
        prefix = enchantments[0].name_prefix + " "
    return prefix + definition.name
```

---

## Stats System

### Primary Stats

| Stat | Effect | Base Value |
|------|--------|------------|
| max_hp | Maximum health | 100 |
| hp_regen | HP regenerated per second | 1 |
| max_energy | Energy pool for abilities/tools | 100 |
| energy_regen | Energy regenerated per second | 5 |
| strength | Melee damage, carry capacity | 10 |
| precision | Ranged damage, crit chance | 10 |
| fortitude | Damage reduction, hazard resist | 10 |
| efficiency | Harvest speed, craft speed | 10 |
| luck | Drop rates, crit damage | 10 |

### Derived Stats (calculated)

```gdscript
func calculate_derived_stats(primary: Dictionary) -> Dictionary:
    return {
        "carry_capacity": 20 + (primary.strength * 5),  # Weight units
        "melee_damage_mult": 1.0 + (primary.strength * 0.02),
        "ranged_damage_mult": 1.0 + (primary.precision * 0.02),
        "crit_chance": 0.05 + (primary.precision * 0.005),
        "crit_damage": 1.5 + (primary.luck * 0.02),
        "damage_reduction": primary.fortitude * 0.01,  # 1% per point
        "harvest_speed_mult": 1.0 + (primary.efficiency * 0.03),
        "move_speed_mult": 1.0,  # Modified by equipment
    }
```

### Hazard Resistances

Separate from main stats, come primarily from equipment:

| Resistance | Protects Against |
|------------|------------------|
| heat_resist | Lava, fire zones, burning |
| cold_resist | Ice biomes, freezing water |
| radiation_resist | Radioactive zones, certain enemies |
| toxic_resist | Poison, acid, gas clouds |
| pressure_resist | Deep water, space vacuum |

---

## Enchantment System

### Enchantment Structure

```gdscript
class_name Enchantment
extends Resource

@export var id: String
@export var name: String
@export var name_prefix: String  # "Flaming", "Swift", etc.
@export var tier: int  # I, II, III (1-3)
@export var max_tier: int = 3
@export var stat_bonuses: Dictionary = {}  # Per tier
@export var special_effect: String = ""  # Effect ID
@export var compatible_slots: Array[ItemDefinition.EquipSlot]
@export var incompatible_with: Array[String]  # Other enchant IDs
```

### Enchantment Examples

| Enchantment | Tier I | Tier II | Tier III | Special |
|-------------|--------|---------|----------|---------|
| Flame | +5 heat_resist | +10 heat_resist | +15 heat_resist | Fire immunity at III |
| Swift | +5% move_speed | +10% move_speed | +15% move_speed | - |
| Vampiric | 2% life steal | 4% life steal | 6% life steal | - |
| Unbreaking | +25% durability | +50% durability | +100% durability | No durability loss at III |
| Efficient | +10% harvest | +20% harvest | +30% harvest | - |
| Weighted | +3 strength | +6 strength | +10 strength | -5% move_speed |
| Sharp | +5 melee dmg | +10 melee dmg | +15 melee dmg | Weapons only |
| Precise | +3% crit | +6% crit | +10% crit | - |

### Enchantment Slots

Items have configurable enchantment slot counts based on item type and tier:

| Item Type | Tier 1-2 | Tier 3-4 | Tier 5 |
|-----------|----------|----------|--------|
| Weapons | 1-2 slots | 2-3 slots | 3-4 slots |
| Armor | 1 slot | 2 slots | 2-3 slots |
| Accessories | 1 slot | 1-2 slots | 2 slots |
| Tools | 1 slot | 2 slots | 2-3 slots |

### Enchantment Mutex Groups

Some enchantments conflict and cannot be on the same item:

| Group | Enchantments | Reason |
|-------|--------------|--------|
| Element | Flame, Frost, Shock, Toxic | Conflicting damage types |
| Lifesteal | Vampiric, Berserker | Both heal, different mechanics |
| Speed | Swift, Weighted | Opposite movement effects |
| Durability | Unbreaking, Disposable | Opposite durability effects |

**Rules:**
- Only one enchant from each mutex group per item
- Non-mutex enchants stack freely up to slot limit
- Example valid combo: Flame I + Vampiric II + Precise III (3 slots, no conflicts)
- Example invalid: Flame II + Frost I (same mutex group)

### Applying Enchantments

- Requires **Enchantment Core** (tier must match or exceed enchant tier)
- Requires **Enchanting Station** (higher tier stations for higher enchants)
- Requires **Enchanting Skill** (skill level gates enchant tier access)
- Can add enchants up to slot limit
- Can overwrite specific enchantment slot (destroys old one in that slot)
- Mutex violations prevented by UI/server

---

## Socket & Gem System

### Sockets

- Equipment can have 0-3 sockets based on tier and type
- Tier 1-2: 0-1 sockets
- Tier 3-4: 1-2 sockets
- Tier 5: 2-3 sockets
- Crafting skill can add +1 socket (rare)

### Gems

```gdscript
class_name Gem
extends Resource

@export var id: String
@export var name: String
@export var tier: int
@export var stat_bonuses: Dictionary
@export var color: Color  # For visual display
```

| Gem | Tier 1 | Tier 2 | Tier 3 |
|-----|--------|--------|--------|
| Ruby (Red) | +3 strength | +6 strength | +10 strength |
| Sapphire (Blue) | +10 max_energy | +20 max_energy | +35 max_energy |
| Emerald (Green) | +3 efficiency | +6 efficiency | +10 efficiency |
| Diamond (White) | +2 all stats | +4 all stats | +6 all stats |
| Onyx (Black) | +5 fortitude | +10 fortitude | +15 fortitude |
| Topaz (Yellow) | +3 luck | +6 luck | +10 luck |

- Gems can be removed (requires tool, may have failure chance)
- Gems can be combined: 3x Tier N = 1x Tier N+1

---

## Set Bonuses

### Set Definition

```gdscript
class_name EquipmentSet
extends Resource

@export var id: String
@export var name: String
@export var piece_ids: Array[String]  # Item definition IDs
@export var bonuses: Dictionary  # piece_count -> bonus_dict
```

### Example Sets

**Iron Guardian Set** (Tier 2)
- Pieces: Iron Helm, Iron Chestplate, Iron Leggings, Iron Boots
- 2pc: +10 max_hp
- 4pc: +15% damage reduction, Thorns (reflect 5% damage)

**Nanofiber Infiltrator Set** (Tier 4)
- Pieces: Nano Visor, Nano Suit, Nano Leggings, Nano Boots
- 2pc: +15% move_speed
- 4pc: -50% detection range, +20% crit damage

**Explorer's Garb** (Tier 3, mixed)
- Pieces: Explorer Hat, Explorer Vest, Explorer Pants, Explorer Boots, Explorer Pack (accessory)
- 2pc: +20% harvest speed
- 3pc: +25% hazard resistance (all types)
- 5pc: Double resource drops, Auto-map reveal

---

## Durability System

### Durability Mechanics

- All tools/weapons/armor have durability
- Durability decreases with use:
  - Tools: -1 per block mined/action
  - Weapons: -1 per hit
  - Armor: -1 per hit taken
- At 0 durability: item breaks, becomes "Broken [Item]"
- Broken items provide no stats, cannot be used
- Repair at Repair Station with materials

### Repair Costs

```
Repair Cost = (Max Durability - Current) / Max Durability * Base Material Cost

Example: Iron Pickaxe at 20/100 durability
- Needs 80% of materials
- Base cost: 3 Iron Ingots
- Repair cost: 2.4 → 3 Iron Ingots (rounded up)
```

### Durability Modifiers

- **Unbreaking Enchantment**: Reduces durability loss
  - Tier I: 25% chance to not lose durability
  - Tier II: 50% chance
  - Tier III: Never loses durability
- **Quality**: Higher quality = more base durability
- **Material**: Higher tier materials = more durability

---

## Inventory System

### Inventory Structure

```gdscript
class_name PlayerInventory
extends RefCounted

# Equipment slots
var equipment: Dictionary = {
    "head": null,
    "chest": null,
    "legs": null,
    "boots": null,
    "main_hand": null,
    "off_hand": null,
    "accessory_1": null,
    "accessory_2": null,
}

# Hotbar (8 slots, references to inventory items or equipment)
var hotbar: Array[ItemStack] = []  # Size 8

# Main inventory (grid)
var inventory: Array[ItemStack] = []  # Dynamic size based on capacity

# Calculated
var current_weight: float = 0.0
var max_weight: float = 100.0  # From carry_capacity stat

func can_add_item(item: ItemInstance, count: int = 1) -> bool:
    var added_weight := item.definition.weight * count
    return current_weight + added_weight <= max_weight

func get_free_slots() -> int:
    var used := 0
    for stack in inventory:
        if stack != null:
            used += 1
    return inventory.size() - used
```

### Item Stack

```gdscript
class_name ItemStack
extends RefCounted

var item: ItemInstance  # For equipment, this is the actual item
var count: int = 1      # For stackables

func can_merge_with(other: ItemStack) -> bool:
    if item.definition.id != other.item.definition.id:
        return false
    if item.definition.max_stack <= 1:
        return false
    return count + other.count <= item.definition.max_stack
```

### Weight System

- Every item has weight
- Total carried weight vs max carry capacity
- Over capacity: Cannot pick up more, movement penalty
- Equipment weight counts while equipped

---

## Death & Drop System

### On Death (Default: Corpse Run)

**Everything drops, but everything is retrievable:**

1. **Creates "Corpse" at death location containing:**
   - All equipped items
   - All inventory contents (materials, equipment, consumables)
   - Hotbar contents
   - Basically everything except learned blueprints/skills

2. **Corpse Properties:**
   - Visible on map with marker (configurable)
   - Persists indefinitely or timed (configurable, default: forever)
   - Only the dead player can loot their own corpse (configurable)
   - Protected from other players (configurable for PvP servers)
   - Contains exact items - nothing destroyed

3. **Respawn:**
   - Player spawns with nothing (or basic starter kit, configurable)
   - At last activated respawn point (bed, base beacon)
   - Or world spawn if none set
   - Can immediately attempt corpse recovery

4. **Recovery:**
   - Return to corpse location
   - Interact to open corpse inventory
   - Take back items (weight limit applies)
   - May need multiple trips for heavy loads
   - Corpse disappears when empty

### Server Configuration

```gdscript
enum DeathPenalty {
    NONE,           # Keep everything, no drop
    CORPSE_RUN,     # Default - drop all to corpse, retrievable
    PARTIAL_DROP,   # Drop materials only, keep equipment
    HARDCORE        # Drop all, corpse can be looted by others
}

@export var corpse_duration_minutes: int = -1  # -1 = forever, 0+ = minutes until despawn
@export var corpse_map_marker: bool = true
@export var corpse_protected: bool = true  # Only owner can loot
@export var respawn_starter_kit: bool = true  # Give basic tools on respawn
```

### Starter Kit (on respawn if enabled)
- Stone Pickaxe (Tier 1)
- Stone Axe (Tier 1)
- 10x Bandages
- 5x Torches

This lets players attempt recovery without being completely helpless.

---

## Crafting System

### Recipe Structure

```gdscript
class_name CraftingRecipe
extends Resource

@export var id: String
@export var result_item_id: String
@export var result_count: int = 1
@export var ingredients: Array[RecipeIngredient]
@export var required_station: String  # Station ID
@export var required_skill: String    # Skill ID
@export var required_skill_level: int
@export var craft_time: float = 1.0   # Seconds
@export var xp_reward: int = 10       # Skill XP gained

class RecipeIngredient:
    var item_id: String
    var count: int
    var consume: bool = true  # False for tools used in crafting
```

### Crafting Stations

| Station | Tier | Recipes |
|---------|------|---------|
| Hand Crafting | 0 | Basic materials, bandages, torches |
| Workbench | 1 | Tier 1 tools, basic armor, furniture |
| Forge | 2 | Metal processing, Tier 2-3 weapons/armor |
| Advanced Workbench | 2 | Complex items, machinery parts |
| Enchanting Table | 2 | Apply enchantments |
| Fabricator | 3 | Tech items, Tier 4 equipment |
| Exotic Lab | 4 | Tier 5 items, experimental gear |

### Crafting Quality

Crafting skill affects output quality:

```gdscript
func calculate_craft_quality(skill_level: int, recipe_level: int) -> float:
    var level_diff := skill_level - recipe_level
    var base_quality := 1.0

    if level_diff < 0:
        # Under-leveled: quality penalty
        base_quality = 0.8 + (level_diff * 0.02)  # Min 0.6
    else:
        # Over-leveled: quality bonus
        base_quality = 1.0 + (level_diff * 0.01)  # Max 1.2

    # Random variance: +/- 5%
    base_quality += randf_range(-0.05, 0.05)

    return clampf(base_quality, 0.6, 1.25)
```

Quality affects:
- All stat values (multiplied by quality)
- Durability (multiplied by quality)
- Visual indicator on item ("Crude", "Standard", "Fine", "Masterwork")

---

## Skill System

### Skill Categories

**Combat Skills**
| Skill | Levels By | Effects |
|-------|-----------|---------|
| Melee Combat | Hitting enemies with melee | Damage, crit chance, combos |
| Ranged Combat | Hitting enemies at range | Damage, accuracy, reload speed |
| Defense | Taking damage, blocking | Damage reduction, block efficiency |
| Athletics | Running, jumping, dodging | Move speed, stamina, dodge iframes |

**Gathering Skills**
| Skill | Levels By | Effects |
|-------|-----------|---------|
| Mining | Mining ore/stone | Speed, double drops, rare finds |
| Woodcutting | Chopping trees | Speed, double drops, special wood |
| Foraging | Picking plants, berries | Better yields, rare finds |
| Hunting | Killing animals | Better drops, tracking ability |
| Fishing | Catching fish | Catch rate, rare fish access |

**Production Skills**
| Skill | Levels By | Effects |
|-------|-----------|---------|
| Smithing | Crafting metal items | Quality, new recipes, speed |
| Tailoring | Crafting cloth/leather | Quality, new recipes, speed |
| Engineering | Crafting tech/machines | Quality, new recipes, speed |
| Alchemy | Brewing potions | Potency, new recipes, duration |
| Enchanting | Applying enchants | Success rate, tier access |
| Cooking | Preparing food | Buff strength, duration |
| Jewelcrafting | Cutting gems, jewelry | Gem quality, socket adding |

**Utility Skills**
| Skill | Levels By | Effects |
|-------|-----------|---------|
| Exploration | Discovering areas | Map reveal range, hazard sense |
| Survival | Taking hazard damage | Hazard resistance, regen in wild |
| Trading | Buying/selling | Better prices, barter options |
| Leadership | Playing in groups | Group buff radius, shared XP |

### Skill Leveling

```gdscript
class_name Skill
extends Resource

@export var id: String
@export var name: String
@export var category: String
@export var max_level: int = 100

# XP required for each level (exponential curve)
func xp_for_level(level: int) -> int:
    return int(100 * pow(1.1, level - 1))

# Milestones grant special unlocks
@export var milestones: Dictionary = {
    10: "unlock_basic_recipes",
    25: "unlock_intermediate_recipes",
    50: "unlock_advanced_recipes",
    75: "unlock_expert_recipes",
    99: "unlock_master_recipes",
}
```

### Skill Synergies

Some skills boost others:
- Mining 50+ : +10% Smithing XP gain
- Foraging 25+ : +5% Alchemy ingredient yield
- Engineering 50+ : Enchanting can add sockets

---

## Tool Modes

### Multi-Mode Tools

Higher tier tools unlock additional modes:

**Pickaxe Modes:**
| Mode | Effect | Unlock |
|------|--------|--------|
| Standard | Mine one block | Default |
| Precision | Mine faster, drops intact ore | Tier 2 |
| Area (3x3) | Mine 9 blocks at once | Tier 3 |
| Vein | Mine entire ore vein | Tier 4, Mining 50 |
| Ore Sense | Highlight nearby ores | Tier 4, accessory |

**Weapon Modes:**
| Mode | Effect | Unlock |
|------|--------|--------|
| Standard | Normal attacks | Default |
| Heavy | Slow, high damage | Melee 25 |
| Swift | Fast, lower damage | Melee 25 |
| Charged | Hold to charge power | Tier 3 weapon |

### Mode Switching

```gdscript
# Input action to cycle modes
func _input(event):
    if event.is_action_pressed("cycle_tool_mode"):
        if equipped_tool and equipped_tool.available_modes.size() > 1:
            current_mode = (current_mode + 1) % equipped_tool.available_modes.size()
            emit_signal("mode_changed", equipped_tool.available_modes[current_mode])
```

---

## Implementation Priority

### Phase 1: Core Data Structures
1. ItemDefinition resource
2. ItemInstance class
3. Material definitions
4. Basic inventory (array-based)

### Phase 2: Equipment
1. Equipment slots
2. Stat calculation
3. Equip/unequip logic
4. Basic UI

### Phase 3: Crafting
1. Recipe definitions
2. Crafting stations
3. Basic crafting UI
4. Quality system

### Phase 4: Skills
1. Skill definitions
2. XP gain system
3. Milestone unlocks
4. Skill UI

### Phase 5: Advanced Features
1. Enchantment system
2. Socket/gem system
3. Set bonuses
4. Tool modes

### Phase 6: Polish
1. Death/drop system
2. Durability/repair
3. Trading between players
4. Full inventory UI

---

## Network Considerations

### Server Authority
- Server validates all inventory operations
- Server calculates final stats
- Client predicts for responsiveness, server confirms

### Sync Messages
- `inventory_update`: Full or delta inventory sync
- `equip_item`: Request to equip item
- `craft_request`: Request to craft recipe
- `skill_update`: Skill level/XP changes
- `item_drop`: Item dropped in world
- `item_pickup`: Item picked up

### Anti-Cheat
- Server tracks all item sources
- Crafted items logged with crafter ID
- Impossible item stacks rejected
- Stat calculations server-side only
