class_name Homeworld
extends Node2D
## Hearthhold, the lamplighters' home between runs: a pool of light in the
## dark where the pilot walks between buildings. The Launch Pad starts a run;
## the Shipyard, Lab, Outpost Relay and Hearth open their panels. Research
## finishes here on the real clock.
##
## GameFlow creates it with setup(), listens for launch_requested, and saves
## on changed. After a run it opens on the Hearth's report.

signal launch_requested
signal changed

const BUILDINGS := {
	"pad": {"name": "LAUNCH PAD", "hint": "Pick the darkness and launch", "position": Vector2(0.0, -235.0), "radius": 96.0},
	"hearth": {"name": "HEARTH", "hint": "Records and the last run", "position": Vector2(0.0, 40.0), "radius": 56.0},
	"shipyard": {"name": "SHIPYARD", "hint": "Upgrades and blueprints", "position": Vector2(-430.0, -20.0), "radius": 90.0},
	"lab": {"name": "LAB", "hint": "Research", "position": Vector2(430.0, -20.0), "radius": 80.0},
	"relay": {"name": "OUTPOST RELAY", "hint": "Collect from your outposts", "position": Vector2(-260.0, 230.0), "radius": 44.0},
	"quarters": {"name": "QUARTERS", "hint": "Your pilot's level and stats", "position": Vector2(270.0, 190.0), "radius": 46.0},
}
## How close (beyond a building's radius) the pilot must be to use it.
const REACH := 60.0
const WALK_AREA := Rect2(-590.0, -320.0, 1180.0, 620.0)
const HELP_TEXT := "WASD move  ·  E use a building  ·  Enter launch a run  ·  Esc close  ·  H hide help"

var meta: MetaProgress
var pilot: Pilot
var panel: HomePanel
var near := ""

var _last_run: RunState
var _banked := 0
var _tuning := SurfaceTuning.new()
var _use_cooldown := 0.0
var _research_check := 0.0
var _camera: Camera2D
var _terrain: SurfaceTerrain
var _buildings: HomeBuildings
var _veil: LanternVeil
var _hud: SpaceHud
var _sfx: Sfx
var _time := 0.0


## Call before adding to the tree.
func setup(p_meta: MetaProgress, last_run: RunState = null, banked := 0) -> void:
	meta = p_meta
	_last_run = last_run
	_banked = banked


func _ready() -> void:
	Glow.ensure(self)
	InputSetup.register()
	if meta == null:
		meta = MetaProgress.new()
	_build_scene()
	pilot.reset_at(BUILDINGS["hearth"]["position"] + Vector2(0.0, 150.0))
	var finished := meta.update_research()
	if not finished.is_empty():
		changed.emit()
	if _last_run != null:
		panel.open("hearth", meta, _last_run, _banked)
	elif not finished.is_empty():
		_announce_research(finished)
	else:
		_hud.show_banner("HEARTHHOLD", "Walk to a building and press E. The launch pad starts a run.", SpaceHud.GOLD, 4.0)


func _process(delta: float) -> void:
	_time += delta
	_use_cooldown = maxf(_use_cooldown - delta, 0.0)
	if not panel.visible:
		pilot.update(delta)
		_keep_pilot_in()
		near = nearest_building()
		if pilot.input.consume_kindle() and not near.is_empty() and _use_cooldown <= 0.0:
			use(near)
	else:
		pilot.input.consume_kindle()
	_buildings.near = near if not panel.visible else ""
	_research_check -= delta
	if _research_check <= 0.0:
		_research_check = 1.0
		var finished := meta.update_research()
		if not finished.is_empty():
			changed.emit()
			_announce_research(finished)
	_update_lights(delta)
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			launch_requested.emit()
		KEY_H:
			_hud.toggle_help()
		KEY_F11:
			var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)


## The building the pilot is close enough to use, or "".
func nearest_building() -> String:
	var best := ""
	var best_distance := INF
	for id: String in BUILDINGS:
		var info: Dictionary = BUILDINGS[id]
		var distance := pilot.position.distance_to(info["position"]) - float(info["radius"])
		if distance < REACH and distance < best_distance:
			best_distance = distance
			best = id
	return best


func use(id: String) -> void:
	_sfx.play("kindle", -8.0)
	panel.open("launch" if id == "pad" else id, meta, _last_run, _banked)


func _on_panel_closed() -> void:
	_use_cooldown = 0.25


func _on_panel_changed() -> void:
	_sfx.play("chime", -6.0)
	changed.emit()


func _announce_research(id: String) -> void:
	var project := Research.get_project(id)
	_hud.show_banner("RESEARCH COMPLETE", "%s: %s" % [project["name"], String(project["desc"]).to_lower()], SpaceHud.CYAN, 3.5)
	_sfx.play("cache", -2.0)


## Buildings are solid, and the pilot stays inside the settlement.
func _keep_pilot_in() -> void:
	for id: String in BUILDINGS:
		var info: Dictionary = BUILDINGS[id]
		var center: Vector2 = info["position"]
		var solid := float(info["radius"]) * (0.45 if id == "pad" else 0.85)
		var offset := pilot.position - center
		if offset.length() < solid + pilot.radius:
			pilot.position = center + offset.normalized() * (solid + pilot.radius)
	pilot.position = pilot.position.clamp(WALK_AREA.position, WALK_AREA.end)


func _update_lights(delta: float) -> void:
	_veil.begin(get_viewport().get_canvas_transform(), _camera.zoom.x)
	var flicker := 1.0 + 0.03 * sin(_time * 9.0) + 0.02 * sin(_time * 23.0)
	_veil.add_light(BUILDINGS["hearth"]["position"], 520.0 * flicker, 1.0)
	_veil.add_light(pilot.position, 240.0, 1.0)
	_veil.add_light(BUILDINGS["pad"]["position"], 260.0, 0.9)
	_veil.add_light(BUILDINGS["shipyard"]["position"], 250.0, 0.85)
	_veil.add_light(BUILDINGS["lab"]["position"], 240.0, 0.85 if meta.has_building("lab") else 0.45)
	_veil.add_light(BUILDINGS["relay"]["position"], 210.0, 0.8)
	_veil.add_light(BUILDINGS["quarters"]["position"], 210.0, 0.8)
	_veil.commit(delta)


func _update_hud() -> void:
	_hud.set_header("HEARTHHOLD  ·  HEARTH LEVEL %d" % meta.hearth_level())
	_hud.set_sparks(meta.sparks)
	_hud.set_resources(meta.resources)
	var status := ""
	if meta.is_researching():
		var project := Research.get_project(String(meta.research_active["id"]))
		status = "LAB: %s  ·  %s left" % [project["name"], Research.duration_text(meta.research_seconds_left())]
	elif meta.has_building("lab"):
		status = "LAB: idle"
	_hud.set_objective(status, SpaceHud.CYAN)
	if panel.visible:
		_hud.set_prompt("")
	elif not near.is_empty():
		var info: Dictionary = BUILDINGS[near]
		_hud.set_prompt("[E] %s  ·  %s" % [String(info["name"]).capitalize(), info["hint"]])
	else:
		_hud.set_prompt("")


## A ring of boulders around the settlement, for the terrain layer.
func _ground_map() -> SurfaceMap:
	var ground := SurfaceMap.new()
	ground.planet_type = PlanetData.Type.ASHEN
	ground.map_seed = 4111
	ground.bounds = Rect2(-1100.0, -750.0, 2200.0, 1500.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4111
	var count := 40
	for i in count:
		var angle := TAU * i / count + rng.randf_range(-0.05, 0.05)
		var rock := SurfaceMap.Rock.new()
		rock.position = Vector2(cos(angle) * 760.0, sin(angle) * 460.0) * rng.randf_range(0.95, 1.12)
		rock.radius = rng.randf_range(46.0, 96.0)
		for k in 13:
			rock.outline.append(Vector2.from_angle(TAU * k / 13.0 + rng.randf_range(-0.12, 0.12)) * rock.radius * rng.randf_range(0.86, 1.12))
		ground.rocks.append(rock)
	return ground


func _build_scene() -> void:
	_terrain = SurfaceTerrain.new()
	add_child(_terrain)
	_terrain.build(_ground_map())
	_terrain.kindled = 0.45
	_buildings = HomeBuildings.new()
	_buildings.meta = meta
	add_child(_buildings)
	pilot = Pilot.new()
	pilot.setup(_tuning)
	pilot.input = ShipInput.new(self)
	add_child(pilot)
	_camera = Camera2D.new()
	_camera.position = Vector2(0.0, -10.0)
	add_child(_camera)
	_camera.make_current()
	_veil = LanternVeil.new()
	add_child(_veil)
	_veil.target_strength = 0.9
	_veil.strength = 0.9
	_hud = SpaceHud.new()
	add_child(_hud)
	_hud.set_vitals_visible(false)
	_hud.set_help(HELP_TEXT)
	_hud.set_header("HEARTHHOLD")
	_sfx = Sfx.new()
	add_child(_sfx)
	panel = HomePanel.new()
	add_child(panel)
	panel.closed.connect(_on_panel_closed)
	panel.changed.connect(_on_panel_changed)
	panel.launch_requested.connect(func() -> void: launch_requested.emit())
