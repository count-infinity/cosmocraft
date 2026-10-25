class_name SpaceGame
extends Node2D
## One run into the dark. Fly into a region that borders your territory,
## kindle a spark, and hold your ground until it ignites. Every ignition
## offers a pick of loot for your ship; burning out the heart conquers the
## sector for good, and then you push on into an adjacent sector with the same
## ship or return home. Planets wake once every region around them is yours;
## landing on one hands off to GameFlow, which plays the assault and surface.
##
## GameFlow normally creates this with a RunState and listens for run_ended.
## Run on its own (or from tests) it starts a fresh practice run.
##
## Command-line options go after `--`:
##   --seed=N                      play a specific sector
##   --autoplay                    let the autopilot fly (and pick loot)
##   --god                         ignore damage
##   --debug                       show the debug overlay
##   --claim-speed=X               multiply claim speed
##   --shot-on-ignite              with --capture, also grab each ignition
##   --show=loot|refit             open that screen at the start (screenshots)
##   --log-fps                     print frame timing every second
##   --map-at=T                    open the sector map at time T
##   --visit=asteroids|nebula|nest|rich|heart|planet   start inside such a region

signal run_ended(run: RunState)
## A heart burned out; GameFlow records the conquest.
signal sector_relit(sector_id: int)
## Emitted when the pilot lands on an awake planet; GameFlow runs the surface.
signal landing_requested(planet: PlanetData)

const RESPAWN_IFRAMES := 1.5
const HITSTOP_SECONDS := 0.12
const HITSTOP_SCALE := 0.05
const IGNITION_SECONDS := 0.8
const CLAIM_LIGHT_START := 40.0
const SPAWN_SAFE_DISTANCE := 300.0
const RUN_END_DELAY := 3.5
const POINT_DEFENSE_RANGE := 170.0
const SPARK_STREAK_WINDOW := 0.6
## The heart can't be hurt until the siege reaches this much progress. Then
## the waves stop and it's a duel with the heart and the mites it spawns.
const HEART_SHIELD_UNTIL := 0.4
const SPEED_STEPS: Array[float] = [1.0, 3.0, 10.0]
const IGNITE_COLOR := Color(2.6, 2.0, 1.0)
const SNUFF_COLOR := Color(2.6, 0.4, 1.4)
const SHIELD_HIT_COLOR := Color(0.6, 1.4, 2.4)
const HULL_HIT_COLOR := Color(2.4, 0.8, 0.3)
## Asteroid outlines wobble; collisions use this fraction of the radius.
const ROCK_SOLIDITY := 0.88
## Grid query padding: the largest asteroid radius plus a margin.
const ROCK_REACH := 70.0

@export var tuning: SpaceTuning
## 0 picks a fresh random sector every run.
@export var sector_seed := 0

var run: RunState
var sector: SectorData
var ship: Ship
var stats := ShipStats.new()
var weapons := WeaponSystem.new()
var battle: Battle
var claim: Claim
var director: WaveDirector
var kindle_spark: KindleSpark
var heart_boss: GloomEnemy
## The conquest map and what's already lit (set by GameFlow; null in a
## practice run, which simply ends when the heart burns out).
var galaxy: GalaxyData
var conquered: Dictionary = {}

var _rng := RandomNumberGenerator.new()
var _rock_grid := SpatialGrid.new(160.0)
var _ship_region := -1
## The awake planet the ship is currently over, if any.
var _landable: PlanetData
var _announced_planets: Array[PlanetData] = []
## Set while GameFlow fades out to a planet's surface.
var _landing_pending := false
var _claim_reach := 0.0
var _hitstop_left := 0.0
var _respawn_left := 0.0
var _end_left := -1.0
var _ignition: Dictionary = {}
var _loot_choices: Array[LootPicks.Choice] = []
var _loot_quality := 0
var _loot_gear := 0
var _point_defense_cooldown := 0.0
var _spark_streak := 0
var _spark_streak_left := 0.0
var _paused := false
var _map_open := false
var _speed_index := 0
var _debug_visible := false
var _last_warning := 0.0
var _elapsed := 0.0
var _map_at := -1.0
var _shot_on_ignite := false
var _log_fps := false
var _fps_window := 0.0
var _fps_frames := 0
var _fps_worst := 0.0

var _camera: GameCamera
var _far_layer: CanvasLayer
var _starfield: Starfield
var _far_stars: FarStars
var _regions: RegionLayer
var _asteroid_layer: AsteroidLayer
var _borders: BorderLayer
var _planets: PlanetLayer
var _beacon_root: Node2D
var _pickups: Pickups
var _enemy_root: Node2D
var _projectiles: Projectiles
var _fx: FxLayer
var _veil: NebulaVeil
var _hud: SpaceHud
var _loot: LootScreen
var _refit: RefitScreen
var _choice: SectorChoiceScreen
## Set when the heart burns out: after the loot pick comes the push-on choice.
var _choice_pending := false
var _sfx: Sfx
var _autopilot: Autopilot


func _ready() -> void:
	if tuning == null:
		tuning = SpaceTuning.new()
	Glow.ensure(self)
	_register_input()
	_build_scene()
	var options := _parse_options()
	_apply_options(options)
	var seed_value := int(options.get("seed", sector_seed))
	if run == null:
		run = RunState.fresh(seed_value)
	start_sector(run.sector_seed if run.sector_seed != 0 else seed_value)
	if options.has("visit"):
		_visit(String(options["visit"]))
	match String(options.get("show", "")):
		"loot":
			_loot_choices = LootPicks.roll(_rng, run.loadout, run.unlocked, 1 + int(run.difficulty()["quality"]), LootPicks.HULL_MIN_CLAIMS, 3, int(run.difficulty()["gear"]))
			_loot.open(_loot_choices, _reroll_label(), _can_reroll())
		"refit":
			for id in ["reactor", "twin_laser", "magnet_coil", "focusing_lens"]:
				run.loadout.stow(ComponentLibrary.get_def(id))
			_refit.open(run.loadout, tuning, run.bonuses)
	_hud.show_banner("HOLD THE LIGHT", "Fly into a region that borders your light and press E to kindle it.", SpaceHud.GOLD, 4.0)


func start_sector(seed_value: int) -> void:
	if seed_value == 0:
		seed_value = randi_range(1, 999999)
	run.sector_seed = seed_value
	_clear_claim()
	battle.clear()
	heart_boss = null
	_pickups.clear()
	_ignition = {}
	_rng.seed = seed_value
	sector = SectorGenerator.generate(seed_value, tuning, run.sector_theme)
	_regions.build(sector)
	_borders.sector = sector
	_starfield.build(sector.radius, seed_value)
	_asteroid_layer.build(sector)
	_planets.build(sector)
	_announced_planets.clear()
	_rock_grid.clear()
	for rock in sector.asteroids:
		_rock_grid.insert(rock, rock.position)
	_apply_loadout()
	_respawn_ship()
	_camera.snap_to(ship.position)
	_refresh_territory()
	print("SpaceGame: sector seed %d with %d regions, %d planets" % [seed_value, sector.regions.size(), sector.planets.size()])


## Frontier regions can be kindled, except the heart while it's sealed.
func can_kindle(region: RegionData) -> bool:
	if not sector.is_frontier(region.id):
		return false
	return not region.is_heart or heart_claims_needed() == 0


## Regions you still need to hold before the heart unseals.
func heart_claims_needed() -> int:
	return maxi(tuning.heart_requires_claims - (sector.claimed_count() - 1), 0)


func nearest_frontier(from: Vector2) -> RegionData:
	var best: RegionData = null
	var best_distance := INF
	for region in sector.regions:
		if not can_kindle(region):
			continue
		var distance := from.distance_squared_to(region.anchor)
		if distance < best_distance:
			best_distance = distance
			best = region
	return best


func nearest_enemy(from: Vector2) -> GloomEnemy:
	return battle.nearest_enemy(from)


## Hides and freezes the run (while a planet's surface is being played), or
## brings it back.
func set_active(active: bool) -> void:
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	visible = active
	_far_layer.visible = active
	_hud.visible = active
	if not active:
		_veil.visible = false
	_camera.enabled = active
	if active:
		_landing_pending = false
		_camera.make_current()


## Back from a planet's surface. `outcome` is "kindled" or "left".
func on_returned_from_surface(planet: PlanetData, outcome: String) -> void:
	ship.reset_at(planet.position + Vector2(0.0, -planet.radius - 60.0))
	ship.grant_iframes(RESPAWN_IFRAMES)
	_camera.snap_to(ship.position)
	if outcome != "kindled":
		_hud.show_banner("BACK IN ORBIT", "%s is still waiting for its light." % planet.name, SpaceHud.DIM, 2.0)
		return
	planet.kindled = true
	run.outposts.append({"name": planet.name, "type": planet.type_name(), "resource": planet.resource(), "extractors": planet.extractors})
	_fx.ring(planet.position, IGNITE_COLOR, planet.radius * 4.0, 0.8, 6.0)
	_sfx.play("ignite", -4.0)
	_set_loot_odds(LootPicks.quality_for(sector.regions[planet.touching[0]]) + 1)
	_loot_choices = LootPicks.roll(_rng, run.loadout, run.unlocked, _loot_quality, run.regions_claimed, 3, _loot_gear)
	if _autopilot != null:
		_on_loot_picked(_loot_choices[0])
	else:
		_loot.open(_loot_choices, _reroll_label(), _can_reroll())
	_hud.show_banner("%s KINDLED" % planet.name.to_upper(), "A new outpost for your homeworld.", SpaceHud.GOLD, 2.6)


# --- Host interface (GloomEnemy and WeaponSystem call these) ---------------------

func target_position() -> Vector2:
	return ship.position


func has_objective() -> bool:
	return kindle_spark != null


func objective_position() -> Vector2:
	return kindle_spark.position


func nests_awake() -> bool:
	return true


## Space is open, so the Gloom flies straight at whatever it wants.
func route_to(_enemy: GloomEnemy, goal: Vector2) -> Vector2:
	return goal


func spawn_enemy_shot(origin: Vector2, velocity: Vector2, damage: float, style := "orb") -> void:
	battle.spawn_enemy_shot(origin, velocity, damage, style)


## The heart's endless spawns drop no sparks, so a long boss fight can't be farmed.
func spawn_minions(origin: Vector2, kind: String, count: int, drops_sparks := true) -> void:
	battle.spawn_minions(origin, kind, count, drops_sparks)


func fire_volley(spec: WeaponSpec, origin: Vector2, direction: Vector2, target: GloomEnemy) -> void:
	battle.fire_volley(spec, origin, direction, target, ship.velocity)


func nearest_enemy_within(from: Vector2, reach: float) -> GloomEnemy:
	return battle.nearest_enemy_within(from, reach)


func on_snuffer_reached(enemy: GloomEnemy) -> void:
	if claim == null or enemy.dead:
		return
	claim.snuff()
	kindle_spark.snuffed()
	enemy.dead = true
	_fx.burst(enemy.position, SNUFF_COLOR, 40, 80.0, 420.0, 0.7, 2.4)
	_fx.ring(kindle_spark.position, SNUFF_COLOR, 320.0, 0.5, 5.0)
	_camera.add_trauma(0.55)
	_sfx.play("snuff")
	_hud.show_banner("SPARK SNUFFED", "-%d%% progress" % roundi(tuning.snuff_penalty * 100.0), SpaceHud.RED, 1.6)


# --- Frame loop --------------------------------------------------------------

func _process(delta: float) -> void:
	_elapsed += delta
	if _log_fps:
		_track_frame_time(delta)
	if _map_at >= 0.0 and _elapsed >= _map_at:
		_map_at = -1.0
		_set_map_open(true)
	if not _is_frozen():
		var dt := delta
		if _hitstop_left > 0.0:
			_hitstop_left -= delta
			dt *= HITSTOP_SCALE
		run.elapsed += dt
		_step(dt)
	if _end_left > 0.0:
		_end_left -= delta
		if _end_left <= 0.0:
			run_ended.emit(run)
	_borders.zoom = _camera.zoom.x
	_planets.zoom = _camera.zoom.x
	_planets.map_mode = _map_open
	_update_veil(delta)
	_update_hud()


## The simulation stops while a menu, the map, or a loot pick is open.
func _is_frozen() -> bool:
	return _map_open or _paused or _loot.visible or _refit.visible or _choice.visible


func _step(dt: float) -> void:
	if _autopilot != null:
		_autopilot.think(dt)
	_ship_region = sector.region_at(ship.position)
	var in_light := _ship_region >= 0 and sector.regions[_ship_region].claimed
	if ship.alive:
		ship.update(dt)
		_keep_inside_sector(dt)
		_bounce_ship_off_rocks()
		weapons.update(dt, ship, ship.input, ship.aim_direction, ship.input.is_firing(), ship.input.consume_secondary(), in_light, self)
		_landable = _planet_under_ship()
		if ship.input.consume_kindle():
			if _landable != null:
				_request_landing(_landable)
			else:
				_try_kindle()
	elif not run.is_over():
		_respawn_left -= dt
		if _respawn_left <= 0.0:
			_respawn_ship()
	_ship_region = sector.region_at(ship.position)
	if claim != null:
		_update_claim(dt)
	battle.update_enemies(dt, self, ship, ship.radius, ship.alive, _rock_push)
	battle.update_projectiles(dt, ship, ship.radius, ship.alive, _bullet_hits_rock)
	_update_point_defense(dt)
	_update_pickups(dt)
	if ship.alive:
		if _ship_region >= 0 and sector.regions[_ship_region].claimed:
			ship.regen(dt)
		else:
			ship.dark_regen(dt)
	if not _ignition.is_empty():
		_update_ignition(dt)
	_fx.update(dt)


func _keep_inside_sector(dt: float) -> void:
	var distance := ship.position.length()
	if distance > sector.radius * 1.3:
		ship.velocity -= ship.position / distance * 2400.0 * dt
	var limit := sector.radius * 1.45
	if distance > limit:
		ship.position = ship.position / distance * limit


func _bounce_ship_off_rocks() -> void:
	var push := _rock_push(ship.position, ship.radius)
	if push == Vector2.ZERO:
		return
	ship.position += push
	var normal := push.normalized()
	var into := ship.velocity.dot(normal)
	if into < 0.0:
		ship.velocity -= normal * into * 1.6


## How far to move a circle so it no longer overlaps any asteroid.
func _rock_push(point: Vector2, radius: float) -> Vector2:
	var push := Vector2.ZERO
	for rock: SectorData.Asteroid in _rock_grid.query(point, radius + ROCK_REACH):
		var offset := point - rock.position
		var min_distance := rock.radius * ROCK_SOLIDITY + radius
		var distance := offset.length()
		if distance < min_distance and distance > 0.001:
			push += offset / distance * (min_distance - distance)
	return push


func _bullet_hits_rock(bullet: Projectiles.Bullet) -> bool:
	return _segment_hits_rock(bullet.previous, bullet.position, bullet.radius)


func _segment_hits_rock(from: Vector2, to: Vector2, radius: float) -> bool:
	var middle := (from + to) * 0.5
	for rock: SectorData.Asteroid in _rock_grid.query(middle, from.distance_to(to) * 0.5 + radius + ROCK_REACH):
		var closest := Geometry2D.get_closest_point_to_segment(rock.position, from, to)
		if closest.distance_to(rock.position) < rock.radius * ROCK_SOLIDITY + radius:
			return true
	return false


# --- Loadout and planets --------------------------------------------------------

## Recomputes the ship from the run's loadout (after a refit or loot pick).
func _apply_loadout() -> void:
	stats = run.loadout.compute_stats(tuning, run.bonuses)
	ship.apply_stats(stats, run.loadout.hull)
	weapons.configure(stats.weapons)
	if claim != null:
		claim.speed_scale = stats.claim_speed


## The awake, not yet kindled planet the ship is over (only outside a claim).
func _planet_under_ship() -> PlanetData:
	if claim != null or not _ignition.is_empty() or run.is_over() or _landing_pending:
		return null
	for planet in sector.planets:
		if not planet.kindled and planet.is_awake(sector) and ship.position.distance_to(planet.position) < planet.radius + 20.0:
			return planet
	return null


func _request_landing(planet: PlanetData) -> void:
	_landing_pending = true
	print("SpaceGame: landing on %s" % planet.name)
	_sfx.play("kindle", -2.0)
	landing_requested.emit(planet)


## Announces planets that just woke up because their last region was claimed.
func _announce_awake_planets() -> void:
	for planet in sector.planets:
		if planet.is_awake(sector) and not planet.kindled and not _announced_planets.has(planet):
			_announced_planets.append(planet)
			_hud.show_banner("%s AWAKENS" % planet.name.to_upper(), "Land on it to kindle an outpost.", planet.info()["accent"], 2.6)
			_fx.ring(planet.position, Color(planet.info()["accent"], 1.0) * 2.0, planet.radius * 3.0, 0.8, 5.0)


func _open_refit() -> void:
	if not ship.alive or claim != null or not _ignition.is_empty() or run.is_over():
		return
	var region := sector.get_region(sector.region_at(ship.position))
	if region == null or not region.claimed:
		_hud.show_banner("REFIT IN YOUR TERRITORY", "Fly back into your light to change your ship.", SpaceHud.DIM, 1.6)
		_sfx.play("deny")
		return
	_refit.open(run.loadout, tuning, run.bonuses)


func _on_refit_closed() -> void:
	_apply_loadout()


func _offer_loot(region: RegionData) -> void:
	_set_loot_odds(LootPicks.quality_for(region))
	_loot_choices = LootPicks.roll(_rng, run.loadout, run.unlocked, _loot_quality, run.regions_claimed, 3, _loot_gear)
	if _autopilot != null:
		_on_loot_picked(_loot_choices[0])
		return
	_loot.open(_loot_choices, _reroll_label(), _can_reroll())


func _on_loot_picked(choice: LootPicks.Choice) -> void:
	var note := LootPicks.apply(choice, run)
	_loot.close()
	_apply_loadout()
	_sfx.play("kindle", -4.0)
	_hud.show_banner(choice.title(), note, SpaceHud.GOLD, 2.2)
	print("SpaceGame: picked %s" % choice.title())
	if _choice_pending:
		_choice_pending = false
		_offer_next_sectors()


func _on_loot_reroll() -> void:
	if run.free_rerolls > 0:
		run.free_rerolls -= 1
	elif run.sparks >= LootPicks.REROLL_COST:
		run.sparks -= LootPicks.REROLL_COST
	else:
		return
	_loot_choices = LootPicks.roll(_rng, run.loadout, run.unlocked, _loot_quality, run.regions_claimed, 3, _loot_gear)
	_loot.open(_loot_choices, _reroll_label(), _can_reroll())


## Loot quality for a region (or planet) plus the darkness's bonus, and the
## darkness's gear level for new parts.
func _set_loot_odds(region_quality: int) -> void:
	var dark := run.difficulty()
	_loot_quality = mini(region_quality + int(dark["quality"]), LootPicks.RARITY_WEIGHTS.size() - 1)
	_loot_gear = int(dark["gear"])


func _can_reroll() -> bool:
	return run.free_rerolls > 0 or run.sparks >= LootPicks.REROLL_COST


func _reroll_label() -> String:
	if run.free_rerolls > 0:
		return "Reroll (free, %d left)" % run.free_rerolls
	return "Reroll (%d sparks)" % LootPicks.REROLL_COST


# --- Claiming ----------------------------------------------------------------

func _try_kindle() -> void:
	if claim != null or not _ignition.is_empty() or run.is_over():
		return
	var region := sector.get_region(_ship_region)
	if region == null:
		_hud.show_banner("NOTHING TO CLAIM", "There's only void out here.", SpaceHud.DIM, 1.4)
		_sfx.play("deny")
		return
	if region.claimed:
		return
	if not sector.is_frontier(region.id):
		_hud.show_banner("TOO DEEP IN THE DARK", "Claim a region that borders your light first.", SpaceHud.RED, 1.8)
		_sfx.play("deny")
		return
	if region.is_heart and heart_claims_needed() > 0:
		_hud.show_banner("THE HEART IS SEALED", "Hold %d more regions to break the seal." % heart_claims_needed(), SpaceHud.RED, 2.0)
		_sfx.play("deny")
		return
	claim = Claim.new(region.id, region.claim_seconds, tuning)
	claim.speed_scale = stats.claim_speed
	var dark := run.difficulty()
	var threat := tuning.threat_for(region.depth) * float(dark["threat"])
	battle.damage_scale = float(dark["damage"])
	if region.modifier == RegionData.Modifier.NEST:
		threat *= tuning.nest_credit_scale
	if region.is_heart:
		threat += 0.5
	director = WaveDirector.new(tuning, threat, _rng.randi(), _roster_depth(region), tuning.pace_for(claim.seconds_remaining()))
	kindle_spark = KindleSpark.new()
	kindle_spark.position = ship.position
	_beacon_root.add_child(kindle_spark)
	_claim_reach = _farthest_vertex_distance(region, kindle_spark.position)
	_regions.set_param(region.id, "state", float(RegionLayer.Look.CLAIMING))
	_regions.set_param(region.id, "spark_pos", kindle_spark.position)
	_regions.set_param(region.id, "claim_radius", CLAIM_LIGHT_START)
	_borders.claiming_id = region.id
	_fx.ring(kindle_spark.position, IGNITE_COLOR, 260.0, 0.6, 4.0)
	_camera.add_trauma(0.25)
	_sfx.play("kindle")
	if region.is_heart:
		_awaken_heart(region)
	else:
		var seconds := roundi(claim.seconds_remaining())
		_hud.show_banner("KINDLED", "%s  ·  hold the light for %ds" % [region.name, seconds], SpaceHud.GOLD, 1.8)
	print("SpaceGame: kindled %s (depth %d, %ds)" % [region.name, region.depth, roundi(claim.seconds_remaining())])


func _awaken_heart(region: RegionData) -> void:
	heart_boss = battle.spawn("heart", false, region.anchor, (1.0 + (director.threat - 1.0) * 0.5) * float(run.difficulty()["health"]))
	heart_boss.shielded = true
	_camera.add_trauma(0.6)
	_sfx.play("elite")
	_hud.show_banner("THE HEART AWAKENS", "Hold the light to break its shell, then burn it out.", SpaceHud.RED, 3.0)


func _update_claim(dt: float) -> void:
	claim.speed_scale = stats.claim_speed
	claim.update(dt, ship.alive and _ship_region == claim.region_id)
	if heart_boss != null:
		# The heart's region can't ignite while it beats.
		if claim.state == Claim.State.COMPLETE:
			claim.state = Claim.State.ACTIVE
			claim.progress = 0.99
		heart_boss.shielded = claim.progress < HEART_SHIELD_UNTIL
	if claim.state == Claim.State.COMPLETE:
		_begin_ignition()
		return
	if claim.state == Claim.State.FAILED:
		_fail_claim()
		return
	kindle_spark.progress = claim.progress
	_regions.set_param(claim.region_id, "claim_radius", CLAIM_LIGHT_START + _claim_reach * claim.progress)
	var alarm := 0.0
	if claim.state == Claim.State.DRAINING:
		alarm = 0.6 + 0.4 * sin(_elapsed * 10.0)
		if _elapsed - _last_warning > 0.5:
			_last_warning = _elapsed
			_sfx.play("warn", -6.0)
	elif claim.state == Claim.State.PAUSED:
		alarm = 0.35
	_regions.set_param(claim.region_id, "alarm", alarm)
	_borders.alarm = alarm
	if heart_boss != null and not heart_boss.shielded:
		return  # The shell is broken: only the duel with the heart is left.
	for request in director.update(dt, claim.progress, battle.enemies.size(), battle.count_kind("snuffer")):
		_spawn_request(request)


## How far out a region counts: its depth, and one more for the heart.
func _ring(region: RegionData) -> int:
	return region.depth + (1 if region.is_heart else 0)


## Which ring's Gloom a region sends: darker levels bring tougher kinds sooner.
func _roster_depth(region: RegionData) -> int:
	return _ring(region) + int(run.difficulty()["roster"])


## The deepest region held so far (home is 0).
func _deepest_claimed() -> int:
	var deepest := 0
	for region in sector.regions:
		if region.claimed:
			deepest = maxi(deepest, region.depth)
	return deepest


func _spawn_request(request: Dictionary) -> void:
	var region := sector.get_region(claim.region_id)
	var kind: String = request["kind"]
	var count: int = request["count"]
	var elite: bool = request["elite"]
	var health := tuning.health_scale(_ring(region)) * float(run.difficulty()["health"])
	var origin := _dark_spawn_point(region)
	for i in count:
		battle.spawn(kind, elite, origin + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, 26.0 * sqrt(count)), health)
	_fx.burst(origin, GloomEnemy.GLOW_COLOR, 10 + count * 2, 40.0, 160.0, 0.6, 2.0)
	if request.get("climax", false):
		_hud.show_banner("AN ELITE SNUFFER HUNTS YOUR SPARK" if elite else "A SNUFFER HUNTS YOUR SPARK", "Stop it before it reaches the light.", SpaceHud.VIOLET, 2.4)
		_sfx.play("elite")
		_camera.add_trauma(0.3)


## A point just outside the region, past an edge that faces the dark. The Gloom
## comes out of unclaimed space, never out of your own light.
func _dark_spawn_point(region: RegionData) -> Vector2:
	var edges: Array[int] = []
	var weights: Array[float] = []
	var total := 0.0
	for k in region.polygon.size():
		var neighbor := sector.get_region(region.edge_neighbors[k])
		if neighbor != null and neighbor.claimed:
			continue
		edges.append(k)
		weights.append(region.edge_length(k))
		total += weights[-1]
	if edges.is_empty():
		for k in region.polygon.size():
			edges.append(k)
			weights.append(region.edge_length(k))
			total += weights[-1]
	var point := region.anchor
	for attempt in 5:
		var roll := _rng.randf() * total
		var chosen := edges[-1]
		for i in edges.size():
			roll -= weights[i]
			if roll <= 0.0:
				chosen = edges[i]
				break
		var a := region.polygon[chosen]
		var b := region.polygon[(chosen + 1) % region.polygon.size()]
		point = a.lerp(b, _rng.randf_range(0.1, 0.9)) + region.edge_outward_normal(chosen) * _rng.randf_range(70.0, 150.0)
		if point.distance_to(ship.position) > SPAWN_SAFE_DISTANCE:
			break
	return point


func _begin_ignition() -> void:
	var region := sector.get_region(claim.region_id)
	var claim_sparks := claim.sparks_collected
	var origin := ship.position if ship.alive else kindle_spark.position
	region.claimed = true
	region.beacon = kindle_spark.position
	run.regions_claimed += 1
	_ignition = {
		"region_id": region.id,
		"origin": origin,
		"radius": 0.0,
		"reach": _farthest_vertex_distance(region, origin) + 160.0,
	}
	_regions.set_param(region.id, "ignite_pos", origin)
	_regions.set_param(region.id, "ignite_radius", 0.0)
	_regions.set_param(region.id, "alarm", 0.0)
	_clear_claim_objects()
	if region.modifier == RegionData.Modifier.RICH:
		_pickups.drop(origin, tuning.rich_bonus_sparks)
	_pickups.pull_all()
	_hitstop_left = HITSTOP_SECONDS
	_camera.add_trauma(0.7)
	_camera.punch(0.08)
	_fx.ring(origin, IGNITE_COLOR, 420.0, 0.7, 8.0)
	_fx.burst(origin, IGNITE_COLOR, 60, 120.0, 620.0, 0.9, 2.6)
	_sfx.play("ignite")
	if region.is_heart:
		_hud.show_banner("THE HEART BURNS OUT", "The sector is relit, and it's yours for good.", SpaceHud.GOLD, 2.6)
	else:
		_hud.show_banner("REGION IGNITED", region.name, SpaceHud.GOLD, 2.0)
	if _shot_on_ignite:
		ScreenCapture.request(0.3)
	print("SpaceGame: ignited %s (%d/%d claimed, %d sparks this claim, %d total)" % [region.name, sector.claimed_count(), sector.regions.size(), claim_sparks, run.sparks])


## The ignition wave rolls out from the ship, burning away every Gloom
## creature it touches. When it reaches the far edge the region is yours.
func _update_ignition(dt: float) -> void:
	var region_id: int = _ignition["region_id"]
	var origin: Vector2 = _ignition["origin"]
	var reach: float = _ignition["reach"]
	var radius: float = _ignition["radius"] + reach / IGNITION_SECONDS * dt
	_ignition["radius"] = radius
	_regions.set_param(region_id, "ignite_radius", radius)
	for enemy in battle.enemies:
		if not enemy.dead and enemy.position.distance_to(origin) < radius:
			battle.burn(enemy)
	if radius >= reach:
		for enemy in battle.enemies:
			battle.burn(enemy)
		battle.remove_dead()
		_finish_ignition(sector.get_region(region_id))
	battle.remove_dead()


func _finish_ignition(region: RegionData) -> void:
	_regions.set_param(region.id, "ignite_radius", -1.0)
	_ignition = {}
	_regions.refresh(sector)
	_refresh_territory()
	if region.is_heart:
		_sector_relit(region)
		return
	_offer_loot(region)
	_announce_awake_planets()
	if heart_claims_needed() == 0 and not sector.heart().claimed and sector.is_frontier(sector.heart_id):
		_hud.show_banner("THE HEART IS EXPOSED", "Burn it out to conquer the sector.", SpaceHud.RED, 2.4)


## The heart burned out: the sector is conquered for good. A loot pick, then
## the choice to push on or go home.
func _sector_relit(region: RegionData) -> void:
	run.sectors_conquered.append(run.sector_id)
	if run.sector_id >= 0:
		conquered[run.sector_id] = true
	sector_relit.emit(run.sector_id)
	print("SpaceGame: relit %s" % (run.sector_name if not run.sector_name.is_empty() else "the sector"))
	_choice_pending = true
	_set_loot_odds(LootPicks.quality_for(region) + 1)
	_loot_choices = LootPicks.roll(_rng, run.loadout, run.unlocked, _loot_quality, run.regions_claimed, 3, _loot_gear)
	if _autopilot != null:
		_on_loot_picked(_loot_choices[0])
	else:
		_loot.open(_loot_choices, _reroll_label(), _can_reroll())


## Adjacent dark sectors to push on into (easiest first), or home. A practice
## run with no galaxy just goes home.
func _offer_next_sectors() -> void:
	if galaxy == null:
		_end_run(RunState.Outcome.VICTORY)
		return
	var options: Array[Dictionary] = []
	if galaxy != null and run.sector_id >= 0:
		for id in galaxy.dark_neighbors(run.sector_id, conquered).slice(0, 3):
			var target := galaxy.get_sector(id)
			var system := galaxy.system_of(id)
			options.append({"id": id, "name": target.name, "system": system.name, "tier": target.tier, "color": system.color, "blurb": system.blurb})
	if _autopilot != null:
		var push := not options.is_empty() and run.sectors_conquered.size() < 2
		_on_sector_chosen(int(options[0]["id"]) if push else SectorChoiceScreen.HOME)
		return
	_choice.open(options, roundi(run.sparks * (1.0 + RunState.VICTORY_BONUS)))


func _on_sector_chosen(id: int) -> void:
	_choice.close()
	if id == SectorChoiceScreen.HOME or galaxy == null:
		_end_run(RunState.Outcome.VICTORY)
		return
	run.enter_sector(galaxy, id)
	start_sector(run.sector_seed)
	var system := galaxy.system_of(id)
	_hud.show_banner("INTO %s" % run.sector_name.to_upper(), "%s  ·  tier %d  ·  %s" % [system.name, run.sector_tier, system.blurb], system.color, 3.5)
	print("SpaceGame: pushing on into %s (tier %d)" % [run.sector_name, run.sector_tier])


## Banners for what a conquest unlocked (GameFlow passes relight_sector's news).
func show_conquest_news(news: Dictionary) -> void:
	if bool(news.get("galaxy", false)):
		_hud.show_banner("THE GALAXY IS LIT", "Every sector is yours. The darkness levels still go deeper.", SpaceHud.GOLD, 5.0)
	elif not String(news.get("system", "")).is_empty():
		_hud.show_banner("%s FALLS" % String(news["system"]).to_upper(), "The whole system is yours: +%d%% rewards from now on." % roundi(MetaProgress.SYSTEM_REWARD_BONUS * 100.0), SpaceHud.GOLD, 4.0)
	elif int(news.get("unlocked", -1)) >= 0:
		_hud.show_banner("%s UNLOCKED" % Difficulty.name_of(int(news["unlocked"])).to_upper(), "A darker level, with better rewards. Change it from the pause menu between fights.", SpaceHud.VIOLET, 4.0)


func _fail_claim(silent := false) -> void:
	var region := sector.get_region(claim.region_id)
	print("SpaceGame: claim on %s failed at %d%%" % [region.name, roundi(claim.progress * 100.0)])
	if kindle_spark != null:
		_fx.burst(kindle_spark.position, GloomEnemy.GLOW_COLOR, 30, 40.0, 260.0, 0.8, 2.0)
	if not silent:
		_hud.show_banner("THE LIGHT WENT OUT", "%s stays dark. Kindle it again when you're ready." % region.name, SpaceHud.RED, 2.6)
		_sfx.play("snuff")
	_clear_claim()
	battle.dissolve_all()
	heart_boss = null


## Ends any claim in progress and puts the region back to how it looked.
func _clear_claim() -> void:
	if claim != null:
		_regions.set_param(claim.region_id, "alarm", 0.0)
	_clear_claim_objects()
	_pickups.clear()
	if sector != null:
		_regions.refresh(sector)


func _clear_claim_objects() -> void:
	claim = null
	director = null
	if kindle_spark != null:
		kindle_spark.queue_free()
		kindle_spark = null
	_borders.claiming_id = -1
	_borders.alarm = 0.0


func _farthest_vertex_distance(region: RegionData, from: Vector2) -> float:
	var farthest := 0.0
	for point in region.polygon:
		farthest = maxf(farthest, point.distance_to(from))
	return farthest


# --- Run end -------------------------------------------------------------------

func _end_run(outcome: RunState.Outcome) -> void:
	if run.is_over():
		return
	run.outcome = outcome
	_end_left = RUN_END_DELAY
	match outcome:
		RunState.Outcome.VICTORY:
			_hud.show_banner("RETURNING HOME", "%d sparks banked, plus the victory bonus." % run.sparks, SpaceHud.GOLD, RUN_END_DELAY)
		RunState.Outcome.DEFEAT:
			_hud.show_banner("THE LIGHT IS LOST", "%d sparks banked. The dark keeps the rest." % run.sparks, SpaceHud.RED, RUN_END_DELAY)
		RunState.Outcome.ABANDONED:
			_hud.show_banner("RUN ABANDONED", "%d sparks banked." % run.sparks, SpaceHud.DIM, RUN_END_DELAY)
	print("SpaceGame: run over (%s) with %d sparks, %d regions, %d kills" % [RunState.Outcome.keys()[outcome], run.sparks, run.regions_claimed, run.kills])


# --- Kills, pickups, point defense -----------------------------------------------

## Drops sparks during a claim (more in a nest) and finishes the heart's region
## when the heart dies.
func _on_enemy_killed(enemy: GloomEnemy) -> void:
	run.kills += 1
	if claim != null and _rng.randf() < enemy.spark_chance:
		var drops := enemy.spark_count
		if sector.get_region(claim.region_id).modifier == RegionData.Modifier.NEST:
			drops = ceili(drops * tuning.nest_drop_scale)
		_pickups.drop(enemy.position, drops)
	if enemy == heart_boss:
		heart_boss = null
		_fx.ring(enemy.position, GloomEnemy.HEART_COLOR, 900.0, 1.0, 10.0)
		_camera.add_trauma(1.0)
		if claim != null:
			claim.progress = 1.0
			claim.state = Claim.State.COMPLETE


## Point Defense zaps the nearest incoming shot every so often.
func _update_point_defense(dt: float) -> void:
	if stats.point_defense <= 0.0 or not ship.alive:
		return
	_point_defense_cooldown -= dt
	if _point_defense_cooldown > 0.0:
		return
	var best: Projectiles.Bullet = null
	var best_distance := POINT_DEFENSE_RANGE * POINT_DEFENSE_RANGE
	for bullet in _projectiles.bullets:
		if bullet.friendly or bullet.life <= 0.0:
			continue
		var distance := bullet.position.distance_squared_to(ship.position)
		if distance < best_distance:
			best_distance = distance
			best = bullet
	if best == null:
		_point_defense_cooldown = 0.0
		return
	best.life = 0.0
	_point_defense_cooldown = 1.0 / stats.point_defense
	_fx.zap(ship.position, best.position, SHIELD_HIT_COLOR)
	_sfx.play("zap", -10.0)


## Sparks shave time off the claim and bank as currency. Collecting several
## in a row raises the chime's pitch.
func _update_pickups(dt: float) -> void:
	_spark_streak_left -= dt
	if _spark_streak_left <= 0.0:
		_spark_streak = 0
	var collected: int = _pickups.update(dt, ship.position, ship.alive, stats.magnet).get(Pickups.SPARK, 0)
	if collected == 0:
		return
	run.add_sparks(collected)
	_spark_streak += collected
	_spark_streak_left = SPARK_STREAK_WINDOW
	_sfx.play("spark", -8.0, 1.0 + minf(_spark_streak, 16) * 0.035)
	if claim != null:
		for i in collected:
			claim.add_spark()
		_hud.flash_claim()


# --- Ship ----------------------------------------------------------------------

func _respawn_ship() -> void:
	var home := sector.home()
	ship.reset_at(home.beacon)
	ship.grant_iframes(RESPAWN_IFRAMES)
	_fx.ring(home.beacon, IGNITE_COLOR, 200.0, 0.5, 4.0)


func _on_ship_dashed(origin: Vector2, direction: Vector2) -> void:
	_fx.burst(origin, SHIELD_HIT_COLOR, 14, 30.0, 160.0, 0.35, 2.0, (-direction).angle(), 0.8)
	_sfx.play("dash", -6.0)


func _on_ship_damaged(_amount: float, hull_hit: bool) -> void:
	_camera.add_trauma(0.35 if hull_hit else 0.2)
	_fx.burst(ship.position, HULL_HIT_COLOR if hull_hit else SHIELD_HIT_COLOR, 10, 60.0, 260.0, 0.35, 2.0)
	_sfx.play("hurt", -4.0)


func _on_ship_destroyed() -> void:
	_fx.burst(ship.position, IGNITE_COLOR, 70, 80.0, 520.0, 1.0, 2.6)
	_fx.ring(ship.position, IGNITE_COLOR, 380.0, 0.7, 6.0)
	_camera.add_trauma(0.9)
	_sfx.play("death")
	print("SpaceGame: ship destroyed")
	var lost_claim := ""
	if claim != null:
		lost_claim = sector.get_region(claim.region_id).name
		_fail_claim(true)
	if run.revives_left <= 0:
		_end_run(RunState.Outcome.DEFEAT)
		return
	run.revives_left -= 1
	_respawn_left = tuning.respawn_delay
	var subtitle := "Rekindling at home. %d spare spark%s left." % [run.revives_left, "" if run.revives_left == 1 else "s"]
	if not lost_claim.is_empty():
		subtitle = "The claim on %s failed. %s" % [lost_claim, subtitle]
	_hud.show_banner("SPARE SPARK USED", subtitle, SpaceHud.ORANGE, tuning.respawn_delay + 0.5)


# --- HUD -----------------------------------------------------------------------

func _update_hud() -> void:
	_hud.set_vitals(ship.shield / maxf(stats.max_shield, 1.0), ship.hull / maxf(stats.max_hull, 1.0), ship.dash_readiness())
	_hud.set_sparks(run.sparks)
	_hud.set_resources(run.resources)
	_hud.set_ammo(weapons.ammo_status())
	if claim != null:
		var region := sector.get_region(claim.region_id)
		var status := "HOLD THE LIGHT  ·  ~%ds" % ceili(claim.seconds_remaining())
		var color := SpaceHud.GOLD
		if heart_boss != null and not heart_boss.shielded:
			status = "THE SHELL IS BROKEN  ·  DESTROY THE HEART"
			color = SpaceHud.RED
		elif claim.state == Claim.State.PAUSED:
			status = "OUTSIDE THE REGION  ·  PAUSED  ·  draining in %.1fs" % maxf(tuning.claim_grace_seconds - claim.outside_time, 0.0)
			color = SpaceHud.ORANGE
		elif claim.state == Claim.State.DRAINING:
			status = "THE LIGHT IS FADING  ·  GET BACK INSIDE"
			color = SpaceHud.RED
		if claim.spark_seconds > 0.05 and color == SpaceHud.GOLD:
			status += "  ·  sparks -%.1fs" % claim.spark_seconds
		var title := "THE HEART" if region.is_heart else region.name.to_upper()
		_hud.set_claim(title, claim.progress, status, color, tuning.elite_threshold)
	else:
		_hud.hide_claim()
	_hud.set_prompt(_prompt_text())
	_hud.set_indicators(_indicators())
	if _debug_visible:
		_hud.set_debug(_debug_text())


func _prompt_text() -> String:
	if _map_open:
		return "SECTOR MAP  ·  Tab to close"
	if _paused:
		return "PAUSED  ·  Esc to resume  ·  Q to abandon the run  ·  [ ] darkness: %s" % Difficulty.name_of(run.darkness)
	if not ship.alive or claim != null or not _ignition.is_empty() or run.is_over():
		return ""
	var region := sector.get_region(_ship_region)
	if region == null:
		return "The void past the edge of the sector."
	if _landable != null:
		return "[E] Land on %s  ·  %s world  ·  %s" % [_landable.name, _landable.type_name(), PlanetData.RESOURCE_NAMES[_landable.resource()]]
	if region.claimed:
		return "%s  ·  your light. Shields recharge here.  ·  [F] Refit ship" % region.name
	var name := "THE HEART" if region.is_heart else region.name
	if region.is_heart and heart_claims_needed() > 0:
		return "THE HEART  ·  sealed. Hold %d more regions to break the seal." % heart_claims_needed()
	if sector.is_frontier(region.id):
		var seconds := roundi(region.claim_seconds / (tuning.claim_speed_multiplier * stats.claim_speed))
		var prompt := "[E] Kindle %s  ·  hold ~%ds  ·  threat: %s" % [name, seconds, _threat_label(region)]
		if region.modifier != RegionData.Modifier.NONE:
			prompt += "\n%s: %s" % [region.modifier_name(), RegionData.MODIFIER_HINTS[region.modifier]]
		var newcomers := WaveDirector.kinds_new_at(_roster_depth(region), _deepest_claimed() + int(run.difficulty()["roster"]))
		if not newcomers.is_empty():
			var names: Array[String] = []
			for kind in newcomers:
				names.append(String(GloomEnemy.KINDS[kind]["name"]))
			prompt += "\nDeeper in the dark: %s appear here" % ", ".join(names)
		return prompt
	return "%s  ·  too deep in the dark. Claim a region that borders your light first." % name


## Territory count and the run objective in the top-right corner.
func _refresh_territory() -> void:
	var header := "TERRITORY  %d / %d  ·  %s" % [sector.claimed_count(), sector.regions.size(), Difficulty.name_of(run.darkness).to_upper()]
	if not run.sector_name.is_empty():
		header = "%s  ·  %s" % [run.sector_name.to_upper(), header]
	_hud.set_header(header)
	_borders.heart_claims_needed = heart_claims_needed()
	var heart := sector.heart()
	if heart == null or heart.claimed:
		_hud.set_objective("")
	elif heart_claims_needed() > 0:
		_hud.set_objective("THE HEART: sealed  ·  hold %d more" % heart_claims_needed())
	else:
		var steps := sector.steps_to_heart()
		_hud.set_objective("THE HEART: exposed  ·  %d claim%s away" % [steps, "" if steps == 1 else "s"])


## Darkness closes in while the ship is inside an unlit nebula.
func _update_veil(delta: float) -> void:
	var region := sector.get_region(_ship_region)
	var in_nebula := region != null and region.modifier == RegionData.Modifier.NEBULA and not region.claimed
	_veil.target_strength = 1.0 if in_nebula and ship.alive and not _map_open else 0.0
	_veil.update_veil(delta, get_viewport().get_canvas_transform() * ship.position, _camera.zoom.x)


func _threat_label(region: RegionData) -> String:
	match region.depth:
		0, 1:
			return "low"
		2:
			return "medium"
		3:
			return "high"
	return "severe"


func _indicators() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var to_screen := get_viewport().get_canvas_transform()
	if kindle_spark != null:
		list.append({"position": to_screen * kindle_spark.position, "color": SpaceHud.GOLD, "size": 14.0})
	for enemy in battle.enemies:
		if enemy.dead:
			continue
		if enemy.kind == "snuffer":
			list.append({"position": to_screen * enemy.position, "color": SpaceHud.VIOLET, "size": 16.0 if enemy.elite else 11.0})
		elif enemy.kind == "heart":
			list.append({"position": to_screen * enemy.position, "color": SpaceHud.RED, "size": 20.0})
	for planet in sector.planets:
		if not planet.kindled and planet.is_awake(sector):
			list.append({"position": to_screen * planet.position, "color": planet.info()["accent"], "size": 13.0})
	if claim == null and ship.alive and not _map_open:
		var frontier := nearest_frontier(ship.position)
		if frontier != null and frontier.id != _ship_region:
			list.append({"position": to_screen * frontier.anchor, "color": Color(1.0, 0.78, 0.4, 0.55), "size": 10.0})
	return list


func _debug_text() -> String:
	var text := "FPS %d  ·  enemies %d  ·  bullets %d  ·  pickups %d\nseed %d  ·  claim speed x%.1f  ·  god mode %s\nDPS %.1f  ·  power %d/%d  ·  kills %d" % [
		Engine.get_frames_per_second(), battle.enemies.size(), _projectiles.bullets.size(),
		_pickups.count(), sector.sector_seed, tuning.claim_speed_multiplier, "on" if battle.god_mode else "off",
		stats.total_dps(), stats.power_used, stats.power_capacity, run.kills,
	]
	if director != null:
		text += "\ncredits %.1f  ·  threat x%.2f" % [director.credits, director.threat]
	return text


# --- Input and setup -------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if _loot.visible or _choice.visible:
		return
	if event.is_action_pressed("refit"):
		if _refit.visible:
			_refit.close()
		else:
			_open_refit()
		return
	if _refit.visible:
		return
	if event.is_action_pressed("map"):
		_set_map_open(not _map_open)
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ESCAPE:
			_paused = not _paused
			if _paused:
				_hud.show_banner("PAUSED", "Esc to resume  ·  Q to abandon the run", SpaceHud.DIM, 3600.0)
			else:
				_hud.hide_banner()
		KEY_Q:
			if _paused:
				_paused = false
				_end_run(RunState.Outcome.ABANDONED)
		KEY_BRACKETLEFT, KEY_MINUS:
			if _paused:
				change_darkness(-1)
		KEY_BRACKETRIGHT, KEY_EQUAL:
			if _paused:
				change_darkness(1)
		KEY_F1:
			_debug_visible = not _debug_visible
			if not _debug_visible:
				_hud.set_debug("")
		KEY_F2:
			_speed_index = (_speed_index + 1) % SPEED_STEPS.size()
			tuning.claim_speed_multiplier = SPEED_STEPS[_speed_index]
			_hud.show_banner("CLAIM SPEED x%.0f" % tuning.claim_speed_multiplier, "Debug: F2 cycles 1x / 3x / 10x", SpaceHud.DIM, 1.2)
		KEY_F3:
			battle.god_mode = not battle.god_mode
			_hud.show_banner("GOD MODE %s" % ("ON" if battle.god_mode else "OFF"), "", SpaceHud.DIM, 1.2)
		KEY_F4:
			start_sector(0)
			_hud.show_banner("NEW SECTOR", "Debug: seed %d" % sector.sector_seed, SpaceHud.GOLD, 1.6)
		KEY_F5:
			_sfx.muted = not _sfx.muted
			_hud.show_banner("SOUND %s" % ("OFF" if _sfx.muted else "ON"), "", SpaceHud.DIM, 1.0)
		KEY_H:
			_hud.toggle_help()
		KEY_F11:
			var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)


## Steps the run's darkness up or down (from the pause menu). Only between
## fights, and only as dark as the homeworld has unlocked. Returns true if it
## changed.
func change_darkness(step: int) -> bool:
	if claim != null or not _ignition.is_empty() or run.is_over():
		_hud.show_banner("FINISH THIS FIGHT FIRST", "The darkness can only change between claims.", SpaceHud.DIM, 1.6)
		_sfx.play("deny")
		return false
	var wanted := run.darkness + step
	if not run.set_darkness(wanted):
		var why := "Relight a sector on %s to go darker." % Difficulty.name_of(run.darkness_max) if wanted > run.darkness_max else "This is as light as it gets."
		_hud.show_banner("DARKNESS: %s" % Difficulty.name_of(run.darkness).to_upper(), why, SpaceHud.DIM, 2.4)
		_sfx.play("deny")
		return false
	_refresh_territory()
	_hud.show_banner("DARKNESS: %s" % Difficulty.name_of(run.darkness).to_upper(), "%s\n%s" % [Difficulty.summary(run.darkness), Difficulty.reward_text(run.darkness)], SpaceHud.VIOLET if step > 0 else SpaceHud.CYAN, 3600.0)
	_sfx.play("kindle", -6.0)
	print("SpaceGame: darkness now %s" % Difficulty.name_of(run.darkness))
	return true


func _set_map_open(open: bool) -> void:
	_map_open = open
	_camera.map_mode = open
	_borders.map_mode = open
	var view := get_viewport_rect().size
	_camera.map_zoom = minf(view.x, view.y) / (sector.radius * 2.0 * 1.5)


## Debug: moves the ship into the first region matching a modifier name,
## "heart", or next to the first planet ("planet", which also wakes it).
func _visit(what: String) -> void:
	if what == "planet" and not sector.planets.is_empty():
		var planet := sector.planets[0]
		for region_id in planet.touching:
			sector.regions[region_id].claimed = true
		_regions.refresh(sector)
		_refresh_territory()
		ship.position = planet.position
		_camera.snap_to(planet.position)
		return
	for region in sector.regions:
		var matches := region.is_heart if what == "heart" else region.modifier_name().to_lower() == what
		if matches:
			ship.position = region.anchor
			_camera.snap_to(region.anchor)
			return


func _build_scene() -> void:
	_far_layer = CanvasLayer.new()
	_far_layer.layer = -1
	add_child(_far_layer)
	_far_stars = FarStars.new()
	_far_layer.add_child(_far_stars)

	_starfield = Starfield.new()
	add_child(_starfield)
	_regions = RegionLayer.new()
	add_child(_regions)
	_asteroid_layer = AsteroidLayer.new()
	add_child(_asteroid_layer)
	_borders = BorderLayer.new()
	add_child(_borders)
	_planets = PlanetLayer.new()
	add_child(_planets)
	_beacon_root = Node2D.new()
	add_child(_beacon_root)
	_pickups = Pickups.new()
	add_child(_pickups)
	_enemy_root = Node2D.new()
	add_child(_enemy_root)
	_projectiles = Projectiles.new()
	add_child(_projectiles)
	ship = Ship.new()
	ship.tuning = tuning
	ship.input = ShipInput.new(self)
	add_child(ship)
	_fx = FxLayer.new()
	add_child(_fx)
	_camera = GameCamera.new()
	_camera.target = ship
	add_child(_camera)
	_far_stars.camera = _camera
	_veil = NebulaVeil.new()
	add_child(_veil)
	_hud = SpaceHud.new()
	add_child(_hud)
	_loot = LootScreen.new()
	add_child(_loot)
	_refit = RefitScreen.new()
	add_child(_refit)
	_choice = SectorChoiceScreen.new()
	add_child(_choice)
	_sfx = Sfx.new()
	add_child(_sfx)
	battle = Battle.new(_enemy_root, _projectiles, _fx, _sfx, _camera, _rng)
	battle.max_alive = tuning.max_alive

	ship.dashed.connect(_on_ship_dashed)
	ship.damaged.connect(_on_ship_damaged)
	ship.destroyed.connect(_on_ship_destroyed)
	battle.enemy_killed.connect(_on_enemy_killed)
	_loot.picked.connect(_on_loot_picked)
	_loot.reroll_requested.connect(_on_loot_reroll)
	_refit.closed.connect(_on_refit_closed)
	_choice.chosen.connect(_on_sector_chosen)


## Adds the actions every mode needs at runtime, so project.godot stays untouched.
func _register_input() -> void:
	InputSetup.register()


func _parse_options() -> Dictionary:
	var options := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	return options


func _apply_options(options: Dictionary) -> void:
	if options.has("autoplay"):
		_autopilot = Autopilot.new(self)
		ship.input = _autopilot
		_camera.look_ahead_enabled = false
	battle.god_mode = options.has("god")
	_debug_visible = options.has("debug")
	if options.has("claim-speed"):
		tuning.claim_speed_multiplier = maxf(float(options["claim-speed"]), 0.1)
	if options.has("map-at"):
		_map_at = float(options["map-at"])
	_shot_on_ignite = options.has("shot-on-ignite")
	_log_fps = options.has("log-fps")


## Prints average FPS and the worst frame each second (--log-fps).
func _track_frame_time(delta: float) -> void:
	_fps_window += delta
	_fps_frames += 1
	_fps_worst = maxf(_fps_worst, delta)
	if _fps_window >= 1.0:
		print("SpaceGame: t=%.0fs fps=%.0f worst=%.1fms enemies=%d" % [_elapsed, _fps_frames / _fps_window, _fps_worst * 1000.0, battle.enemies.size()])
		_fps_window = 0.0
		_fps_frames = 0
		_fps_worst = 0.0
