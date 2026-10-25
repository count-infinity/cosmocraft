class_name Loadout
extends RefCounted
## A hull, the parts fitted to it, and a hold for parts waiting to be fitted.
## Placement has three budgets, after Stars Without Number: grid space, power
## (reactors supply it, most parts draw it), and hardpoints (weapons must cover
## one). Big parts also need a big enough hull class.

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
## How much each mark past Mk I adds.
const MARK_DAMAGE := 0.3
const MARK_RATE := 0.12
const MARK_EFFECT := 0.5


class Fitted:
	var def: ComponentDef
	var origin := Vector2i.ZERO
	var rotation := 0
	var mark := 1

	func cells() -> Array[Vector2i]:
		var result: Array[Vector2i] = []
		for cell in def.cells(rotation):
			result.append(cell + origin)
		return result

	## Power this part supplies (reactors only, +1 per mark past Mk I).
	func supply() -> int:
		return -def.power + mark - 1 if def.is_reactor() else 0

	## Power this part draws.
	func draw() -> int:
		return 0 if def.is_reactor() else def.power


class Stowed:
	var def: ComponentDef
	var mark := 1


var hull: HullDef
var fitted: Array[Fitted] = []
var hold: Array[Stowed] = []


func _init(p_hull: HullDef = null) -> void:
	hull = p_hull if p_hull != null else HullDef.skiff()


## The ship every run starts with: a Skiff with a pulse laser and a shield.
static func starter() -> Loadout:
	var loadout := Loadout.new(HullDef.skiff())
	loadout.place(ComponentLibrary.get_def("pulse_laser"), Vector2i(2, 0), 0)
	loadout.place(ComponentLibrary.get_def("shield_generator"), Vector2i(1, 2), 0)
	return loadout


func occupant(cell: Vector2i) -> Fitted:
	for item in fitted:
		if item.cells().has(cell):
			return item
	return null


func power_capacity() -> int:
	var total := hull.power
	for item in fitted:
		total += item.supply()
	return total


func power_used() -> int:
	var total := 0
	for item in fitted:
		total += item.draw()
	return total


## Empty when the part fits at that spot; otherwise the reason it doesn't.
## `moving` is a part already fitted that is being moved (it doesn't block
## itself, and its power is freed).
func check_place(def: ComponentDef, origin: Vector2i, rotation: int, moving: Fitted = null) -> String:
	if def.min_hull_class > hull.hull_class:
		return "Needs a bigger hull"
	var on_hardpoint := false
	for cell in def.cells(rotation):
		var spot := cell + origin
		var kind := hull.cell(spot)
		if kind == HullDef.Cell.VOID:
			return "Doesn't fit there"
		var other := occupant(spot)
		if other != null and other != moving:
			return "That space is taken"
		if kind == HullDef.Cell.HARDPOINT:
			on_hardpoint = true
	if def.needs_hardpoint and not on_hardpoint:
		return "Weapons must cover a hardpoint"
	if not def.is_reactor():
		var free := power_capacity() - power_used() + (moving.draw() if moving != null else 0)
		if def.power > free:
			return "Not enough power (needs %d, %d free)" % [def.power, free]
	return ""


func can_place(def: ComponentDef, origin: Vector2i, rotation: int) -> bool:
	return check_place(def, origin, rotation).is_empty()


func place(def: ComponentDef, origin: Vector2i, rotation: int, mark := 1) -> Fitted:
	if not can_place(def, origin, rotation):
		return null
	var item := Fitted.new()
	item.def = def
	item.origin = origin
	item.rotation = posmod(rotation, 4)
	item.mark = mark
	fitted.append(item)
	return item


## Moves a fitted part. Leaves it where it was and returns false if the new
## spot doesn't work.
func move(item: Fitted, origin: Vector2i, rotation: int) -> bool:
	if not check_place(item.def, origin, rotation, item).is_empty():
		return false
	item.origin = origin
	item.rotation = posmod(rotation, 4)
	return true


## Empty when the part can come off; otherwise the reason it can't.
func check_remove(item: Fitted) -> String:
	if item.def.is_reactor() and power_capacity() - item.supply() < power_used():
		return "Unpower some parts before removing this reactor"
	return ""


func remove(item: Fitted) -> bool:
	if not check_remove(item).is_empty():
		return false
	fitted.erase(item)
	return true


func stow(def: ComponentDef, mark := 1) -> Stowed:
	var stowed := Stowed.new()
	stowed.def = def
	stowed.mark = mark
	hold.append(stowed)
	return stowed


## Fits a part in the first spot (and rotation) that works, or returns null.
func auto_fit(def: ComponentDef, mark := 1) -> Fitted:
	var grid := hull.size()
	for rotation in 4:
		for y in grid.y:
			for x in grid.x:
				var item := place(def, Vector2i(x, y), rotation, mark)
				if item != null:
					return item
	return null


## Parts sharing an edge with this one.
func neighbors(item: Fitted) -> Array[Fitted]:
	var result: Array[Fitted] = []
	for cell in item.cells():
		for direction in DIRECTIONS:
			var other := occupant(cell + direction)
			if other != null and other != item and not result.has(other):
				result.append(other)
	return result


## Moves everything to a new hull, keeping parts in roughly the same place.
## Anything that no longer fits goes to the hold.
func change_hull(new_hull: HullDef) -> void:
	var previous := fitted.duplicate()
	var shift := (new_hull.size() - hull.size()) / 2
	hull = new_hull
	fitted.clear()
	previous.sort_custom(func(a: Fitted, b: Fitted) -> bool: return a.def.is_reactor() and not b.def.is_reactor())
	for item: Fitted in previous:
		var placed := place(item.def, item.origin + shift, item.rotation, item.mark)
		if placed == null:
			placed = auto_fit(item.def, item.mark)
		if placed == null:
			stow(item.def, item.mark)


## Adds everything up. `bonuses` uses the same stat keys (plus "damage") and
## comes from permanent upgrades.
func compute_stats(tuning: SpaceTuning, bonuses: Dictionary = {}) -> ShipStats:
	var sums := {}
	for item in fitted:
		var scale := ComponentDef.mark_scale(item.mark, MARK_EFFECT)
		for key: String in item.def.stats:
			var value := float(item.def.stats[key])
			if value > 0.0:
				value *= scale
			sums[key] = float(sums.get(key, 0.0)) + value
	for key: String in bonuses:
		sums[key] = float(sums.get(key, 0.0)) + float(bonuses[key])
	var stats := ShipStats.new()
	stats.max_hull = hull.base_hull + float(sums.get("max_hull", 0.0))
	stats.max_shield = hull.base_shield + float(sums.get("max_shield", 0.0))
	stats.speed = tuning.ship_max_speed * hull.speed_scale * maxf(1.0 + float(sums.get("speed", 0.0)), 0.5)
	stats.magnet = tuning.magnet_radius + float(sums.get("magnet", 0.0))
	stats.dash_cooldown = tuning.dash_cooldown * maxf(1.0 - float(sums.get("dash_cooldown", 0.0)), 0.3)
	stats.claim_speed = 1.0 + float(sums.get("claim_speed", 0.0))
	stats.point_defense = float(sums.get("point_defense", 0.0))
	stats.dark_regen = float(sums.get("dark_regen", 0.0))
	stats.power_used = power_used()
	stats.power_capacity = power_capacity()
	stats.radius = hull.radius
	var damage_bonus := float(bonuses.get("damage", 0.0))
	for item in fitted:
		if item.def.is_weapon():
			stats.weapons.append(_weapon_spec(item, damage_bonus))
	return stats


func _weapon_spec(item: Fitted, damage_bonus: float) -> WeaponSpec:
	var spec := WeaponSpec.from_weapon(item.def.id, item.def.weapon)
	var damage_scale := ComponentDef.mark_scale(item.mark, MARK_DAMAGE) + damage_bonus
	var rate_scale := ComponentDef.mark_scale(item.mark, MARK_RATE)
	for neighbor in neighbors(item):
		var boost := ComponentDef.mark_scale(neighbor.mark, MARK_EFFECT)
		damage_scale += float(neighbor.def.adjacency.get("damage", 0.0)) * boost
		rate_scale += float(neighbor.def.adjacency.get("rate", 0.0)) * boost
	spec.damage *= damage_scale
	spec.rate *= rate_scale
	if spec.ammo > 0:
		spec.ammo += item.mark - 1
	var center := Vector2.ZERO
	var cells := item.cells()
	for cell in cells:
		center += Vector2(cell) + Vector2(0.5, 0.5)
	spec.mount = hull.mount_offset(center / cells.size())
	return spec
