extends GutTest
## Drives the refit and loot screens' input handling without a mouse.

var tuning: SpaceTuning


func before_each() -> void:
	tuning = SpaceTuning.new()


func _refit_with(loadout: Loadout) -> RefitScreen:
	var screen := RefitScreen.new()
	add_child_autofree(screen)
	screen.open(loadout, tuning, {})
	return screen


func _cell_center(view: Control, cell: Vector2i) -> Vector2:
	return view.grid_origin() + (Vector2(cell) + Vector2(0.5, 0.5)) * RefitScreen.CELL


func _hold_row(view: Control, index: int) -> Vector2:
	var rect: Rect2 = view.hold_rect()
	return rect.position + Vector2(40.0, 36.0 + (index + 0.5) * RefitScreen.HOLD_ROW)


func test_parts_move_from_the_hold_onto_the_grid() -> void:
	var loadout := Loadout.starter()
	loadout.stow(ComponentLibrary.get_def("magnet_coil"))
	var view := _refit_with(loadout)._view
	view._mouse = _hold_row(view, 0)
	view._pick_up()
	assert_false(view.held.is_empty(), "Picked up from the hold")
	assert_eq(loadout.hold.size(), 0, "Hold is empty while it's in hand")
	view._mouse = _cell_center(view, Vector2i(1, 1))
	view._put_down()
	assert_true(view.held.is_empty(), "Placed")
	assert_not_null(loadout.occupant(Vector2i(1, 1)), "Fitted where it was dropped")


func test_bad_placements_explain_themselves() -> void:
	var loadout := Loadout.starter()
	var view := _refit_with(loadout)._view
	view._mouse = _cell_center(view, Vector2i(2, 0))
	view._pick_up()
	assert_eq(loadout.fitted.size(), 1, "Laser lifted off the grid")
	view._mouse = _cell_center(view, Vector2i(2, 1))
	view._put_down()
	assert_eq(view.message, "Weapons must cover a hardpoint", "Explains why it won't go there")
	assert_false(view.held.is_empty(), "Still in hand")


func test_closing_returns_whatever_is_in_hand() -> void:
	var loadout := Loadout.starter()
	var screen := _refit_with(loadout)
	var view := screen._view
	view._mouse = _cell_center(view, Vector2i(2, 0))
	view._pick_up()
	watch_signals(screen)
	screen.close()
	assert_signal_emitted(screen, "closed", "Tells the game to re-apply the ship")
	assert_eq(loadout.fitted.size(), 2, "Laser went back")
	assert_not_null(loadout.occupant(Vector2i(2, 0)), "To its original spot")


func test_rotating_the_held_part() -> void:
	var loadout := Loadout.starter()
	loadout.stow(ComponentLibrary.get_def("thruster"))
	var view := _refit_with(loadout)._view
	view._mouse = _hold_row(view, 0)
	view._pick_up()
	view.rotate_held()
	assert_eq(int(view.held["rotation"]), 1, "Quarter turn")


func test_dropping_on_the_hold_stows_the_part() -> void:
	var loadout := Loadout.starter()
	var view := _refit_with(loadout)._view
	view._mouse = _cell_center(view, Vector2i(1, 2))
	view._pick_up()
	view._mouse = view.hold_rect().get_center()
	view._put_down()
	assert_eq(loadout.hold.size(), 1, "Shield stowed")
	assert_eq(loadout.fitted.size(), 1, "Only the laser left fitted")


func test_number_keys_pick_loot() -> void:
	var screen := LootScreen.new()
	add_child_autofree(screen)
	var choices: Array[LootPicks.Choice] = []
	for id in ["magnet_coil", "thruster", "reactor"]:
		var choice := LootPicks.Choice.new()
		choice.def = ComponentLibrary.get_def(id)
		choices.append(choice)
	screen.open(choices, "Reroll", false)
	watch_signals(screen)
	var key := InputEventKey.new()
	key.keycode = KEY_2
	key.pressed = true
	screen._unhandled_input(key)
	assert_signal_emitted_with_parameters(screen, "picked", [choices[1]])
