class_name SurfaceProps
extends Node2D
## Everything on a planet's surface that isn't terrain or Gloom: resource
## deposits, supply caches, the lander on its pad, the Ember Vein and the
## pylon planted on it. The mission sets the siege fields each frame.

const LANDER_SHAPE: Array[Vector2] = [
	Vector2(0, -38), Vector2(12, -18), Vector2(30, 6), Vector2(26, 22), Vector2(10, 14),
	Vector2(0, 24), Vector2(-10, 14), Vector2(-26, 22), Vector2(-30, 6), Vector2(-12, -18),
]
const HULL_COLOR := Color(0.05, 0.045, 0.075)
const TRIM_COLOR := Color(2.0, 1.45, 0.6)
const PAD_COLOR := Color(1.4, 1.1, 0.6, 0.6)
const EMBER_COLOR := Color(2.8, 1.3, 0.4)
const CACHE_COLOR := Color(2.2, 1.7, 0.7)
const ALARM_COLOR := Color(2.6, 0.5, 0.4)
const PAD_RADIUS := 92.0

var map: SurfaceMap
var resource := "ore"
var pylon_planted := false
var siege_progress := 0.0
var siege_radius := 320.0
## 0..1: how urgently the siege ring should flash (the pilot is outside it).
var alarm := 0.0
var kindled := false

var _time := 0.0
var _fissure: Array[PackedVector2Array] = []


func build(new_map: SurfaceMap, planet_resource: String) -> void:
	map = new_map
	resource = planet_resource
	_fissure = _make_fissure()
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	for deposit in map.deposits:
		deposit.flash = maxf(deposit.flash - delta * 5.0, 0.0)
	queue_redraw()


func _draw() -> void:
	if map == null:
		return
	_draw_vein()
	_draw_pad()
	for deposit in map.deposits:
		if deposit.extractor:
			_draw_extractor(deposit)
		elif deposit.is_intact():
			_draw_deposit(deposit)
	for cache in map.caches:
		_draw_cache(cache)
	if pylon_planted or kindled:
		_draw_pylon()


# --- The Ember Vein and pylon ------------------------------------------------------

## A jagged crack in the ground with a few branches, leaking ember light.
func _make_fissure() -> Array[PackedVector2Array]:
	var rng := RandomNumberGenerator.new()
	rng.seed = map.map_seed + 7
	var lines: Array[PackedVector2Array] = []
	var trunk := PackedVector2Array()
	var heading := rng.randf() * TAU
	for side: float in [-1.0, 1.0]:
		var point := map.vein
		var direction := Vector2.from_angle(heading) * side
		var half := PackedVector2Array()
		for step in 6:
			direction = direction.rotated(rng.randf_range(-0.5, 0.5))
			point += direction * rng.randf_range(14.0, 24.0)
			half.append(point)
			if step == 2 or step == 4:
				var branch := PackedVector2Array([point])
				var branch_direction := direction.rotated(rng.randf_range(0.6, 1.1) * (1.0 if rng.randf() < 0.5 else -1.0))
				var tip := point
				for k in 3:
					tip += branch_direction.rotated(rng.randf_range(-0.4, 0.4)) * rng.randf_range(10.0, 16.0)
					branch.append(tip)
				lines.append(branch)
		if side < 0.0:
			half.reverse()
			trunk.append_array(half)
			trunk.append(map.vein)
		else:
			trunk.append_array(half)
	lines.insert(0, trunk)
	return lines


func _draw_vein() -> void:
	var beat := 0.5 + 0.5 * sin(_time * 2.2)
	var glow := 1.0 if kindled else 0.55 + 0.45 * beat
	for ring in 4:
		draw_circle(map.vein, 22.0 + ring * 13.0, Color(EMBER_COLOR, (0.03 + 0.03 * glow) * (1.0 - ring * 0.2)))
	for i in _fissure.size():
		var line := _fissure[i]
		var width := 7.0 if i == 0 else 4.0
		draw_polyline(line, Color(0.02, 0.01, 0.0, 0.9), width + 4.0)
		draw_polyline(line, EMBER_COLOR * (0.55 + 0.6 * glow), width * 0.5)


func _draw_pylon() -> void:
	var center := map.vein
	var flame := 0.85 + 0.15 * sin(_time * 13.0) + 0.1 * sin(_time * 31.0)
	var light := 1.0 if kindled else siege_progress
	if not kindled:
		_draw_siege_ring(center)
	var base := PackedVector2Array()
	for i in 6:
		base.append(center + Vector2.from_angle(TAU * i / 6.0 + PI / 6.0) * 22.0)
	draw_colored_polygon(base, HULL_COLOR)
	base.append(base[0])
	draw_polyline(base, TRIM_COLOR, 2.0)
	# Progress segments around the base fill as the siege goes on.
	var segments := 12
	for i in segments:
		var lit := float(i) / segments < light
		var start := -PI * 0.5 + TAU * i / segments + 0.05
		draw_arc(center, 34.0, start, start + TAU / segments - 0.1, 6, EMBER_COLOR if lit else Color(0.35, 0.3, 0.4, 0.6), 4.0 if lit else 2.0)
	draw_circle(center, 10.0, HULL_COLOR)
	draw_circle(center, 15.0 * flame * (0.6 + 0.4 * light), Color(EMBER_COLOR, 0.16))
	draw_circle(center, 6.0 * flame, EMBER_COLOR * (1.0 + light))


func _draw_siege_ring(center: Vector2) -> void:
	var color := Color(1.6, 1.15, 0.5, 0.45).lerp(Color(ALARM_COLOR, 0.8), alarm)
	var dashes := 48
	var spin := _time * 0.12
	for i in dashes:
		var start := spin + TAU * i / dashes
		draw_arc(center, siege_radius, start, start + TAU / dashes * 0.55, 4, color, 2.0)


# --- Lander -----------------------------------------------------------------------

func _draw_pad() -> void:
	var center := map.landing
	draw_circle(center, PAD_RADIUS, Color(0.08, 0.07, 0.1, 0.75))
	draw_arc(center, PAD_RADIUS, 0.0, TAU, 64, PAD_COLOR, 2.0)
	for i in 8:
		var blink := 0.4 + 0.6 * maxf(sin(_time * 3.0 - i * 0.785), 0.0)
		draw_circle(center + Vector2.from_angle(TAU * i / 8.0) * PAD_RADIUS, 3.0, TRIM_COLOR * blink)
	var hull := PackedVector2Array()
	for point in LANDER_SHAPE:
		hull.append(center + point * 1.25)
	var shadow := PackedVector2Array()
	for point in hull:
		shadow.append(point + Vector2(12.0, 16.0))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.4))
	draw_colored_polygon(hull, HULL_COLOR)
	hull.append(hull[0])
	draw_polyline(hull, TRIM_COLOR, 2.0)
	draw_circle(center + Vector2(0.0, -14.0), 5.0, TRIM_COLOR)
	var engine := 0.6 + 0.4 * sin(_time * 5.0)
	draw_circle(center + Vector2(-16.0, 26.0), 3.5, Color(2.2, 1.0, 0.3) * engine)
	draw_circle(center + Vector2(16.0, 26.0), 3.5, Color(2.2, 1.0, 0.3) * engine)


# --- Deposits and caches -----------------------------------------------------------

func _draw_deposit(deposit: SurfaceMap.Deposit) -> void:
	var color: Color = PlanetData.RESOURCE_COLORS[resource]
	var flash := deposit.flash
	var size := deposit.radius()
	var rng := RandomNumberGenerator.new()
	rng.seed = deposit.shape_seed
	draw_circle(deposit.position + Vector2(6.0, 9.0), size * 0.95, Color(0.0, 0.0, 0.0, 0.4))
	match resource:
		"crystal":
			var spikes := 4 + (2 if deposit.size > 1.0 else 0)
			for i in spikes:
				var angle := -PI * 0.5 + rng.randf_range(-1.0, 1.0)
				var length := size * rng.randf_range(0.8, 1.45)
				var width := size * rng.randf_range(0.22, 0.32)
				var foot := deposit.position + Vector2(rng.randf_range(-0.45, 0.45) * size, rng.randf_range(0.0, 0.35) * size)
				var direction := Vector2.from_angle(angle)
				var side := direction.orthogonal() * width
				var spike := PackedVector2Array([foot - side, foot + direction * length * 0.75 - side * 0.9, foot + direction * length, foot + direction * length * 0.75 + side * 0.9, foot + side])
				draw_colored_polygon(spike, Color(color * 0.28, 1.0).lerp(Color(2.5, 2.5, 2.5), flash))
				spike.append(spike[0])
				draw_polyline(spike, color * (0.8 + flash), 1.5)
		"biomass":
			var pods := 3 + (2 if deposit.size > 1.0 else 0)
			for i in pods:
				var offset := Vector2.from_angle(rng.randf() * TAU) * size * rng.randf_range(0.0, 0.55)
				var pod := size * rng.randf_range(0.38, 0.55)
				var swell := 1.0 + 0.06 * sin(_time * 2.0 + i)
				draw_circle(deposit.position + offset, pod * swell, Color(color * 0.22, 1.0).lerp(Color(2.5, 2.5, 2.5), flash))
				draw_arc(deposit.position + offset, pod * swell, 0.0, TAU, 20, color * 0.7, 1.5)
				draw_circle(deposit.position + offset, pod * 0.35, color * (0.9 + 0.3 * sin(_time * 3.0 + i)))
		_:
			var outline := PackedVector2Array()
			for i in 9:
				outline.append(deposit.position + Vector2.from_angle(TAU * i / 9.0) * size * rng.randf_range(0.78, 1.08))
			draw_colored_polygon(outline, Color(0.13, 0.09, 0.07).lerp(Color(2.0, 2.0, 2.0), flash))
			for i in 3:
				var a := deposit.position + Vector2.from_angle(rng.randf() * TAU) * size * 0.75
				var b := deposit.position + Vector2.from_angle(rng.randf() * TAU) * size * 0.2
				draw_line(a, b, color * (0.8 + 0.3 * sin(_time * 2.5 + i)), 2.5)
			outline.append(outline[0])
			draw_polyline(outline, Color(color * 0.45, 0.8), 1.5)
	if deposit.hp < deposit.max_hp:
		var left := deposit.hp / deposit.max_hp
		draw_arc(deposit.position, size + 9.0, -PI * 0.5, -PI * 0.5 + TAU * left, 24, Color(color, 0.8), 2.0)


## A small derrick on a deposit site, its head turning and its tank glowing.
func _draw_extractor(deposit: SurfaceMap.Deposit) -> void:
	var color: Color = PlanetData.RESOURCE_COLORS[resource]
	var center := deposit.position
	var base := PackedVector2Array()
	for i in 6:
		base.append(center + Vector2.from_angle(TAU * i / 6.0) * 20.0)
	draw_colored_polygon(base, HULL_COLOR)
	base.append(base[0])
	draw_polyline(base, TRIM_COLOR * 0.8, 2.0)
	var spin := _time * 2.0 + deposit.shape_seed % 10
	for i in 3:
		var arm := Vector2.from_angle(spin + TAU * i / 3.0) * 16.0
		draw_line(center, center + arm, TRIM_COLOR, 2.0)
	var glow := 0.6 + 0.4 * sin(_time * 3.0 + deposit.shape_seed % 7)
	draw_circle(center, 7.0, color * glow)
	draw_arc(center, 26.0, 0.0, TAU, 24, Color(color, 0.3 * glow), 1.5)


func _draw_cache(cache: SurfaceMap.Cache) -> void:
	var hexagon := PackedVector2Array()
	for i in 6:
		hexagon.append(cache.position + Vector2.from_angle(TAU * i / 6.0) * 15.0)
	var shadow := PackedVector2Array()
	for point in hexagon:
		shadow.append(point + Vector2(5.0, 7.0))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.4))
	draw_colored_polygon(hexagon, HULL_COLOR)
	hexagon.append(hexagon[0])
	if cache.opened:
		draw_polyline(hexagon, Color(0.6, 0.5, 0.4, 0.6), 1.5)
		return
	var pulse := 0.6 + 0.4 * sin(_time * 3.0 + cache.position.x)
	draw_polyline(hexagon, CACHE_COLOR * pulse, 2.0)
	draw_circle(cache.position, 4.0, CACHE_COLOR * (0.8 + 0.6 * pulse))
	draw_arc(cache.position, 24.0 + 4.0 * pulse, 0.0, TAU, 24, Color(CACHE_COLOR, 0.25 * pulse), 1.5)
