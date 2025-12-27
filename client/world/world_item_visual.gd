class_name WorldItemVisual
extends Node2D
## Visual representation of a ground item in the world.
## Renders as a colored rectangle (placeholder) with bobbing animation and glow.


## Reference to the world item data
var world_item: WorldItem

## Item registry for looking up item definitions
var item_registry: Object

## Visual components
var sprite: ColorRect
var glow: ColorRect
var label: Label

## Animation state
var _bob_time: float = 0.0
var _bob_amplitude: float = 4.0
var _bob_speed: float = 3.0
var _base_y: float = 0.0

## Quality color mapping
const QUALITY_COLORS := {
	1: Color(0.6, 0.6, 0.6),    # Tier 1: Gray
	2: Color(0.3, 0.8, 0.3),    # Tier 2: Green
	3: Color(0.3, 0.5, 0.9),    # Tier 3: Blue
	4: Color(0.7, 0.3, 0.9),    # Tier 4: Purple
	5: Color(0.9, 0.6, 0.2),    # Tier 5: Orange/Gold
}

## Size of the item sprite
const SPRITE_SIZE := Vector2(24, 24)


func _init() -> void:
	# Create sprite (colored rectangle placeholder)
	sprite = ColorRect.new()
	sprite.size = SPRITE_SIZE
	sprite.position = -SPRITE_SIZE / 2  # Center the sprite
	add_child(sprite)

	# Create glow effect (slightly larger, semi-transparent)
	glow = ColorRect.new()
	glow.size = SPRITE_SIZE + Vector2(8, 8)
	glow.position = -(SPRITE_SIZE + Vector2(8, 8)) / 2
	glow.z_index = -1
	add_child(glow)

	# Create label for item name
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.position = Vector2(-50, SPRITE_SIZE.y / 2 + 4)
	label.size = Vector2(100, 20)
	label.add_theme_font_size_override("font_size", 10)
	add_child(label)


## Initialize the visual with a world item
func initialize(p_world_item: WorldItem, p_item_registry: Object) -> void:
	world_item = p_world_item
	item_registry = p_item_registry

	# Set position from world item
	position = world_item.position
	_base_y = position.y

	# Set colors based on item tier/quality
	_update_colors()

	# Set label text
	_update_label()

	# Randomize starting bob phase so items don't all bob in sync
	_bob_time = randf() * TAU


func _process(delta: float) -> void:
	if world_item == null:
		return

	# Bobbing animation
	_bob_time += delta * _bob_speed
	var bob_offset := sin(_bob_time) * _bob_amplitude
	position.y = _base_y + bob_offset

	# Pulse glow alpha
	var glow_alpha := 0.2 + sin(_bob_time * 0.5) * 0.1
	var glow_color := glow.color
	glow_color.a = glow_alpha
	glow.color = glow_color


func _update_colors() -> void:
	if world_item == null or world_item.item_stack == null:
		sprite.color = Color.GRAY
		glow.color = Color(0.5, 0.5, 0.5, 0.2)
		return

	var tier := world_item.get_tier()
	var quality := world_item.get_quality()

	# Get base color from tier
	var base_color: Color = QUALITY_COLORS.get(tier, Color.GRAY)

	# Adjust brightness based on quality (0.5-1.5 normal range)
	var brightness := lerpf(0.7, 1.3, (quality - 0.5))
	base_color = base_color * brightness
	base_color.a = 1.0

	# Apply to sprite
	sprite.color = base_color

	# Glow is same color but semi-transparent
	var glow_color := base_color
	glow_color.a = 0.3
	glow.color = glow_color


func _update_label() -> void:
	if world_item == null:
		label.text = "???"
		return

	var display_text := world_item.get_display_name()
	label.text = display_text

	# Color the label based on tier
	var tier := world_item.get_tier()
	label.add_theme_color_override("font_color", QUALITY_COLORS.get(tier, Color.WHITE))


## Update the visual when the world item data changes
func refresh() -> void:
	if world_item == null:
		return

	position = world_item.position
	_base_y = position.y
	_update_colors()
	_update_label()


## Check if the player is close enough to pick up this item
func is_in_pickup_range(player_position: Vector2, pickup_range: float) -> bool:
	if world_item == null:
		return false
	return position.distance_to(player_position) <= pickup_range


## Get the item ID
func get_item_id() -> String:
	if world_item == null:
		return ""
	return world_item.id
