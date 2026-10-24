class_name CorpseVisual
extends Node2D
## Visual representation of a player corpse in the world.
## Renders as a tombstone-like marker with player name.


## Corpse data from server
var corpse_id: String = ""
var player_id: String = ""
var player_name: String = ""

## Visual components
var sprite: ColorRect
var label: Label

## Animation state
var _pulse_time: float = 0.0
var _pulse_speed: float = 2.0

## Visual constants
const SPRITE_SIZE := Vector2(32, 32)
const CORPSE_COLOR := Color(0.5, 0.3, 0.2)  # Brown/grave color
const OWN_CORPSE_COLOR := Color(0.8, 0.4, 0.3)  # Brighter for own corpse


func _init() -> void:
	# Create sprite (tombstone placeholder)
	sprite = ColorRect.new()
	sprite.size = SPRITE_SIZE
	sprite.position = -SPRITE_SIZE / 2  # Center the sprite
	sprite.color = CORPSE_COLOR
	add_child(sprite)

	# Create label for player name
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.position = Vector2(-60, SPRITE_SIZE.y / 2 + 4)
	label.size = Vector2(120, 20)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.7))
	add_child(label)


## Initialize from corpse data dictionary
func initialize(corpse_data: Dictionary, local_player_id: String) -> void:
	corpse_id = corpse_data.get("id", "")
	player_id = corpse_data.get("player_id", "")
	player_name = corpse_data.get("player_name", "Unknown")

	# Set position
	var pos_data: Dictionary = corpse_data.get("position", {})
	position = Vector2(
		float(pos_data.get("x", 0.0)),
		float(pos_data.get("y", 0.0))
	)

	# Update label
	label.text = "%s's Corpse" % player_name

	# Highlight own corpse differently
	if player_id == local_player_id:
		sprite.color = OWN_CORPSE_COLOR
		label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))

	# Randomize pulse phase
	_pulse_time = randf() * TAU


func _process(delta: float) -> void:
	# Gentle pulsing animation
	_pulse_time += delta * _pulse_speed
	var pulse := 0.8 + sin(_pulse_time) * 0.2
	sprite.modulate.a = pulse


## Get the corpse ID
func get_corpse_id() -> String:
	return corpse_id


## Check if this is the local player's corpse
func is_own_corpse(local_player_id: String) -> bool:
	return player_id == local_player_id


## Check if player is in range to recover corpse
func is_in_recovery_range(player_position: Vector2, recovery_range: float) -> bool:
	return position.distance_to(player_position) <= recovery_range
