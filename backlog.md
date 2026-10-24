# Cosmocraft Development Backlog

## High Priority (Security/Bugs)

### [SEC-001] Add permission system to admin commands
**Problem:** Any connected player can execute admin commands like `/spawn`. This is a security risk in multiplayer.

**Files:** `server/commands/command_processor.gd`, `server/game_server.gd`

**Fix:** Add permission levels (PLAYER, MODERATOR, ADMIN) and check permissions before executing commands:
```gdscript
enum Permission { PLAYER, MODERATOR, ADMIN }
var _player_permissions: Dictionary = {}  # player_id -> Permission

func execute(command_text: String, player_id: String, context: CommandContext) -> Dictionary:
    var required_permission := get_command_permission(cmd)
    if not has_permission(player_id, required_permission):
        return {"success": false, "message": "Insufficient permissions"}
```

---

### [BUG-001] Hitbox radius inconsistency between combat files
**Problem:** `DEFAULT_HITBOX_RADIUS` is 16.0 in `CombatProcessor` but 20.0 in `AttackResolver`. This causes inconsistent hit detection.

**Files:**
- `server/combat/combat_processor.gd:21`
- `server/combat/attack_resolver.gd:23`

**Fix:** Define once in `GameConstants` and reference from both files:
```gdscript
# In game_constants.gd
const DEFAULT_HITBOX_RADIUS: float = 16.0

# In combat files
var radius := target.get("hitbox_radius", GameConstants.DEFAULT_HITBOX_RADIUS)
```

---

### [BUG-002] Time-based attack detection is fragile
**Problem:** `CombatProcessor` uses time tolerance (`ATTACK_TIME_TOLERANCE = 0.1`) to detect if an enemy just attacked. Network latency or game loop drift could cause attacks to be missed or double-processed.

**Files:** `server/combat/combat_processor.gd:147-149`

**Fix:** Replace with flag-based system:
```gdscript
# In EnemyState
var pending_attack: bool = false

# In combat processing
if enemy.pending_attack:
    # Process attack
    enemy.pending_attack = false
```

---

## Medium Priority (Maintainability)

### [REFACTOR-001] Implement command registry pattern
**Problem:** Adding new commands requires modifying the `match` statement and manually updating `/help`. Violates Open/Closed Principle.

**Files:** `server/commands/command_processor.gd:25-31`

**Fix:** Use a command registry:
```gdscript
var _commands: Dictionary = {}  # command_name -> {handler: Callable, help: String, permission: Permission}

func register_command(name: String, handler: Callable, help_text: String, perm: Permission) -> void:
    _commands[name] = {"handler": handler, "help": help_text, "permission": perm}

func execute(command_text: String, context: CommandContext) -> Dictionary:
    if _commands.has(cmd):
        return _commands[cmd]["handler"].call(parts, context)
    return {"success": false, "message": "Unknown command"}
```

---

### [REFACTOR-002] Create CommandContext for system access
**Problem:** `CommandProcessor` constructor only takes `EnemyManager`. Adding commands that need other systems (inventory, player state) requires changing the constructor signature.

**Files:** `server/commands/command_processor.gd:7-10`, `server/game_server.gd`

**Fix:** Create a context object:
```gdscript
class_name CommandContext
extends RefCounted

var enemy_manager: EnemyManager
var game_state: GameState
var player_id: String
var player_position: Vector2
# Add other systems as needed
```

---

### [REFACTOR-003] Extract common damage calculation logic
**Problem:** `calculate_melee_damage()` and `calculate_ranged_damage()` in `CombatCalculator` share ~80% identical code (stat multiplier, crit handling, damage reduction).

**Files:** `shared/combat/combat_calculator.gd:35-69` vs `80-122`

**Fix:** Extract shared logic to private helper:
```gdscript
static func _calculate_base_damage(
    base_damage: float,
    stat_value: float,
    base_stat: float,
    defender_fortitude: float,
    crit_chance: float,
    rng: RandomNumberGenerator
) -> DamageResult:
    # Common logic here
```

---

### [FEATURE-001] Add command history to CommandInput
**Problem:** No way to recall previously entered commands with up/down arrows.

**Files:** `client/ui/command_input.gd`

**Fix:** Add history array and handle arrow keys:
```gdscript
var _history: Array[String] = []
var _history_index: int = -1
const MAX_HISTORY: int = 50

func _input(event: InputEvent) -> void:
    if _is_active and event is InputEventKey and event.pressed:
        if event.keycode == KEY_UP:
            _navigate_history(-1)
        elif event.keycode == KEY_DOWN:
            _navigate_history(1)
```

---

### [REFACTOR-004] Create SpawnPoint class
**Problem:** Spawn points are untyped dictionaries, making it easy to misspell keys or miss required fields.

**Files:** `server/enemies/enemy_manager.gd:107-114`

**Fix:** Create typed class:
```gdscript
class_name SpawnPoint
extends RefCounted

var id: String
var definition_id: String
var position: Vector2
var respawn_time: float
var max_enemies: int
var current_enemy_id: String = ""
```

---

## Lower Priority (Code Quality)

### [CLEANUP-001] Preload scripts in AttackResolver
**Problem:** `TargetDataScript` is loaded with `load()` multiple times in different methods instead of being preloaded once.

**Files:** `server/combat/attack_resolver.gd:200-202, 207-209, 214-216, 234`

**Fix:** Add preload at top of file:
```gdscript
const TargetDataScript = preload("res://shared/combat/target_data.gd")
```

---

### [CLEANUP-002] Move hardcoded combat formulas to GameConstants
**Problem:** Balance values like base stat (10), multiplier (0.02), minimum (0.1) are hardcoded in `CombatCalculator`.

**Files:** `shared/combat/combat_calculator.gd:51-53, 96-99`

**Fix:** Move to `GameConstants`:
```gdscript
# game_constants.gd
const COMBAT_BASE_STAT: float = 10.0
const COMBAT_STAT_MULTIPLIER: float = 0.02
const COMBAT_MIN_STAT_MULT: float = 0.1
```

---

### [CLEANUP-003] Add deterministic RNG to EnemyAI
**Problem:** `EnemyAI` uses global `randf()` which makes tests non-deterministic.

**Files:** `server/enemies/enemy_ai.gd:100, 133, 137`

**Fix:** Accept optional RNG parameter like `CombatCalculator` does:
```gdscript
static func process_enemy(
    enemy: RefCounted,
    definition: RefCounted,
    player_positions: Dictionary,
    delta: float,
    current_time: float,
    rng: RandomNumberGenerator = null
) -> void:
    var rand_val := rng.randf() if rng else randf()
```

---

### [CLEANUP-004] Remove unused distance parameter in ranged damage
**Problem:** `calculate_ranged_damage()` has an unused `distance` parameter with a TODO comment.

**Files:** `shared/combat/combat_calculator.gd:101-106`

**Fix:** Either implement distance falloff or remove the parameter to avoid confusion.

---

### [CLEANUP-005] Use typed parameters instead of RefCounted
**Problem:** Many methods use `RefCounted` as type hint, losing compile-time safety and IDE autocomplete.

**Files:**
- `server/combat/combat_processor.gd:64` - `enemy_manager: RefCounted`
- `server/enemies/enemy_ai.gd:50` - `enemy: RefCounted`
- `server/enemies/enemy_manager.gd` - `_enemy_registry: RefCounted`

**Fix:** Use actual types or create interfaces:
```gdscript
# Option 1: Use actual type
func process_player_attack(..., enemy_manager: EnemyManager, ...) -> PlayerAttackResult:

# Option 2: Create interface base class
class_name IEnemyManager
extends RefCounted
func get_alive_enemies() -> Array: return []
func damage_enemy(_id: String, _amount: float, _attacker: String) -> float: return -1.0
```

---

### [CLEANUP-006] Validate command input
**Problem:** No validation for malicious command input (extremely long strings, injection attempts).

**Files:** `server/commands/command_processor.gd:35-48`

**Fix:** Add input validation:
```gdscript
func _spawn(parts: Array, player_pos: Vector2) -> Dictionary:
    if parts.size() < 2:
        return {"success": false, "message": "Usage: /spawn <type>"}
    var enemy_type := parts[1].to_lower()
    if enemy_type.length() > 64:
        return {"success": false, "message": "Enemy type name too long"}
    if not enemy_type.is_valid_identifier():
        return {"success": false, "message": "Invalid enemy type format"}
```

---

## Feature Requests

### [FEATURE-002] Add tab auto-complete for commands
**Problem:** Users must type full command names and arguments.

**Files:** `client/ui/command_input.gd`

**Fix:** Track registered commands and implement tab completion for command names and known arguments (like enemy types).

---

### [FEATURE-003] Show command feedback in UI instead of console
**Problem:** Command responses only print to Godot console, not visible to players.

**Files:** `client/ui/command_input.gd`, `client/ui/hud.gd`

**Fix:** Add temporary message display in CommandInput or create a chat/log panel.
