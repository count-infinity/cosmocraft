class_name LootEntry
extends RefCounted
## A single entry in a loot table.
## Represents one possible item drop with quantity range and drop chance.


## Item ID to drop (references ItemRegistry)
var item_id: String = ""

## Minimum quantity to drop (inclusive)
var min_quantity: int = 1

## Maximum quantity to drop (inclusive)
var max_quantity: int = 1

## Drop chance as percentage (0.0 - 100.0)
## 100.0 = guaranteed, 0.0 = never drops
var drop_chance: float = 100.0

## Weight for weighted random selection (higher = more likely)
## Used when the loot table uses weighted selection instead of individual rolls
var weight: float = 1.0

## Quality range for dropped items (min, max)
var min_quality: float = 1.0
var max_quality: float = 1.0


func _init(
	p_item_id: String = "",
	p_min_quantity: int = 1,
	p_max_quantity: int = 1,
	p_drop_chance: float = 100.0,
	p_weight: float = 1.0
) -> void:
	item_id = p_item_id
	min_quantity = maxi(1, p_min_quantity)
	max_quantity = maxi(min_quantity, p_max_quantity)
	drop_chance = clampf(p_drop_chance, 0.0, 100.0)
	weight = maxf(0.0, p_weight)


## Roll whether this entry drops
func roll_drop() -> bool:
	if drop_chance >= 100.0:
		return true
	if drop_chance <= 0.0:
		return false
	return randf() * 100.0 < drop_chance


## Roll quantity within the min/max range
func roll_quantity() -> int:
	if min_quantity == max_quantity:
		return min_quantity
	return randi_range(min_quantity, max_quantity)


## Roll quality within the min/max range
func roll_quality() -> float:
	if min_quality == max_quality:
		return min_quality
	return randf_range(min_quality, max_quality)


## Check if this entry is valid (has item_id)
func is_valid() -> bool:
	return not item_id.is_empty()


## Set quality range (uses GameConstants for bounds)
func set_quality_range(p_min: float, p_max: float) -> LootEntry:
	min_quality = clampf(p_min, GameConstants.QUALITY_MIN, GameConstants.QUALITY_MAX)
	max_quality = clampf(maxf(p_max, min_quality), GameConstants.QUALITY_MIN, GameConstants.QUALITY_MAX)
	return self


## Validate and fix all fields to ensure consistency
## Call this after loading from external data
func validate() -> LootEntry:
	min_quantity = maxi(1, min_quantity)
	max_quantity = maxi(min_quantity, max_quantity)
	drop_chance = clampf(drop_chance, 0.0, 100.0)
	weight = maxf(0.0, weight)
	min_quality = clampf(min_quality, GameConstants.QUALITY_MIN, GameConstants.QUALITY_MAX)
	max_quality = clampf(maxf(max_quality, min_quality), GameConstants.QUALITY_MIN, GameConstants.QUALITY_MAX)
	return self


## Serialize to dictionary
func to_dict() -> Dictionary:
	return {
		"item_id": item_id,
		"min_quantity": min_quantity,
		"max_quantity": max_quantity,
		"drop_chance": drop_chance,
		"weight": weight,
		"min_quality": min_quality,
		"max_quality": max_quality,
	}


## Create from dictionary (validates data after loading)
static func from_dict(data: Dictionary) -> LootEntry:
	var entry := LootEntry.new()
	entry.item_id = data.get("item_id", "")
	entry.min_quantity = int(data.get("min_quantity", 1))
	entry.max_quantity = int(data.get("max_quantity", 1))
	entry.drop_chance = float(data.get("drop_chance", 100.0))
	entry.weight = float(data.get("weight", 1.0))
	entry.min_quality = float(data.get("min_quality", 1.0))
	entry.max_quality = float(data.get("max_quality", 1.0))
	entry.validate()  # Ensure consistency after deserialization
	return entry


## Create a simple entry with just item and quantity
static func simple(p_item_id: String, p_quantity: int = 1) -> LootEntry:
	return LootEntry.new(p_item_id, p_quantity, p_quantity, 100.0)


## Create an entry with a drop chance
static func with_chance(p_item_id: String, p_chance: float, p_quantity: int = 1) -> LootEntry:
	return LootEntry.new(p_item_id, p_quantity, p_quantity, p_chance)


## Create an entry with a quantity range
static func with_range(p_item_id: String, p_min: int, p_max: int, p_chance: float = 100.0) -> LootEntry:
	return LootEntry.new(p_item_id, p_min, p_max, p_chance)
