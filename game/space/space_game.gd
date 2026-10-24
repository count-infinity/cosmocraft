class_name SpaceGame
extends Node2D
## Milestone 0, the Claim. One sector of dark regions: fly into one that
## borders your territory, kindle a spark, and hold your ground until the
## region ignites.
##
## Command-line options go after `--`:
##   --seed=N                      play a specific sector
##   --autoplay                    let the autopilot fly
##   --god                         ignore damage
##   --debug                       show the debug overlay
##   --claim-speed=X               multiply claim speed
##   --capture=DIR --shots=3,20    save screenshots at those times, then quit
##   --shot-on-ignite              with --capture, also grab each ignition
##   --log-fps                     print frame timing every second
##   --map-at=T                    open the sector map at time T

const BACKGROUND := Color(0.012, 0.012, 0.03)
const RESPAWN_IFRAMES := 1.5
const HITSTOP_SECONDS := 0.12
const HITSTOP_SCALE := 0.05
const IGNITION_SECONDS := 0.8
const CLAIM_LIGHT_START := 40.0
const SPAWN_SAFE_DISTANCE := 300.0
const PLAYER_BULLET_LIFE := 0.9
const ENEMY_BULLET_LIFE := 4.0
const SPEED_STEPS: Array[float] = [1.0, 3.0, 10.0]
const IGNITE_COLOR := Color(2.6, 2.0, 1.0)
const SNUFF_COLOR := Color(2.6, 0.4, 1.4)
const SHIELD_HIT_COLOR := Color(0.6, 1.4, 2.4)
const HULL_HIT_COLOR := Color(2.4, 0.8, 0.3)

@export var tuning: SpaceTuning
## 0 picks a fresh random sector every run.
@export var sector_seed := 0

var sector: SectorData
var ship: Ship
var claim: Claim
var director: WaveDirector
var kindle_spark: KindleSpark
var enemies: Array[GloomEnemy] = []

var _rng := RandomNumberGenerator.new()
var _grid := SpatialGrid.new(96.0)
var _ship_region := -1
var _claim_reach := 0.0
var _hitstop_left := 0.0
var _respawn_left := 0.0
var _ignition: Dictionary = {}
var _paused := false
var _map_open := false
var _god_mode := false
var _speed_index := 0
var _debug_visible := false
var _last_warning := 0.0
var _elapsed := 0.0
var _capture_dir := ""
var _capture_times: Array[float] = []
var _capturing := false
var _map_at := -1.0
var _shot_on_ignite := false
var _log_fps := false
var _fps_window := 0.0
var _fps_frames := 0
var _fps_worst := 0.0

var _camera: GameCamera
var _starfield: Starfield
var _far_stars: FarStars
var _regions: RegionLayer
var _borders: BorderLayer
var _beacon_root: Node2D
var _pickups: Pickups
var _enemy_root: Node2D
var _projectiles: Projectiles
var _fx: FxLayer
var _hud: SpaceHud
var _sfx: Sfx
var _autopilot: Autopilot


func _ready() -> void:
	if tuning == null:
		tuning = SpaceTuning.new()
	get_tree().root.use_hdr_2d = true
	RenderingServer.set_default_clear_color(BACKGROUND)
	_register_input()
	_build_scene()
	var options := _parse_options()
	_apply_options(options)
	start_sector(int(options.get("seed", sector_seed)))
	_hud.show_banner("HOLD THE LIGHT", "Fly into a region that borders your light and press E to kindle it.", SpaceHud.GOLD, 4.0)


func start_sector(seed_value: int) -> void:
	if seed_value == 0:
		seed_value = randi_range(1, 999999)
	_clear_claim()
	for enemy in enemies:
		enemy.queue_free()
	enemies.clear()
	_projectiles.clear()
	_pickups.clear()
	_ignition = {}
	_rng.seed = seed_value
	sector = SectorGenerator.generate(seed_value, tuning)
	_regions.build(sector)
	_borders.sector = sector
	_starfield.build(sector.radius, seed_value)
	_respawn_ship()
	_camera.snap_to(ship.position)
	_hud.set_territory(sector.claimed_count(), sector.regions.size())
	print("SpaceGame: sector seed %d with %d regions" % [seed_value, sector.regions.size()])


func nearest_frontier(from: Vector2) -> RegionData:
	var best: RegionData = null
	var best_distance := INF
	for region in sector.regions:
		if not sector.is_frontier(region.id):
			continue
		var distance := from.distance_squared_to(region.centroid)
		if distance < best_distance:
			best_distance = distance
			best = region
	return best


## Closest live enemy, treating Snuffers as closer than they are.
func nearest_enemy(from: Vector2) -> GloomEnemy:
	var best: GloomEnemy = null
	var best_score := INF
	for enemy in enemies:
		if enemy.dead:
			continue
		var score := from.distance_squared_to(enemy.position)
		if enemy.kind == "snuffer":
			score *= 0.25
		if score < best_score:
			best_score = score
			best = enemy
	return best


func spawn_enemy_shot(origin: Vector2, velocity: Vector2, damage: float) -> void:
	_projectiles.spawn(origin, velocity, damage, 6.0, ENEMY_BULLET_LIFE, false)
	_sfx.play("spit", -12.0)


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
	_process_capture()
	if _map_at >= 0.0 and _elapsed >= _map_at:
		_map_at = -1.0
		_set_map_open(true)
	if not (_map_open or _paused):
		var dt := delta
		if _hitstop_left > 0.0:
			_hitstop_left -= delta
			dt *= HITSTOP_SCALE
		_step(dt)
	_borders.zoom = _camera.zoom.x
	_update_hud()


func _step(dt: float) -> void:
	if _autopilot != null:
		_autopilot.think(dt)
	if ship.alive:
		ship.update(dt)
		_keep_inside_sector(dt)
		if ship.input.consume_kindle():
			_try_kindle()
	else:
		_respawn_left -= dt
		if _respawn_left <= 0.0:
			_respawn_ship()
	_ship_region = sector.region_at(ship.position)
	if claim != null:
		_update_claim(dt)
	_update_enemies(dt)
	_update_projectiles(dt)
	_update_pickups(dt)
	if ship.alive and _ship_region >= 0 and sector.regions[_ship_region].claimed:
		ship.regen(dt)
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


# --- Claiming ----------------------------------------------------------------

func _try_kindle() -> void:
	if claim != null or not _ignition.is_empty():
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
	claim = Claim.new(region.id, region.claim_seconds, tuning)
	var threat := 1.0 + tuning.threat_per_depth * maxi(region.depth - 1, 0)
	director = WaveDirector.new(tuning, threat, _rng.randi())
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
	var seconds := roundi(region.claim_seconds / tuning.claim_speed_multiplier)
	print("SpaceGame: kindled %s (depth %d, %ds)" % [region.name, region.depth, seconds])
	_hud.show_banner("KINDLED", "%s  ·  hold the light for %ds" % [region.name, seconds], SpaceHud.GOLD, 1.8)


func _update_claim(dt: float) -> void:
	claim.update(dt, ship.alive and _ship_region == claim.region_id)
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
	var snuffers := 0
	for enemy in enemies:
		if enemy.kind == "snuffer":
			snuffers += 1
	for request in director.update(dt, claim.progress, enemies.size(), snuffers):
		_spawn_request(request)


func _spawn_request(request: Dictionary) -> void:
	var region := sector.get_region(claim.region_id)
	var kind: String = request["kind"]
	var count: int = request["count"]
	var elite: bool = request["elite"]
	var origin := _dark_spawn_point(region)
	for i in count:
		var enemy := GloomEnemy.new()
		enemy.setup(kind, elite, _rng)
		enemy.position = origin + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.0, 26.0 * sqrt(count))
		_enemy_root.add_child(enemy)
		enemies.append(enemy)
	_fx.burst(origin, GloomEnemy.GLOW_COLOR, 10 + count * 2, 40.0, 160.0, 0.6, 2.0)
	if elite:
		_hud.show_banner("A SNUFFER HUNTS YOUR SPARK", "Stop it before it reaches the light.", SpaceHud.VIOLET, 2.4)
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
	var point := region.centroid
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
	var claim_snuffs := claim.snuffs
	var origin := ship.position if ship.alive else kindle_spark.position
	region.claimed = true
	region.beacon = kindle_spark.position
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
	_pickups.pull_all()
	_hitstop_left = HITSTOP_SECONDS
	_camera.add_trauma(0.7)
	_camera.punch(0.08)
	_fx.ring(origin, IGNITE_COLOR, 420.0, 0.7, 8.0)
	_fx.burst(origin, IGNITE_COLOR, 60, 120.0, 620.0, 0.9, 2.6)
	_sfx.play("ignite")
	_hud.show_banner("REGION IGNITED", region.name, SpaceHud.GOLD, 2.6)
	if _shot_on_ignite and not _capture_dir.is_empty():
		_capture_times.append(_elapsed + 0.3)
		_capture_times.sort()
	print("SpaceGame: ignited %s (%d/%d claimed, %d sparks, %d snuffs)" % [region.name, sector.claimed_count(), sector.regions.size(), claim_sparks, claim_snuffs])


## The ignition wave rolls out from the ship, burning away every Gloom
## creature it touches. When it reaches the far edge the region is yours.
func _update_ignition(dt: float) -> void:
	var region_id: int = _ignition["region_id"]
	var origin: Vector2 = _ignition["origin"]
	var reach: float = _ignition["reach"]
	var radius: float = _ignition["radius"] + reach / IGNITION_SECONDS * dt
	_ignition["radius"] = radius
	_regions.set_param(region_id, "ignite_radius", radius)
	for enemy in enemies:
		if not enemy.dead and enemy.position.distance_to(origin) < radius:
			_burn(enemy)
	if radius >= reach:
		for enemy in enemies:
			_burn(enemy)
		_regions.set_param(region_id, "ignite_radius", -1.0)
		_ignition = {}
		_regions.refresh(sector)
		_hud.set_territory(sector.claimed_count(), sector.regions.size())
		if sector.claimed_count() == sector.regions.size():
			_hud.show_banner("SECTOR RELIT", "Every region is yours. Press F4 for a new sector.", SpaceHud.GOLD, 6.0)
	_remove_dead_enemies()


func _fail_claim(silent := false) -> void:
	var region := sector.get_region(claim.region_id)
	print("SpaceGame: claim on %s failed at %d%%" % [region.name, roundi(claim.progress * 100.0)])
	if kindle_spark != null:
		_fx.burst(kindle_spark.position, GloomEnemy.GLOW_COLOR, 30, 40.0, 260.0, 0.8, 2.0)
	if not silent:
		_hud.show_banner("THE LIGHT WENT OUT", "%s stays dark. Kindle it again when you're ready." % region.name, SpaceHud.RED, 2.6)
		_sfx.play("snuff")
	_clear_claim()
	for enemy in enemies:
		_dissolve(enemy)
	_remove_dead_enemies()


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


# --- Enemies, bullets, pickups ---------------------------------------------------

func _update_enemies(dt: float) -> void:
	_rebuild_grid()
	for enemy in enemies:
		if enemy.dead:
			continue
		enemy.update(dt, self)
		_separate(enemy, dt)
		if ship.alive and not enemy.dead and enemy.age > GloomEnemy.SPAWN_IN_TIME:
			var reach := enemy.radius + Ship.RADIUS
			if enemy.position.distance_squared_to(ship.position) < reach * reach:
				if not _god_mode and ship.take_damage(enemy.contact_damage):
					var push := (ship.position - enemy.position).normalized()
					ship.velocity += push * 380.0
					enemy.velocity -= push * 260.0
	_remove_dead_enemies()


func _rebuild_grid() -> void:
	_grid.clear()
	for enemy in enemies:
		if not enemy.dead:
			_grid.insert(enemy, enemy.position)


## Pushes overlapping enemies apart so swarms spread out instead of stacking.
func _separate(enemy: GloomEnemy, dt: float) -> void:
	var push := Vector2.ZERO
	for item: GloomEnemy in _grid.query(enemy.position, enemy.radius + 40.0):
		if item == enemy or item.dead:
			continue
		var offset := enemy.position - item.position
		var min_distance := enemy.radius + item.radius + 2.0
		var distance_squared := offset.length_squared()
		if distance_squared < min_distance * min_distance and distance_squared > 0.0001:
			var distance := sqrt(distance_squared)
			push += offset / distance * (min_distance - distance)
	enemy.position += push * minf(dt * 10.0, 0.5)


func _remove_dead_enemies() -> void:
	var alive: Array[GloomEnemy] = []
	for enemy in enemies:
		if enemy.dead:
			enemy.queue_free()
		else:
			alive.append(enemy)
	enemies = alive


func _update_projectiles(dt: float) -> void:
	_projectiles.update(dt)
	_rebuild_grid()
	for bullet in _projectiles.bullets:
		if bullet.life <= 0.0:
			continue
		if bullet.friendly:
			_hit_enemies_with(bullet)
		elif ship.alive:
			var closest := Geometry2D.get_closest_point_to_segment(ship.position, bullet.previous, bullet.position)
			if closest.distance_to(ship.position) <= Ship.RADIUS + bullet.radius:
				bullet.life = 0.0
				if not _god_mode:
					ship.take_damage(bullet.damage)
				_fx.burst(closest, Projectiles.ENEMY_COLOR, 6, 40.0, 160.0, 0.3, 2.0)
	_projectiles.sweep()
	_remove_dead_enemies()


func _hit_enemies_with(bullet: Projectiles.Bullet) -> void:
	var middle := (bullet.previous + bullet.position) * 0.5
	var reach := bullet.previous.distance_to(bullet.position) * 0.5 + bullet.radius + 36.0
	for enemy: GloomEnemy in _grid.query(middle, reach):
		if enemy.dead:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(enemy.position, bullet.previous, bullet.position)
		if closest.distance_to(enemy.position) <= enemy.radius + bullet.radius:
			bullet.life = 0.0
			_damage_enemy(enemy, bullet.damage, bullet.velocity.normalized(), closest)
			return


func _damage_enemy(enemy: GloomEnemy, amount: float, direction: Vector2, point: Vector2) -> void:
	var killed := enemy.take_damage(amount)
	enemy.velocity += direction * (40.0 if enemy.kind == "snuffer" else 110.0)
	_fx.burst(point, Projectiles.PLAYER_COLOR, 3, 60.0, 220.0, 0.22, 1.6, direction.angle(), 0.9)
	if killed:
		_kill(enemy)
	else:
		_sfx.play("hit", -10.0)


func _kill(enemy: GloomEnemy) -> void:
	if enemy.dead:
		return
	enemy.dead = true
	var big := enemy.kind == "snuffer"
	var glow := GloomEnemy.ELITE_COLOR if enemy.elite else GloomEnemy.GLOW_COLOR
	_fx.burst(enemy.position, glow, 26 if big else 12, 60.0, 340.0 if big else 260.0, 0.55, 2.2)
	_fx.burst(enemy.position, IGNITE_COLOR, 6 if big else 3, 30.0, 140.0, 0.4, 1.8)
	if big:
		_fx.ring(enemy.position, glow, enemy.radius * 5.0, 0.45, 3.0)
	_camera.add_trauma(0.35 if big else 0.06)
	_sfx.play("boom" if big else "pop", -2.0 if big else -6.0)
	if claim != null and _rng.randf() < enemy.spark_chance:
		_pickups.drop(enemy.position, enemy.spark_count)


## Caught by the ignition wave: burns away with no drop.
func _burn(enemy: GloomEnemy) -> void:
	if enemy.dead:
		return
	enemy.dead = true
	_fx.burst(enemy.position, IGNITE_COLOR, 10, 60.0, 300.0, 0.6, 2.2)
	_fx.burst(enemy.position, GloomEnemy.GLOW_COLOR, 6, 40.0, 200.0, 0.5, 2.0)
	_sfx.play("pop", -8.0)


## The claim ended without ignition: the Gloom loses interest and fades.
func _dissolve(enemy: GloomEnemy) -> void:
	if enemy.dead:
		return
	enemy.dead = true
	_fx.burst(enemy.position, GloomEnemy.GLOW_COLOR, 6, 20.0, 90.0, 0.7, 1.6)


func _update_pickups(dt: float) -> void:
	var collected := _pickups.update(dt, ship.position, ship.alive)
	if collected == 0:
		return
	_sfx.play("spark", -8.0)
	if claim != null:
		for i in collected:
			claim.add_spark()


# --- Ship ----------------------------------------------------------------------

func _respawn_ship() -> void:
	var home := sector.home()
	ship.reset_at(home.beacon)
	ship.grant_iframes(RESPAWN_IFRAMES)
	_fx.ring(home.beacon, IGNITE_COLOR, 200.0, 0.5, 4.0)


func _on_ship_fired(origin: Vector2, direction: Vector2) -> void:
	var velocity := direction * tuning.bullet_speed + ship.velocity * 0.3
	_projectiles.spawn(origin, velocity, tuning.bullet_damage, 4.0, PLAYER_BULLET_LIFE, true)
	_fx.burst(origin, Projectiles.PLAYER_COLOR, 2, 40.0, 120.0, 0.12, 1.5, direction.angle(), 0.5)
	_sfx.play("shoot", -14.0)


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
	_respawn_left = tuning.respawn_delay
	var subtitle := "Rekindling at your home beacon..."
	if claim != null:
		subtitle = "Your claim on %s failed. Rekindling at home..." % sector.get_region(claim.region_id).name
		_fail_claim(true)
	_hud.show_banner("SIGNAL LOST", subtitle, SpaceHud.RED, tuning.respawn_delay + 0.5)


# --- HUD -----------------------------------------------------------------------

func _update_hud() -> void:
	_hud.set_vitals(ship.shield / tuning.max_shield, ship.hull / tuning.max_hull, ship.dash_readiness())
	if claim != null:
		var region := sector.get_region(claim.region_id)
		var status := "HOLD THE LIGHT  ·  ~%ds" % ceili(claim.seconds_remaining())
		var color := SpaceHud.GOLD
		if claim.state == Claim.State.PAUSED:
			status = "OUTSIDE THE REGION  ·  PAUSED  ·  draining in %.1fs" % maxf(tuning.claim_grace_seconds - claim.outside_time, 0.0)
			color = SpaceHud.ORANGE
		elif claim.state == Claim.State.DRAINING:
			status = "THE LIGHT IS FADING  ·  GET BACK INSIDE"
			color = SpaceHud.RED
		_hud.set_claim(region.name.to_upper(), claim.progress, status, color, tuning.elite_threshold)
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
		return "PAUSED  ·  Esc to resume"
	if not ship.alive or claim != null or not _ignition.is_empty():
		return ""
	var region := sector.get_region(_ship_region)
	if region == null:
		return "The void past the edge of the sector."
	if region.claimed:
		return "%s  ·  your light. Shields recharge here." % region.name
	if sector.is_frontier(region.id):
		var seconds := roundi(region.claim_seconds / tuning.claim_speed_multiplier)
		return "[E] Kindle %s  ·  hold ~%ds  ·  threat: %s" % [region.name, seconds, _threat_label(region)]
	return "%s  ·  too deep in the dark. Claim a region that borders your light first." % region.name


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
	for enemy in enemies:
		if enemy.kind == "snuffer" and not enemy.dead:
			list.append({"position": to_screen * enemy.position, "color": SpaceHud.VIOLET, "size": 16.0 if enemy.elite else 11.0})
	if claim == null and ship.alive and not _map_open:
		var frontier := nearest_frontier(ship.position)
		if frontier != null and frontier.id != _ship_region:
			list.append({"position": to_screen * frontier.centroid, "color": Color(1.0, 0.78, 0.4, 0.55), "size": 10.0})
	return list


func _debug_text() -> String:
	var text := "FPS %d  ·  enemies %d  ·  bullets %d  ·  sparks %d\nseed %d  ·  claim speed x%.1f  ·  god mode %s" % [
		Engine.get_frames_per_second(), enemies.size(), _projectiles.bullets.size(),
		_pickups.sparks.size(), sector.sector_seed, tuning.claim_speed_multiplier, "on" if _god_mode else "off",
	]
	if director != null:
		text += "\ncredits %.1f  ·  threat x%.2f" % [director.credits, director.threat]
	return text


# --- Input and setup -------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
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
				_hud.show_banner("PAUSED", "Esc to resume", SpaceHud.DIM, 3600.0)
			else:
				_hud.hide_banner()
		KEY_F1:
			_debug_visible = not _debug_visible
			if not _debug_visible:
				_hud.set_debug("")
		KEY_F2:
			_speed_index = (_speed_index + 1) % SPEED_STEPS.size()
			tuning.claim_speed_multiplier = SPEED_STEPS[_speed_index]
			_hud.show_banner("CLAIM SPEED x%.0f" % tuning.claim_speed_multiplier, "Debug: F2 cycles 1x / 3x / 10x", SpaceHud.DIM, 1.2)
		KEY_F3:
			_god_mode = not _god_mode
			_hud.show_banner("GOD MODE %s" % ("ON" if _god_mode else "OFF"), "", SpaceHud.DIM, 1.2)
		KEY_F4:
			start_sector(0)
			_hud.show_banner("NEW SECTOR", "Seed %d" % sector.sector_seed, SpaceHud.GOLD, 1.6)
		KEY_F5:
			_sfx.muted = not _sfx.muted
			_hud.show_banner("SOUND %s" % ("OFF" if _sfx.muted else "ON"), "", SpaceHud.DIM, 1.0)
		KEY_H:
			_hud.toggle_help()
		KEY_F11:
			var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _set_map_open(open: bool) -> void:
	_map_open = open
	_camera.map_mode = open
	_borders.map_mode = open
	var view := get_viewport_rect().size
	_camera.map_zoom = minf(view.x, view.y) / (sector.radius * 2.0 * 1.5)


func _build_scene() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CANVAS
	environment.glow_enabled = true
	environment.glow_intensity = 0.8
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 1.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var levels: Array[float] = [0.0, 0.5, 1.0, 0.8, 0.5, 0.2, 0.0]
	for i in levels.size():
		environment.set_glow_level(i, levels[i])
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var far_layer := CanvasLayer.new()
	far_layer.layer = -1
	add_child(far_layer)
	_far_stars = FarStars.new()
	far_layer.add_child(_far_stars)

	_starfield = Starfield.new()
	add_child(_starfield)
	_regions = RegionLayer.new()
	add_child(_regions)
	_borders = BorderLayer.new()
	add_child(_borders)
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
	_hud = SpaceHud.new()
	add_child(_hud)
	_sfx = Sfx.new()
	add_child(_sfx)

	ship.fired.connect(_on_ship_fired)
	ship.dashed.connect(_on_ship_dashed)
	ship.damaged.connect(_on_ship_damaged)
	ship.destroyed.connect(_on_ship_destroyed)


## Adds the actions this mode needs at runtime, so project.godot stays untouched.
func _register_input() -> void:
	_add_action("fire", [_mouse_event(MOUSE_BUTTON_LEFT)])
	_add_action("dash", [_key_event(KEY_SPACE), _key_event(KEY_SHIFT)])
	_add_action("kindle", [_key_event(KEY_E)])
	_add_action("map", [_key_event(KEY_TAB), _key_event(KEY_M)])


func _add_action(action: StringName, events: Array[InputEvent]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for event in events:
		InputMap.action_add_event(action, event)


func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event


func _mouse_event(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event


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
	_god_mode = options.has("god")
	_debug_visible = options.has("debug")
	if options.has("claim-speed"):
		tuning.claim_speed_multiplier = maxf(float(options["claim-speed"]), 0.1)
	if options.has("capture"):
		_capture_dir = String(options["capture"])
		DirAccess.make_dir_recursive_absolute(_capture_dir)
		for part in String(options.get("shots", "5")).split(","):
			_capture_times.append(float(part))
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
		print("SpaceGame: t=%.0fs fps=%.0f worst=%.1fms enemies=%d" % [_elapsed, _fps_frames / _fps_window, _fps_worst * 1000.0, enemies.size()])
		_fps_window = 0.0
		_fps_frames = 0
		_fps_worst = 0.0


func _process_capture() -> void:
	if _capture_dir.is_empty() or _capturing or _capture_times.is_empty():
		return
	if _elapsed < _capture_times[0]:
		return
	var at: float = _capture_times.pop_front()
	_capturing = true
	_save_screenshot("%s/shot_%05.1f.png" % [_capture_dir, at])


func _save_screenshot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	# With HDR 2D the viewport texture is linear; the screen gets sRGB.
	if get_viewport().use_hdr_2d:
		image.convert(Image.FORMAT_RGBA8)
		image.linear_to_srgb()
	image.save_png(path)
	print("SpaceGame: saved ", path)
	_capturing = false
	if _capture_times.is_empty():
		get_tree().quit()
