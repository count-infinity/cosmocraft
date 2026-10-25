class_name HomeBuildings
extends Node2D
## Draws Hearthhold's buildings: the Hearth's fire, the Launch Pad with your
## ship, the Shipyard, the Lab (a building plot until it's built, a humming
## dome while it researches) and the Outpost Relay with a moon for every
## kindled planet. Labels light up when the pilot can use a building.

const HULL_COLOR := Color(0.05, 0.045, 0.075)
const WALL_COLOR := Color(0.09, 0.075, 0.1)
const TRIM_COLOR := Color(2.0, 1.45, 0.6)
const FIRE_COLOR := Color(2.8, 1.5, 0.5)
const CYAN_COLOR := Color(0.6, 1.6, 2.4)
const PATH_COLOR := Color(0.9, 0.7, 0.45, 0.07)

var meta: MetaProgress
var near := ""
var _time := 0.0
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


static func anchor(id: String) -> Vector2:
	return Homeworld.BUILDINGS[id]["position"]


func _draw() -> void:
	if meta == null:
		return
	for id: String in Homeworld.BUILDINGS:
		if id != "hearth":
			draw_line(anchor("hearth"), anchor(id), PATH_COLOR, 46.0)
	_draw_pad(anchor("pad"))
	_draw_shipyard(anchor("shipyard"))
	_draw_lab(anchor("lab"))
	_draw_relay(anchor("relay"))
	_draw_quarters(anchor("quarters"))
	_draw_hearth(anchor("hearth"))
	for id: String in Homeworld.BUILDINGS:
		var info: Dictionary = Homeworld.BUILDINGS[id]
		var label_at := anchor(id) + Vector2(-120.0, float(info["radius"]) + 30.0)
		draw_string(_font, label_at, info["name"], HORIZONTAL_ALIGNMENT_CENTER, 240.0, 15, SpaceHud.GOLD if near == id else Color(0.75, 0.7, 0.8, 0.75))
		if id == "pad":
			draw_string(_font, label_at + Vector2(0.0, 17.0), Difficulty.name_of(meta.darkness).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 240.0, 12, Color(0.85, 0.5, 1.0, 0.85))


func _shadowed(points: PackedVector2Array, color: Color, trim: Color, width := 2.0) -> void:
	var shadow := PackedVector2Array()
	for point in points:
		shadow.append(point + Vector2(12.0, 16.0))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.4))
	draw_colored_polygon(points, color)
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, trim, width)


func _rect_points(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


func _circle_points(center: Vector2, radius: float, count := 32) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		points.append(center + Vector2.from_angle(TAU * i / count) * radius)
	return points


## A stone ring with a living fire and embers drifting up. The fire grows
## with the Hearth's level.
func _draw_hearth(center: Vector2) -> void:
	_shadowed(_circle_points(center, 56.0, 12), Color(0.12, 0.1, 0.11), Color(TRIM_COLOR * 0.45, 0.9), 3.0)
	draw_circle(center, 42.0, Color(0.16, 0.05, 0.02))
	var flicker := (0.85 + 0.1 * sin(_time * 11.0) + 0.06 * sin(_time * 27.0)) * (0.8 + 0.4 * minf(meta.hearth_level() / 40.0, 1.0))
	draw_circle(center, 34.0 * flicker, Color(FIRE_COLOR, 0.25))
	for i in 6:
		var angle := _time * 0.6 + TAU * i / 6.0
		var tip := center + Vector2.from_angle(angle) * (24.0 + 6.0 * sin(_time * 7.0 + i)) * flicker
		var side := Vector2.from_angle(angle).orthogonal() * 7.0
		draw_colored_polygon(PackedVector2Array([center + side, tip, center - side]), Color(FIRE_COLOR, 0.55))
	draw_circle(center, 14.0 * flicker, Color(2.8, 2.1, 1.0))
	for i in 10:
		var t := fmod(_time * 0.45 + i * 0.1, 1.0)
		var drift := Vector2(sin(i * 3.7 + _time) * 20.0, -t * 90.0)
		draw_circle(center + Vector2(cos(i * 2.1) * 18.0, 0.0) + drift, 2.2 * (1.0 - t), Color(FIRE_COLOR, 1.0 - t))


## The landing pad with your current ship, engines idling.
func _draw_pad(center: Vector2) -> void:
	draw_circle(center, 96.0, Color(0.08, 0.07, 0.1, 0.85))
	var dashes := 36
	for i in dashes:
		var start := TAU * i / dashes + _time * 0.1
		draw_arc(center, 96.0, start, start + TAU / dashes * 0.5, 3, Color(TRIM_COLOR, 0.5), 2.0)
	for i in 8:
		var blink := 0.35 + 0.65 * maxf(sin(_time * 3.0 - i * 0.785), 0.0)
		draw_circle(center + Vector2.from_angle(TAU * i / 8.0) * 80.0, 3.0, TRIM_COLOR * blink)
	var corvette := meta.starting_hull().id == "corvette"
	var shape: Array[Vector2] = Ship.CORVETTE_SHAPE if corvette else Ship.SKIFF_SHAPE
	var hull := PackedVector2Array()
	for point in shape:
		hull.append(center + point.rotated(-PI * 0.5) * 3.2)
	_shadowed(hull, HULL_COLOR, TRIM_COLOR, 2.5)
	var engine := 0.6 + 0.4 * sin(_time * 6.0)
	draw_circle(center + Vector2(0.0, 30.0), 5.0 * engine, Color(2.2, 1.0, 0.3))
	draw_circle(center + Vector2(0.0, -12.0), 4.0, TRIM_COLOR)


## A long hangar with its doors open toward the Hearth and a crane overhead.
func _draw_shipyard(center: Vector2) -> void:
	var body := Rect2(center - Vector2(95.0, 62.0), Vector2(190.0, 124.0))
	_shadowed(_rect_points(body), WALL_COLOR, Color(TRIM_COLOR * 0.7, 0.9), 2.0)
	for i in 5:
		var x := body.position.x + 22.0 + i * 36.5
		draw_line(Vector2(x, body.position.y + 8.0), Vector2(x, body.end.y - 30.0), Color(TRIM_COLOR * 0.35, 0.6), 1.5)
	var door := Rect2(Vector2(body.end.x - 6.0, center.y - 30.0), Vector2(10.0, 60.0))
	draw_rect(door, Color(2.0, 1.4, 0.6, 0.5 + 0.2 * sin(_time * 2.0)))
	var swing := sin(_time * 0.4) * 0.5
	var pivot := Vector2(body.position.x + 30.0, body.position.y + 20.0)
	var arm := pivot + Vector2.from_angle(swing) * 120.0
	draw_line(pivot, arm, Color(TRIM_COLOR, 0.8), 3.0)
	draw_line(arm, arm + Vector2(0.0, 22.0), Color(TRIM_COLOR, 0.6), 1.5)
	draw_circle(pivot, 6.0, TRIM_COLOR)


## A building plot until it's built; then a dome that pulses while it works.
func _draw_lab(center: Vector2) -> void:
	if not meta.has_building("lab"):
		var plot := Rect2(center - Vector2(80.0, 60.0), Vector2(160.0, 120.0))
		var dashes := 20
		var points := _rect_points(plot)
		for side in 4:
			var a := points[side]
			var b := points[(side + 1) % 4]
			for i in dashes:
				var t := float(i) / dashes
				draw_line(a.lerp(b, t), a.lerp(b, t + 0.5 / dashes), Color(TRIM_COLOR, 0.45), 2.0)
		for corner in points:
			draw_circle(corner, 4.0, Color(TRIM_COLOR, 0.8))
		draw_string(_font, center + Vector2(-80.0, 6.0), "%d sparks" % Research.LAB_COST, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 14, Color(TRIM_COLOR, 0.8))
		return
	var base := Rect2(center - Vector2(80.0, 30.0), Vector2(160.0, 80.0))
	_shadowed(_rect_points(base), WALL_COLOR, Color(CYAN_COLOR * 0.6, 0.9), 2.0)
	var researching := meta.is_researching()
	var pulse := 0.5 + 0.5 * sin(_time * (4.0 if researching else 1.0))
	_shadowed(_circle_points(center + Vector2(0.0, -20.0), 52.0, 28), Color(0.07, 0.09, 0.13), CYAN_COLOR * (0.6 + 0.4 * pulse), 2.5)
	draw_circle(center + Vector2(0.0, -20.0), 30.0, Color(CYAN_COLOR, 0.12 + (0.25 * pulse if researching else 0.0)))
	var antenna := center + Vector2(0.0, -20.0) + Vector2.from_angle(_time * 0.8) * 40.0
	draw_line(center + Vector2(0.0, -20.0), antenna, Color(CYAN_COLOR, 0.8), 2.0)
	draw_circle(antenna, 4.0, CYAN_COLOR)
	if researching:
		var progress := meta.research_progress()
		draw_arc(center + Vector2(0.0, -20.0), 64.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, CYAN_COLOR, 4.0)
	for i in 4:
		var window := Rect2(Vector2(base.position.x + 14.0 + i * 38.0, base.end.y - 22.0), Vector2(18.0, 10.0))
		draw_rect(window, Color(CYAN_COLOR * (0.4 + 0.4 * pulse), 0.8))


## A low hab with lit windows; a beacon blinks on its roof when the pilot
## has stat points waiting.
func _draw_quarters(center: Vector2) -> void:
	var body := Rect2(center - Vector2(56.0, 34.0), Vector2(112.0, 68.0))
	_shadowed(_rect_points(body), WALL_COLOR, Color(TRIM_COLOR * 0.7, 0.9), 2.0)
	var roof := PackedVector2Array([body.position + Vector2(-8.0, 0.0), body.position + Vector2(56.0, -26.0), Vector2(body.end.x + 8.0, body.position.y)])
	draw_colored_polygon(roof, Color(0.11, 0.09, 0.12))
	roof.append(roof[0])
	draw_polyline(roof, Color(TRIM_COLOR * 0.6, 0.9), 2.0)
	for i in 3:
		var window := Rect2(Vector2(body.position.x + 14.0 + i * 32.0, center.y - 8.0), Vector2(18.0, 14.0))
		draw_rect(window, Color(2.0, 1.5, 0.7, 0.55 + 0.15 * sin(_time * 1.3 + i)))
	if meta.pilot_points_free() > 0:
		var blink := 0.5 + 0.5 * sin(_time * 5.0)
		draw_circle(body.position + Vector2(56.0, -30.0), 4.0 + 2.0 * blink, TRIM_COLOR * (1.0 + blink))


## A relay mast; each kindled planet circles it as a little moon.
func _draw_relay(center: Vector2) -> void:
	_shadowed(_circle_points(center, 34.0, 8), WALL_COLOR, Color(TRIM_COLOR * 0.6, 0.9), 2.0)
	for i in 4:
		var strut := Vector2.from_angle(PI * 0.25 + i * PI * 0.5)
		draw_line(center + strut * 12.0, center + strut * 44.0, Color(TRIM_COLOR * 0.5, 0.8), 2.0)
	var pending := not meta.pending_total().is_empty()
	var pulse := 0.5 + 0.5 * sin(_time * (5.0 if pending else 1.2))
	draw_circle(center, 9.0, TRIM_COLOR * (0.7 + 0.6 * pulse))
	if pending:
		draw_arc(center, 20.0 + 26.0 * fmod(_time, 1.0), 0.0, TAU, 32, Color(TRIM_COLOR, 0.6 * (1.0 - fmod(_time, 1.0))), 2.0)
	var count := meta.outposts.size()
	for i in mini(count, 12):
		var outpost: Dictionary = meta.outposts[i]
		var angle := _time * 0.35 + TAU * i / maxf(count, 1.0)
		var reach := 62.0 + 10.0 * (i % 2)
		var moon := center + Vector2.from_angle(angle) * reach
		var color: Color = PlanetData.RESOURCE_COLORS.get(String(outpost["resource"]), TRIM_COLOR)
		draw_circle(moon, 6.0, Color(color * 0.5, 1.0))
		draw_arc(moon, 6.0, 0.0, TAU, 12, color, 1.5)
