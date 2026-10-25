class_name HomePanel
extends CanvasLayer
## The window a homeworld building opens: the Launch Pad (pick the darkness
## and launch), the Shipyard (permanent upgrades and blueprints, for sparks),
## the Lab (build it, then research with planet resources on a real-time
## clock), the Outpost Relay (collect what kindled planets have mined) and the
## Hearth (the last run, records, and Hearth levels to spend). Esc or E closes
## it. `changed` fires whenever progress was spent, gained or picked, so
## GameFlow can save.

signal closed
signal changed
signal launch_requested

const PAGES := ["launch", "shipyard", "lab", "relay", "hearth", "quarters"]
const TRACK_ROW := Vector2(482.0, 64.0)
const WINDOW := Vector2(1120.0, 600.0)
const UPGRADE_CARD := Vector2(250.0, 84.0)
const BLUEPRINT_CARD := Vector2(160.0, 58.0)
const RESEARCH_CARD := Vector2(510.0, 70.0)
const GAP := 12.0
const CARD_COLOR := Color(0.05, 0.04, 0.08, 0.95)
const LOCKED_COLOR := Color(0.45, 0.42, 0.55)
const DONE_COLOR := Color(0.45, 0.9, 0.6)
const TEXT_COLOR := Color(0.94, 0.92, 1.0)

var page := ""
var _view: PanelView


class PanelView extends Control:
	var panel: HomePanel
	var meta: MetaProgress
	var last_run: RunState
	var last_banked := 0
	var message := ""
	var clock := 0.0
	var _hover := ""
	var _font: Font

	func _ready() -> void:
		_font = ThemeDB.fallback_font
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _process(_delta: float) -> void:
		if visible:
			clock = MetaProgress.now()
			queue_redraw()

	func window() -> Rect2:
		return Rect2((size - WINDOW) * 0.5, WINDOW)

	func content_origin() -> Vector2:
		return window().position + Vector2(36.0, 118.0)

	# --- Layout -------------------------------------------------------------------

	func upgrade_rect(i: int) -> Rect2:
		return Rect2(content_origin() + Vector2((i % 3) * (UPGRADE_CARD.x + GAP), (i / 3) * (UPGRADE_CARD.y + GAP)), UPGRADE_CARD)

	func blueprint_rect(i: int) -> Rect2:
		var top := upgrade_rect(MetaUpgrades.LIST.size() - 1).end.y + 44.0
		return Rect2(Vector2(content_origin().x + (i % 4) * (BLUEPRINT_CARD.x + GAP), top + (i / 4) * (BLUEPRINT_CARD.y + GAP)), BLUEPRINT_CARD)

	func research_rect(i: int) -> Rect2:
		return Rect2(content_origin() + Vector2((i % 2) * (RESEARCH_CARD.x + GAP + 14.0), (i / 2) * (RESEARCH_CARD.y + GAP)), RESEARCH_CARD)

	func build_rect() -> Rect2:
		return Rect2(window().get_center() - Vector2(220.0, 20.0), Vector2(440.0, 120.0))

	func collect_rect() -> Rect2:
		return Rect2(window().end - Vector2(360.0, 92.0), Vector2(320.0, 56.0))

	func map_rect() -> Rect2:
		return Rect2(content_origin(), Vector2(700.0, 420.0))

	## Star map coordinates to screen.
	func map_point(point: Vector2) -> Vector2:
		var rect := map_rect()
		var scale := minf(rect.size.x / GalaxyData.MAP_SIZE.x, rect.size.y / GalaxyData.MAP_SIZE.y)
		return rect.position + (rect.size - GalaxyData.MAP_SIZE * scale) * 0.5 + point * scale

	func side_rect() -> Rect2:
		var left := map_rect().end.x + 24.0
		return Rect2(Vector2(left, content_origin().y), Vector2(window().end.x - 36.0 - left, 420.0))

	func darkness_prev_rect() -> Rect2:
		var side := side_rect()
		return Rect2(side.position + Vector2(0.0, 214.0), Vector2(36.0, 30.0))

	func darkness_next_rect() -> Rect2:
		var side := side_rect()
		return Rect2(Vector2(side.end.x - 36.0, side.position.y + 214.0), Vector2(36.0, 30.0))

	func launch_rect() -> Rect2:
		var side := side_rect()
		return Rect2(Vector2(side.position.x, side.end.y - 50.0), Vector2(side.size.x, 50.0))

	func hearth_card() -> Rect2:
		return Rect2(content_origin() + Vector2(530.0, 0.0), Vector2(WINDOW.x - 72.0 - 530.0, 440.0))

	func track_rect(i: int) -> Rect2:
		return Rect2(hearth_card().position + Vector2(18.0, 112.0 + i * (TRACK_ROW.y + 8.0)), TRACK_ROW)

	func reset_rect() -> Rect2:
		var card := hearth_card()
		return Rect2(Vector2(card.end.x - 158.0, card.end.y - 36.0), Vector2(140.0, 26.0))

	func _hit(point: Vector2) -> String:
		match panel.page:
			"launch":
				if darkness_prev_rect().has_point(point):
					return "darkness_prev"
				if darkness_next_rect().has_point(point):
					return "darkness_next"
				if launch_rect().has_point(point):
					return "launch"
				for sector in meta.galaxy().sectors:
					if map_point(sector.position).distance_to(point) < 14.0 and meta.can_select_sector(sector.id):
						return "sector:%d" % sector.id
			"hearth":
				for i in HearthRanks.TRACKS.size():
					if track_rect(i).has_point(point):
						return "hearth:" + String(HearthRanks.TRACKS[i]["id"])
				if reset_rect().has_point(point):
					return "hearth_reset"
			"quarters":
				for i in PilotRanks.STATS.size():
					if track_rect(i).has_point(point):
						return "pilot:" + String(PilotRanks.STATS[i]["id"])
				if reset_rect().has_point(point):
					return "pilot_reset"
			"shipyard":
				for i in MetaUpgrades.LIST.size():
					if upgrade_rect(i).has_point(point):
						return "upgrade:" + String(MetaUpgrades.LIST[i]["id"])
				var ids: Array = MetaUpgrades.BLUEPRINTS.keys()
				for i in ids.size():
					if blueprint_rect(i).has_point(point):
						return "blueprint:" + String(ids[i])
			"lab":
				if not meta.has_building("lab"):
					return "build_lab" if build_rect().has_point(point) else ""
				for i in Research.LIST.size():
					if research_rect(i).has_point(point):
						return "research:" + String(Research.LIST[i]["id"])
			"relay":
				if collect_rect().has_point(point):
					return "collect"
		return ""

	# --- Input --------------------------------------------------------------------

	func _gui_input(event: InputEvent) -> void:
		var motion := event as InputEventMouseMotion
		if motion != null:
			_hover = _hit(motion.position)
			return
		var click := event as InputEventMouseButton
		if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
			return
		if not window().has_point(click.position):
			panel.close()
			return
		press(_hit(click.position))

	## Acts on a target from _hit() (also how tests press buttons).
	func press(target: String) -> void:
		if target == "darkness_prev" or target == "darkness_next":
			target = "darkness:%d" % (meta.darkness + (1 if target == "darkness_next" else -1))
		if target.begins_with("sector:"):
			var id := int(target.trim_prefix("sector:"))
			if meta.select_sector(id):
				var sector := meta.galaxy().get_sector(id)
				message = "Next run: %s  ·  tier %d" % [sector.name, sector.tier]
				panel.changed.emit()
		elif target.begins_with("darkness:"):
			var level := int(target.trim_prefix("darkness:"))
			if level < 0:
				message = "Twilight is as light as it gets"
			elif meta.select_darkness(level):
				message = "Next run: %s  ·  %s" % [Difficulty.name_of(level), Difficulty.reward_text(level)]
				panel.changed.emit()
			else:
				message = "Relight a sector on %s to unlock %s" % [Difficulty.name_of(meta.darkness_unlocked), Difficulty.name_of(level)]
		elif target == "launch":
			panel.launch_requested.emit()
		elif target.begins_with("hearth:"):
			var id := target.trim_prefix("hearth:")
			if meta.spend_hearth_point(id):
				message = "%s: %d" % [HearthRanks.get_track(id)["name"], int(meta.hearth_points[id])]
				panel.changed.emit()
			elif meta.hearth_points_free() <= 0:
				message = "No Hearth points to spend: bank more sparks to raise the Hearth's level"
			else:
				message = "That one is maxed out"
		elif target == "hearth_reset":
			if meta.hearth_points_spent() > 0:
				meta.reset_hearth_points()
				message = "Hearth points returned: spend them however you like"
				panel.changed.emit()
		elif target.begins_with("pilot:"):
			var id := target.trim_prefix("pilot:")
			if meta.spend_pilot_point(id):
				message = "%s: %d" % [PilotRanks.get_stat(id)["name"], int(meta.pilot_points[id])]
				panel.changed.emit()
			elif meta.pilot_points_free() <= 0:
				message = "No points to spend: your pilot levels up from fighting and building on planets"
			else:
				message = "That one is maxed out"
		elif target == "pilot_reset":
			if not meta.pilot_points.is_empty():
				meta.reset_pilot_points()
				message = "Stat points returned: spend them however you like"
				panel.changed.emit()
		elif target.begins_with("upgrade:"):
			var id := target.trim_prefix("upgrade:")
			if meta.buy(id):
				message = "Bought %s" % MetaUpgrades.get_upgrade(id)["name"]
				panel.changed.emit()
			else:
				message = "Maxed out" if meta.is_maxed(id) else "Not enough sparks"
		elif target.begins_with("blueprint:"):
			var id := target.trim_prefix("blueprint:")
			if meta.buy_blueprint(id):
				message = "%s can now show up in loot picks" % ComponentLibrary.get_def(id).display_name
				panel.changed.emit()
			elif not meta.blueprints.has(id):
				message = "Not enough sparks"
		elif target == "build_lab":
			if meta.build_lab():
				message = "The Lab is built. Pick something to research."
				panel.changed.emit()
			else:
				message = "Not enough sparks: the Lab costs %d" % Research.LAB_COST
		elif target.begins_with("research:"):
			var id := target.trim_prefix("research:")
			var project := Research.get_project(id)
			if meta.start_research(id):
				message = "Researching %s: back in %s" % [project["name"], Research.duration_text(Research.seconds(project))]
				panel.changed.emit()
			elif meta.research_done.has(id):
				message = "Already researched"
			elif meta.is_researching():
				message = "The Lab is busy with %s" % Research.get_project(String(meta.research_active["id"]))["name"]
			else:
				message = "Needs %s" % Research.cost_text(project)
		elif target == "collect":
			var got := meta.collect_outposts()
			if got.is_empty():
				message = "Nothing to collect yet"
			else:
				var parts: Array[String] = []
				for kind in PlanetData.RESOURCE_ORDER:
					if got.has(kind):
						parts.append("%d %s" % [int(got[kind]), kind])
				message = "Collected " + ", ".join(parts)
				panel.changed.emit()
		queue_redraw()

	# --- Drawing ------------------------------------------------------------------

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.02, 0.6))
		var frame := window()
		draw_rect(frame, Color(0.025, 0.02, 0.045, 0.97))
		draw_rect(frame, Color(0.55, 0.45, 0.3, 0.8), false, 1.5)
		var titles := {
			"launch": ["THE STAR MAP", "pick a dark sector next to your territory to invade, or a conquered one to replay"],
			"shipyard": ["THE SHIPYARD", "spend sparks on upgrades that last between runs"],
			"lab": ["THE LAB", "research runs on the real clock, even while you're out in the dark"],
			"relay": ["OUTPOST RELAY", "kindled planets mine for you while you're away"],
			"hearth": ["THE HEARTH", "the light you've kept"],
			"quarters": ["QUARTERS", "your pilot: levels earned on planets, stats to spend"],
		}
		var title: Array = titles.get(panel.page, ["", ""])
		draw_string(_font, frame.position + Vector2(36.0, 52.0), title[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 30, SpaceHud.GOLD)
		draw_string(_font, frame.position + Vector2(38.0, 78.0), title[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, SpaceHud.DIM)
		draw_string(_font, Vector2(frame.position.x, frame.position.y + 36.0), "[Esc] close", HORIZONTAL_ALIGNMENT_RIGHT, frame.size.x - 30.0, 13, SpaceHud.DIM)
		_draw_wallet(Vector2(frame.end.x - 36.0, frame.position.y + 74.0))
		match panel.page:
			"launch":
				_draw_launch()
			"shipyard":
				_draw_shipyard()
			"lab":
				_draw_lab()
			"relay":
				_draw_relay()
			"hearth":
				_draw_hearth()
			"quarters":
				_draw_quarters()
		if not message.is_empty():
			draw_string(_font, Vector2(frame.position.x + 36.0, frame.end.y - 24.0), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, SpaceHud.GOLD)
		elif panel.page == "hearth":
			draw_string(_font, Vector2(frame.position.x + 36.0, frame.end.y - 24.0), "Next: " + panel.next_goal(meta), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, SpaceHud.GOLD)

	## Sparks and resources, right-aligned at `right`.
	func _draw_wallet(right: Vector2) -> void:
		var x := right.x
		for i in range(PlanetData.RESOURCE_ORDER.size() - 1, -1, -1):
			var kind: String = PlanetData.RESOURCE_ORDER[i]
			var text := str(int(meta.resources.get(kind, 0)))
			var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
			x -= width
			draw_string(_font, Vector2(x, right.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, _display(PlanetData.RESOURCE_COLORS[kind]))
			x -= 16.0
			HudCanvas.draw_resource_icon(self, Vector2(x, right.y - 6.0), kind, 6.5)
			x -= 22.0
		var sparks := str(meta.sparks)
		x -= _font.get_string_size(sparks, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_string(_font, Vector2(x, right.y), sparks, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, SpaceHud.GOLD)
		var at := Vector2(x - 12.0, right.y - 6.0)
		draw_colored_polygon(PackedVector2Array([at + Vector2(0, -8), at + Vector2(5, 0), at + Vector2(0, 8), at + Vector2(-5, 0)]), SpaceHud.GOLD)

	func _display(color: Color) -> Color:
		return Color(minf(color.r, 1.0), minf(color.g, 1.0), minf(color.b, 1.0))

	func _card(rect: Rect2, accent: Color, hovered: bool) -> void:
		draw_rect(rect, CARD_COLOR)
		draw_rect(rect, accent, false, 2.5 if hovered else 1.2)

	func _draw_shipyard() -> void:
		draw_string(_font, content_origin() + Vector2(0.0, -12.0), "UPGRADES", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, SpaceHud.DIM)
		for i in MetaUpgrades.LIST.size():
			_draw_upgrade(upgrade_rect(i), MetaUpgrades.LIST[i])
		var ids: Array = MetaUpgrades.BLUEPRINTS.keys()
		draw_string(_font, blueprint_rect(0).position + Vector2(0.0, -12.0), "BLUEPRINTS  ·  add parts to the loot pool", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, SpaceHud.DIM)
		for i in ids.size():
			_draw_blueprint(blueprint_rect(i), String(ids[i]))
		var side := Rect2(Vector2(upgrade_rect(2).end.x + 30.0, content_origin().y), Vector2(window().end.x - upgrade_rect(2).end.x - 66.0, 250.0))
		_card(side, Color(0.35, 0.32, 0.45), false)
		var hull := meta.starting_hull()
		draw_string(_font, side.position + Vector2(16.0, 28.0), "YOUR SHIP", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, SpaceHud.DIM)
		draw_string(_font, side.position + Vector2(16.0, 54.0), hull.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, TEXT_COLOR)
		var parts := meta.start_parts()
		var extra := "Starts with: " + (", ".join(parts.map(func(id: String) -> String: return ComponentLibrary.get_def(id).display_name)) if not parts.is_empty() else "the standard kit")
		draw_multiline_string(_font, side.position + Vector2(16.0, 84.0), extra, HORIZONTAL_ALIGNMENT_LEFT, side.size.x - 32.0, 13, 4, SpaceHud.DIM)
		draw_multiline_string(_font, side.position + Vector2(16.0, 150.0), "Upgrades and blueprints cost sparks, which every run brings home, won or lost.", HORIZONTAL_ALIGNMENT_LEFT, side.size.x - 32.0, 13, 4, SpaceHud.DIM)

	func _draw_upgrade(rect: Rect2, upgrade: Dictionary) -> void:
		var id: String = upgrade["id"]
		var maxed := meta.is_maxed(id)
		var affordable := meta.can_buy(id)
		var accent := SpaceHud.GOLD if affordable else (DONE_COLOR if maxed else LOCKED_COLOR)
		_card(rect, accent, _hover == "upgrade:" + id)
		draw_string(_font, rect.position + Vector2(12.0, 22.0), upgrade["name"], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 24.0, 16, TEXT_COLOR)
		draw_string(_font, rect.position + Vector2(12.0, 42.0), upgrade["desc"], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 24.0, 12, SpaceHud.DIM)
		for r in int(upgrade["max"]):
			draw_rect(Rect2(rect.position + Vector2(12.0 + r * 16.0, 56.0), Vector2(11.0, 11.0)), SpaceHud.GOLD if r < meta.rank(id) else Color(0.2, 0.18, 0.26))
		var price := "MAX" if maxed else "%d" % meta.next_cost(id)
		draw_string(_font, Vector2(rect.position.x, rect.end.y - 14.0), price, HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 12.0, 15, accent)

	func _draw_blueprint(rect: Rect2, id: String) -> void:
		var def := ComponentLibrary.get_def(id)
		var owned := meta.blueprints.has(id)
		var accent := DONE_COLOR if owned else (SpaceHud.GOLD if meta.can_buy_blueprint(id) else LOCKED_COLOR)
		_card(rect, accent, _hover == "blueprint:" + id)
		draw_rect(Rect2(rect.position + Vector2(10.0, 12.0), Vector2(22.0, 22.0)), Color(def.color, 0.4))
		draw_string(_font, rect.position + Vector2(10.0, 28.0), def.glyph, HORIZONTAL_ALIGNMENT_CENTER, 22.0, 11, Color.WHITE)
		draw_string(_font, rect.position + Vector2(40.0, 26.0), def.display_name, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 46.0, 13, TEXT_COLOR)
		var price := "UNLOCKED" if owned else "%d" % int(MetaUpgrades.BLUEPRINTS[id])
		draw_string(_font, rect.position + Vector2(40.0, 46.0), price, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 46.0, 12, accent)

	func _draw_lab() -> void:
		if not meta.has_building("lab"):
			var rect := build_rect()
			var affordable := meta.can_build_lab()
			_card(rect, SpaceHud.GOLD if affordable else LOCKED_COLOR, _hover == "build_lab")
			draw_string(_font, rect.position + Vector2(0.0, 44.0), "BUILD THE LAB", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 24, SpaceHud.GOLD if affordable else LOCKED_COLOR)
			draw_string(_font, rect.position + Vector2(0.0, 78.0), "%d sparks" % Research.LAB_COST, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 17, TEXT_COLOR)
			draw_multiline_string(_font, Vector2(rect.position.x - 80.0, rect.end.y + 40.0), "Research turns ore, crystal and biomass from kindled planets into lasting advantages: tougher ships, faster claims, a better-equipped pilot, starting parts.", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x + 160.0, 14, 6, SpaceHud.DIM)
			return
		for i in Research.LIST.size():
			_draw_project(research_rect(i), Research.LIST[i])

	func _draw_project(rect: Rect2, project: Dictionary) -> void:
		var id: String = project["id"]
		var done := meta.research_done.has(id)
		var active := meta.is_researching() and String(meta.research_active["id"]) == id
		var affordable := meta.can_start_research(id)
		var accent := DONE_COLOR if done else (SpaceHud.CYAN if active else (SpaceHud.GOLD if affordable else LOCKED_COLOR))
		_card(rect, accent, _hover == "research:" + id)
		draw_string(_font, rect.position + Vector2(14.0, 24.0), project["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT_COLOR if not done else DONE_COLOR)
		draw_string(_font, rect.position + Vector2(14.0, 46.0), project["desc"], HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 150.0, 12, SpaceHud.DIM)
		var right := rect.position.x + rect.size.x - 14.0
		if done:
			draw_string(_font, Vector2(rect.position.x, rect.position.y + 38.0), "DONE", HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 14.0, 15, DONE_COLOR)
		elif active:
			var progress := meta.research_progress(clock)
			var bar := Rect2(Vector2(right - 120.0, rect.position.y + 46.0), Vector2(120.0, 7.0))
			draw_rect(bar, Color(0.12, 0.1, 0.18))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), SpaceHud.CYAN)
			draw_string(_font, Vector2(right - 200.0, rect.position.y + 30.0), Research.duration_text(meta.research_seconds_left(clock)) + " left", HORIZONTAL_ALIGNMENT_RIGHT, 200.0, 15, SpaceHud.CYAN)
		else:
			draw_string(_font, Vector2(right - 220.0, rect.position.y + 26.0), Research.cost_text(project), HORIZONTAL_ALIGNMENT_RIGHT, 220.0, 13, accent)
			draw_string(_font, Vector2(right - 220.0, rect.position.y + 48.0), Research.duration_text(Research.seconds(project)), HORIZONTAL_ALIGNMENT_RIGHT, 220.0, 13, SpaceHud.DIM)

	func _draw_relay() -> void:
		var origin := content_origin()
		var rate := meta.outpost_rate()
		draw_string(_font, origin + Vector2(0.0, -12.0), "Each outpost mines %.0f an hour, and up to %d hours' worth piles up between visits." % [rate, int(MetaProgress.OUTPOST_CAP_HOURS)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, SpaceHud.DIM)
		if meta.outposts.is_empty():
			draw_multiline_string(_font, origin + Vector2(0.0, 60.0), "No outposts yet.\n\nOut in a sector, claim every region around a planet to wake it, then land on it, find its Ember Vein and kindle it. Every kindled planet becomes an outpost that mines for you here, run after run.", HORIZONTAL_ALIGNMENT_LEFT, WINDOW.x - 120.0, 16, 8, TEXT_COLOR)
			return
		var row_height := 34.0
		var shown := mini(meta.outposts.size(), 11)
		for i in shown:
			var outpost: Dictionary = meta.outposts[meta.outposts.size() - 1 - i]
			var y := origin.y + 22.0 + i * row_height
			var kind := String(outpost["resource"])
			draw_rect(Rect2(Vector2(origin.x, y - 22.0), Vector2(WINDOW.x - 450.0, row_height - 6.0)), CARD_COLOR)
			HudCanvas.draw_resource_icon(self, Vector2(origin.x + 18.0, y - 8.0), kind, 6.5)
			draw_string(_font, Vector2(origin.x + 36.0, y - 2.0), String(outpost["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TEXT_COLOR)
			var extractors := int(outpost.get("extractors", 0))
			var detail := "%s world" % String(outpost["type"])
			if extractors > 0:
				detail += "  ·  %d extractor%s" % [extractors, "" if extractors == 1 else "s"]
			draw_string(_font, Vector2(origin.x + 250.0, y - 2.0), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, SpaceHud.DIM)
			var pending := meta.outpost_pending(outpost, clock)
			draw_string(_font, Vector2(origin.x, y - 2.0), "+%d %s" % [pending, kind], HORIZONTAL_ALIGNMENT_RIGHT, WINDOW.x - 470.0, 14, _display(PlanetData.RESOURCE_COLORS[kind]) if pending > 0 else SpaceHud.DIM)
		if meta.outposts.size() > shown:
			draw_string(_font, Vector2(origin.x, origin.y + 22.0 + shown * row_height), "and %d more" % (meta.outposts.size() - shown), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, SpaceHud.DIM)
		var rect := collect_rect()
		var totals := meta.pending_total(clock)
		_card(rect, SpaceHud.GOLD if not totals.is_empty() else LOCKED_COLOR, _hover == "collect")
		draw_string(_font, rect.position + Vector2(0.0, 36.0), "COLLECT ALL", HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 20, SpaceHud.GOLD if not totals.is_empty() else LOCKED_COLOR)

	func _draw_launch() -> void:
		var map := meta.galaxy()
		var owned := meta.conquered_set()
		var selected := meta.launch_sector()
		var rect := map_rect()
		var pulse := 0.5 + 0.5 * sin(clock * 3.0)
		draw_rect(rect, Color(0.012, 0.01, 0.028, 0.95))
		draw_rect(rect, Color(0.35, 0.32, 0.45), false, 1.0)
		for system in map.systems:
			var center := map_point(system.position)
			var fallen := map.system_conquered(system.id, owned)
			draw_circle(center, 58.0, Color(system.color, 0.07 if fallen else 0.025))
			draw_arc(center, 58.0, 0.0, TAU, 48, Color(system.color, 0.35 if fallen else 0.15), 1.0)
			draw_string(_font, center + Vector2(-90.0, -60.0), system.name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 180.0, 11, Color(system.color, 0.95 if fallen else 0.7))
		for sector in map.sectors:
			for neighbor in sector.neighbors:
				if neighbor < sector.id:
					continue
				var both := owned.has(sector.id) and owned.has(neighbor)
				var one := owned.has(sector.id) or owned.has(neighbor)
				var color := Color(1.0, 0.78, 0.4, 0.6) if both else (Color(0.85, 0.5, 1.0, 0.35) if one else Color(0.5, 0.48, 0.6, 0.14))
				draw_line(map_point(sector.position), map_point(map.sectors[neighbor].position), color, 2.0 if both else 1.0)
		for sector in map.sectors:
			var at := map_point(sector.position)
			var system := map.systems[sector.system_id]
			if sector.id == map.home_id:
				draw_circle(at, 9.0, SpaceHud.GOLD)
				draw_arc(at, 13.0, 0.0, TAU, 24, SpaceHud.GOLD, 1.5)
			elif owned.has(sector.id):
				draw_circle(at, 6.5, SpaceHud.GOLD)
			elif map.can_invade(sector.id, owned):
				draw_circle(at, 6.0, Color(system.color, 0.25))
				draw_arc(at, 7.0 + 2.0 * pulse, 0.0, TAU, 24, Color(system.color, 0.9), 2.0)
				draw_string(_font, at + Vector2(9.0, -6.0), str(sector.tier), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(system.color, 0.9))
			else:
				draw_circle(at, 4.0, Color(0.45, 0.42, 0.55, 0.6))
			if sector.id == selected:
				draw_arc(at, 15.0, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.9), 2.0)
			elif _hover == "sector:%d" % sector.id:
				draw_arc(at, 13.0, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, 0.45), 1.5)
		var systems_lit := map.systems_conquered(owned)
		draw_string(_font, Vector2(rect.position.x, rect.end.y + 22.0), "Conquered %d of %d sectors  ·  %d of %d systems  ·  +%d%% rewards from fallen systems" % [owned.size(), map.sectors.size(), systems_lit, map.systems.size(), roundi(meta.conquest_bonus() * 100.0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SpaceHud.DIM)
		_draw_sector_card(map, selected, owned)
		_draw_darkness_picker()
		var button := launch_rect()
		_card(button, SpaceHud.GOLD, _hover == "launch")
		draw_rect(button.grow(-1.0), Color(0.12, 0.08, 0.03, 0.9))
		draw_string(_font, button.position + Vector2(0.0, 32.0), "LAUNCH  [Enter]", HORIZONTAL_ALIGNMENT_CENTER, button.size.x, 19, SpaceHud.GOLD)

	func _draw_sector_card(map: GalaxyData, id: int, owned: Dictionary) -> void:
		var side := side_rect()
		var card := Rect2(side.position, Vector2(side.size.x, 180.0))
		var sector := map.get_sector(id)
		var system := map.system_of(id)
		_card(card, system.color, false)
		var x := card.position.x + 16.0
		draw_string(_font, Vector2(x, card.position.y + 30.0), sector.name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 32.0, 18, TEXT_COLOR)
		draw_string(_font, Vector2(x, card.position.y + 50.0), "%s  ·  tier %d" % [system.name, sector.tier], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, system.color)
		var status := "Conquered: replay it for sparks and resources" if owned.has(id) else "Dark: burn out its heart to conquer it"
		draw_string(_font, Vector2(x, card.position.y + 76.0), status, HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 32.0, 12, DONE_COLOR if owned.has(id) else SpaceHud.GOLD)
		draw_string(_font, Vector2(x, card.position.y + 96.0), Difficulty.tier_text(sector.tier), HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 32.0, 12, SpaceHud.DIM)
		draw_multiline_string(_font, Vector2(x, card.position.y + 122.0), system.blurb, HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 32.0, 13, 4, Color(0.8, 0.78, 0.9))

	func _draw_darkness_picker() -> void:
		var side := side_rect()
		draw_string(_font, Vector2(side.position.x, side.position.y + 204.0), "DARKNESS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SpaceHud.DIM)
		var prev := darkness_prev_rect()
		var next := darkness_next_rect()
		var can_lighter := meta.darkness > 0
		var can_darker := meta.darkness < meta.darkness_unlocked
		_card(prev, SpaceHud.GOLD if can_lighter else LOCKED_COLOR, _hover == "darkness_prev")
		_card(next, SpaceHud.GOLD if can_darker else LOCKED_COLOR, _hover == "darkness_next")
		draw_string(_font, prev.position + Vector2(0.0, 21.0), "<", HORIZONTAL_ALIGNMENT_CENTER, prev.size.x, 16, SpaceHud.GOLD if can_lighter else LOCKED_COLOR)
		draw_string(_font, next.position + Vector2(0.0, 21.0), ">", HORIZONTAL_ALIGNMENT_CENTER, next.size.x, 16, SpaceHud.GOLD if can_darker else LOCKED_COLOR)
		draw_string(_font, Vector2(prev.end.x, prev.position.y + 22.0), Difficulty.name_of(meta.darkness).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, next.position.x - prev.end.x, 18, SpaceHud.VIOLET)
		var below := prev.end.y + 20.0
		draw_multiline_string(_font, Vector2(side.position.x, below), Difficulty.summary(meta.darkness), HORIZONTAL_ALIGNMENT_LEFT, side.size.x, 12, 4, SpaceHud.DIM)
		draw_string(_font, Vector2(side.position.x, below + 44.0), Difficulty.reward_text(meta.darkness), HORIZONTAL_ALIGNMENT_LEFT, side.size.x, 12, TEXT_COLOR)
		if not can_darker and meta.darkness_unlocked < Difficulty.MAX_LEVEL:
			draw_string(_font, Vector2(side.position.x, below + 62.0), "Relight a sector on %s to unlock %s" % [Difficulty.name_of(meta.darkness_unlocked), Difficulty.name_of(meta.darkness_unlocked + 1)], HORIZONTAL_ALIGNMENT_LEFT, side.size.x, 11, LOCKED_COLOR)

	## The pilot sheet: level and stats on the left, points to spend on the right.
	func _draw_quarters() -> void:
		var origin := content_origin()
		var left := Rect2(origin, Vector2(500.0, 440.0))
		_card(left, Color(0.35, 0.32, 0.45), false)
		var x := left.position.x + 18.0
		var tuning := SurfaceTuning.new()
		var bonuses := meta.stat_bonuses()
		draw_string(_font, Vector2(x, left.position.y + 34.0), "PILOT LEVEL %d" % meta.pilot_level(), HORIZONTAL_ALIGNMENT_LEFT, -1, 21, SpaceHud.GOLD)
		var progress := PilotRanks.progress_for(meta.pilot_xp)
		var bar := Rect2(Vector2(x, left.position.y + 50.0), Vector2(left.size.x - 36.0, 8.0))
		draw_rect(bar, Color(0.12, 0.1, 0.15))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(progress.x) / float(progress.y), bar.size.y)), SpaceHud.GOLD)
		draw_string(_font, Vector2(x, left.position.y + 76.0), "%d / %d to the next level  ·  earned by fighting and building on planets" % [progress.x, progress.y], HORIZONTAL_ALIGNMENT_LEFT, left.size.x - 36.0, 12, SpaceHud.DIM)
		var lines := [
			["Health", "%d" % roundi(tuning.pilot_health + float(bonuses.get("pilot_health", 0.0)))],
			["Barrier", "%d" % roundi(tuning.pilot_barrier + float(bonuses.get("pilot_barrier", 0.0)))],
			["Speed", "%d%%" % roundi(100.0 + 100.0 * float(bonuses.get("pilot_speed", 0.0)))],
			["Roll recharge", "%.2fs" % (tuning.roll_cooldown * maxf(1.0 - float(bonuses.get("pilot_roll", 0.0)), 0.4))],
			["Sidearm damage", "%d%%" % roundi(100.0 + 100.0 * (float(bonuses.get("damage", 0.0)) + float(bonuses.get("sidearm_damage", 0.0))))],
			["Lantern reach", "%d%%" % roundi(100.0 + 100.0 * float(bonuses.get("lantern", 0.0)))],
			["Flares", "%d" % (2 + int(bonuses.get("flares", 0.0)))],
		]
		for i in lines.size():
			var y := left.position.y + 116.0 + i * 30.0
			draw_string(_font, Vector2(x, y), lines[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, SpaceHud.DIM)
			draw_string(_font, Vector2(x + 200.0, y), lines[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TEXT_COLOR)
		draw_multiline_string(_font, Vector2(x, left.end.y - 46.0), "Research at the Lab and Hearth points add to these too.", HORIZONTAL_ALIGNMENT_LEFT, left.size.x - 36.0, 12, 4, SpaceHud.DIM)
		var card := hearth_card()
		_card(card, Color(0.55, 0.45, 0.3), false)
		var hx := card.position.x + 18.0
		var free := meta.pilot_points_free()
		draw_string(_font, Vector2(hx, card.position.y + 34.0), "STATS", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, SpaceHud.GOLD)
		draw_string(_font, Vector2(hx, card.position.y + 100.0), ("%d point%s to spend" % [free, "" if free == 1 else "s"]) if free > 0 else "All points spent", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, SpaceHud.GOLD if free > 0 else SpaceHud.DIM)
		for i in PilotRanks.STATS.size():
			var stat: Dictionary = PilotRanks.STATS[i]
			var id: String = stat["id"]
			var rect := track_rect(i)
			var points := int(meta.pilot_points.get(id, 0))
			var cap := int(stat["max"])
			var can := meta.can_spend_pilot_point(id)
			_card(rect, SpaceHud.GOLD if can else LOCKED_COLOR, _hover == "pilot:" + id)
			draw_string(_font, rect.position + Vector2(14.0, 24.0), stat["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT_COLOR)
			draw_string(_font, rect.position + Vector2(14.0, 46.0), stat["desc"] + ("" if cap <= 0 else "  (up to %d)" % cap), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 120.0, 12, SpaceHud.DIM)
			draw_string(_font, Vector2(rect.position.x, rect.position.y + 38.0), str(points), HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 16.0, 22, SpaceHud.GOLD if points > 0 else LOCKED_COLOR)
		if not meta.pilot_points.is_empty():
			var reset := reset_rect()
			_card(reset, LOCKED_COLOR, _hover == "pilot_reset")
			draw_string(_font, reset.position + Vector2(0.0, 18.0), "Reset points", HORIZONTAL_ALIGNMENT_CENTER, reset.size.x, 12, SpaceHud.DIM)

	func _draw_hearth() -> void:
		var origin := content_origin()
		var left := Rect2(origin, Vector2(500.0, 440.0))
		_card(left, Color(0.35, 0.32, 0.45), false)
		var x := left.position.x + 18.0
		if last_run == null:
			draw_string(_font, Vector2(x, left.position.y + 34.0), "WELCOME HOME, LAMPLIGHTER", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, SpaceHud.GOLD)
			draw_multiline_string(_font, Vector2(x, left.position.y + 66.0), "The sectors beyond are smothered by the Gloom. Claim the dark one region at a time, wake planets by claiming the space around them, and kindle them on foot. Burn out a sector's heart to relight it. Whatever happens, your sparks and what you dig up come home.", HORIZONTAL_ALIGNMENT_LEFT, left.size.x - 36.0, 14, 5, TEXT_COLOR)
		else:
			var outcome := {
				RunState.Outcome.VICTORY: ["THE SECTOR WAS RELIT", SpaceHud.GOLD],
				RunState.Outcome.DEFEAT: ["THE LIGHT WAS LOST", SpaceHud.RED],
				RunState.Outcome.ABANDONED: ["RUN ABANDONED", SpaceHud.DIM],
			}
			var title: Array = outcome.get(last_run.outcome, ["LAST RUN", SpaceHud.DIM])
			draw_string(_font, Vector2(x, left.position.y + 34.0), title[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, title[1])
			draw_string(_font, Vector2(x + 300.0, left.position.y + 34.0), Difficulty.name_of(last_run.darkness).to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, left.size.x - 336.0, 13, SpaceHud.VIOLET)
			var minutes := int(last_run.elapsed) / 60
			var gathered: Array[String] = []
			for kind in PlanetData.RESOURCE_ORDER:
				if int(last_run.resources.get(kind, 0)) > 0:
					gathered.append("%d %s" % [int(last_run.resources[kind]), kind])
			var lines := [
				["Regions claimed", str(last_run.regions_claimed)],
				["Planets kindled", str(last_run.outposts.size())],
				["Gloom destroyed", str(last_run.kills)],
				["Time", "%d:%02d" % [minutes, int(last_run.elapsed) % 60]],
				["Sparks banked", str(last_banked)],
				["Resources", ", ".join(gathered) if not gathered.is_empty() else "none"],
			]
			for i in lines.size():
				var y := left.position.y + 66.0 + i * 27.0
				draw_string(_font, Vector2(x, y), lines[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, SpaceHud.DIM)
				draw_string(_font, Vector2(x + 170.0, y), lines[i][1], HORIZONTAL_ALIGNMENT_LEFT, left.size.x - 200.0, 14, TEXT_COLOR)
			if meta.newly_unlocked >= 0:
				draw_string(_font, Vector2(x, left.position.y + 238.0), "New darkness unlocked: %s" % Difficulty.name_of(meta.newly_unlocked), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, SpaceHud.VIOLET)
		draw_string(_font, Vector2(x, left.position.y + 282.0), "RECORDS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, SpaceHud.DIM)
		var relit := Difficulty.name_of(meta.darkness_relit) if meta.darkness_relit >= 0 else "none yet"
		var records := [
			["Runs", str(meta.runs)], ["Sectors relit", str(meta.wins)],
			["Darkest relit", relit], ["Best run", "%d regions" % meta.best_regions],
			["Outposts", str(meta.outposts.size())], ["Research", "%d of %d" % [meta.research_done.size(), Research.LIST.size()]],
		]
		for i in records.size():
			var column := i % 2
			var row := i / 2
			var at := Vector2(x + column * 240.0, left.position.y + 310.0 + row * 26.0)
			draw_string(_font, at, records[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, SpaceHud.DIM)
			draw_string(_font, at + Vector2(110.0, 0.0), records[i][1], HORIZONTAL_ALIGNMENT_LEFT, 120.0, 13, TEXT_COLOR)
		var card := hearth_card()
		_card(card, Color(0.55, 0.45, 0.3), false)
		var hx := card.position.x + 18.0
		draw_string(_font, Vector2(hx, card.position.y + 34.0), "HEARTH LEVEL %d" % meta.hearth_level(), HORIZONTAL_ALIGNMENT_LEFT, -1, 21, SpaceHud.GOLD)
		var progress := HearthRanks.progress_for(meta.hearth_xp)
		var bar := Rect2(Vector2(hx, card.position.y + 50.0), Vector2(card.size.x - 36.0, 8.0))
		draw_rect(bar, Color(0.12, 0.1, 0.15))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(progress.x) / float(progress.y), bar.size.y)), SpaceHud.GOLD)
		draw_string(_font, Vector2(hx, card.position.y + 76.0), "%d / %d to the next level  ·  every banked spark feeds the Hearth" % [progress.x, progress.y], HORIZONTAL_ALIGNMENT_LEFT, card.size.x - 36.0, 12, SpaceHud.DIM)
		var free := meta.hearth_points_free()
		draw_string(_font, Vector2(hx, card.position.y + 100.0), ("%d point%s to spend" % [free, "" if free == 1 else "s"]) if free > 0 else "All points spent", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, SpaceHud.GOLD if free > 0 else SpaceHud.DIM)
		for i in HearthRanks.TRACKS.size():
			var track: Dictionary = HearthRanks.TRACKS[i]
			var id: String = track["id"]
			var rect := track_rect(i)
			var points := int(meta.hearth_points.get(id, 0))
			var cap := int(track["max"])
			var can := meta.can_spend_hearth_point(id)
			_card(rect, SpaceHud.GOLD if can else LOCKED_COLOR, _hover == "hearth:" + id)
			draw_string(_font, rect.position + Vector2(14.0, 24.0), track["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT_COLOR)
			draw_string(_font, rect.position + Vector2(14.0, 46.0), track["desc"] + ("" if cap <= 0 else "  (up to %d)" % cap), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 120.0, 12, SpaceHud.DIM)
			draw_string(_font, Vector2(rect.position.x, rect.position.y + 38.0), str(points), HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 16.0, 22, SpaceHud.GOLD if points > 0 else LOCKED_COLOR)
		if meta.hearth_points_spent() > 0:
			var reset := reset_rect()
			_card(reset, LOCKED_COLOR, _hover == "hearth_reset")
			draw_string(_font, reset.position + Vector2(0.0, 18.0), "Reset points", HORIZONTAL_ALIGNMENT_CENTER, reset.size.x, 12, SpaceHud.DIM)

func _ready() -> void:
	layer = 30
	_view = PanelView.new()
	_view.panel = self
	add_child(_view)
	visible = false


func open(new_page: String, meta: MetaProgress, last_run: RunState = null, banked := 0) -> void:
	page = new_page
	_view.meta = meta
	_view.last_run = last_run
	_view.last_banked = banked
	_view.message = ""
	_view.clock = MetaProgress.now()
	visible = true
	_view.queue_redraw()


func close() -> void:
	if not visible:
		return
	visible = false
	page = ""
	closed.emit()


func press(target: String) -> void:
	_view.press(target)


## A nudge toward the next useful thing to do at home.
func next_goal(meta: MetaProgress) -> String:
	if meta.hearth_points_free() > 0:
		return "spend your %d Hearth point%s" % [meta.hearth_points_free(), "" if meta.hearth_points_free() == 1 else "s"]
	if meta.pilot_points_free() > 0:
		return "spend your pilot's %d stat point%s at the Quarters" % [meta.pilot_points_free(), "" if meta.pilot_points_free() == 1 else "s"]
	if not meta.has_building("lab"):
		return "build the Lab (%d sparks)" % Research.LAB_COST if meta.sparks >= Research.LAB_COST else "bring home %d sparks to build the Lab" % Research.LAB_COST
	if not meta.is_researching():
		for project in Research.LIST:
			if meta.can_start_research(project["id"]):
				return "start researching %s at the Lab" % project["name"]
	if meta.darkness < meta.darkness_unlocked:
		return "launch on %s for better rewards" % Difficulty.name_of(meta.darkness_unlocked)
	if meta.is_researching():
		return "launch a run while %s finishes" % Research.get_project(String(meta.research_active["id"]))["name"]
	if meta.outposts.is_empty():
		return "kindle a planet for resources to research with"
	return "relight a sector on %s to unlock %s" % [Difficulty.name_of(meta.darkness_unlocked), Difficulty.name_of(meta.darkness_unlocked + 1)]

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and (key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_E):
		get_viewport().set_input_as_handled()
		close()
