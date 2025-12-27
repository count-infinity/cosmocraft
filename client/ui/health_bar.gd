class_name HealthBar
extends Control
## Health bar UI showing current and max HP.
## Displays as a colored bar with text overlay.
## Flashes red when taking damage.


## Signal emitted when player dies (for death overlay)
signal player_died

## Signal emitted when player respawns
signal player_respawned


## Reference to game client
var game_client: GameClient = null

## Current displayed HP (for smooth transitions)
var _displayed_hp: float = 100.0
var _target_hp: float = 100.0
var _max_hp: float = 100.0

## Damage flash state
var _is_flashing: bool = false
var _flash_timer: float = 0.0
const FLASH_DURATION: float = 0.15
const FLASH_COLOR: Color = Color(1.0, 0.2, 0.2, 0.8)

## HP interpolation speed
const HP_LERP_SPEED: float = 8.0

## UI elements
var _bar_background: ColorRect
var _bar_fill: ColorRect
var _hp_label: Label
var _damage_flash: ColorRect

## Colors
const BAR_BG_COLOR: Color = Color(0.15, 0.15, 0.15, 0.9)
const BAR_FULL_COLOR: Color = Color(0.2, 0.8, 0.2)
const BAR_MID_COLOR: Color = Color(0.9, 0.8, 0.1)
const BAR_LOW_COLOR: Color = Color(0.9, 0.2, 0.2)
const BAR_EMPTY_COLOR: Color = Color(0.3, 0.1, 0.1)

## Thresholds for color changes
const LOW_HP_THRESHOLD: float = 0.25
const MID_HP_THRESHOLD: float = 0.5


func _ready() -> void:
	_create_ui()


func _create_ui() -> void:
	# Set minimum size
	custom_minimum_size = Vector2(200, 24)

	# Background bar
	_bar_background = ColorRect.new()
	_bar_background.color = BAR_BG_COLOR
	_bar_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bar_background)

	# Fill bar (will be sized based on HP percentage)
	_bar_fill = ColorRect.new()
	_bar_fill.color = BAR_FULL_COLOR
	_bar_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_bar_fill.anchor_right = 1.0
	add_child(_bar_fill)

	# Damage flash overlay
	_damage_flash = ColorRect.new()
	_damage_flash.color = FLASH_COLOR
	_damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_flash.visible = false
	add_child(_damage_flash)

	# HP text label
	_hp_label = Label.new()
	_hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.add_theme_color_override("font_color", Color.WHITE)
	_hp_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_hp_label.add_theme_constant_override("outline_size", 2)
	add_child(_hp_label)

	_update_display()


func _process(delta: float) -> void:
	# Smooth HP transitions
	if not is_equal_approx(_displayed_hp, _target_hp):
		_displayed_hp = lerpf(_displayed_hp, _target_hp, HP_LERP_SPEED * delta)
		if absf(_displayed_hp - _target_hp) < 0.5:
			_displayed_hp = _target_hp
		_update_display()

	# Handle damage flash
	if _is_flashing:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_is_flashing = false
			_damage_flash.visible = false


## Initialize with game client reference
func initialize(client: GameClient) -> void:
	game_client = client

	if game_client != null:
		game_client.health_updated.connect(_on_health_updated)
		game_client.player_died.connect(_on_player_died)
		game_client.player_respawned.connect(_on_player_respawned)

		# Initialize with default values - will be updated when we receive health_update
		set_hp(100.0, 100.0)


## Set current and max HP
func set_hp(current: float, max_value: float) -> void:
	var old_hp := _target_hp
	_target_hp = current
	_max_hp = max_value

	# Check if we took damage
	if current < old_hp and old_hp > 0.0:
		_trigger_damage_flash()

	_update_display()


## Get current HP percentage (0.0 to 1.0)
func get_hp_percent() -> float:
	if _max_hp <= 0.0:
		return 0.0
	return clampf(_displayed_hp / _max_hp, 0.0, 1.0)


## Trigger the damage flash effect
func _trigger_damage_flash() -> void:
	_is_flashing = true
	_flash_timer = FLASH_DURATION
	_damage_flash.visible = true


## Update the visual display
func _update_display() -> void:
	var hp_percent := get_hp_percent()

	# Update bar width
	if _bar_fill != null:
		_bar_fill.anchor_right = hp_percent

	# Update bar color based on HP level
	if _bar_fill != null:
		if hp_percent <= LOW_HP_THRESHOLD:
			_bar_fill.color = BAR_LOW_COLOR
		elif hp_percent <= MID_HP_THRESHOLD:
			# Interpolate between low and mid colors
			var t := (hp_percent - LOW_HP_THRESHOLD) / (MID_HP_THRESHOLD - LOW_HP_THRESHOLD)
			_bar_fill.color = BAR_LOW_COLOR.lerp(BAR_MID_COLOR, t)
		else:
			# Interpolate between mid and full colors
			var t := (hp_percent - MID_HP_THRESHOLD) / (1.0 - MID_HP_THRESHOLD)
			_bar_fill.color = BAR_MID_COLOR.lerp(BAR_FULL_COLOR, t)

	# Update label
	if _hp_label != null:
		_hp_label.text = "%d / %d" % [int(_displayed_hp), int(_max_hp)]


## Called when health is updated from server
func _on_health_updated(player_id: String, current_hp: float, max_hp: float) -> void:
	if game_client == null:
		return

	# Only update if this is the local player
	if player_id == game_client.local_player_id:
		set_hp(current_hp, max_hp)


## Called when local player dies
func _on_player_died() -> void:
	player_died.emit()


## Called when local player respawns
func _on_player_respawned() -> void:
	# Reset HP to max on respawn
	if game_client != null:
		# Get from player state if available, otherwise use defaults
		var max_hp := 100.0
		set_hp(max_hp, max_hp)
		_displayed_hp = max_hp  # Instant update, no animation
	player_respawned.emit()
