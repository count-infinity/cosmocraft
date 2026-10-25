class_name RefitScreen
extends CanvasLayer
## The fitting grid. Your hull is drawn in the shape of the ship; parts are
## shapes you place on it. Click a part (on the grid or in the hold) to pick it
## up, R or right click rotates, click to place, click the hold to stow it.
## Weapons must cover a hardpoint, and everything has to fit the power budget.

signal closed

const CELL := 52.0
const HOLD_ROW := 34.0

var _view: RefitView


class RefitView extends Control:
	var loadout: Loadout
	var tuning: SpaceTuning
	var bonuses: Dictionary = {}
	var stats: ShipStats
	var message := ""
	## What's in hand: {def, mark, rotation, from_fitted, origin, original_rotation}.
	var held: Dictionary = {}
	var _mouse := Vector2.ZERO
	var _font: Font

	func _ready() -> void:
		_font = ThemeDB.fallback_font
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func refresh() -> void:
		stats = loadout.compute_stats(tuning, bonuses)
		queue_redraw()

	func grid_origin() -> Vector2:
		var grid := Vector2(loadout.hull.size()) * CELL
		return Vector2(size.x * 0.33 - grid.x * 0.5, size.y * 0.5 - grid.y * 0.5 + 20.0)

	func hold_rect() -> Rect2:
		return Rect2(Vector2(size.x * 0.62, 120.0), Vector2(size.x * 0.32, HOLD_ROW * 7.0 + 40.0))

	func cell_at(point: Vector2) -> Vector2i:
		var local := (point - grid_origin()) / CELL
		return Vector2i(floori(local.x), floori(local.y))

	## Where the held part's top-left cell would go, keeping the cursor near its middle.
	func held_origin() -> Vector2i:
		var cells: Array[Vector2i] = (held["def"] as ComponentDef).cells(held["rotation"])
		var extent := Vector2i.ZERO
		for cell in cells:
			extent = Vector2i(maxi(extent.x, cell.x), maxi(extent.y, cell.y))
		return cell_at(_mouse) - Vector2i(extent.x / 2, extent.y / 2)

	func _gui_input(event: InputEvent) -> void:
		var motion := event as InputEventMouseMotion
		if motion != null:
			_mouse = motion.position
			queue_redraw()
			return
		var click := event as InputEventMouseButton
		if click == null or not click.pressed:
			return
		_mouse = click.position
		if click.button_index == MOUSE_BUTTON_RIGHT:
			rotate_held()
		elif click.button_index == MOUSE_BUTTON_LEFT:
			if held.is_empty():
				_pick_up()
			else:
				_put_down()
		queue_redraw()

	func rotate_held() -> void:
		if not held.is_empty():
			held["rotation"] = (int(held["rotation"]) + 1) % 4
			queue_redraw()

	func _pick_up() -> void:
		message = ""
		var item := loadout.occupant(cell_at(_mouse))
		if item != null:
			var reason := loadout.check_remove(item)
			if not reason.is_empty():
				message = reason
				return
			held = {"def": item.def, "mark": item.mark, "rotation": item.rotation, "from_fitted": true, "origin": item.origin, "original_rotation": item.rotation}
			loadout.remove(item)
			refresh()
			return
		var index := _hold_index_at(_mouse)
		if index >= 0:
			var stowed := loadout.hold[index]
			held = {"def": stowed.def, "mark": stowed.mark, "rotation": 0, "from_fitted": false}
			loadout.hold.remove_at(index)
			refresh()

	func _put_down() -> void:
		if hold_rect().has_point(_mouse):
			loadout.stow(held["def"], held["mark"])
			held = {}
			message = ""
			refresh()
			return
		var def: ComponentDef = held["def"]
		var reason := loadout.check_place(def, held_origin(), held["rotation"])
		if reason.is_empty():
			loadout.place(def, held_origin(), held["rotation"], held["mark"])
			held = {}
			message = ""
			refresh()
		else:
			message = reason

	## Puts whatever is in hand back where it came from.
	func return_held() -> void:
		if held.is_empty():
			return
		var def: ComponentDef = held["def"]
		if bool(held["from_fitted"]) and loadout.place(def, held["origin"], held["original_rotation"], held["mark"]) != null:
			pass
		else:
			loadout.stow(def, held["mark"])
		held = {}
		refresh()

	func _hold_index_at(point: Vector2) -> int:
		var rect := hold_rect()
		if not rect.has_point(point):
			return -1
		var index := int((point.y - rect.position.y - 36.0) / HOLD_ROW)
		return index if index >= 0 and index < loadout.hold.size() else -1

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.0, 0.03, 0.92))
		draw_string(_font, Vector2(0.0, 52.0), "REFIT  ·  %s" % loadout.hull.display_name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, SpaceHud.GOLD)
		draw_string(_font, Vector2(0.0, 80.0), "Click a part to pick it up  ·  R or right click to rotate  ·  click to place  ·  drop on the hold to stow  ·  F or Esc to close", HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, SpaceHud.DIM)
		_draw_grid()
		_draw_hold()
		_draw_stats()
		if not held.is_empty():
			_draw_held()
		if not message.is_empty():
			draw_string(_font, Vector2(0.0, size.y - 36.0), message, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, SpaceHud.RED)

	func _draw_grid() -> void:
		var origin := grid_origin()
		for cell in loadout.hull.open_cells():
			var square := Rect2(origin + Vector2(cell) * CELL, Vector2.ONE * CELL).grow(-2.0)
			draw_rect(square, Color(0.1, 0.09, 0.14))
			draw_rect(square, Color(0.3, 0.28, 0.4), false, 1.0)
			if loadout.hull.cell(cell) == HullDef.Cell.HARDPOINT:
				var c := square.get_center()
				var mark := Color(1.0, 0.62, 0.3, 0.7)
				draw_arc(c, CELL * 0.22, 0.0, TAU, 20, mark, 2.0)
				draw_line(c - Vector2(CELL * 0.32, 0), c + Vector2(CELL * 0.32, 0), mark, 1.0)
				draw_line(c - Vector2(0, CELL * 0.32), c + Vector2(0, CELL * 0.32), mark, 1.0)
		draw_string(_font, origin + Vector2(0.0, -14.0), "NOSE", HORIZONTAL_ALIGNMENT_CENTER, loadout.hull.size().x * CELL, 12, SpaceHud.DIM)
		for item in loadout.fitted:
			_draw_part(item.def, item.cells(), item.mark, origin, 1.0)

	func _draw_part(def: ComponentDef, cells: Array[Vector2i], mark: int, origin: Vector2, alpha: float, tint := Color.WHITE) -> void:
		var color := def.color * tint
		var center := Vector2.ZERO
		for cell in cells:
			var square := Rect2(origin + Vector2(cell) * CELL, Vector2.ONE * CELL).grow(-4.0)
			draw_rect(square, Color(color, 0.32 * alpha))
			draw_rect(square, Color(color, alpha), false, 2.0)
			center += square.get_center()
		center /= cells.size()
		draw_string(_font, center + Vector2(-40.0, 6.0), def.glyph, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 18, Color(1, 1, 1, 0.95 * alpha))
		if mark > 1:
			draw_string(_font, center + Vector2(-40.0, 22.0), "I".repeat(mark), HORIZONTAL_ALIGNMENT_CENTER, 80.0, 12, Color(SpaceHud.GOLD, alpha))

	func _draw_held() -> void:
		var def: ComponentDef = held["def"]
		var cells: Array[Vector2i] = []
		var origin_cell := held_origin()
		for cell in def.cells(held["rotation"]):
			cells.append(cell + origin_cell)
		var valid := loadout.check_place(def, origin_cell, held["rotation"]).is_empty()
		var over_grid := false
		for cell in cells:
			if loadout.hull.cell(cell) != HullDef.Cell.VOID:
				over_grid = true
		if over_grid:
			_draw_part(def, cells, held["mark"], grid_origin(), 0.9, Color(0.6, 1.4, 0.7) if valid else Color(1.6, 0.4, 0.4))
		else:
			var shape: Array[Vector2i] = def.cells(held["rotation"])
			var floating_origin := _mouse - Vector2(CELL * 0.5, CELL * 0.5)
			_draw_part(def, shape, held["mark"], floating_origin, 0.8)
		draw_string(_font, _mouse + Vector2(24.0, -18.0), def.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.95, 0.92, 1.0))

	func _draw_hold() -> void:
		var rect := hold_rect()
		var highlight := not held.is_empty() and rect.has_point(_mouse)
		draw_rect(rect, Color(0.05, 0.04, 0.08, 0.9))
		draw_rect(rect, SpaceHud.GOLD if highlight else Color(0.35, 0.32, 0.45), false, 1.5)
		draw_string(_font, rect.position + Vector2(14.0, 24.0), "HOLD  (parts not fitted)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, SpaceHud.DIM)
		if loadout.hold.is_empty():
			draw_string(_font, rect.position + Vector2(14.0, 60.0), "Empty. Loot that doesn't fit lands here.", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 28.0, 13, Color(0.6, 0.58, 0.7))
		for i in loadout.hold.size():
			var stowed := loadout.hold[i]
			var row := Vector2(rect.position.x + 14.0, rect.position.y + 36.0 + i * HOLD_ROW)
			draw_rect(Rect2(row + Vector2(0, 4), Vector2(24, 24)), Color(stowed.def.color, 0.4))
			draw_string(_font, row + Vector2(0, 22), stowed.def.glyph, HORIZONTAL_ALIGNMENT_CENTER, 24.0, 12, Color.WHITE)
			var label := stowed.def.display_name + ("  Mk " + "I".repeat(stowed.mark) if stowed.mark > 1 else "")
			draw_string(_font, row + Vector2(34, 21), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 60.0, 15, Color(0.9, 0.88, 0.96))

	func _draw_stats() -> void:
		var rect := hold_rect()
		var x := rect.position.x
		var y := rect.end.y + 34.0
		var used := stats.power_used
		var capacity := stats.power_capacity
		draw_string(_font, Vector2(x, y), "POWER  %d / %d" % [used, capacity], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ComponentLibrary.POWER_COLOR)
		var bar := Rect2(Vector2(x, y + 10.0), Vector2(rect.size.x, 10.0))
		draw_rect(bar, Color(0.12, 0.1, 0.15))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(used) / maxf(capacity, 1.0), 0.0, 1.0), bar.size.y)), ComponentLibrary.POWER_COLOR)
		var lines := [
			"Hull  %d      Shield  %d" % [roundi(stats.max_hull), roundi(stats.max_shield)],
			"Speed  %d      Magnet  %d" % [roundi(stats.speed), roundi(stats.magnet)],
			"Dash cooldown  %.2fs      Claims  x%.2f" % [stats.dash_cooldown, stats.claim_speed],
			"Firepower  %.1f / s      Weapons  %d" % [stats.total_dps(), stats.weapons.size()],
		]
		for i in lines.size():
			draw_string(_font, Vector2(x, y + 48.0 + i * 24.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.86, 0.84, 0.92))


func _ready() -> void:
	layer = 20
	_view = RefitView.new()
	add_child(_view)
	visible = false


func open(loadout: Loadout, tuning: SpaceTuning, bonuses: Dictionary) -> void:
	_view.loadout = loadout
	_view.tuning = tuning
	_view.bonuses = bonuses
	_view.held = {}
	_view.message = ""
	_view.refresh()
	visible = true


func close() -> void:
	if not visible:
		return
	_view.return_held()
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_R:
		_view.rotate_held()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
