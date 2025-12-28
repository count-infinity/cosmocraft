class_name EnemyVisual
extends Node2D
## Visual representation of an enemy in the world.
## Renders as a colored rectangle with health bar, name, and facing indicator.
## Uses interpolation for smooth movement between server updates.


## Reference to the enemy state data
var enemy_id: String = ""
var definition_id: String = ""
var display_name: String = ""

## Enemy tier for coloring
var tier: int = 1

## State interpolator for smooth movement
var _interpolator: StateInterpolator

## Visual components
var body: ColorRect
var facing_indicator: Polygon2D
var name_label: Label
var health_bar: EnemyHealthBar

## Current state
var current_hp: float = 1.0
var max_hp: float = 1.0
var is_alive: bool = true

## Colors by tier
const TIER_COLORS := {
	1: Color(0.7, 0.7, 0.7),     # Tier 1: Gray (weak)
	2: Color(0.3, 0.7, 0.3),     # Tier 2: Green
	3: Color(0.4, 0.5, 0.9),     # Tier 3: Blue
	4: Color(0.7, 0.3, 0.8),     # Tier 4: Purple
	5: Color(0.9, 0.4, 0.2),     # Tier 5: Red/Orange (dangerous)
}

## Dead enemy color
const COLOR_DEAD := Color(0.3, 0.3, 0.3, 0.5)

## Size of the enemy body
const BODY_SIZE: float = 28.0


func _init() -> void:
	_create_visuals()
	_interpolator = StateInterpolator.new()


func _create_visuals() -> void:
	var half_size := BODY_SIZE / 2.0

	# Body - colored rectangle
	body = ColorRect.new()
	body.size = Vector2(BODY_SIZE, BODY_SIZE)
	body.position = Vector2(-half_size, -half_size)
	body.color = TIER_COLORS.get(1, Color.GRAY)
	add_child(body)

	# Facing indicator (triangle pointing in facing direction)
	var indicator_length := BODY_SIZE * 0.6
	var indicator_base := BODY_SIZE * 0.2
	facing_indicator = Polygon2D.new()
	facing_indicator.polygon = PackedVector2Array([
		Vector2(indicator_length, 0),
		Vector2(indicator_length * 0.4, -indicator_base),
		Vector2(indicator_length * 0.4, indicator_base)
	])
	facing_indicator.color = Color(1.0, 0.3, 0.3, 0.8)  # Reddish indicator
	add_child(facing_indicator)

	# Name label above the enemy
	name_label = Label.new()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(-50, -half_size - 30)
	name_label.size = Vector2(100, 20)
	name_label.add_theme_font_size_override("font_size", 11)
	add_child(name_label)

	# Health bar (using EnemyHealthBar widget)
	health_bar = EnemyHealthBar.create()
	add_child(health_bar)


## Initialize the enemy visual with data
func initialize(
	p_id: String,
	p_definition_id: String,
	p_display_name: String,
	p_position: Vector2,
	p_tier: int = 1,
	p_max_hp: float = 10.0
) -> void:
	enemy_id = p_id
	definition_id = p_definition_id
	display_name = p_display_name
	tier = p_tier
	max_hp = p_max_hp
	current_hp = p_max_hp
	position = p_position

	# Update visuals
	_update_appearance()
	name_label.text = display_name

	# Initialize interpolator with current position
	_interpolator.initialize_with_state({
		"position": p_position,
		"facing_angle": 0.0
	})


## Update the enemy state from server data (position + health)
func update_state(
	new_position: Vector2,
	new_facing: Vector2,
	new_current_hp: float,
	new_max_hp: float,
	new_is_alive: bool
) -> void:
	# Calculate facing angle from direction vector
	var facing_angle := 0.0
	if new_facing.length_squared() > 0.01:
		facing_angle = new_facing.angle()

	_interpolator.add_state({
		"position": new_position,
		"facing_angle": facing_angle
	})

	# Update health
	update_health(new_current_hp, new_max_hp, new_is_alive)


## Update health only (does not affect interpolation buffer)
func update_health(new_hp: float, new_max_hp: float, new_is_alive: bool) -> void:
	var old_hp := current_hp
	current_hp = new_hp
	max_hp = new_max_hp

	# Show health bar on damage
	if new_hp < old_hp:
		var damage := old_hp - new_hp
		health_bar.take_damage(damage, current_hp, max_hp)
	elif new_hp != old_hp:
		health_bar.set_health(current_hp, max_hp)

	# Handle death
	if not new_is_alive and is_alive:
		_on_death()
	elif new_is_alive and not is_alive:
		_on_revive()

	is_alive = new_is_alive


## Get the current facing direction as a Vector2
func get_current_facing() -> Vector2:
	var latest := _interpolator.get_latest_state()
	if latest.is_empty():
		return Vector2.RIGHT
	var angle: float = latest.get("facing_angle", 0.0)
	return Vector2(cos(angle), sin(angle))


## Show damage number at this enemy's position
func show_damage(damage: float, is_crit: bool = false) -> DamageNumber:
	var damage_num := DamageNumber.create(damage, position, is_crit)
	# Add to parent so it persists after enemy dies
	if get_parent() != null:
		get_parent().add_child(damage_num)
	return damage_num


## Show a miss indicator
func show_miss() -> DamageNumber:
	var miss_num := DamageNumber.create_miss(position)
	if get_parent() != null:
		get_parent().add_child(miss_num)
	return miss_num


func _process(_delta: float) -> void:
	_apply_interpolation()


func _apply_interpolation() -> void:
	if not _interpolator.has_data():
		return

	position = _interpolator.interpolate_position()
	facing_indicator.rotation = _interpolator.interpolate_angle("facing_angle")


func _update_appearance() -> void:
	# Set body color based on tier
	var base_color: Color = TIER_COLORS.get(tier, TIER_COLORS[1])
	body.color = base_color

	# Set name label color
	name_label.add_theme_color_override("font_color", base_color)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	name_label.add_theme_constant_override("outline_size", 1)


func _on_death() -> void:
	# Gray out the enemy
	body.color = COLOR_DEAD
	facing_indicator.visible = false
	health_bar.hide_bar()

	# Change name to "Corpse of X"
	name_label.text = "Corpse of %s" % display_name
	name_label.add_theme_color_override("font_color", COLOR_DEAD)

	# Flash effect (brief white flash then fade)
	_play_death_effect()


func _on_revive() -> void:
	# Restore appearance
	_update_appearance()
	facing_indicator.visible = true

	# Restore original name
	name_label.text = display_name


func _play_death_effect() -> void:
	# Simple death flash - briefly go white then fade to dead color
	body.color = Color.WHITE
	var tween := create_tween()
	tween.tween_property(body, "color", COLOR_DEAD, 0.3)


## Mark as dead (public method for factory)
func mark_dead() -> void:
	is_alive = false
	_on_death()


## Get the enemy ID
func get_enemy_id() -> String:
	return enemy_id


## Check if at a position (for click detection)
func is_at_position(check_pos: Vector2, radius: float = BODY_SIZE) -> bool:
	return position.distance_to(check_pos) <= radius


## Factory method to create an enemy visual
static func create(
	p_id: String,
	p_definition_id: String,
	p_display_name: String,
	p_position: Vector2,
	p_tier: int = 1,
	p_max_hp: float = 10.0
) -> EnemyVisual:
	var instance := EnemyVisual.new()
	instance.initialize(p_id, p_definition_id, p_display_name, p_position, p_tier, p_max_hp)
	return instance


## Factory method to create from EnemyState data dictionary
static func create_from_state(enemy_data: Dictionary, definition_data: Dictionary = {}) -> EnemyVisual:
	var id: String = enemy_data.get("id", "")
	var def_id: String = enemy_data.get("definition_id", "")

	var pos_data: Dictionary = enemy_data.get("position", {})
	var pos := Vector2(
		float(pos_data.get("x", 0.0)),
		float(pos_data.get("y", 0.0))
	)

	var display_name: String = definition_data.get("display_name", def_id)
	var tier: int = int(definition_data.get("tier", 1))
	var max_hp: float = float(enemy_data.get("max_hp", 10.0))

	var instance := EnemyVisual.new()
	instance.initialize(id, def_id, display_name, pos, tier, max_hp)

	# Set current HP
	instance.current_hp = float(enemy_data.get("current_hp", max_hp))
	instance.is_alive = enemy_data.get("is_alive", true)

	if not instance.is_alive:
		instance.mark_dead()

	return instance
