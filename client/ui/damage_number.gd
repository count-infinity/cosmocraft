class_name DamageNumber
extends Node2D
## Floating damage number that rises and fades.
## Used to display damage dealt to entities.


## How long the number stays visible
const DISPLAY_DURATION: float = 1.2

## How far the number rises (in pixels)
const RISE_DISTANCE: float = 40.0

## Normal damage color
const COLOR_NORMAL := Color(1.0, 1.0, 1.0)  # White

## Critical hit color
const COLOR_CRIT := Color(1.0, 0.8, 0.0)  # Gold

## Healing color
const COLOR_HEAL := Color(0.3, 1.0, 0.3)  # Green

## Miss color
const COLOR_MISS := Color(0.7, 0.7, 0.7)  # Gray


## The label displaying the damage value
var _label: Label

## Time elapsed since creation
var _elapsed: float = 0.0

## Starting position
var _start_position: Vector2

## Whether this is a critical hit
var _is_crit: bool = false


func _init() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)


func _ready() -> void:
	_start_position = position
	# Center the label on the node
	_label.position = Vector2(-50, -12)
	_label.size = Vector2(100, 24)


func _process(delta: float) -> void:
	_elapsed += delta

	# Calculate animation progress (0 to 1)
	var progress := _elapsed / DISPLAY_DURATION

	if progress >= 1.0:
		queue_free()
		return

	# Rise animation
	var rise_offset := RISE_DISTANCE * progress
	position = _start_position + Vector2(0, -rise_offset)

	# Fade out in the last 40% of duration
	var fade_start := 0.6
	if progress > fade_start:
		var fade_progress := (progress - fade_start) / (1.0 - fade_start)
		modulate.a = 1.0 - fade_progress

	# Scale effect for crits - starts big and shrinks to normal
	if _is_crit:
		var scale_progress := minf(progress * 4.0, 1.0)
		var crit_scale := lerpf(1.5, 1.0, scale_progress)
		_label.scale = Vector2(crit_scale, crit_scale)


## Configure the damage number display
func setup(damage: float, is_crit: bool = false, is_heal: bool = false) -> void:
	_is_crit = is_crit

	# Set text
	var damage_text := str(int(damage))
	if is_heal:
		damage_text = "+" + damage_text
	_label.text = damage_text

	# Set color based on type
	if is_heal:
		_label.modulate = COLOR_HEAL
	elif is_crit:
		_label.modulate = COLOR_CRIT
	else:
		_label.modulate = COLOR_NORMAL

	# Set font size
	var font_size := 16
	if is_crit:
		font_size = 24
	_label.add_theme_font_size_override("font_size", font_size)

	# Add outline for visibility
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 2)


## Show a "MISS" text
func setup_miss() -> void:
	_is_crit = false
	_label.text = "MISS"
	_label.modulate = COLOR_MISS
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 2)


## Factory method to create a damage number
static func create(damage: float, world_position: Vector2, is_crit: bool = false) -> DamageNumber:
	var instance := DamageNumber.new()
	instance.position = world_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
	instance.setup(damage, is_crit)
	return instance


## Factory method to create a heal number
static func create_heal(amount: float, world_position: Vector2) -> DamageNumber:
	var instance := DamageNumber.new()
	instance.position = world_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
	instance.setup(amount, false, true)
	return instance


## Factory method to create a miss indicator
static func create_miss(world_position: Vector2) -> DamageNumber:
	var instance := DamageNumber.new()
	instance.position = world_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
	instance.setup_miss()
	return instance
