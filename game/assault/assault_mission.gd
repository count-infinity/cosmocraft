class_name AssaultMission
extends Node2D
## The assault on an awakened planet: a side-scrolling run along its horizon,
## in the spirit of Thunder Force and ActRaiser's action stages. Your ship
## flies in with its fitted loadout while the Gloom's ground defenses (spore
## turrets, thorn batteries, hives) and skimmer waves try to stop it. At the
## end stands the bastion, shielded by its pods. Break it and you land; every
## ground defense destroyed on the way thins out what waits on the surface.
##
## GameFlow creates this with setup() and listens for finished(outcome,
## suppression): "landed", "retreated" (pulled back to orbit, or bounced back
## by a spare spark) or "defeat". `suppression` is the share of ground
## defenses destroyed.
##
## Command-line options go after `--`: --autoplay, --god.

signal finished(outcome: String, suppression: float)

const SCROLL_SPEED := 115.0
const STAGE_LENGTH := 7400.0
const VIEW := Vector2(1280.0, 720.0)
## Where the bastion stands, from the screen's left edge once scrolling stops.
const BASTION_OFFSET := 980.0
const WAVE_INTERVAL := Vector2(3.5, 6.0)
const FINISH_SECONDS := 2.2
const DEFEAT_SECONDS := 2.5
const RESPAWN_IFRAMES := 1.5
const IGNITE_COLOR := Color(2.6, 2.0, 1.0)
const SHIELD_HIT_COLOR := Color(0.6, 1.4, 2.4)
const HULL_HIT_COLOR := Color(2.4, 0.8, 0.3)
const HELP_TEXT := "WASD move  ·  mouse aim  ·  left click fire  ·  right click torpedo  ·  Space/Shift dash
Esc pause (Q pulls back to orbit)  ·  H hide help  ·  F3 god mode  ·  F5 mute"

var run: RunState
var planet: PlanetData
var tuning: SpaceTuning
var ship: Ship
var stats := ShipStats.new()
var weapons := WeaponSystem.new()
var battle: Battle
## World x of the screen's left edge.
var scroll := 0.0
var defenses_total := 0
var defenses_destroyed := 0
var bastion: GloomEnemy
var pods: Array[GloomEnemy] = []

var _space_tuning: SpaceTuning
var _autoplay := false
var _rng := RandomNumberGenerator.new()
var _defenses: Array[GloomEnemy] = []
var _wave_left := 3.0
var _phase := "descent"
var _end_left := -1.0
var _outcome := ""
var _paused := false
var _time := 0.0
var _shield_announced := false
var _log_left := 8.0

var _sky: AssaultSky
var _terrain: AssaultTerrain
var _anchor: Node2D
var _camera: GameCamera
var _enemy_root: Node2D
var _projectiles: Projectiles
var _pickups: Pickups
var _fx: FxLayer
var _hud: SpaceHud
var _sfx: Sfx
var _autopilot: AssaultAutopilot


## Call before adding the mission to the tree.
func setup(p_run: RunState, p_planet: PlanetData, space_tuning: SpaceTuning, autoplay := false) -> void:
	run = p_run
	planet = p_planet
	_space_tuning = space_tuning
	_autoplay = autoplay


func _ready() -> void:
	Glow.ensure(self)
	InputSetup.register()
	var options := _parse_options()
	if run == null:
		run = RunState.fresh(int(options.get("seed", 1)))
	if planet == null:
		planet = SurfaceMission._sample_planet(int(options.get("seed", 7)))
	tuning = _space_tuning if _space_tuning != null else SpaceTuning.new()
	_autoplay = _autoplay or options.has("autoplay")
	_rng.seed = planet.surface_seed + 77
	_build_scene()
	battle.god_mode = options.has("god")
	_terrain.build(planet.surface_seed + 5, planet.type, STAGE_LENGTH + VIEW.x + 600.0, STAGE_LENGTH + 500.0)
	_place_defenses()
	_place_bastion()
	ship.reset_at(Vector2(220.0, 300.0))
	ship.grant_iframes(RESPAWN_IFRAMES)
	_anchor.position = VIEW * 0.5
	_camera.snap_to(_anchor.position)
	_camera.snap_zoom()
	_hud.show_banner("ASSAULT ON %s" % planet.name.to_upper(), "Burn down its ground defenses and break the bastion to land.", SpaceHud.GOLD, 3.2)
	print("AssaultMission: %s (%s, depth %d): %d ground defenses" % [planet.name, planet.type_name(), planet.depth, defenses_total])


# --- Host interface (GloomEnemy and WeaponSystem call these) ---------------------

func target_position() -> Vector2:
	return ship.position


func has_objective() -> bool:
	return false


func objective_position() -> Vector2:
	return ship.position


func nests_awake() -> bool:
	return true


func route_to(_enemy: GloomEnemy, goal: Vector2) -> Vector2:
	return goal


## Ground growths only shoot while they're on screen.
func in_view(point: Vector2) -> bool:
	return point.x > scroll - 20.0 and point.x < scroll + VIEW.x + 20.0


func spawn_enemy_shot(origin: Vector2, velocity: Vector2, damage: float, style := "orb") -> void:
	battle.spawn_enemy_shot(origin, velocity, damage, style)


func spawn_minions(origin: Vector2, kind: String, count: int, drops_sparks := true) -> void:
	battle.spawn_minions(origin, kind, count, drops_sparks)


func fire_volley(spec: WeaponSpec, origin: Vector2, direction: Vector2, target: GloomEnemy) -> void:
	battle.fire_volley(spec, origin, direction, target, ship.velocity)


func nearest_enemy_within(from: Vector2, reach: float) -> GloomEnemy:
	return battle.nearest_enemy_within(from, reach)


func on_snuffer_reached(_enemy: GloomEnemy) -> void:
	pass


# --- Queries (the autopilot and tests use these) -------------------------------------

func ground_y(x: float) -> float:
	return _terrain.ground_y(x)


func suppression() -> float:
	return float(defenses_destroyed) / maxf(defenses_total, 1.0)


func in_bastion_phase() -> bool:
	return _phase == "bastion"


## The bastion is still standing (Battle frees the Gloom it kills).
func bastion_alive() -> bool:
	return bastion != null and is_instance_valid(bastion) and not bastion.dead


## Enemy shots within `reach` of a point (for the autopilot's dodging).
func threats_near(point: Vector2, reach: float) -> Array[Vector2]:
	var found: Array[Vector2] = []
	for bullet in _projectiles.bullets:
		if not bullet.friendly and bullet.position.distance_to(point) < reach:
			found.append(bullet.position)
	return found


# --- Frame loop --------------------------------------------------------------

func _process(delta: float) -> void:
	if not _paused:
		run.elapsed += delta
		_step(delta)
	if _end_left > 0.0:
		_end_left -= delta
		if _end_left <= 0.0:
			finished.emit(_outcome, suppression())
	_update_hud()


func _step(dt: float) -> void:
	_time += dt
	if _phase == "descent":
		scroll = minf(scroll + SCROLL_SPEED * dt, STAGE_LENGTH)
		if scroll >= STAGE_LENGTH:
			_begin_bastion()
	_anchor.position = Vector2(scroll + VIEW.x * 0.5, VIEW.y * 0.5)
	_sky.scroll = scroll
	if _autopilot != null:
		_autopilot.think(dt)
	var active := ship.alive and _outcome.is_empty()
	if active:
		ship.update(dt)
		if _phase == "descent":
			ship.position.x += SCROLL_SPEED * dt
		_keep_ship_in_view()
		weapons.update(dt, ship, ship.input, ship.aim_direction, ship.input.is_firing(), ship.input.consume_secondary(), true, self)
		ship.dark_regen(dt)
	battle.update_enemies(dt, self, ship, ship.radius, active, _push_out)
	battle.update_projectiles(dt, ship, ship.radius, active, _bullet_blocked)
	_cull_behind()
	if _outcome.is_empty():
		_update_waves(dt)
	_update_pickups(dt)
	_update_bastion_shield()
	_fx.update(dt)
	if _autopilot != null:
		_log_left -= dt
		if _log_left <= 0.0:
			_log_left = 8.0
			_log_state()


func _keep_ship_in_view() -> void:
	var left := scroll + 30.0
	var right := scroll + VIEW.x - 80.0
	ship.position.x = clampf(ship.position.x, left, right)
	var floor := ground_y(ship.position.x) - ship.radius - 6.0
	if ship.position.y > floor:
		ship.position.y = floor
		if ship.velocity.y > 0.0:
			ship.velocity.y = -ship.velocity.y * 0.4
	ship.position.y = maxf(ship.position.y, 30.0)


## Flying Gloom can't go underground; growths stay where they're rooted.
func _push_out(point: Vector2, radius: float) -> Vector2:
	var floor := ground_y(point.x) - radius
	return Vector2(0.0, minf(floor - point.y, 0.0))


func _bullet_blocked(bullet: Projectiles.Bullet) -> bool:
	return bullet.position.y > ground_y(bullet.position.x)


## Gloom left behind by the scroll is gone for good (and earns nothing).
func _cull_behind() -> void:
	var removed := false
	for enemy in battle.enemies:
		if not enemy.dead and enemy.position.x < scroll - 160.0:
			enemy.dead = true
			removed = true
	if removed:
		battle.remove_dead()


# --- Ground defenses, waves and the bastion ----------------------------------------------

func _health() -> float:
	return tuning.health_scale(planet.depth) * float(run.difficulty()["health"])


## Growths along the way: more of them, and nastier kinds, deeper in the dark.
func _place_defenses() -> void:
	var threat := float(run.difficulty()["threat"])
	var x := 900.0
	while x < STAGE_LENGTH + 200.0:
		x += _rng.randf_range(260.0, 460.0) / clampf(threat, 0.8, 1.6)
		if absf(_terrain.slope(x)) > 0.55 or x > STAGE_LENGTH + 250.0:
			continue
		var kind := "spore_turret"
		var roll := _rng.randf()
		if x > 1800.0 and roll < 0.18 + 0.04 * planet.depth:
			kind = "hive"
		elif roll < 0.55 and (planet.depth >= 2 or x > 2600.0):
			kind = "thorn_battery"
		_defenses.append(_plant(kind, x, _health()))
	defenses_total = _defenses.size()


func _plant(kind: String, x: float, health: float) -> GloomEnemy:
	var radius := float(GloomEnemy.KINDS[kind]["radius"])
	var enemy := battle.spawn(kind, false, Vector2(x, ground_y(x) - radius * 0.35), health)
	enemy.rotation = PI * 1.25
	enemy.age = GloomEnemy.SPAWN_IN_TIME
	return enemy


## The bastion and its pods wait on the plateau at the end.
func _place_bastion() -> void:
	var base_x := STAGE_LENGTH + BASTION_OFFSET
	var boss_health := _health() * (1.0 + 0.25 * maxi(planet.depth - 1, 0))
	bastion = _plant("bastion", base_x, boss_health)
	bastion.shielded = true
	# Pods guard the near side and the top of the spire, where shots can reach them.
	for offset: float in [-320.0, -170.0]:
		pods.append(_plant("bastion_pod", base_x + offset, _health()))
	var top := battle.spawn("bastion_pod", false, Vector2(base_x, ground_y(base_x) - 140.0), _health())
	top.age = GloomEnemy.SPAWN_IN_TIME
	pods.append(top)


func _begin_bastion() -> void:
	_phase = "bastion"
	_wave_left = 4.0
	_hud.show_banner("THE GLOOM BASTION", "Break its pods to bring down the shield, then break the bastion.", SpaceHud.RED, 3.0)
	_sfx.play("elite")
	_camera.add_trauma(0.4)


func _update_bastion_shield() -> void:
	if not bastion_alive():
		return
	var pods_left := 0
	for pod in pods:
		if is_instance_valid(pod) and not pod.dead:
			pods_left += 1
	bastion.shielded = pods_left > 0
	if not bastion.shielded and not _shield_announced:
		_shield_announced = true
		_hud.show_banner("THE SHIELD FALLS", "Finish the bastion!", SpaceHud.GOLD, 2.0)
		_fx.ring(bastion.position, SHIELD_HIT_COLOR, 220.0, 0.5, 4.0)
		_sfx.play("shatter")


## Skimmer columns, mite packs and dart pairs from the right edge.
func _update_waves(dt: float) -> void:
	_wave_left -= dt
	if _wave_left > 0.0:
		return
	var threat := float(run.difficulty()["threat"])
	_wave_left = _rng.randf_range(WAVE_INTERVAL.x, WAVE_INTERVAL.y) / clampf(threat, 0.7, 2.0) * (1.4 if _phase == "bastion" else 1.0)
	var right := scroll + VIEW.x + 40.0
	var floor := ground_y(right)
	var y := _rng.randf_range(110.0, maxf(floor - 160.0, 150.0))
	var health := _health()
	var roll := _rng.randf()
	if roll < 0.5:
		var count := _rng.randi_range(4, 6)
		for i in count:
			battle.spawn("skimmer", false, Vector2(right + i * 55.0, y), health)
	elif roll < 0.8 or planet.depth < 2:
		for i in _rng.randi_range(3, 5):
			battle.spawn("mite", false, Vector2(right + _rng.randf_range(0.0, 60.0), y + _rng.randf_range(-50.0, 50.0)), health)
	else:
		for i in 2:
			battle.spawn("dart", false, Vector2(right + i * 40.0, y + i * 60.0), health)


# --- Kills, pickups, the ship -----------------------------------------------------

func _on_enemy_killed(enemy: GloomEnemy) -> void:
	run.kills += 1
	if _rng.randf() < enemy.spark_chance:
		_pickups.drop(enemy.position, enemy.spark_count)
	if _defenses.has(enemy):
		defenses_destroyed += 1
	if enemy == bastion:
		_fx.ring(enemy.position, GloomEnemy.HEART_COLOR, 700.0, 1.0, 8.0)
		_fx.burst(enemy.position, IGNITE_COLOR, 80, 100.0, 600.0, 1.0, 2.6)
		_camera.add_trauma(0.9)
		_sfx.play("ignite")
		planet.assaulted = true
		_hud.show_banner("THE BASTION FALLS", "Ground defenses destroyed: %d of %d. Taking her down to land." % [defenses_destroyed, defenses_total], SpaceHud.GOLD, FINISH_SECONDS + 1.0)
		_finish("landed", FINISH_SECONDS)
		for other in battle.enemies:
			battle.burn(other)


func _update_pickups(dt: float) -> void:
	var collected := _pickups.update(dt, ship.position, ship.alive and _outcome.is_empty(), stats.magnet)
	var sparks := int(collected.get(Pickups.SPARK, 0))
	if sparks > 0:
		run.add_sparks(sparks)
		_sfx.play("spark", -8.0)


func _finish(outcome: String, delay: float) -> void:
	if not _outcome.is_empty():
		return
	_outcome = outcome
	_end_left = delay
	print("AssaultMission: %s (%d of %d defenses)" % [outcome, defenses_destroyed, defenses_total])


func _on_ship_damaged(_amount: float, hull_hit: bool) -> void:
	_camera.add_trauma(0.35 if hull_hit else 0.2)
	_fx.burst(ship.position, HULL_HIT_COLOR if hull_hit else SHIELD_HIT_COLOR, 10, 60.0, 260.0, 0.35, 2.0)
	_sfx.play("hurt", -4.0)


func _on_ship_dashed(origin: Vector2, direction: Vector2) -> void:
	_fx.burst(origin, SHIELD_HIT_COLOR, 14, 30.0, 160.0, 0.35, 2.0, (-direction).angle(), 0.8)
	_sfx.play("dash", -6.0)


## Out of hull: a spare spark pulls you back to orbit, otherwise the run ends.
func _on_ship_destroyed() -> void:
	_fx.burst(ship.position, IGNITE_COLOR, 70, 80.0, 520.0, 1.0, 2.6)
	_camera.add_trauma(0.9)
	_sfx.play("death")
	if run.revives_left > 0:
		run.revives_left -= 1
		_hud.show_banner("BOUNCED BACK TO ORBIT", "A spare spark pulled you out. %d left. Try again when you're ready." % run.revives_left, SpaceHud.ORANGE, DEFEAT_SECONDS + 0.5)
		_finish("retreated", DEFEAT_SECONDS)
	else:
		_hud.show_banner("THE LIGHT IS LOST", "%d sparks banked. The dark keeps the rest." % run.sparks, SpaceHud.RED, DEFEAT_SECONDS + 0.5)
		_finish("defeat", DEFEAT_SECONDS)


## A progress line every eight seconds under autoplay, for smoke tests.
func _log_state() -> void:
	var pods_left := 0
	for pod in pods:
		if is_instance_valid(pod) and not pod.dead:
			pods_left += 1
	var boss := "%.0f/%.0f" % [bastion.hp, bastion.max_hp] if bastion_alive() else "down"
	print("AssaultMission: t=%.0fs %s scroll=%.0f ship=%s hull %.0f shield %.0f  defenses %d/%d  pods %d  bastion %s  enemies %d" % [
		_time, _phase, scroll, ship.position, ship.hull, ship.shield, defenses_destroyed, defenses_total, pods_left, boss, battle.enemies.size()])


# --- HUD and input ----------------------------------------------------------------

func _update_hud() -> void:
	_hud.set_vitals(ship.shield / maxf(stats.max_shield, 1.0), ship.hull / maxf(stats.max_hull, 1.0), ship.dash_readiness())
	_hud.set_sparks(run.sparks)
	_hud.set_resources(run.resources)
	_hud.set_ammo(weapons.ammo_status())
	_hud.set_objective("Ground defenses destroyed  %d / %d" % [defenses_destroyed, defenses_total], SpaceHud.GOLD)
	if _phase == "descent":
		_hud.set_claim("DESCENT", scroll / STAGE_LENGTH, "Burn the ground defenses: fewer will wait for you on the surface", SpaceHud.GOLD, 2.0)
	elif bastion_alive():
		var status := "Break its pods to bring down the shield" if bastion.shielded else "THE SHIELD IS DOWN  ·  FINISH IT"
		_hud.set_claim("THE GLOOM BASTION", 1.0 - bastion.hp / maxf(bastion.max_hp, 1.0), status, SpaceHud.RED, 2.0)
	else:
		_hud.hide_claim()
	_hud.set_prompt("PAUSED  ·  Esc to resume  ·  Q to pull back to orbit" if _paused else "")


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ESCAPE:
			_paused = not _paused
			if _paused:
				_hud.show_banner("PAUSED", "Esc to resume  ·  Q to pull back to orbit", SpaceHud.DIM, 3600.0)
			else:
				_hud.hide_banner()
		KEY_Q:
			if _paused and _outcome.is_empty():
				_paused = false
				_hud.hide_banner()
				_finish("retreated", 0.3)
		KEY_F3:
			battle.god_mode = not battle.god_mode
			_hud.show_banner("GOD MODE %s" % ("ON" if battle.god_mode else "OFF"), "", SpaceHud.DIM, 1.2)
		KEY_F5:
			_sfx.muted = not _sfx.muted
		KEY_H:
			_hud.toggle_help()


func _build_scene() -> void:
	_sky = AssaultSky.new()
	_sky.planet_type = planet.type
	add_child(_sky)
	_terrain = AssaultTerrain.new()
	add_child(_terrain)
	_pickups = Pickups.new()
	add_child(_pickups)
	_enemy_root = Node2D.new()
	add_child(_enemy_root)
	_projectiles = Projectiles.new()
	add_child(_projectiles)
	ship = Ship.new()
	ship.tuning = tuning
	add_child(ship)
	_fx = FxLayer.new()
	add_child(_fx)
	_anchor = Node2D.new()
	add_child(_anchor)
	_camera = GameCamera.new()
	_camera.target = _anchor
	_camera.play_zoom = 1.0
	_camera.follow_speed = 40.0
	_camera.look_ahead_enabled = false
	add_child(_camera)
	_hud = SpaceHud.new()
	add_child(_hud)
	_hud.set_help(HELP_TEXT)
	_hud.set_header("ASSAULT ON %s  ·  %s WORLD" % [planet.name.to_upper(), planet.type_name().to_upper()])
	_sfx = Sfx.new()
	add_child(_sfx)
	battle = Battle.new(_enemy_root, _projectiles, _fx, _sfx, _camera, _rng)
	battle.max_alive = 60
	battle.damage_scale = float(run.difficulty()["damage"])
	stats = run.loadout.compute_stats(tuning, run.bonuses)
	ship.apply_stats(stats, run.loadout.hull)
	weapons.configure(stats.weapons)
	if _autoplay:
		_autopilot = AssaultAutopilot.new(self)
		ship.input = _autopilot
	else:
		ship.input = ShipInput.new(self)
	ship.damaged.connect(_on_ship_damaged)
	ship.dashed.connect(_on_ship_dashed)
	ship.destroyed.connect(_on_ship_destroyed)
	battle.enemy_killed.connect(_on_enemy_killed)


func _parse_options() -> Dictionary:
	var options := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	return options
