class_name SurfaceMission
extends Node2D
## Landfall: the pilot sets down on an awake planet to kindle it. The surface
## is smothered in dark; the lantern shows a little of it at a time. Break
## resource deposits, raid caches and clear nests on the way to the Ember Vein,
## then plant a pylon on it and hold the light around it while the Gloom
## comes out of the dark (a ground siege, like a claim in space). When the
## pylon ignites the whole planet lights up, the Gloom burns, and it becomes
## an outpost for the homeworld.
##
## GameFlow creates this with setup() and listens for finished(outcome):
## "kindled", "left" (lifted off before kindling) or "defeat" (lost the pilot
## with no spare sparks left). Run on its own it lands on a sample planet.
## `suppression` (the share of ground defenses destroyed in the assault)
## thins out the nests and sleeping packs.
##
## Command-line options go after `--`:
##   --autoplay              let the autopilot walk (and fight)
##   --god                   ignore damage
##   --surface-start=vein    start next to the vein (screenshots, siege tests)

signal finished(outcome: String)

enum Phase { EXPLORE, SIEGE, KINDLED, LOST }

const PLANT_DISTANCE := 95.0
## Up to this share of nests and packs are gone when every ground defense fell.
const SUPPRESSION_EFFECT := 0.5
## Building an extractor on a kindled planet: its cost in the planet's
## resource, and how close the pilot must stand.
const EXTRACTOR_COST := 10
const EXTRACTOR_REACH := 80.0
const LANDER_RADIUS := 150.0
const LANDER_LIGHT := 280.0
const VEIN_LIGHT := 210.0
const FLARE_LIGHT := 360.0
const FLARE_LIGHT_SECONDS := 6.0
const IN_FLIGHT_FLARE_LIGHT := 190.0
const SPAWN_RING := Vector2(540.0, 700.0)
const SPAWN_SAFE_DISTANCE := 380.0
const KINDLE_WAVE_SPEED := 2600.0
const LIFTOFF_SECONDS := 1.0
const DEFEAT_SECONDS := 3.0
const ROUTE_REFRESH := 0.45
const RESPAWN_IFRAMES := 1.5
const HITSTOP_SECONDS := 0.1
const HITSTOP_SCALE := 0.05
const SPARK_STREAK_WINDOW := 0.6
const CACHE_REACH := 30.0
const IGNITE_COLOR := Color(2.6, 2.0, 1.0)
const SNUFF_COLOR := Color(2.6, 0.4, 1.4)
const BARRIER_HIT_COLOR := Color(0.6, 1.4, 2.4)
const HEALTH_HIT_COLOR := Color(2.4, 0.8, 0.3)
const SIDEARM := {"mode": "aimed", "rate": 6.5, "damage": 1.5, "speed": 950.0, "life": 0.75, "count": 1, "spread": 3.0, "style": "bolt"}
const FLARE := {"mode": "secondary", "rate": 1.5, "damage": 6.0, "speed": 520.0, "life": 0.85, "count": 1, "aoe": 120.0, "ammo": 2, "style": "flare"}
const HELP_TEXT := "WASD move  ·  mouse aim  ·  left click fire  ·  right click flare  ·  Space/Shift roll
E plant the pylon / lift off  ·  Esc pause  ·  H hide help
F3 god mode  ·  F5 mute  ·  F11 fullscreen"

var run: RunState
var planet: PlanetData
var tuning: SurfaceTuning
var map: SurfaceMap
var pilot: Pilot
var weapons := WeaponSystem.new()
var battle: Battle
var claim: Claim
var director: WaveDirector
var phase := Phase.EXPLORE
## Resources picked up on this planet (they also go straight into the run).
var haul := 0

var _space_tuning: SpaceTuning
var _autoplay := false
var _suppression := 0.0
var _rng := RandomNumberGenerator.new()
var _routes: Dictionary = {}
var _flare_lights: Array[Dictionary] = []
var _discovered_caches: Array[SurfaceMap.Cache] = []
var _wave_radius := -1.0
var _wave_reach := 0.0
var _respawn_left := 0.0
var _end_left := -1.0
var _outcome := ""
var _hitstop_left := 0.0
var _hazard_tick := false
var _spark_streak := 0
var _spark_streak_left := 0.0
var _last_warning := 0.0
var _paused := false
var _time := 0.0
var _route_sweep := 0.0
var _log_left := 10.0

var _camera: GameCamera
var _terrain: SurfaceTerrain
var _props: SurfaceProps
var _pickups: Pickups
var _enemy_root: Node2D
var _projectiles: Projectiles
var _fx: FxLayer
var _veil: LanternVeil
var _glints: SurfaceGlints
var _hud: SpaceHud
var _sfx: Sfx
var _autopilot: SurfaceAutopilot


## Call before adding the mission to the tree.
func setup(p_run: RunState, p_planet: PlanetData, space_tuning: SpaceTuning, autoplay := false, suppression := 0.0) -> void:
	run = p_run
	planet = p_planet
	_space_tuning = space_tuning
	_autoplay = autoplay
	_suppression = clampf(suppression, 0.0, 1.0)


func _ready() -> void:
	Glow.ensure(self)
	InputSetup.register()
	var options := _parse_options()
	if run == null:
		run = RunState.fresh(int(options.get("seed", 1)))
	if planet == null:
		planet = _sample_planet(int(options.get("seed", 7)))
	tuning = SurfaceTuning.from_space(_space_tuning if _space_tuning != null else SpaceTuning.new())
	_autoplay = _autoplay or options.has("autoplay")
	_rng.seed = planet.surface_seed
	tuning.lantern_radius *= 1.0 + float(run.bonuses.get("lantern", 0.0))
	tuning.pilot_speed *= 1.0 + float(run.bonuses.get("pilot_speed", 0.0))
	tuning.roll_cooldown *= maxf(1.0 - float(run.bonuses.get("pilot_roll", 0.0)), 0.4)
	map = SurfaceMap.generate(planet.surface_seed, planet.type, planet.depth, int(run.difficulty()["roster"]))
	if _suppression > 0.0:
		var keep := 1.0 - SUPPRESSION_EFFECT * _suppression
		map.nests.resize(ceili(map.nests.size() * keep))
		map.packs.resize(ceili(map.packs.size() * keep))
	_build_scene()
	battle.god_mode = options.has("god")
	_populate()
	pilot.reset_at(map.landing + Vector2(0.0, SurfaceProps.PAD_RADIUS + 30.0))
	if options.get("surface-start", "") == "vein":
		pilot.position = map.vein + Vector2(-140.0, 60.0)
	pilot.grant_iframes(RESPAWN_IFRAMES)
	_camera.snap_to(pilot.position)
	_camera.snap_zoom()
	_hud.show_banner("LANDFALL", "%s  ·  find the Ember Vein and plant a pylon on it" % planet.name, SpaceHud.GOLD, 3.5)
	print("SurfaceMission: landed on %s (%s, depth %d, seed %d): %d rocks, %d deposits, %d nests, %d packs" % [
		planet.name, planet.type_name(), planet.depth, planet.surface_seed,
		map.rocks.size(), map.deposits.size(), map.nests.size(), map.packs.size()])


# --- Host interface (GloomEnemy and WeaponSystem call these) ---------------------

func target_position() -> Vector2:
	return pilot.position


func has_objective() -> bool:
	return claim != null


func objective_position() -> Vector2:
	return map.vein


## Nests stop sending packs once the pylon is planted; the siege is enough.
func nests_awake() -> bool:
	return phase == Phase.EXPLORE


## A waypoint toward `goal` that goes around rocks: the goal itself when the
## way is clear, otherwise the next step of a grid path, refreshed now and then.
func route_to(enemy: GloomEnemy, goal: Vector2) -> Vector2:
	var key := enemy.get_instance_id()
	var entry: Dictionary = _routes.get(key, {})
	if entry.is_empty() or _time >= float(entry["refresh"]) or Vector2(entry["goal"]).distance_squared_to(goal) > 25600.0:
		entry = {"goal": goal, "refresh": _time + ROUTE_REFRESH * _rng.randf_range(0.8, 1.2), "path": PackedVector2Array(), "index": 0}
		if map.segment_hits_rock(enemy.position, goal, enemy.radius * 0.8):
			entry["path"] = map.find_path(enemy.position, goal)
		_routes[key] = entry
	var path: PackedVector2Array = entry["path"]
	if path.is_empty():
		return goal
	var index: int = entry["index"]
	while index < path.size() - 1 and enemy.position.distance_to(path[index]) < SurfaceMap.CELL * 1.2:
		index += 1
	entry["index"] = index
	return path[index]


func spawn_enemy_shot(origin: Vector2, velocity: Vector2, damage: float, style := "orb") -> void:
	battle.spawn_enemy_shot(origin, velocity, damage, style)


func spawn_minions(origin: Vector2, kind: String, count: int, drops_sparks := true) -> void:
	battle.spawn_minions(origin, kind, count, drops_sparks)


func fire_volley(spec: WeaponSpec, origin: Vector2, direction: Vector2, target: GloomEnemy) -> void:
	battle.fire_volley(spec, origin, direction, target, pilot.velocity)


func nearest_enemy_within(from: Vector2, reach: float) -> GloomEnemy:
	return battle.nearest_enemy_within(from, reach)


func on_snuffer_reached(enemy: GloomEnemy) -> void:
	if claim == null or enemy.dead:
		return
	claim.snuff()
	enemy.dead = true
	_fx.burst(enemy.position, SNUFF_COLOR, 40, 80.0, 420.0, 0.7, 2.4)
	_fx.ring(map.vein, SNUFF_COLOR, tuning.siege_radius, 0.5, 5.0)
	_camera.add_trauma(0.5)
	_sfx.play("snuff")
	_hud.show_banner("PYLON SNUFFED", "-%d%% progress" % roundi(tuning.snuff_penalty * 100.0), SpaceHud.RED, 1.6)


# --- Queries (the autopilot and tests use these) -------------------------------------

func at_lander() -> bool:
	return pilot.position.distance_to(map.landing) < LANDER_RADIUS


func near_vein() -> bool:
	return pilot.position.distance_to(map.vein) < PLANT_DISTANCE


func inside_siege() -> bool:
	return pilot.position.distance_to(map.vein) < tuning.siege_radius


## Light that rearms flares: the lander or a kindled planet. Like a claim in
## space, the pylon's light doesn't help until it ignites.
func in_steady_light() -> bool:
	return phase == Phase.KINDLED or at_lander()


## Any light at all, including a flare's glow; the barrier recharges in it.
func in_any_light() -> bool:
	if in_steady_light():
		return true
	for light in _flare_lights:
		if pilot.position.distance_to(light["position"]) < FLARE_LIGHT * 0.55:
			return true
	return false


func resource() -> String:
	return planet.resource()


## The closest thing lying on the ground waiting to be picked up, or INF.
func nearest_pickup(from: Vector2, reach: float) -> Vector2:
	var best := Vector2.INF
	var best_distance := reach
	for item in _pickups.items:
		var distance := item.position.distance_to(from)
		if distance < best_distance:
			best_distance = distance
			best = item.position
	return best


# --- Frame loop --------------------------------------------------------------

func _process(delta: float) -> void:
	if not _paused:
		var dt := delta
		if _hitstop_left > 0.0:
			_hitstop_left -= delta
			dt *= HITSTOP_SCALE
		run.elapsed += dt
		_step(dt)
	if _end_left > 0.0:
		_end_left -= delta
		if _end_left <= 0.0:
			finished.emit(_outcome)
	_update_lights(delta)
	_update_hud()


func _step(dt: float) -> void:
	_time += dt
	if _autopilot != null:
		_autopilot.think(dt)
	if pilot.alive and _outcome.is_empty():
		_step_pilot(dt)
	elif _respawn_left > 0.0:
		_respawn_left -= dt
		if _respawn_left <= 0.0:
			_respawn_pilot()
	if claim != null:
		_update_siege(dt)
	_slow_gloom_in_light()
	var active := pilot.alive and _outcome.is_empty()
	battle.update_enemies(dt, self, pilot, pilot.radius, active, _push_out)
	battle.update_projectiles(dt, pilot, pilot.radius, active, _bullet_blocked)
	_update_pickups(dt)
	if pilot.alive and in_any_light():
		pilot.regen(dt, tuning.barrier_regen, tuning.lander_heal if at_lander() else 0.0)
	_update_flare_lights(dt)
	if _wave_radius >= 0.0:
		_update_kindle_wave(dt)
	_sweep_routes(dt)
	_fx.update(dt)
	if _autopilot != null:
		_log_left -= dt
		if _log_left <= 0.0:
			_log_left = 10.0
			_log_state()


func _step_pilot(dt: float) -> void:
	var hazard := map.hazard_at(pilot.position)
	var info := map.hazard_info()
	pilot.slow = float(info["slow"]) if hazard != null and not pilot.is_rolling() else 0.0
	pilot.update(dt)
	_keep_pilot_on_ground()
	weapons.update(dt, pilot, pilot.input, pilot.aim_direction, pilot.input.is_firing(), pilot.input.consume_secondary(), in_steady_light(), self)
	if hazard != null and not pilot.is_rolling() and not battle.god_mode:
		_hazard_tick = true
		pilot.take_damage(tuning.hazard_dps * float(info["dps"]) * tuning.hit_iframes)
		_hazard_tick = false
	if pilot.input.consume_kindle():
		_interact()
	for cache in map.caches:
		if cache.opened:
			continue
		var distance := cache.position.distance_to(pilot.position)
		if distance < tuning.lantern_radius * 0.8 and not _discovered_caches.has(cache):
			_discovered_caches.append(cache)
		if distance < CACHE_REACH + pilot.radius:
			_open_cache(cache)


func _keep_pilot_on_ground() -> void:
	var push := _push_out(pilot.position, pilot.radius)
	if push != Vector2.ZERO:
		pilot.position += push
		var normal := push.normalized()
		var into := pilot.velocity.dot(normal)
		if into < 0.0:
			pilot.velocity -= normal * into
	pilot.position = map.clamp_inside(pilot.position, 24.0)


## How far to move a circle out of rocks and intact deposits.
func _push_out(point: Vector2, radius: float) -> Vector2:
	var push := map.rock_push(point, radius)
	for deposit in map.deposits:
		if not deposit.is_intact():
			continue
		var offset := point - deposit.position
		var min_distance := deposit.radius() + radius
		var distance := offset.length()
		if distance < min_distance and distance > 0.001:
			push += offset / distance * (min_distance - distance)
	return push


## Rocks stop every shot; the pilot's shots also chip away at deposits.
func _bullet_blocked(bullet: Projectiles.Bullet) -> bool:
	if map.segment_hits_rock(bullet.previous, bullet.position, bullet.radius):
		return true
	if not bullet.friendly:
		return false
	for deposit in map.deposits:
		if not deposit.is_intact():
			continue
		var closest := Geometry2D.get_closest_point_to_segment(deposit.position, bullet.previous, bullet.position)
		if closest.distance_to(deposit.position) < deposit.radius() + bullet.radius:
			_hit_deposit(deposit, bullet.damage, closest)
			return true
	return false


func _hit_deposit(deposit: SurfaceMap.Deposit, damage: float, point: Vector2) -> void:
	deposit.hp -= damage
	deposit.flash = 1.0
	var color := Pickups.color_of(resource())
	_fx.burst(point, color, 4, 40.0, 180.0, 0.3, 1.6)
	if deposit.hp > 0.0:
		_sfx.play("clink", -8.0)
		return
	_grant_xp(PilotRanks.DEPOSIT_XP)
	_pickups.drop(deposit.position, maxi(roundi(deposit.shards * float(run.difficulty()["reward"])), 1), resource())
	_fx.burst(deposit.position, color, 26, 60.0, 320.0, 0.6, 2.2)
	_fx.ring(deposit.position, color, deposit.radius() * 3.0, 0.35, 2.5)
	_camera.add_trauma(0.18)
	_sfx.play("shatter", -4.0)


# --- Interactions ------------------------------------------------------------------

func _interact() -> void:
	if phase == Phase.KINDLED:
		var site := extractor_site()
		if site != null:
			_build_extractor(site)
			return
	match phase:
		Phase.EXPLORE:
			if near_vein():
				_plant_pylon()
			elif at_lander():
				_lift_off("left")
		Phase.SIEGE:
			if at_lander():
				_lift_off("left")
		Phase.KINDLED:
			_lift_off("kindled")


func _open_cache(cache: SurfaceMap.Cache) -> void:
	cache.opened = true
	_grant_xp(PilotRanks.CACHE_XP)
	_fx.burst(cache.position, SurfaceProps.CACHE_COLOR, 24, 40.0, 260.0, 0.6, 2.0)
	_fx.ring(cache.position, SurfaceProps.CACHE_COLOR, 120.0, 0.4, 3.0)
	_sfx.play("cache", -2.0)
	match cache.contents:
		"repair":
			pilot.heal_full()
			_hud.show_banner("FIELD REPAIRS", "A lamplighter's cache: health and barrier restored.", SpaceHud.CYAN, 2.0)
		"flares":
			for mount in weapons.mounts:
				if mount.spec.mode == "secondary":
					mount.spec.ammo += 1
					mount.ammo = mount.spec.ammo
			_hud.show_banner("FLARE CACHE", "One more flare, and every flare restocked.", SpaceHud.GOLD, 2.0)
		_:
			var sparks := 12 + 4 * map.depth
			_pickups.drop(cache.position, sparks)
			_hud.show_banner("SPARK CACHE", "%d sparks left by the last lamplighter." % sparks, SpaceHud.GOLD, 2.0)
	print("SurfaceMission: opened a %s cache" % cache.contents)


func _lift_off(outcome: String) -> void:
	if not _outcome.is_empty():
		return
	_outcome = outcome
	_end_left = LIFTOFF_SECONDS
	_sfx.play("liftoff")
	_fx.burst(pilot.position, IGNITE_COLOR, 30, 60.0, 260.0, 0.8, 2.0)
	pilot.visible = false
	pilot.velocity = Vector2.ZERO
	print("SurfaceMission: lifting off (%s) with %d %s" % [outcome, haul, resource()])


# --- The ground siege -----------------------------------------------------------------

func _plant_pylon() -> void:
	phase = Phase.SIEGE
	claim = Claim.new(-1, tuning.siege_seconds(map.depth), tuning)
	claim.speed_scale = 1.0 + float(run.bonuses.get("claim_speed", 0.0))
	var dark := run.difficulty()
	director = WaveDirector.new(tuning, tuning.threat_for(map.depth) * float(dark["threat"]), _rng.randi(), map.depth + int(dark["roster"]))
	_props.pylon_planted = true
	_glints.show_vein = false
	_fx.ring(map.vein, IGNITE_COLOR, tuning.siege_radius, 0.6, 4.0)
	_camera.add_trauma(0.3)
	_sfx.play("plant")
	_hud.show_banner("PYLON PLANTED", "Stay inside its light for ~%ds. Snuffers will go for the pylon." % roundi(claim.seconds_remaining()), SpaceHud.GOLD, 2.4)
	print("SurfaceMission: pylon planted (%ds)" % roundi(claim.seconds_remaining()))


func _update_siege(dt: float) -> void:
	claim.update(dt, pilot.alive and _outcome.is_empty() and inside_siege())
	if claim.state == Claim.State.COMPLETE:
		_kindle()
		return
	if claim.state == Claim.State.FAILED:
		_fail_siege()
		return
	_props.siege_progress = claim.progress
	var alarm := 0.0
	if claim.state == Claim.State.DRAINING:
		alarm = 0.6 + 0.4 * sin(_time * 10.0)
		if _time - _last_warning > 0.5:
			_last_warning = _time
			_sfx.play("warn", -6.0)
	elif claim.state == Claim.State.PAUSED:
		alarm = 0.35
	_props.alarm = alarm
	for request in director.update(dt, claim.progress, _siege_enemy_count(), battle.count_kind("snuffer")):
		_spawn_siege(request)


## The pylon's light and flares make the Gloom sluggish.
func _slow_gloom_in_light() -> void:
	var pylon_reach := pylon_light_radius() * 0.85 if phase == Phase.SIEGE else -1.0
	for enemy in battle.enemies:
		var slow := 0.0
		if enemy.position.distance_to(map.vein) < pylon_reach:
			slow = tuning.pylon_slow
		for light in _flare_lights:
			if enemy.position.distance_to(light["position"]) < FLARE_LIGHT * 0.6:
				slow = maxf(slow, tuning.flare_slow)
		enemy.slow = slow


## How far the pylon's light reaches; it grows as the siege goes on.
func pylon_light_radius() -> float:
	if phase == Phase.KINDLED:
		return 700.0
	return lerpf(VEIN_LIGHT, tuning.siege_radius + 110.0, claim.progress if claim != null else 0.0)


## Awake Gloom that count against the siege's cap (sleepers and nests don't).
func _siege_enemy_count() -> int:
	var count := 0
	for enemy in battle.enemies:
		if not enemy.dead and not enemy.dormant and enemy.kind != "nest":
			count += 1
	return count


func _spawn_siege(request: Dictionary) -> void:
	var kind: String = request["kind"]
	var count: int = request["count"]
	var elite: bool = request["elite"]
	var origin := _siege_spawn_point()
	var health := tuning.health_scale(map.depth) * float(run.difficulty()["health"])
	for i in count:
		var spot := origin + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, 22.0 * sqrt(count))
		battle.spawn(kind, elite, spot, health)
	if request.get("climax", false):
		_hud.show_banner("AN ELITE SNUFFER HUNTS YOUR PYLON" if elite else "A SNUFFER HUNTS YOUR PYLON", "Stop it before it reaches the light.", SpaceHud.VIOLET, 2.4)
		_sfx.play("elite")
		_camera.add_trauma(0.3)


## Somewhere walkable in the dark ring around the pylon, away from the pilot.
func _siege_spawn_point() -> Vector2:
	var point := map.vein
	for attempt in 14:
		point = map.vein + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(SPAWN_RING.x, SPAWN_RING.y)
		point = map.clamp_inside(point, 60.0)
		if map.is_walkable(point) and point.distance_to(pilot.position) > SPAWN_SAFE_DISTANCE:
			return point
	return point


func _fail_siege(silent := false) -> void:
	print("SurfaceMission: siege failed at %d%%" % roundi(claim.progress * 100.0))
	claim = null
	director = null
	phase = Phase.EXPLORE
	_props.pylon_planted = false
	_props.alarm = 0.0
	_glints.show_vein = true
	for enemy in battle.enemies:
		if not enemy.dormant and enemy.kind != "nest":
			battle.dissolve(enemy)
	battle.remove_dead()
	if not silent:
		_hud.show_banner("THE PYLON WENT DARK", "Plant it again when you're ready.", SpaceHud.RED, 2.6)
		_sfx.play("snuff")


## The pylon ignites: a wave of light rolls across the planet, burning every
## Gloom creature it touches, and the haul flies to the pilot.
func _kindle() -> void:
	phase = Phase.KINDLED
	claim = null
	director = null
	_props.kindled = true
	_props.alarm = 0.0
	_wave_radius = 0.0
	_wave_reach = 0.0
	for corner: Vector2 in [map.bounds.position, map.bounds.end, Vector2(map.bounds.position.x, map.bounds.end.y), Vector2(map.bounds.end.x, map.bounds.position.y)]:
		_wave_reach = maxf(_wave_reach, map.vein.distance_to(corner))
	var payout := roundi(tuning.haul(map.depth) * (1.0 + float(run.bonuses.get("surface_haul", 0.0))) * float(run.difficulty()["reward"]))
	_pickups.drop(map.vein, payout, resource())
	_pickups.drop(map.vein, tuning.kindle_sparks)
	_pickups.pull_all()
	_hitstop_left = HITSTOP_SECONDS
	_camera.add_trauma(0.7)
	_camera.punch(0.08)
	_fx.ring(map.vein, IGNITE_COLOR, 520.0, 0.8, 8.0)
	_fx.burst(map.vein, IGNITE_COLOR, 70, 120.0, 640.0, 1.0, 2.6)
	_sfx.play("ignite")
	_hud.show_banner("%s KINDLED" % planet.name.to_upper(), "Its outpost will mine %s for your homeworld. Build extractors on its deposits to mine faster." % PlanetData.RESOURCE_NAMES[resource()].to_lower(), SpaceHud.GOLD, 4.0)
	_grant_xp(PilotRanks.kindle_xp(map.depth))
	print("SurfaceMission: %s kindled (+%d %s, +%d sparks)" % [planet.name, payout, resource(), tuning.kindle_sparks])


func _update_kindle_wave(dt: float) -> void:
	_wave_radius += KINDLE_WAVE_SPEED * dt
	var progress := clampf(_wave_radius / _wave_reach, 0.0, 1.0)
	_terrain.kindled = progress
	_veil.target_strength = lerpf(0.94, 0.08, progress)
	_veil.strength = _veil.target_strength
	for enemy in battle.enemies:
		if not enemy.dead and enemy.position.distance_to(map.vein) < _wave_radius:
			battle.burn(enemy)
	battle.remove_dead()
	if progress >= 1.0:
		_wave_radius = -1.0


# --- Pilot growth and building -----------------------------------------------------

## Pilot experience; a new level heals the pilot on the spot.
func _grant_xp(amount: int) -> void:
	if not run.add_pilot_xp(amount):
		return
	if pilot.alive:
		pilot.heal_full()
		_fx.ring(pilot.position, Color(1.8, 1.5, 0.6), 160.0, 0.5, 4.0)
	_sfx.play("cache", -4.0)
	_hud.show_banner("PILOT LEVEL %d" % run.pilot_level(), "Healed. A point to spend at the Quarters back home.", SpaceHud.GOLD, 2.4)


## A deposit site near the pilot where an extractor can go, once kindled.
func extractor_site() -> SurfaceMap.Deposit:
	if phase != Phase.KINDLED or not pilot.alive:
		return null
	for deposit in map.deposits:
		if not deposit.extractor and deposit.position.distance_to(pilot.position) < EXTRACTOR_REACH + deposit.radius():
			return deposit
	return null


func _build_extractor(site: SurfaceMap.Deposit) -> void:
	var stock := int(run.resources.get(resource(), 0))
	if stock < EXTRACTOR_COST:
		_hud.show_banner("NOT ENOUGH %s" % PlanetData.RESOURCE_NAMES[resource()].to_upper(), "An extractor costs %d. Break more deposits." % EXTRACTOR_COST, SpaceHud.DIM, 1.8)
		_sfx.play("deny")
		return
	run.add_resource(resource(), -EXTRACTOR_COST)
	site.extractor = true
	planet.extractors += 1
	_grant_xp(PilotRanks.EXTRACTOR_XP)
	_fx.burst(site.position, Pickups.color_of(resource()), 30, 40.0, 220.0, 0.6, 2.0)
	_fx.ring(site.position, IGNITE_COLOR, 120.0, 0.4, 3.0)
	_sfx.play("plant", -2.0)
	_hud.show_banner("EXTRACTOR BUILT", "%s's outpost mines +%d an hour (%d extractor%s)." % [planet.name, int(MetaProgress.EXTRACTOR_RATE), planet.extractors, "" if planet.extractors == 1 else "s"], SpaceHud.GOLD, 2.0)
	print("SurfaceMission: extractor built (%d)" % planet.extractors)


# --- Kills, pickups, flares --------------------------------------------------------

## Nests always drop their sparks; other Gloom only drop sparks during the siege.
func _on_enemy_killed(enemy: GloomEnemy) -> void:
	run.kills += 1
	_routes.erase(enemy.get_instance_id())
	_grant_xp(int(PilotRanks.KILL_XP.get(enemy.kind, 2)))
	if enemy.kind == "nest":
		_pickups.drop(enemy.position, enemy.spark_count)
		_hud.show_banner("NEST DESTROYED", "", SpaceHud.VIOLET, 1.0)
	elif phase == Phase.SIEGE and _rng.randf() < enemy.spark_chance:
		_pickups.drop(enemy.position, enemy.spark_count)


func _update_pickups(dt: float) -> void:
	_spark_streak_left -= dt
	if _spark_streak_left <= 0.0:
		_spark_streak = 0
	var collected := _pickups.update(dt, pilot.position, pilot.alive and _outcome.is_empty(), tuning.pilot_magnet)
	for kind: String in collected:
		var amount := int(collected[kind])
		if kind == Pickups.SPARK:
			run.add_sparks(amount)
			_spark_streak += amount
			_spark_streak_left = SPARK_STREAK_WINDOW
			_sfx.play("spark", -8.0, 1.0 + minf(_spark_streak, 16) * 0.035)
			if claim != null:
				for i in amount:
					claim.add_spark()
				_hud.flash_claim()
		else:
			run.add_resource(kind, amount)
			haul += amount
			_sfx.play("chime", -8.0, 1.0 + randf() * 0.1)


func _on_exploded(bullet: Projectiles.Bullet, point: Vector2) -> void:
	if bullet.style == "flare":
		_flare_lights.append({"position": point, "left": FLARE_LIGHT_SECONDS})


func _update_flare_lights(dt: float) -> void:
	var kept: Array[Dictionary] = []
	for light in _flare_lights:
		light["left"] = float(light["left"]) - dt
		if float(light["left"]) > 0.0:
			kept.append(light)
	_flare_lights = kept


## Forgets routes for Gloom that are gone, every few seconds.
func _sweep_routes(dt: float) -> void:
	_route_sweep -= dt
	if _route_sweep > 0.0:
		return
	_route_sweep = 3.0
	var alive := {}
	for enemy in battle.enemies:
		alive[enemy.get_instance_id()] = true
	for key: int in _routes.keys():
		if not alive.has(key):
			_routes.erase(key)


# --- Pilot -----------------------------------------------------------------------

func _respawn_pilot() -> void:
	pilot.reset_at(map.landing + Vector2(0.0, SurfaceProps.PAD_RADIUS + 30.0))
	pilot.grant_iframes(RESPAWN_IFRAMES)
	_fx.ring(pilot.position, IGNITE_COLOR, 200.0, 0.5, 4.0)


func _on_pilot_rolled(origin: Vector2, direction: Vector2) -> void:
	_fx.burst(origin, BARRIER_HIT_COLOR, 10, 30.0, 140.0, 0.3, 1.8, (-direction).angle(), 0.8)
	_sfx.play("dash", -8.0)


func _on_pilot_damaged(_amount: float, health_hit: bool) -> void:
	if _hazard_tick:
		_fx.burst(pilot.position, map.hazard_info()["color"], 5, 30.0, 120.0, 0.3, 1.6)
		_sfx.play("burn", -8.0)
		return
	_camera.add_trauma(0.35 if health_hit else 0.2)
	_fx.burst(pilot.position, HEALTH_HIT_COLOR if health_hit else BARRIER_HIT_COLOR, 10, 60.0, 240.0, 0.35, 2.0)
	_sfx.play("hurt", -4.0)


func _on_pilot_destroyed() -> void:
	_fx.burst(pilot.position, IGNITE_COLOR, 60, 80.0, 460.0, 1.0, 2.4)
	_fx.ring(pilot.position, IGNITE_COLOR, 300.0, 0.7, 5.0)
	_camera.add_trauma(0.9)
	_sfx.play("death")
	print("SurfaceMission: pilot down")
	if claim != null:
		_fail_siege(true)
	if run.revives_left <= 0:
		phase = Phase.LOST
		_outcome = "defeat"
		_end_left = DEFEAT_SECONDS
		_hud.show_banner("THE LIGHT IS LOST", "%d sparks banked. The dark keeps the rest." % run.sparks, SpaceHud.RED, DEFEAT_SECONDS)
		return
	run.revives_left -= 1
	_respawn_left = tuning.respawn_delay
	_hud.show_banner("SPARE SPARK USED", "Rekindling at the lander. %d spare spark%s left." % [run.revives_left, "" if run.revives_left == 1 else "s"], SpaceHud.ORANGE, tuning.respawn_delay + 0.5)


# --- Lights and HUD ---------------------------------------------------------------

## Feeds the dark its pools of light, most important first.
func _update_lights(delta: float) -> void:
	_veil.begin(get_viewport().get_canvas_transform(), _camera.zoom.x)
	if pilot.alive and pilot.visible:
		var flicker := 1.0 + 0.025 * sin(_time * 17.0) + 0.015 * sin(_time * 41.0)
		_veil.add_light(pilot.position, tuning.lantern_radius * flicker, 1.0)
	_veil.add_light(map.landing, LANDER_LIGHT, 1.0)
	match phase:
		Phase.SIEGE, Phase.KINDLED:
			_veil.add_light(map.vein, pylon_light_radius(), 1.0)
		_:
			_veil.add_light(map.vein, VEIN_LIGHT * (0.9 + 0.1 * sin(_time * 2.2)), 0.8)
	for bullet in _projectiles.bullets:
		if bullet.style == "flare":
			_veil.add_light(bullet.position, IN_FLIGHT_FLARE_LIGHT, 0.95)
	for light in _flare_lights:
		var fade := clampf(float(light["left"]) / FLARE_LIGHT_SECONDS, 0.0, 1.0)
		_veil.add_light(light["position"], FLARE_LIGHT * sqrt(fade), minf(fade * 1.6, 1.0))
	var glow := float(map.hazard_info()["glow"])
	for hazard in map.hazards:
		_veil.add_light(hazard.position, hazard.radius * 1.35, glow)
	for cache in map.caches:
		if not cache.opened:
			_veil.add_light(cache.position, 80.0, 0.55)
	for deposit in map.deposits:
		if deposit.is_intact():
			_veil.add_light(deposit.position, 70.0 * deposit.size, 0.35)
	_veil.commit(delta)


func _update_hud() -> void:
	_hud.set_header("%s  ·  %s WORLD  ·  PILOT LEVEL %d" % [planet.name.to_upper(), planet.type_name().to_upper(), run.pilot_level()])
	_hud.set_vitals(pilot.barrier / maxf(pilot.max_barrier, 1.0), pilot.health / maxf(pilot.max_health, 1.0), pilot.roll_readiness())
	_hud.set_sparks(run.sparks)
	_hud.set_resources(run.resources)
	_hud.set_ammo(weapons.ammo_status())
	if claim != null:
		var status := "HOLD THE LIGHT  ·  ~%ds" % ceili(claim.seconds_remaining())
		var color := SpaceHud.GOLD
		if claim.state == Claim.State.PAUSED:
			status = "OUTSIDE THE LIGHT  ·  PAUSED  ·  fading in %.1fs" % maxf(tuning.claim_grace_seconds - claim.outside_time, 0.0)
			color = SpaceHud.ORANGE
		elif claim.state == Claim.State.DRAINING:
			status = "THE PYLON IS FADING  ·  GET BACK TO IT"
			color = SpaceHud.RED
		_hud.set_claim("EMBER VEIN", claim.progress, status, color, tuning.elite_threshold)
	else:
		_hud.hide_claim()
	match phase:
		Phase.EXPLORE:
			_hud.set_objective("Find the Ember Vein and plant a pylon", SpaceHud.GOLD)
		Phase.SIEGE:
			_hud.set_objective("Hold the light around the pylon", SpaceHud.GOLD)
		Phase.KINDLED:
			_hud.set_objective("Planet kindled  ·  E to lift off", SpaceHud.GOLD)
		Phase.LOST:
			_hud.set_objective("")
	_hud.set_prompt(_prompt_text())
	_hud.set_indicators(_indicators())


func _prompt_text() -> String:
	if _paused:
		return "PAUSED  ·  Esc to resume  ·  Q to lift off and leave the planet dark"
	if not pilot.alive or not _outcome.is_empty():
		return ""
	match phase:
		Phase.KINDLED:
			var site := extractor_site()
			if site != null:
				return "[E] Build an extractor  ·  %d %s  ·  this outpost mines +%d an hour" % [EXTRACTOR_COST, resource(), int(MetaProgress.EXTRACTOR_RATE)]
			return "[E] Lift off  ·  %d %s gathered here  ·  walk to a deposit to build an extractor" % [haul, PlanetData.RESOURCE_NAMES[resource()].to_lower()]
		Phase.EXPLORE:
			if near_vein():
				return "[E] Plant the pylon  ·  hold its light for ~%ds  ·  the Gloom will come" % roundi(tuning.siege_seconds(map.depth) / tuning.claim_speed_multiplier)
			if at_lander():
				return "[E] Lift off  ·  the planet stays dark  ·  health recovers here"
	var hazard := map.hazard_at(pilot.position)
	if hazard != null:
		return "%s! Get out, or roll through it." % map.hazard_info()["name"]
	return ""


func _indicators() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var to_screen := get_viewport().get_canvas_transform()
	if phase != Phase.KINDLED:
		list.append({"position": to_screen * map.vein, "color": SpaceHud.GOLD, "size": 14.0})
	list.append({"position": to_screen * map.landing, "color": SpaceHud.CYAN, "size": 11.0})
	for cache in _discovered_caches:
		if not cache.opened:
			list.append({"position": to_screen * cache.position, "color": Color(1.0, 0.85, 0.45, 0.7), "size": 9.0})
	for enemy in battle.enemies:
		if enemy.kind == "snuffer" and not enemy.dead and not enemy.dormant:
			list.append({"position": to_screen * enemy.position, "color": SpaceHud.VIOLET, "size": 15.0 if enemy.elite else 11.0})
	return list


## A progress line every ten seconds under autoplay, for smoke tests.
func _log_state() -> void:
	var intact := 0
	for deposit in map.deposits:
		if deposit.is_intact():
			intact += 1
	var to_vein := pilot.position.distance_to(map.vein)
	print("SurfaceMission: t=%.0fs %s  hp %.0f/%.0f  barrier %.0f  vein %.0f away  deposits %d/%d  haul %d  awake %d  enemies %d  fps %d" % [
		_time, Phase.keys()[phase], pilot.health, pilot.max_health, pilot.barrier, to_vein,
		intact, map.deposits.size(), haul, _siege_enemy_count(), battle.enemies.size(), Engine.get_frames_per_second()])


# --- Input and setup -------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ESCAPE:
			_paused = not _paused
			if _paused:
				_hud.show_banner("PAUSED", "Esc to resume  ·  Q to lift off", SpaceHud.DIM, 3600.0)
			else:
				_hud.hide_banner()
		KEY_Q:
			if _paused and phase != Phase.LOST:
				_paused = false
				_hud.hide_banner()
				_lift_off("kindled" if phase == Phase.KINDLED else "left")
		KEY_F3:
			battle.god_mode = not battle.god_mode
			_hud.show_banner("GOD MODE %s" % ("ON" if battle.god_mode else "OFF"), "", SpaceHud.DIM, 1.2)
		KEY_F5:
			_sfx.muted = not _sfx.muted
		KEY_H:
			_hud.toggle_help()
		KEY_F11:
			var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)


## Nests and sleeping packs from the map.
func _populate() -> void:
	var health := tuning.health_scale(map.depth) * float(run.difficulty()["health"])
	for point in map.nests:
		battle.spawn("nest", false, point, health)
	for pack in map.packs:
		var center: Vector2 = pack["position"]
		var count: int = pack["count"]
		for i in count:
			var spot := center + Vector2.from_angle(TAU * i / count + _rng.randf()) * _rng.randf_range(10.0, 30.0 + 8.0 * count)
			var enemy := battle.spawn(String(pack["kind"]), false, spot, health)
			enemy.dormant = true
			enemy.wake_range = tuning.enemy_wake_range
			enemy.rotation = _rng.randf() * TAU


func _build_scene() -> void:
	_terrain = SurfaceTerrain.new()
	add_child(_terrain)
	_terrain.build(map)
	_props = SurfaceProps.new()
	_props.siege_radius = tuning.siege_radius
	add_child(_props)
	_props.build(map, planet.resource())
	_pickups = Pickups.new()
	add_child(_pickups)
	_enemy_root = Node2D.new()
	add_child(_enemy_root)
	_projectiles = Projectiles.new()
	add_child(_projectiles)
	pilot = Pilot.new()
	pilot.setup(tuning, float(run.bonuses.get("pilot_health", 0.0)), float(run.bonuses.get("pilot_barrier", 0.0)))
	add_child(pilot)
	_fx = FxLayer.new()
	add_child(_fx)
	_camera = GameCamera.new()
	_camera.target = pilot
	_camera.play_zoom = 1.15
	add_child(_camera)
	_veil = LanternVeil.new()
	add_child(_veil)
	_glints = SurfaceGlints.new()
	_glints.map = map
	_glints.resource = planet.resource()
	add_child(_glints)
	_hud = SpaceHud.new()
	add_child(_hud)
	_hud.set_labels("BARRIER", "HEALTH", "ROLL", "FLARES")
	_hud.set_help(HELP_TEXT)
	_sfx = Sfx.new()
	add_child(_sfx)
	battle = Battle.new(_enemy_root, _projectiles, _fx, _sfx, _camera, _rng)
	battle.max_alive = tuning.max_alive
	battle.speed_scale = tuning.enemy_speed_scale
	battle.damage_scale = float(run.difficulty()["damage"])
	_glints.battle = battle

	var sidearm := WeaponSpec.from_weapon("sidearm", SIDEARM)
	sidearm.mount = Vector2(15.0, 5.0)
	sidearm.damage *= 1.0 + float(run.bonuses.get("damage", 0.0)) + float(run.bonuses.get("sidearm_damage", 0.0))
	var flare := WeaponSpec.from_weapon("flare", FLARE)
	flare.mount = Vector2(0.0, -11.0)
	flare.ammo += int(run.bonuses.get("flares", 0.0))
	var specs: Array[WeaponSpec] = [sidearm, flare]
	weapons.configure(specs)

	if _autoplay:
		_autopilot = SurfaceAutopilot.new(self)
		pilot.input = _autopilot
		_camera.look_ahead_enabled = false
	else:
		pilot.input = ShipInput.new(self)
	pilot.rolled.connect(_on_pilot_rolled)
	pilot.damaged.connect(_on_pilot_damaged)
	pilot.destroyed.connect(_on_pilot_destroyed)
	battle.enemy_killed.connect(_on_enemy_killed)
	battle.exploded.connect(_on_exploded)


func _parse_options() -> Dictionary:
	var options := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	return options


## A planet to land on when the mission runs by itself.
static func _sample_planet(seed_value: int) -> PlanetData:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var sample := PlanetData.new()
	sample.id = 0
	sample.name = "Tamsin's Rest"
	sample.type = rng.randi_range(0, PlanetData.Type.size() - 1) as PlanetData.Type
	sample.surface_seed = rng.randi()
	sample.depth = 2
	return sample
