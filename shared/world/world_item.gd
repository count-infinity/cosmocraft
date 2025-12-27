class_name WorldItem
extends RefCounted
## Represents an item dropped on the ground in the world.
## Used by both server (authoritative) and client (visual representation).


## Unique identifier for this world item
var id: String = ""

## The item stack data
var item_stack: ItemStack

## World position in pixels
var position: Vector2 = Vector2.ZERO

## Unix timestamp when this item was spawned
var spawn_time: float = 0.0

## Player ID who dropped this item (for loot protection)
## Empty string means no protection (anyone can pick up)
var owner_id: String = ""

## ID counter for collision-resistant generation
static var _id_counter: int = 0


func _init(
	p_id: String = "",
	p_item_stack: ItemStack = null,
	p_position: Vector2 = Vector2.ZERO,
	p_owner_id: String = ""
) -> void:
	id = p_id
	item_stack = p_item_stack
	position = p_position
	owner_id = p_owner_id
	spawn_time = Time.get_unix_time_from_system()


## Check if this item has despawned based on current time
func is_despawned() -> bool:
	var current_time := Time.get_unix_time_from_system()
	return (current_time - spawn_time) >= GameConstants.LOOT_DESPAWN_TIME


## Get time remaining until despawn in seconds
func get_time_until_despawn() -> float:
	var current_time := Time.get_unix_time_from_system()
	var elapsed := current_time - spawn_time
	return maxf(0.0, GameConstants.LOOT_DESPAWN_TIME - elapsed)


## Check if loot protection is active
func is_protected() -> bool:
	if owner_id.is_empty():
		return false
	var current_time := Time.get_unix_time_from_system()
	return (current_time - spawn_time) < GameConstants.LOOT_PROTECTION_DURATION


## Check if a player can pick up this item
func can_pickup(player_id: String) -> bool:
	# If protected, only owner can pick up
	if is_protected() and player_id != owner_id:
		return false
	return true


## Get the display name of the item
func get_display_name() -> String:
	if item_stack == null or item_stack.is_empty():
		return "Unknown Item"
	return item_stack.get_display_text()


## Get the item quality (for visual effects)
func get_quality() -> float:
	if item_stack == null or item_stack.item == null:
		return 1.0
	return item_stack.item.quality


## Get the item tier (for visual effects)
func get_tier() -> int:
	if item_stack == null or item_stack.item == null or item_stack.item.definition == null:
		return 1
	return item_stack.item.definition.tier


## Serialize to dictionary for network transfer
func to_dict() -> Dictionary:
	return {
		"id": id,
		"stack": item_stack.to_dict() if item_stack else {"empty": true},
		"position": {"x": position.x, "y": position.y},
		"spawn_time": spawn_time,
		"owner_id": owner_id,
	}


## Create from dictionary (used by client to reconstruct from server data)
static func from_dict(data: Dictionary, item_registry: Object) -> WorldItem:
	var world_item := WorldItem.new()
	world_item.id = data.get("id", "")

	var stack_data: Dictionary = data.get("stack", {"empty": true})
	world_item.item_stack = ItemStack.from_dict(stack_data, item_registry)

	var pos_data: Dictionary = data.get("position", {})
	world_item.position = Vector2(
		pos_data.get("x", 0.0),
		pos_data.get("y", 0.0)
	)

	world_item.spawn_time = data.get("spawn_time", Time.get_unix_time_from_system())
	world_item.owner_id = data.get("owner_id", "")

	return world_item


## Generate a unique ID for a new world item
## Uses timestamp + counter + random to prevent collisions
static func generate_id() -> String:
	_id_counter += 1
	var timestamp := int(Time.get_unix_time_from_system() * 1000)
	var random_bytes := PackedByteArray()
	for _i in range(4):
		random_bytes.append(randi() % 256)
	return "wi_%d_%d_%s" % [timestamp, _id_counter, random_bytes.hex_encode()]
