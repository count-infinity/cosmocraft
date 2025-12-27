class_name EnemyHealthBar
extends Node2D
## Health bar widget for enemies.
## Appears above enemy when damaged, fades after inactivity.


## How long to show after taking damage
const VISIBLE_DURATION: float = 4.0

## Fade out duration in seconds
const FADE_DURATION: float = 0.3

## Bar dimensions
const BAR_WIDTH: float = 40.0
const BAR_HEIGHT: float = 6.0

## Vertical offset above entity
const VERTICAL_OFFSET: float = -24.0

## Health thresholds for color changes
const LOW_THRESHOLD: float = 0.25
const MID_THRESHOLD: float = 0.50

## Colors
const COLOR_HIGH := Color(0.2, 0.8, 0.2)  # Green
const COLOR_MID := Color(0.9, 0.8, 0.1)   # Yellow
const COLOR_LOW := Color(0.9, 0.2, 0.1)   # Red
const COLOR_BG := Color(0.1, 0.1, 0.1, 0.8)  # Dark background
const COLOR_BORDER := Color(0.2, 0.2, 0.2, 0.9)  # Border


## Background ColorRect
var _background: ColorRect

## Health fill ColorRect
var _fill: ColorRect

## Current health percentage (0.0 to 1.0)
var _health_percent: float = 1.0

## Target health percent (for smooth transitions)
var _target_percent: float = 1.0

## Time since last damage
var _time_since_damage: float = 0.0

## Whether the bar is currently visible
var _is_visible: bool = false


func _init() -> void:
	# Create background
	_background = ColorRect.new()
	_background.size = Vector2(BAR_WIDTH + 2, BAR_HEIGHT + 2)
	_background.position = Vector2(-BAR_WIDTH / 2 - 1, VERTICAL_OFFSET - 1)
	_background.color = COLOR_BORDER
	add_child(_background)

	# Create inner background
	var inner_bg := ColorRect.new()
	inner_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	inner_bg.position = Vector2(1, 1)
	inner_bg.color = COLOR_BG
	_background.add_child(inner_bg)

	# Create health fill
	_fill = ColorRect.new()
	_fill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_fill.position = Vector2(1, 1)
	_fill.color = COLOR_HIGH
	_background.add_child(_fill)

	# Start hidden
	visible = false


func _process(delta: float) -> void:
	# Smooth health transition
	if not is_equal_approx(_health_percent, _target_percent):
		_health_percent = lerpf(_health_percent, _target_percent, delta * 10.0)
		_update_fill()

	# Handle visibility timer
	if _is_visible:
		_time_since_damage += delta
		if _time_since_damage >= VISIBLE_DURATION:
			_fade_out()


## Update the health value
func set_health(current: float, maximum: float) -> void:
	if maximum <= 0:
		_target_percent = 0.0
	else:
		_target_percent = clampf(current / maximum, 0.0, 1.0)

	# Show bar when health changes
	_show()


## Take damage and show the bar
func take_damage(_damage: float, current: float, maximum: float) -> void:
	set_health(current, maximum)


## Update the fill bar size and color
func _update_fill() -> void:
	# Update width
	_fill.size.x = BAR_WIDTH * _health_percent

	# Update color based on health
	if _health_percent <= LOW_THRESHOLD:
		_fill.color = COLOR_LOW
	elif _health_percent <= MID_THRESHOLD:
		_fill.color = COLOR_MID
	else:
		_fill.color = COLOR_HIGH


## Show the health bar
func _show() -> void:
	_is_visible = true
	_time_since_damage = 0.0
	visible = true
	modulate.a = 1.0


## Fade out the health bar with animation
func _fade_out() -> void:
	_is_visible = false
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(func(): visible = false)


## Hide immediately
func hide_bar() -> void:
	_is_visible = false
	visible = false


## Check if currently showing
func is_showing() -> bool:
	return _is_visible


## Factory method to create a health bar
static func create() -> EnemyHealthBar:
	return EnemyHealthBar.new()
