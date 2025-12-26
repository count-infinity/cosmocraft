class_name Corpse
extends RefCounted
## Represents a player's corpse containing their dropped items on death.
## Implements the "full corpse run" death penalty system.


## Signal emitted when corpse is looted
signal looted(by_player_id: String)

## Signal emitted when corpse expires
signal expired


## Unique corpse ID
var id: String = ""

## ID of the player who died
var owner_id: String = ""

## Player name (for display)
var owner_name: String = ""

## World position where player died
var position: Vector2 = Vector2.ZERO

## Timestamp when corpse was created (server time)
var created_at: float = 0.0

## Duration in seconds before corpse expires (configurable)
var expire_duration: float = 300.0  # 5 minutes default

## Whether corpse has been looted by owner
var is_looted: bool = false

## The inventory containing dropped items
var inventory: Inventory

## The equipment that was dropped
var equipment: EquipmentSlots

## Reference to item registry for serialization
var _item_registry: ItemRegistry


func _init(item_registry: ItemRegistry = null) -> void:
	_item_registry = item_registry
	id = _generate_id()
	inventory = Inventory.new(9999.0, item_registry)  # Unlimited weight for corpse
	equipment = EquipmentSlots.new()


## Generate unique corpse ID
func _generate_id() -> String:
	return "corpse_%d_%d" % [Time.get_unix_time_from_system(), randi()]


## Set the item registry
func set_item_registry(registry: ItemRegistry) -> void:
	_item_registry = registry
	inventory.set_item_registry(registry)


## Initialize corpse from player death
func init_from_death(
	player_id: String,
	player_name: String,
	death_position: Vector2,
	player_inventory: Inventory,
	player_equipment: EquipmentSlots,
	server_time: float
) -> void:
	owner_id = player_id
	owner_name = player_name
	position = death_position
	created_at = server_time

	# Transfer all inventory items to corpse
	for stack in player_inventory.get_all_stacks():
		inventory.add_stack(stack)

	# Transfer all equipped items to corpse
	for slot in ItemEnums.EquipSlot.values():
		if slot == ItemEnums.EquipSlot.NONE:
			continue
		var item := player_equipment.unequip(slot)
		if item != null:
			equipment.equip(item)


## Check if corpse has expired
func is_expired(current_time: float) -> bool:
	return current_time >= created_at + expire_duration


## Get time remaining before expiration
func get_time_remaining(current_time: float) -> float:
	var remaining := (created_at + expire_duration) - current_time
	return maxf(0.0, remaining)


## Get formatted time remaining
func get_time_remaining_text(current_time: float) -> String:
	var remaining := get_time_remaining(current_time)
	if remaining <= 0:
		return "Expired"

	var minutes := int(remaining / 60)
	var seconds := int(remaining) % 60
	return "%d:%02d" % [minutes, seconds]


## Check if a player can loot this corpse
## Owner can always loot, others can loot after protection period
func can_loot(player_id: String, current_time: float, protection_duration: float = 60.0) -> bool:
	if is_looted:
		return false

	# Owner can always loot
	if player_id == owner_id:
		return true

	# Others can loot after protection period
	return current_time >= created_at + protection_duration


## Loot all items from corpse to player inventory
## Returns items that couldn't fit
func loot_all(player_inventory: Inventory, player_equipment: EquipmentSlots) -> Dictionary:
	var leftover_inventory: Array[ItemStack] = []
	var leftover_equipment: Array[ItemInstance] = []

	# Try to equip items first
	for slot in ItemEnums.EquipSlot.values():
		if slot == ItemEnums.EquipSlot.NONE:
			continue
		var item := equipment.get_equipped(slot)
		if item != null:
			var replaced := player_equipment.equip(item)
			if replaced != null:
				# Couldn't equip (slot taken), add to inventory instead
				var stack := ItemStack.new(replaced, 1)
				var inv_leftover := player_inventory.add_stack(stack)
				if inv_leftover != null:
					leftover_inventory.append(inv_leftover)

	# Transfer inventory items
	for stack in inventory.get_all_stacks():
		var leftover := player_inventory.add_stack(stack)
		if leftover != null and not leftover.is_empty():
			leftover_inventory.append(leftover)

	# Clear corpse if everything was taken
	if leftover_inventory.is_empty() and leftover_equipment.is_empty():
		is_looted = true
		inventory.clear()
		equipment.clear()
		looted.emit(owner_id)
	else:
		# Put leftovers back in corpse
		inventory.clear()
		for stack in leftover_inventory:
			inventory.add_stack(stack)

	return {
		"inventory_leftover": leftover_inventory,
		"equipment_leftover": leftover_equipment,
	}


## Loot a specific item from corpse inventory
func loot_stack(stack: ItemStack, player_inventory: Inventory) -> ItemStack:
	var idx := -1
	for i in range(inventory.get_stack_count()):
		if inventory.get_stack_at(i) == stack:
			idx = i
			break

	if idx < 0:
		return null

	var leftover := player_inventory.add_stack(stack)
	if leftover == null or leftover.is_empty():
		inventory.remove_stack(stack)

	# Check if corpse is empty
	if inventory.is_empty() and equipment.get_all_equipped().is_empty():
		is_looted = true
		looted.emit(owner_id)

	return leftover


## Check if corpse is empty
func is_empty() -> bool:
	return inventory.is_empty() and equipment.get_all_equipped().is_empty()


## Get display text for corpse
func get_display_text(current_time: float) -> String:
	var lines: Array[String] = []
	lines.append("%s's Corpse" % owner_name)
	lines.append("Time remaining: %s" % get_time_remaining_text(current_time))

	var item_count := inventory.get_stack_count()
	var equip_count := equipment.get_all_equipped().size()
	lines.append("%d items, %d equipment" % [item_count, equip_count])

	return "\n".join(lines)


## Serialize to dictionary
func to_dict() -> Dictionary:
	var equip_data: Dictionary = {}
	for slot in ItemEnums.EquipSlot.values():
		if slot == ItemEnums.EquipSlot.NONE:
			continue
		var item := equipment.get_equipped(slot)
		if item != null:
			equip_data[slot] = item.to_dict()

	return {
		"id": id,
		"owner_id": owner_id,
		"owner_name": owner_name,
		"position": {"x": position.x, "y": position.y},
		"created_at": created_at,
		"expire_duration": expire_duration,
		"is_looted": is_looted,
		"inventory": inventory.to_dict(),
		"equipment": equip_data,
	}


## Deserialize from dictionary
func from_dict(data: Dictionary) -> void:
	id = data.get("id", "")
	owner_id = data.get("owner_id", "")
	owner_name = data.get("owner_name", "")

	var pos_data: Dictionary = data.get("position", {})
	position = Vector2(pos_data.get("x", 0), pos_data.get("y", 0))

	created_at = data.get("created_at", 0.0)
	expire_duration = data.get("expire_duration", 300.0)
	is_looted = data.get("is_looted", false)

	# Restore inventory
	var inv_data: Dictionary = data.get("inventory", {})
	inventory.from_dict(inv_data)

	# Restore equipment
	var equip_data: Dictionary = data.get("equipment", {})
	for slot_key in equip_data:
		var slot: int = slot_key if slot_key is int else int(slot_key)
		var item_data: Dictionary = equip_data[slot_key]
		if _item_registry != null:
			var item := ItemInstance.from_dict(item_data, _item_registry)
			if item != null:
				equipment.equip(item)


## Corpse Manager - tracks all corpses in the world
class Manager extends RefCounted:
	## All active corpses indexed by ID
	var _corpses: Dictionary = {}

	## Corpses indexed by owner ID
	var _by_owner: Dictionary = {}

	## Reference to item registry
	var _item_registry: ItemRegistry


	func _init(item_registry: ItemRegistry = null) -> void:
		_item_registry = item_registry


	## Create a corpse from player death
	func create_corpse(
		player_id: String,
		player_name: String,
		death_position: Vector2,
		player_inventory: Inventory,
		player_equipment: EquipmentSlots,
		server_time: float,
		expire_duration: float = 300.0
	) -> Corpse:
		var corpse := Corpse.new(_item_registry)
		corpse.expire_duration = expire_duration
		corpse.init_from_death(
			player_id, player_name, death_position,
			player_inventory, player_equipment, server_time
		)

		_corpses[corpse.id] = corpse
		_by_owner[player_id] = corpse.id

		return corpse


	## Get corpse by ID
	func get_corpse(corpse_id: String) -> Corpse:
		return _corpses.get(corpse_id, null)


	## Get corpse for a player (their most recent death)
	func get_player_corpse(player_id: String) -> Corpse:
		var corpse_id: String = _by_owner.get(player_id, "")
		if corpse_id.is_empty():
			return null
		return get_corpse(corpse_id)


	## Get all corpses
	func get_all() -> Array[Corpse]:
		var result: Array[Corpse] = []
		for corpse in _corpses.values():
			result.append(corpse)
		return result


	## Get corpses near a position
	func get_corpses_near(pos: Vector2, radius: float) -> Array[Corpse]:
		var result: Array[Corpse] = []
		var radius_sq := radius * radius

		for corpse in _corpses.values():
			if corpse.position.distance_squared_to(pos) <= radius_sq:
				result.append(corpse)

		return result


	## Remove a corpse
	func remove_corpse(corpse_id: String) -> void:
		var corpse := get_corpse(corpse_id)
		if corpse != null:
			_by_owner.erase(corpse.owner_id)
			_corpses.erase(corpse_id)


	## Clean up expired corpses
	## Returns array of expired corpse IDs
	func cleanup_expired(current_time: float) -> Array[String]:
		var expired: Array[String] = []

		for corpse_id in _corpses.keys():
			var corpse: Corpse = _corpses[corpse_id]
			if corpse.is_expired(current_time) or corpse.is_looted:
				expired.append(corpse_id)
				corpse.expired.emit()

		for corpse_id in expired:
			remove_corpse(corpse_id)

		return expired


	## Get count of active corpses
	func get_count() -> int:
		return _corpses.size()


	## Clear all corpses
	func clear() -> void:
		_corpses.clear()
		_by_owner.clear()
