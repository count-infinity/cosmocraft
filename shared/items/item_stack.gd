class_name ItemStack
extends RefCounted
## A stack of items in inventory.
## For stackable items (materials), holds count.
## For non-stackable items (equipment), count is always 1.


## The item in this stack
var item: ItemInstance

## How many items in the stack
var count: int = 1


func _init(p_item: ItemInstance = null, p_count: int = 1) -> void:
	item = p_item
	count = p_count if p_item else 0


## Check if stack is empty
func is_empty() -> bool:
	return item == null or count <= 0


## Check if stack is full
func is_full() -> bool:
	if item == null or item.definition == null:
		return false
	return count >= item.definition.max_stack


## Get remaining space in stack
func get_remaining_space() -> int:
	if item == null or item.definition == null:
		return 0
	return maxi(0, item.definition.max_stack - count)


## Check if another stack can merge into this one
func can_merge_with(other: ItemStack) -> bool:
	if other == null or other.is_empty():
		return false
	if is_empty():
		return true  # Empty stacks can accept anything
	if item.definition == null or other.item.definition == null:
		return false
	if item.definition.id != other.item.definition.id:
		return false
	if not item.definition.is_stackable():
		return false
	return count < item.definition.max_stack


## Merge another stack into this one
## Returns the leftover count that couldn't fit
func merge_from(other: ItemStack) -> int:
	if not can_merge_with(other):
		return other.count

	if is_empty():
		# Take everything from other
		item = other.item
		count = other.count
		other.item = null
		other.count = 0
		return 0

	var space := get_remaining_space()
	var to_add := mini(space, other.count)

	count += to_add
	other.count -= to_add

	if other.count <= 0:
		other.item = null

	return other.count


## Split off a portion of this stack
## Returns a new stack with the split items, or null if can't split
func split(amount: int) -> ItemStack:
	if amount <= 0 or amount >= count:
		return null
	if item == null:
		return null

	# For non-stackable items, can't split
	if not item.definition.is_stackable():
		return null

	var split_stack := ItemStack.new()
	split_stack.item = item  # Same definition for stackables
	split_stack.count = amount
	count -= amount

	return split_stack


## Take one item from the stack
## Returns the item, or null if empty
func take_one() -> ItemInstance:
	if is_empty():
		return null

	count -= 1
	var taken := item

	if count <= 0:
		item = null
		count = 0

	return taken


## Add items to the stack (for stackables)
## Returns how many couldn't be added
func add(amount: int) -> int:
	if item == null or item.definition == null:
		return amount
	if not item.definition.is_stackable():
		return amount

	var space := get_remaining_space()
	var to_add := mini(space, amount)
	count += to_add
	return amount - to_add


## Get total weight of this stack
func get_weight() -> float:
	if item == null or item.definition == null:
		return 0.0
	return item.definition.weight * count


## Get display name with count
func get_display_text() -> String:
	if item == null:
		return "Empty"

	var name := item.get_display_name()
	if count > 1:
		return "%s x%d" % [name, count]
	return name


## Serialize to dictionary
func to_dict() -> Dictionary:
	if item == null:
		return {"empty": true}

	return {
		"item": item.to_dict(),
		"count": count,
	}


## Create from dictionary
static func from_dict(data: Dictionary, item_registry: Object) -> ItemStack:
	if data.get("empty", false):
		return ItemStack.new()

	var item_data: Dictionary = data.get("item", {})
	var item_instance := ItemInstance.from_dict(item_data, item_registry)
	var stack_count: int = data.get("count", 1)

	return ItemStack.new(item_instance, stack_count)


## Create a stack from an item definition (for creating new items)
static func create_from_definition(
	item_def: ItemDefinition,
	p_count: int = 1,
	p_quality: float = 1.0
) -> ItemStack:
	var instance := ItemInstance.create(item_def, p_quality)
	var actual_count := mini(p_count, item_def.max_stack)
	return ItemStack.new(instance, actual_count)
