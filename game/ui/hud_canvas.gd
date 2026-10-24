class_name HudCanvas
extends Control
## The custom-drawn parts of the HUD: the claim bar, shield and hull meters,
## the dash pip, and arrows at the screen edge pointing to off-screen targets.

var claim_visible := false
var claim_progress := 0.0
var claim_color := SpaceHud.GOLD
var elite_mark := 0.9
var shield_ratio := 1.0
var hull_ratio := 1.0
var dash_ready := 1.0
## Each entry: {"position": Vector2 (screen), "color": Color, "size": float}
var indicators: Array[Dictionary] = []

var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if claim_visible:
		_draw_claim_bar()
	_draw_vitals()
	_draw_indicators()


func _draw_claim_bar() -> void:
	var bar := Rect2(size.x * 0.5 - 260.0, 62.0, 520.0, 12.0)
	draw_rect(bar.grow(3.0), Color(0.0, 0.0, 0.0, 0.55))
	draw_rect(bar, Color(0.12, 0.08, 0.16))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * claim_progress, bar.size.y)), claim_color)
	var mark_x := bar.position.x + bar.size.x * elite_mark
	draw_line(Vector2(mark_x, bar.position.y - 5.0), Vector2(mark_x, bar.end.y + 5.0), SpaceHud.VIOLET, 2.0)


func _draw_vitals() -> void:
	var origin := Vector2(24.0, size.y - 74.0)
	_draw_meter(origin, "SHIELD", shield_ratio, SpaceHud.CYAN)
	_draw_meter(origin + Vector2(0.0, 24.0), "HULL", hull_ratio, SpaceHud.ORANGE)
	var pip := origin + Vector2(272.0, 17.0)
	var ready := dash_ready >= 1.0
	draw_arc(pip, 9.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(dash_ready, 0.0, 1.0), 24, SpaceHud.GOLD if ready else SpaceHud.DIM, 3.0)
	draw_string(_font, pip + Vector2(16.0, 5.0), "DASH", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SpaceHud.GOLD if ready else SpaceHud.DIM)


func _draw_meter(origin: Vector2, label: String, ratio: float, color: Color) -> void:
	draw_string(_font, origin + Vector2(0.0, 11.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SpaceHud.DIM)
	var bar := Rect2(origin + Vector2(58.0, 2.0), Vector2(180.0, 9.0))
	draw_rect(bar.grow(2.0), Color(0.0, 0.0, 0.0, 0.5))
	draw_rect(bar, Color(0.12, 0.1, 0.15))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(ratio, 0.0, 1.0), bar.size.y)), color)


func _draw_indicators() -> void:
	var margin := 34.0
	var bounds := Rect2(Vector2(margin, margin), size - Vector2(margin, margin) * 2.0)
	var center := size * 0.5
	for indicator in indicators:
		var target: Vector2 = indicator["position"]
		if bounds.has_point(target):
			continue
		var direction := (target - center).normalized()
		var edge := _edge_point(center, direction, bounds)
		var arrow_size: float = indicator["size"]
		var tip := edge + direction * arrow_size * 0.6
		var back := edge - direction * arrow_size * 0.6
		var side := direction.orthogonal() * arrow_size * 0.55
		draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), indicator["color"])


func _edge_point(center: Vector2, direction: Vector2, bounds: Rect2) -> Vector2:
	var t := INF
	if direction.x > 0.0001:
		t = minf(t, (bounds.end.x - center.x) / direction.x)
	elif direction.x < -0.0001:
		t = minf(t, (bounds.position.x - center.x) / direction.x)
	if direction.y > 0.0001:
		t = minf(t, (bounds.end.y - center.y) / direction.y)
	elif direction.y < -0.0001:
		t = minf(t, (bounds.position.y - center.y) / direction.y)
	return center + direction * t
