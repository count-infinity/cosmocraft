class_name SectorChoiceScreen
extends CanvasLayer
## After a heart burns out: push on into an adjacent dark sector with the ship
## you've built (harder, but you keep going), or return home and bank
## everything with the victory bonus. Click a card or press 1-4.

signal chosen(sector_id: int)

const CARD_SIZE := Vector2(230.0, 250.0)
const CARD_GAP := 24.0
const HOME := -1

var _view: ChoiceView


class ChoiceView extends Control:
	## Each option: {"id": int, "name": String, "system": String, "tier": int,
	## "color": Color, "blurb": String}. The last card is always "return home".
	var options: Array[Dictionary] = []
	var banked_preview := 0
	var screen: SectorChoiceScreen
	var _hover := -1
	var _font: Font

	func _ready() -> void:
		_font = ThemeDB.fallback_font
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func card_count() -> int:
		return options.size() + 1

	func card_rect(i: int) -> Rect2:
		var total := CARD_SIZE.x * card_count() + CARD_GAP * (card_count() - 1)
		var left := (size.x - total) * 0.5
		return Rect2(Vector2(left + i * (CARD_SIZE.x + CARD_GAP), size.y * 0.5 - CARD_SIZE.y * 0.5 + 30.0), CARD_SIZE)

	func id_for(i: int) -> int:
		return int(options[i]["id"]) if i < options.size() else HOME

	func _gui_input(event: InputEvent) -> void:
		var motion := event as InputEventMouseMotion
		if motion != null:
			_hover = -1
			for i in card_count():
				if card_rect(i).has_point(motion.position):
					_hover = i
			queue_redraw()
		var click := event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			for i in card_count():
				if card_rect(i).has_point(click.position):
					screen.chosen.emit(id_for(i))
					return

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.02, 0.72))
		var top := card_rect(0).position.y
		draw_string(_font, Vector2(0.0, top - 92.0), "THE SECTOR IS RELIT", HORIZONTAL_ALIGNMENT_CENTER, size.x, 36, SpaceHud.GOLD)
		draw_string(_font, Vector2(0.0, top - 56.0), "It's yours for good. Push on into the dark with this ship, or go home and bank %d sparks with the victory bonus." % banked_preview, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, SpaceHud.DIM)
		draw_string(_font, Vector2(0.0, top - 32.0), "Dying out there keeps every sector you've conquered, but loses the bonus.", HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color(0.7, 0.66, 0.8))
		for i in card_count():
			_draw_card(i)

	func _draw_card(i: int) -> void:
		var rect := card_rect(i)
		var home := i >= options.size()
		var accent: Color = SpaceHud.GOLD if home else Color(options[i]["color"])
		draw_rect(rect, Color(0.04, 0.035, 0.07, 0.96))
		draw_rect(rect, accent, false, 3.0 if _hover == i else 1.5)
		draw_string(_font, rect.position + Vector2(14.0, 26.0), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, SpaceHud.DIM)
		var center := rect.position + Vector2(rect.size.x * 0.5, 78.0)
		if home:
			draw_circle(center, 22.0, Color(SpaceHud.GOLD, 0.2))
			draw_circle(center, 9.0, SpaceHud.GOLD)
			draw_string(_font, rect.position + Vector2(0.0, 140.0), "RETURN HOME", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 20, SpaceHud.GOLD)
			draw_multiline_string(_font, rect.position + Vector2(16.0, 170.0), "Bank your sparks with the +25% victory bonus. Spend them at Hearthhold.", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 32.0, 13, 4, SpaceHud.DIM)
			return
		var option := options[i]
		draw_circle(center, 20.0, Color(accent, 0.12))
		draw_arc(center, 20.0, 0.0, TAU, 32, accent, 2.0)
		draw_string(_font, center + Vector2(-20.0, 6.0), str(option["tier"]), HORIZONTAL_ALIGNMENT_CENTER, 40.0, 16, accent)
		draw_string(_font, rect.position + Vector2(0.0, 134.0), String(option["name"]).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 17, Color(0.95, 0.92, 1.0))
		draw_string(_font, rect.position + Vector2(0.0, 156.0), "%s  ·  tier %d" % [option["system"], int(option["tier"])], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 13, accent)
		draw_multiline_string(_font, rect.position + Vector2(16.0, 182.0), "Push on: %s" % option["blurb"], HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 32.0, 12, 4, SpaceHud.DIM)


func _ready() -> void:
	layer = 21
	_view = ChoiceView.new()
	_view.screen = self
	add_child(_view)
	visible = false


func open(options: Array[Dictionary], banked_preview: int) -> void:
	_view.options = options
	_view.banked_preview = banked_preview
	visible = true
	_view.queue_redraw()


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var index := key.keycode - KEY_1
	if index >= 0 and index < _view.card_count():
		get_viewport().set_input_as_handled()
		chosen.emit(_view.id_for(index))
