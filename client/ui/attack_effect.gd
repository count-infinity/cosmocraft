class_name AttackEffect
extends Node2D
## Visual effect for attacks.
## Shows a brief flash/arc/line effect from attacker to target.
## Self-destructs after animation completes.


## Effect type
enum EffectType {
	MELEE_SLASH,    ## Arc/slash effect for melee attacks
	MELEE_THRUST,   ## Line/thrust effect for stab attacks
	RANGED_BULLET,  ## Small projectile effect
	HIT_IMPACT,     ## Impact flash at hit location
}


## Duration of the effect in seconds
const EFFECT_DURATION: float = 0.25

## Colors for different effect types
const COLOR_MELEE := Color(0.9, 0.9, 0.9, 0.9)      # White
const COLOR_RANGED := Color(1.0, 0.9, 0.3, 0.9)     # Yellow
const COLOR_IMPACT := Color(1.0, 0.6, 0.2, 0.9)     # Orange
const COLOR_CRIT := Color(1.0, 0.3, 0.3, 1.0)       # Red

## Slash effect constants
const SLASH_ARC_ANGLE: float = PI / 3.0        ## 60 degree arc
const SLASH_SEGMENTS: int = 8                   ## Polygon segments for smooth arc
const SLASH_INNER_RADIUS_FACTOR: float = 0.3    ## Inner radius as fraction of outer
const SLASH_MIN_LENGTH: float = 20.0            ## Minimum arc length
const SLASH_MAX_LENGTH: float = 50.0            ## Maximum arc length
const SLASH_ROTATION_SPEED: float = 0.05        ## Radians per frame

## Thrust effect constants
const THRUST_WIDTH_NORMAL: float = 4.0          ## Line width for normal hits
const THRUST_WIDTH_CRIT: float = 6.0            ## Line width for critical hits

## Bullet effect constants
const BULLET_SIZE_NORMAL: float = 6.0           ## Bullet size for normal hits
const BULLET_SIZE_CRIT: float = 8.0             ## Bullet size for critical hits
const BULLET_FADE_START: float = 0.7            ## Progress when fade begins (0.0-1.0)

## Impact effect constants
const IMPACT_SIZE_NORMAL: float = 12.0          ## Impact size for normal hits
const IMPACT_SIZE_CRIT: float = 18.0            ## Impact size for critical hits
const IMPACT_SCALE_GROWTH: float = 1.5          ## Additional scale at end of animation


## Effect parameters
var effect_type: EffectType = EffectType.MELEE_SLASH
var start_pos: Vector2 = Vector2.ZERO
var end_pos: Vector2 = Vector2.ZERO
var is_crit: bool = false

## Animation state
var _elapsed: float = 0.0
var _effect_node: CanvasItem = null


func _init() -> void:
	z_index = 10  # Render above most things


func _ready() -> void:
	_create_effect()


func _process(delta: float) -> void:
	_elapsed += delta

	var progress := _elapsed / EFFECT_DURATION

	if progress >= 1.0:
		queue_free()
		return

	# Animate the effect based on type
	match effect_type:
		EffectType.MELEE_SLASH:
			_animate_slash(progress)
		EffectType.MELEE_THRUST:
			_animate_thrust(progress)
		EffectType.RANGED_BULLET:
			_animate_bullet(progress)
		EffectType.HIT_IMPACT:
			_animate_impact(progress)


## Configure the attack effect
func setup(
	p_effect_type: EffectType,
	p_start_pos: Vector2,
	p_end_pos: Vector2,
	p_is_crit: bool = false
) -> void:
	effect_type = p_effect_type
	start_pos = p_start_pos
	end_pos = p_end_pos
	is_crit = p_is_crit
	position = start_pos


func _create_effect() -> void:
	match effect_type:
		EffectType.MELEE_SLASH:
			_create_slash()
		EffectType.MELEE_THRUST:
			_create_thrust()
		EffectType.RANGED_BULLET:
			_create_bullet()
		EffectType.HIT_IMPACT:
			_create_impact()


func _create_slash() -> void:
	# Create an arc shape for melee slash
	var arc := Polygon2D.new()

	var angle := start_pos.angle_to_point(end_pos)
	var distance := start_pos.distance_to(end_pos)
	var arc_length := clampf(distance, SLASH_MIN_LENGTH, SLASH_MAX_LENGTH)

	# Build an arc polygon
	var points: PackedVector2Array = []
	var inner_radius := arc_length * SLASH_INNER_RADIUS_FACTOR
	var outer_radius := arc_length

	# Outer arc
	for i in range(SLASH_SEGMENTS + 1):
		var t := float(i) / float(SLASH_SEGMENTS)
		var a := angle - SLASH_ARC_ANGLE / 2 + SLASH_ARC_ANGLE * t
		points.append(Vector2(cos(a), sin(a)) * outer_radius)

	# Inner arc (reverse)
	for i in range(SLASH_SEGMENTS, -1, -1):
		var t := float(i) / float(SLASH_SEGMENTS)
		var a := angle - SLASH_ARC_ANGLE / 2 + SLASH_ARC_ANGLE * t
		points.append(Vector2(cos(a), sin(a)) * inner_radius)

	arc.polygon = points
	arc.color = COLOR_CRIT if is_crit else COLOR_MELEE
	add_child(arc)
	_effect_node = arc


func _create_thrust() -> void:
	# Create a line/thrust shape
	var line := Line2D.new()
	line.width = THRUST_WIDTH_CRIT if is_crit else THRUST_WIDTH_NORMAL
	line.default_color = COLOR_CRIT if is_crit else COLOR_MELEE
	line.add_point(Vector2.ZERO)
	line.add_point(end_pos - start_pos)
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(line)
	_effect_node = line


func _create_bullet() -> void:
	# Create a small circle for projectile
	var bullet := ColorRect.new()
	var size := BULLET_SIZE_CRIT if is_crit else BULLET_SIZE_NORMAL
	bullet.size = Vector2(size, size)
	bullet.position = Vector2(-size / 2, -size / 2)
	bullet.color = COLOR_CRIT if is_crit else COLOR_RANGED
	add_child(bullet)
	_effect_node = bullet


func _create_impact() -> void:
	# Create an expanding ring/flash effect at the impact point
	position = end_pos

	var impact := ColorRect.new()
	var size := IMPACT_SIZE_CRIT if is_crit else IMPACT_SIZE_NORMAL
	impact.size = Vector2(size, size)
	impact.position = Vector2(-size / 2, -size / 2)
	impact.color = COLOR_CRIT if is_crit else COLOR_IMPACT
	add_child(impact)
	_effect_node = impact


func _animate_slash(progress: float) -> void:
	if _effect_node == null:
		return

	# Fade out and slight rotation
	modulate.a = 1.0 - progress
	_effect_node.rotation += SLASH_ROTATION_SPEED


func _animate_thrust(progress: float) -> void:
	if _effect_node == null:
		return

	# Fade out
	modulate.a = 1.0 - progress


func _animate_bullet(progress: float) -> void:
	if _effect_node == null:
		return

	# Move from start to end
	position = start_pos.lerp(end_pos, progress)

	# Fade out in last portion
	if progress > BULLET_FADE_START:
		var fade_progress := (progress - BULLET_FADE_START) / (1.0 - BULLET_FADE_START)
		modulate.a = 1.0 - fade_progress


func _animate_impact(progress: float) -> void:
	if _effect_node == null:
		return

	# Expand and fade
	var scale_factor := 1.0 + progress * IMPACT_SCALE_GROWTH
	_effect_node.scale = Vector2(scale_factor, scale_factor)
	modulate.a = 1.0 - progress


# =============================================================================
# Factory Methods
# =============================================================================


## Create a melee slash effect
static func create_melee_slash(
	from_pos: Vector2,
	to_pos: Vector2,
	p_is_crit: bool = false
) -> AttackEffect:
	var effect := AttackEffect.new()
	effect.setup(EffectType.MELEE_SLASH, from_pos, to_pos, p_is_crit)
	return effect


## Create a melee thrust effect
static func create_melee_thrust(
	from_pos: Vector2,
	to_pos: Vector2,
	p_is_crit: bool = false
) -> AttackEffect:
	var effect := AttackEffect.new()
	effect.setup(EffectType.MELEE_THRUST, from_pos, to_pos, p_is_crit)
	return effect


## Create a ranged bullet effect
static func create_ranged(
	from_pos: Vector2,
	to_pos: Vector2,
	p_is_crit: bool = false
) -> AttackEffect:
	var effect := AttackEffect.new()
	effect.setup(EffectType.RANGED_BULLET, from_pos, to_pos, p_is_crit)
	return effect


## Create an impact effect at a position
static func create_impact(
	at_pos: Vector2,
	p_is_crit: bool = false
) -> AttackEffect:
	var effect := AttackEffect.new()
	effect.setup(EffectType.HIT_IMPACT, at_pos, at_pos, p_is_crit)
	return effect


## Create an attack effect based on weapon type
## weapon_type: "melee", "ranged", or specific weapon types
static func create_for_weapon(
	weapon_type: String,
	from_pos: Vector2,
	to_pos: Vector2,
	p_is_crit: bool = false
) -> AttackEffect:
	match weapon_type.to_lower():
		"ranged", "bow", "crossbow", "gun":
			return create_ranged(from_pos, to_pos, p_is_crit)
		"thrust", "spear", "dagger", "rapier":
			return create_melee_thrust(from_pos, to_pos, p_is_crit)
		_:
			# Default to slash for melee
			return create_melee_slash(from_pos, to_pos, p_is_crit)
