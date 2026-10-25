class_name BorderLayer
extends Node2D
## Region borders, beacons, frontier markers, and the labels shown on the map.
## Line widths are in screen pixels so borders stay visible when zoomed out.

const TERRITORY_COLOR := Color(1.5, 0.82, 0.3)
const INTERIOR_COLOR := Color(1.0, 0.7, 0.3, 0.22)
const DARK_COLOR := Color(0.55, 0.32, 0.9, 0.3)
const CLAIM_COLOR := Color(2.2, 1.9, 1.4)
const ALARM_COLOR := Color(2.6, 0.45, 0.35)
const BEACON_COLOR := Color(2.2, 1.6, 0.7)
const MARKER_COLOR := Color(1.0, 0.75, 0.4)
const LABEL_COLOR := Color(0.85, 0.82, 0.95)
const THREAT_COLOR := Color(1.0, 0.4, 0.4)
const HEART_COLOR := Color(2.2, 0.25, 0.4)
const HEART_LABEL_COLOR := Color(1.0, 0.35, 0.4)
const MODIFIER_COLORS := {
	RegionData.Modifier.NEST: Color(1.0, 0.35, 0.6),
	RegionData.Modifier.RICH: Color(1.0, 0.85, 0.35),
	RegionData.Modifier.ASTEROIDS: Color(0.8, 0.72, 0.62),
	RegionData.Modifier.NEBULA: Color(0.5, 0.65, 1.0),
}

var sector: SectorData
var claiming_id := -1
var alarm := 0.0
var map_mode := false
var zoom := 1.0
## Claims still needed before the heart can be kindled (0 = unsealed).
var heart_claims_needed := 0

var _time := 0.0
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if sector == null:
		return
	var pixel := 1.0 / maxf(zoom, 0.01)
	_draw_edges(pixel)
	_draw_markers(pixel)
	if map_mode:
		_draw_labels(pixel)


func _draw_edges(pixel: float) -> void:
	for region in sector.regions:
		if region.id == claiming_id:
			continue
		var count := region.polygon.size()
		for k in count:
			var other_id := region.edge_neighbors[k]
			var other := sector.get_region(other_id)
			var a := region.polygon[k]
			var b := region.polygon[(k + 1) % count]
			if region.claimed:
				if other == null or not other.claimed:
					draw_line(a, b, TERRITORY_COLOR, 3.0 * pixel)
				elif region.id < other_id:
					draw_line(a, b, INTERIOR_COLOR, 1.5 * pixel)
			elif other == null or (not other.claimed and region.id < other_id):
				draw_line(a, b, DARK_COLOR, 1.5 * pixel)
	var claiming := sector.get_region(claiming_id)
	if claiming != null:
		var color := CLAIM_COLOR.lerp(ALARM_COLOR, clampf(alarm, 0.0, 1.0))
		color.a = 0.7 + 0.3 * sin(_time * 6.0)
		var outline := claiming.polygon.duplicate()
		outline.append(claiming.polygon[0])
		draw_polyline(outline, color, 3.5 * pixel)


func _draw_markers(pixel: float) -> void:
	var marker_scale := maxf(1.0, pixel * 0.6)
	for region in sector.regions:
		if region.claimed:
			var is_home := region.id == sector.home_id
			var size := (11.0 if is_home else 7.0) * marker_scale
			_draw_diamond(region.beacon, size, BEACON_COLOR, true)
			if is_home:
				var ring_color := BEACON_COLOR
				ring_color.a = 0.5
				draw_arc(region.beacon, size * 2.2, 0.0, TAU, 40, ring_color, 1.5 * pixel)
		elif region.is_heart:
			_draw_heart_marker(region, marker_scale, pixel)
		elif sector.is_frontier(region.id) and region.id != claiming_id:
			var pulse := 0.5 + 0.5 * sin(_time * 3.0 + region.id)
			var color := MARKER_COLOR
			color.a = 0.35 + 0.4 * pulse
			_draw_diamond(region.anchor, (9.0 + 3.0 * pulse) * marker_scale, color, false, 2.0 * pixel)


## A slow crimson heartbeat, ringed by a dashed seal until it can be kindled.
func _draw_heart_marker(region: RegionData, marker_scale: float, pixel: float) -> void:
	var beat := pow(maxf(sin(_time * 3.2), 0.0), 6.0)
	var size := (13.0 + 5.0 * beat) * marker_scale
	_draw_diamond(region.anchor, size, HEART_COLOR, true)
	if heart_claims_needed > 0:
		var seal := HEART_COLOR
		seal.a = 0.6
		for i in 12:
			var start := TAU * i / 12.0 + _time * 0.3
			draw_arc(region.anchor, size * 2.4, start, start + TAU / 24.0, 6, seal, 2.0 * pixel)


func _draw_labels(pixel: float) -> void:
	var title_size := int(15.0 * pixel)
	var detail_size := int(12.0 * pixel)
	var width := 420.0 * pixel
	for region in sector.regions:
		var color := LABEL_COLOR
		var title := region.name.to_upper()
		var detail := "%ds" % roundi(region.claim_seconds)
		if region.claimed:
			color = MARKER_COLOR
			detail = "HOME" if region.id == sector.home_id else "YOURS"
		elif region.is_heart:
			color = HEART_LABEL_COLOR
			title = "THE HEART"
			if heart_claims_needed > 0:
				detail = "SEALED  ·  claim %d more" % heart_claims_needed
			elif sector.is_frontier(region.id):
				detail = "%ds  ·  CAN KINDLE" % roundi(region.claim_seconds)
		elif sector.is_frontier(region.id):
			color = MARKER_COLOR
			detail = "%ds  ·  CAN KINDLE" % roundi(region.claim_seconds)
		else:
			color.a = 0.55
		var top_left := region.anchor + Vector2(-width * 0.5, -6.0 * pixel)
		draw_string(_font, top_left, title, HORIZONTAL_ALIGNMENT_CENTER, width, title_size, color)
		draw_string(_font, top_left + Vector2(0.0, 18.0 * pixel), detail, HORIZONTAL_ALIGNMENT_CENTER, width, detail_size, color)
		if region.modifier != RegionData.Modifier.NONE and not region.claimed:
			var modifier_color: Color = MODIFIER_COLORS[region.modifier]
			draw_string(_font, top_left + Vector2(0.0, -17.0 * pixel), region.modifier_name(), HORIZONTAL_ALIGNMENT_CENTER, width, detail_size, modifier_color)
		if not region.claimed:
			var pips := mini(region.depth, 5)
			var threat_color := THREAT_COLOR
			threat_color.a = color.a
			for i in pips:
				var offset := (i - (pips - 1) * 0.5) * 9.0 * pixel
				draw_circle(region.anchor + Vector2(offset, 30.0 * pixel), 2.5 * pixel, threat_color)


func _draw_diamond(center: Vector2, size: float, color: Color, filled: bool, width := 2.0) -> void:
	var points := PackedVector2Array([
		center + Vector2(0.0, -size),
		center + Vector2(size * 0.7, 0.0),
		center + Vector2(0.0, size),
		center + Vector2(-size * 0.7, 0.0),
	])
	if filled:
		draw_colored_polygon(points, color)
	else:
		points.append(points[0])
		draw_polyline(points, color, width)
