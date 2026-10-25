extends GutTest

var tuning: SpaceTuning


func before_each() -> void:
	tuning = SpaceTuning.new()


func _def(id: String) -> ComponentDef:
	return ComponentLibrary.get_def(id)


func test_every_component_has_the_basics() -> void:
	var defs := ComponentLibrary.all()
	assert_gt(defs.size(), 12, "A decent pool of parts")
	for def in defs:
		assert_false(def.display_name.is_empty(), "%s has a name" % def.id)
		assert_eq(def.glyph.length(), 2, "%s has a two-letter glyph" % def.id)
		assert_eq(def.needs_hardpoint, def.is_weapon(), "%s: only weapons need hardpoints" % def.id)


func test_starter_loadout() -> void:
	var loadout := Loadout.starter()
	assert_eq(loadout.hull.id, "skiff", "Starts on a Skiff")
	assert_eq(loadout.fitted.size(), 2, "Pulse laser and shield generator")
	assert_eq(loadout.power_used(), 3, "Draws 3 power")
	assert_eq(loadout.power_capacity(), 4, "Skiff supplies 4")


func test_shapes_rotate() -> void:
	var twin := _def("twin_laser")
	assert_eq(twin.cells(0), [Vector2i(0, 0), Vector2i(0, 1)] as Array[Vector2i], "Vertical at rotation 0")
	var turned := twin.cells(1)
	assert_eq(turned.size(), 2, "Still two cells")
	assert_true(turned.has(Vector2i(0, 0)) and turned.has(Vector2i(1, 0)), "Horizontal after a quarter turn")


func test_parts_must_sit_on_open_cells() -> void:
	var loadout := Loadout.new(HullDef.skiff())
	assert_eq(loadout.check_place(_def("magnet_coil"), Vector2i(0, 0), 0), "Doesn't fit there", "(0,0) is outside the Skiff")
	assert_eq(loadout.check_place(_def("magnet_coil"), Vector2i(9, 9), 0), "Doesn't fit there", "Off the grid")
	assert_true(loadout.can_place(_def("magnet_coil"), Vector2i(1, 1), 0), "Open cell")


func test_parts_cannot_overlap() -> void:
	var loadout := Loadout.starter()
	assert_eq(loadout.check_place(_def("magnet_coil"), Vector2i(1, 2), 0), "That space is taken", "Shield is there")


func test_weapons_need_a_hardpoint() -> void:
	var loadout := Loadout.new(HullDef.skiff())
	assert_eq(loadout.check_place(_def("pulse_laser"), Vector2i(2, 1), 0), "Weapons must cover a hardpoint", "Open cell isn't enough")
	assert_true(loadout.can_place(_def("pulse_laser"), Vector2i(0, 2), 0), "Side hardpoint works")


func test_power_budget() -> void:
	var loadout := Loadout.starter()
	var reason := loadout.check_place(_def("shield_generator"), Vector2i(3, 2), 0)
	assert_string_starts_with(reason, "Not enough power", "Room for it, but only 1 power free")
	assert_not_null(loadout.place(_def("reactor"), Vector2i(3, 2), 0), "A reactor fits there instead")
	assert_eq(loadout.power_capacity(), 8, "Reactor adds 4")
	assert_not_null(loadout.place(_def("kindler_array"), Vector2i(1, 1), 0), "Now there's power for a 2-power part")


func test_reactor_removal_is_blocked_when_it_would_leave_parts_unpowered() -> void:
	var loadout := Loadout.starter()
	var reactor := loadout.place(_def("reactor"), Vector2i(3, 2), 0)
	var thruster := loadout.place(_def("thruster"), Vector2i(0, 3), 0)
	assert_not_null(thruster, "Thruster fits on reactor power")
	var coil := loadout.place(_def("magnet_coil"), Vector2i(1, 1), 0)
	assert_not_null(coil, "Coil fits too")
	assert_eq(loadout.power_used(), 5, "Over the hull's own 4")
	assert_false(loadout.remove(reactor), "Can't pull the reactor")
	assert_true(loadout.remove(coil), "Removing a consumer works")
	assert_true(loadout.remove(reactor), "Now the reactor can come out")


func test_big_parts_need_a_big_hull() -> void:
	assert_eq(Loadout.new(HullDef.skiff()).check_place(_def("lance"), Vector2i(2, 0), 0), "Needs a bigger hull", "No lance on a Skiff")
	assert_true(Loadout.new(HullDef.corvette()).can_place(_def("lance"), Vector2i(3, 0), 0), "Corvette can mount it")


func test_lens_boosts_adjacent_weapons_only() -> void:
	var loadout := Loadout.new(HullDef.skiff())
	loadout.place(_def("pulse_laser"), Vector2i(2, 0), 0)
	var base := loadout.compute_stats(tuning).weapons[0].damage
	loadout.place(_def("focusing_lens"), Vector2i(2, 1), 0)
	assert_almost_eq(loadout.compute_stats(tuning).weapons[0].damage, base * 1.3, 0.001, "Lens touching the laser")
	var far := Loadout.new(HullDef.skiff())
	far.place(_def("pulse_laser"), Vector2i(2, 0), 0)
	far.place(_def("focusing_lens"), Vector2i(0, 4), 0)
	assert_almost_eq(far.compute_stats(tuning).weapons[0].damage, base, 0.001, "Lens out of reach")


func test_overclock_boosts_fire_rate() -> void:
	var loadout := Loadout.new(HullDef.skiff())
	loadout.place(_def("pulse_laser"), Vector2i(2, 0), 0)
	var base := loadout.compute_stats(tuning).weapons[0].rate
	loadout.place(_def("overclock_coil"), Vector2i(2, 1), 0)
	assert_almost_eq(loadout.compute_stats(tuning).weapons[0].rate, base * 1.25, 0.001, "25% faster")


func test_marks_scale_effects() -> void:
	var loadout := Loadout.new(HullDef.skiff())
	loadout.place(_def("shield_generator"), Vector2i(1, 2), 0, 2)
	assert_almost_eq(loadout.compute_stats(tuning).max_shield, 20.0 + 45.0, 0.001, "Mk II shield gives 45")
	var reactor := Loadout.new(HullDef.skiff())
	reactor.place(_def("reactor"), Vector2i(1, 2), 0, 3)
	assert_eq(reactor.power_capacity(), 4 + 6, "Mk III reactor supplies 6")


func test_marked_weapons_hit_harder() -> void:
	var loadout := Loadout.new(HullDef.skiff())
	loadout.place(_def("pulse_laser"), Vector2i(2, 0), 0, 3)
	var spec := loadout.compute_stats(tuning).weapons[0]
	assert_almost_eq(spec.damage, 1.6, 0.001, "Mk III is +60% damage")
	assert_almost_eq(spec.rate, 7.0 * 1.24, 0.001, "Mk III is +24% rate")


func test_utility_stats_add_up() -> void:
	var loadout := Loadout.new(HullDef.skiff())
	var base := loadout.compute_stats(tuning)
	loadout.place(_def("magnet_coil"), Vector2i(1, 1), 0)
	loadout.place(_def("thruster"), Vector2i(0, 3), 0)
	loadout.place(_def("armor_plate"), Vector2i(4, 3), 0)
	var stats := loadout.compute_stats(tuning)
	assert_almost_eq(stats.magnet, base.magnet + 55.0, 0.001, "Magnet coil")
	assert_almost_eq(stats.max_hull, base.max_hull + 30.0, 0.001, "Armor plate")
	assert_almost_eq(stats.speed, base.speed * 1.08, 0.01, "Thruster +12%, armor -4%")


func test_permanent_bonuses_apply() -> void:
	var loadout := Loadout.starter()
	var stats := loadout.compute_stats(tuning, {"max_hull": 20.0, "damage": 0.5})
	assert_almost_eq(stats.max_hull, 120.0, 0.001, "Hull bonus")
	assert_almost_eq(stats.weapons[0].damage, 1.5, 0.001, "Damage bonus")


func test_nose_mounts_fire_from_the_front() -> void:
	var stats := Loadout.starter().compute_stats(tuning)
	assert_gt(stats.weapons[0].mount.x, 0.0, "Nose hardpoint is ahead of center")
	assert_almost_eq(stats.weapons[0].mount.y, 0.0, 0.001, "And centered")


func test_auto_fit_finds_room_until_full() -> void:
	var loadout := Loadout.new(HullDef.skiff())
	loadout.place(_def("reactor"), Vector2i(1, 2), 0)
	loadout.place(_def("reactor"), Vector2i(3, 2), 1)
	var placed := 0
	while loadout.auto_fit(_def("armor_plate")) != null:
		placed += 1
		assert_lt(placed, 20, "Should run out of room")
	assert_gt(placed, 0, "Some plates fit")
	assert_null(loadout.auto_fit(_def("armor_plate")), "Full now")


func test_move_keeps_invalid_moves_from_happening() -> void:
	var loadout := Loadout.starter()
	var laser := loadout.fitted[0]
	assert_false(loadout.move(laser, Vector2i(2, 1), 0), "Can't move a weapon off its hardpoint")
	assert_eq(laser.origin, Vector2i(2, 0), "Stayed put")
	assert_true(loadout.move(laser, Vector2i(0, 2), 0), "Side hardpoint is fine")


func test_changing_hull_keeps_parts() -> void:
	var loadout := Loadout.starter()
	loadout.change_hull(HullDef.corvette())
	assert_eq(loadout.hull.id, "corvette", "New hull")
	assert_eq(loadout.fitted.size(), 2, "Both parts carried over")
	assert_eq(loadout.hold.size(), 0, "Nothing left over")
	var stats := loadout.compute_stats(tuning)
	assert_eq(stats.weapons.size(), 1, "Laser still mounted")
