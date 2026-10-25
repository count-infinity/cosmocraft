class_name GameFlow
extends Node
## The top of the game: loads saved progress, shows the homeworld between
## runs, launches runs, hands off to a planet's surface when the pilot lands
## (and back to space afterwards), and banks what each run earned.
##
## With --autoplay, --capture or --skip-home it launches a run straight away
## (handy for screenshots and smoke tests); --show=home shows the homeworld
## with sample progress instead (add --panel=shipyard|lab|relay|hearth to open
## a building), and --land lands on the sector's first planet right away.
## Autoplay and capture runs never touch the real save.

var meta: MetaProgress

var _home: Homeworld
var _game: SpaceGame
var _mission: SurfaceMission
var _assault: AssaultMission
var _fade: ColorRect
## True while fading between space and a surface.
var _transitioning := false
var _options := {}
var _first_run := true
var _persist := true


func _ready() -> void:
	Glow.ensure(self)
	_build_fade()
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		_options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	_persist = not (_options.has("autoplay") or _options.has("capture"))
	meta = MetaProgress.load_from() if _persist else MetaProgress.new()
	if _options.has("capture"):
		# Vsync stalls the window when the display sleeps; captures don't need it.
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		var times: Array[float] = []
		for part in String(_options.get("shots", "5")).split(","):
			times.append(float(part))
		add_child(ScreenCapture.new(String(_options["capture"]), times))
	if _options.get("show", "") == "home":
		_show_sample_home()
	elif _options.has("autoplay") or _options.has("capture") or _options.has("skip-home"):
		start_run()
	else:
		show_home()


func show_home(last_run: RunState = null, banked := 0) -> void:
	_free_mission()
	if _game != null:
		_game.queue_free()
		_game = null
	if _home != null:
		_home.queue_free()
	_home = Homeworld.new()
	_home.setup(meta, last_run, banked)
	_home.launch_requested.connect(start_run)
	_home.changed.connect(_save)
	add_child(_home)


func start_run() -> void:
	if _home != null:
		_home.queue_free()
		_home = null
	_free_mission()
	if _game != null:
		_game.queue_free()
	var seed_value := randi_range(1, 999999)
	if _first_run and _options.has("seed"):
		seed_value = int(_options["seed"])
	_first_run = false
	meta.newly_unlocked = -1
	var map := meta.galaxy()
	_game = SpaceGame.new()
	_game.run = RunState.create(seed_value, meta)
	_game.run.enter_sector(map, meta.launch_sector())
	_game.run.reward_bonus = meta.conquest_bonus()
	if _options.has("seed") and seed_value == int(_options["seed"]):
		_game.run.sector_seed = seed_value
	_game.galaxy = map
	_game.conquered = meta.conquered_set()
	if _options.has("darkness"):
		var forced := clampi(int(_options["darkness"]), 0, Difficulty.MAX_LEVEL)
		_game.run.darkness_max = maxi(_game.run.darkness_max, forced)
		_game.run.darkness = forced
	_game.run_ended.connect(_on_run_ended)
	_game.sector_relit.connect(_on_sector_relit)
	_game.landing_requested.connect(_on_landing_requested)
	add_child(_game)
	if _options.has("land"):
		_options.erase("land")
		_land_on_first_planet.call_deferred()


## A heart burned out mid-run: the conquest is saved right away, so it sticks
## even if the run ends badly later.
func _on_sector_relit(sector_id: int) -> void:
	var news := meta.relight_sector(sector_id, _game.run.darkness)
	_game.run.darkness_max = meta.darkness_unlocked
	_game.run.reward_bonus = meta.conquest_bonus()
	_save()
	_game.show_conquest_news(news)
	print("GameFlow: conquered %s (%d / %d sectors)" % [_game.run.sector_name, meta.conquered.size(), meta.galaxy().sectors.size()])


## An awake planet: freeze space and fly the assault on it (or go straight
## to the surface if its bastion already fell).
func _on_landing_requested(planet: PlanetData) -> void:
	if _mission != null or _assault != null or _transitioning:
		return
	_transitioning = true
	await _fade_to(1.0)
	_game.set_active(false)
	if planet.assaulted or _options.has("skip-assault"):
		_start_surface(planet, 0.0)
	else:
		_assault = AssaultMission.new()
		_assault.setup(_game.run, planet, _game.tuning, _options.has("autoplay"))
		_assault.finished.connect(_on_assault_finished.bind(planet))
		add_child(_assault)
	await _fade_to(0.0)
	_transitioning = false


func _start_surface(planet: PlanetData, suppression: float) -> void:
	_mission = SurfaceMission.new()
	_mission.setup(_game.run, planet, _game.tuning, _options.has("autoplay"), suppression)
	_mission.finished.connect(_on_surface_finished.bind(planet))
	add_child(_mission)


## The assault ended: land, pull back to orbit, or lose the run.
func _on_assault_finished(outcome: String, suppression: float, planet: PlanetData) -> void:
	if _transitioning:
		return
	_transitioning = true
	await _fade_to(1.0)
	if _assault != null:
		_assault.queue_free()
		_assault = null
	match outcome:
		"landed":
			_start_surface(planet, suppression)
		"defeat":
			_game.run.outcome = RunState.Outcome.DEFEAT
			_on_run_ended(_game.run)
		_:
			_game.set_active(true)
			_game.on_returned_from_surface(planet, "left")
	await _fade_to(0.0)
	_transitioning = false


func _on_surface_finished(outcome: String, planet: PlanetData) -> void:
	if _transitioning:
		return
	_transitioning = true
	await _fade_to(1.0)
	_free_mission()
	if outcome == "defeat":
		_game.run.outcome = RunState.Outcome.DEFEAT
		_on_run_ended(_game.run)
	else:
		_game.set_active(true)
		_game.on_returned_from_surface(planet, outcome)
	await _fade_to(0.0)
	_transitioning = false


func _free_mission() -> void:
	if _mission != null:
		_mission.queue_free()
		_mission = null
	if _assault != null:
		_assault.queue_free()
		_assault = null


## Debug (--land): wakes the sector's first planet and lands on it.
func _land_on_first_planet() -> void:
	if _game == null or _game.sector.planets.is_empty():
		return
	_game._visit("planet")
	_on_landing_requested(_game.sector.planets[0])


func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(Glow.BACKGROUND, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, 0.35)
	await tween.finished


func _on_run_ended(run: RunState) -> void:
	var banked := meta.record_run(run)
	_save()
	print("GameFlow: banked %d sparks (%d total)" % [banked, meta.sparks])
	if _options.has("autoplay"):
		_autoplay_home(run, banked)
		return
	show_home(run, banked)


## Autoplay stops at home like a player would: collects from the Relay, builds
## the Lab, starts research, buys what it can, then launches again.
func _autoplay_home(run: RunState, banked: int) -> void:
	meta.selected_sector = -1
	meta.collect_outposts()
	meta.update_research()
	meta.build_lab()
	for project in Research.LIST:
		if meta.start_research(project["id"]):
			print("GameFlow: autoplay researching %s" % project["name"])
			break
	for upgrade in MetaUpgrades.LIST:
		if meta.buy(upgrade["id"]):
			print("GameFlow: autoplay bought %s" % upgrade["name"])
	var tracks := ["weapons", "hull"]
	var turn := 0
	while meta.hearth_points_free() > 0 and turn < 1000:
		meta.spend_hearth_point(tracks[turn % tracks.size()])
		turn += 1
	if meta.newly_unlocked >= 0:
		print("GameFlow: unlocked darkness %s" % Difficulty.name_of(meta.newly_unlocked))
	show_home(run, banked)
	await get_tree().create_timer(2.5).timeout
	if _home != null:
		start_run()


## Debug: the homeworld after a few made-up runs, for screenshots.
func _show_sample_home() -> void:
	var now := MetaProgress.now()
	meta.sparks = 420
	meta.ranks = {"hull": 2, "magnet": 1, "damage": 1}
	meta.blueprints.append("seeker_pod")
	meta.runs = 3
	meta.best_regions = 9
	meta.lifetime_sparks = 1180
	meta.hearth_xp = 1180
	meta.hearth_points = {"weapons": 3, "hull": 2}
	meta.darkness_unlocked = 3
	meta.darkness = 2
	meta.darkness_relit = 2
	meta.wins = 4
	meta.galaxy_seed = 4242
	var map := meta.galaxy()
	var frontier := map.frontier(meta.conquered_set())
	for i in 3:
		var next := map.frontier(meta.conquered_set())
		next.sort_custom(func(a: int, b: int) -> bool: return map.sectors[a].tier < map.sectors[b].tier)
		meta.conquered.append(next[0])
	meta.selected_sector = -1
	meta.pilot_xp = 900
	meta.pilot_points = {"vitality": 3, "aim": 2}
	meta.outposts[0]["extractors"] = 3
	meta.resources = {"ore": 34, "crystal": 51, "biomass": 12}
	meta.buildings.append("lab")
	meta.research_done.append("ember_coils")
	meta.research_active = {"id": "lens_grinding", "finish_at": now + 140.0}
	for sample in [["Brand VII", "Crystal", "crystal", 5.0], ["Kiln I", "Fungal", "biomass", 9.0], ["Ash Reach", "Ashen", "ore", 2.5]]:
		meta.outposts.append({"name": sample[0], "type": sample[1], "resource": sample[2], "collected_at": now - float(sample[3]) * 3600.0})
	var run := RunState.fresh(1)
	run.outcome = RunState.Outcome.DEFEAT
	run.regions_claimed = 9
	run.kills = 554
	run.elapsed = 742.0
	run.add_resource("crystal", 51)
	run.outposts.append({"name": "Brand VII", "type": "Crystal", "resource": "crystal"})
	show_home(run, 349)
	if String(_options.get("panel", "")) == "none":
		_home.panel.close()
	elif _options.has("panel"):
		_home.panel.open(String(_options["panel"]), meta, run, 349)


func _save() -> void:
	if _persist:
		meta.save()
