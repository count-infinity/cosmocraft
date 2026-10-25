class_name LootScreen
extends CanvasLayer
## "Pick one of three" after a region ignites. Click a card or press 1-3;
## R (or the button) rerolls.

signal picked(choice: LootPicks.Choice)
signal reroll_requested

const CARD_SIZE := Vector2(250.0, 340.0)
const CARD_GAP := 30.0
const PREVIEW_CELL := 22.0
const RARITY_COLORS := {
	ComponentDef.Rarity.COMMON: Color(0.7, 0.76, 0.88),
	ComponentDef.Rarity.UNCOMMON: Color(0.4, 0.95, 0.7),
	ComponentDef.Rarity.RARE: Color(1.0, 0.75, 0.3),
}
const KIND_TAGS := {"component": "NEW PART", "upgrade": "UPGRADE", "hull": "HULL REFIT", "sparks": "SPARKS"}

var _view: LootView


class LootView extends Control:
	var choices: Array[LootPicks.Choice] = []
	var reroll_label := ""
	var can_reroll := false
	var screen: LootScreen
	var _hover := -1
	var _font: Font

	func _ready() -> void:
		_font = ThemeDB.fallback_font
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func card_rect(i: int) -> Rect2:
		var total := CARD_SIZE.x * choices.size() + CARD_GAP * (choices.size() - 1)
		var left := (size.x - total) * 0.5
		return Rect2(Vector2(left + i * (CARD_SIZE.x + CARD_GAP), size.y * 0.5 - CARD_SIZE.y * 0.5 + 10.0), CARD_SIZE)

	func reroll_rect() -> Rect2:
		return Rect2(Vector2(size.x * 0.5 - 120.0, card_rect(0).end.y + 24.0), Vector2(240.0, 40.0))

	func _gui_input(event: InputEvent) -> void:
		var motion := event as InputEventMouseMotion
		if motion != null:
			_hover = -1
			for i in choices.size():
				if card_rect(i).has_point(motion.position):
					_hover = i
			queue_redraw()
		var click := event as InputEventMouseButton
		if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			for i in choices.size():
				if card_rect(i).has_point(click.position):
					screen.picked.emit(choices[i])
					return
			if can_reroll and reroll_rect().has_point(click.position):
				screen.reroll_requested.emit()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.0, 0.03, 0.9))
		draw_string(_font, Vector2(0.0, card_rect(0).position.y - 54.0), "THE LIGHT OFFERS A GIFT", HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, SpaceHud.GOLD)
		draw_string(_font, Vector2(0.0, card_rect(0).position.y - 24.0), "Choose one for this run", HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, SpaceHud.DIM)
		for i in choices.size():
			_draw_card(i, choices[i])
		var button := reroll_rect()
		var button_color := SpaceHud.GOLD if can_reroll else Color(0.4, 0.38, 0.45)
		draw_rect(button, Color(0.06, 0.05, 0.09, 0.9))
		draw_rect(button, button_color, false, 2.0)
		draw_string(_font, button.position + Vector2(0.0, 26.0), reroll_label + "  [R]", HORIZONTAL_ALIGNMENT_CENTER, button.size.x, 16, button_color)

	func _draw_card(i: int, choice: LootPicks.Choice) -> void:
		var rect := card_rect(i)
		var accent: Color = RARITY_COLORS[choice.rarity]
		draw_rect(rect, Color(0.05, 0.04, 0.08, 0.95))
		draw_rect(rect, accent, false, 3.0 if i == _hover else 1.5)
		if i == _hover:
			draw_rect(rect.grow(-3.0), Color(accent, 0.06))
		var x := rect.position.x + 16.0
		var width := rect.size.x - 32.0
		var tag := "%s  ·  %s" % [KIND_TAGS[choice.kind], ComponentDef.RARITY_NAMES[choice.rarity].to_upper()]
		draw_string(_font, Vector2(x, rect.position.y + 26.0), tag, HORIZONTAL_ALIGNMENT_LEFT, width, 12, accent)
		draw_string(_font, Vector2(x, rect.position.y + 56.0), choice.title(), HORIZONTAL_ALIGNMENT_LEFT, width, 22, Color(0.95, 0.92, 1.0))
		var preview_center := Vector2(rect.get_center().x, rect.position.y + 130.0)
		match choice.kind:
			"component", "upgrade":
				_draw_shape(choice.def, preview_center)
			"hull":
				_draw_hull(HullDef.corvette(), preview_center)
			"sparks":
				var s := 26.0
				draw_colored_polygon(PackedVector2Array([
					preview_center + Vector2(0, -s), preview_center + Vector2(s * 0.6, 0),
					preview_center + Vector2(0, s), preview_center + Vector2(-s * 0.6, 0),
				]), SpaceHud.GOLD)
		var info := ""
		if choice.def != null:
			if choice.def.is_reactor():
				info = "Supplies %d power" % (-choice.def.power + choice.mark - 1)
			else:
				info = "Power %d" % choice.def.power
			if choice.def.needs_hardpoint:
				info += "  ·  needs a hardpoint"
			if choice.def.min_hull_class > 1:
				info += "  ·  Corvette+"
		draw_string(_font, Vector2(x, rect.position.y + 206.0), info, HORIZONTAL_ALIGNMENT_LEFT, width, 13, SpaceHud.DIM)
		draw_multiline_string(_font, Vector2(x, rect.position.y + 234.0), choice.description(), HORIZONTAL_ALIGNMENT_LEFT, width, 15, 5, Color(0.86, 0.84, 0.92))
		draw_string(_font, Vector2(rect.position.x, rect.end.y - 14.0), "[%d]" % (i + 1), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 14, accent)

	func _draw_shape(def: ComponentDef, center: Vector2) -> void:
		var cells := def.cells(0)
		var extent := Vector2i.ZERO
		for cell in cells:
			extent = Vector2i(maxi(extent.x, cell.x), maxi(extent.y, cell.y))
		var origin := center - (Vector2(extent) + Vector2.ONE) * PREVIEW_CELL * 0.5
		for cell in cells:
			var square := Rect2(origin + Vector2(cell) * PREVIEW_CELL, Vector2.ONE * PREVIEW_CELL).grow(-2.0)
			draw_rect(square, Color(def.color, 0.35))
			draw_rect(square, def.color, false, 2.0)
		draw_string(_font, Vector2(center.x - 40.0, center.y + 6.0), def.glyph, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 16, Color(1, 1, 1, 0.9))

	func _draw_hull(hull: HullDef, center: Vector2) -> void:
		var cell_size := 13.0
		var grid := Vector2(hull.size())
		var origin := center - grid * cell_size * 0.5
		for cell in hull.open_cells():
			var square := Rect2(origin + Vector2(cell) * cell_size, Vector2.ONE * cell_size).grow(-1.5)
			var hardpoint := hull.cell(cell) == HullDef.Cell.HARDPOINT
			draw_rect(square, Color(1.0, 0.62, 0.3, 0.6) if hardpoint else Color(0.4, 0.4, 0.55, 0.5))


func _ready() -> void:
	layer = 20
	_view = LootView.new()
	_view.screen = self
	add_child(_view)
	visible = false


func open(choices: Array[LootPicks.Choice], reroll_label: String, can_reroll: bool) -> void:
	_view.choices = choices
	_view.reroll_label = reroll_label
	_view.can_reroll = can_reroll
	_view.queue_redraw()
	visible = true


func close() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_1, KEY_2, KEY_3:
			var index := int(key.keycode - KEY_1)
			if index < _view.choices.size():
				get_viewport().set_input_as_handled()
				picked.emit(_view.choices[index])
		KEY_R:
			if _view.can_reroll:
				get_viewport().set_input_as_handled()
				reroll_requested.emit()
