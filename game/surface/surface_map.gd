class_name SurfaceMap
extends RefCounted
## The layout of one planet's surface: where the lander sets down, the Ember
## Vein to kindle, rocks, hazard pools, resource deposits, Gloom nests, supply
## caches and sleeping packs. Generated from the planet's seed, always with a
## walkable route from the lander to the vein. It also answers movement
## questions for the mission: rock collisions, hazards and paths.

const WIDTH := 4400.0
const HEIGHT := 2800.0
## Pathfinding grid cell size.
const CELL := 40.0
## Room the pilot needs between rocks.
const CLEARANCE := 16.0
## Rock outlines wobble; collisions use this fraction of the radius.
const ROCK_SOLIDITY := 0.88
## Grid query padding: the largest rock radius plus a margin.
const ROCK_REACH := 140.0
const LANDING_CLEAR := 380.0
const VEIN_CLEAR := 470.0
const DEPOSIT_RADIUS := 30.0
const NO_CELL := Vector2i(-1, -1)

## Hazard pools by the planet's hazard type. Damage and slow apply while the
## pilot stands in one; glow is how much light the pool gives off.
const HAZARDS := {
	"embers": {"name": "Ember field", "color": Color(2.2, 0.7, 0.25), "dps": 1.0, "slow": 0.15, "glow": 0.35},
	"lava": {"name": "Lava", "color": Color(2.6, 0.85, 0.2), "dps": 1.4, "slow": 0.25, "glow": 0.5},
	"acid": {"name": "Acid", "color": Color(0.6, 2.2, 0.45), "dps": 1.0, "slow": 0.25, "glow": 0.3},
	"spores": {"name": "Spore cloud", "color": Color(1.5, 0.65, 2.1), "dps": 0.8, "slow": 0.2, "glow": 0.25},
	"cryo": {"name": "Cryo frost", "color": Color(0.6, 1.5, 2.6), "dps": 0.6, "slow": 0.55, "glow": 0.25},
	"shards": {"name": "Crystal shards", "color": Color(1.8, 0.7, 2.6), "dps": 1.2, "slow": 0.1, "glow": 0.3},
}

## Sleeping packs, unlocked by depth on the same schedule as WaveDirector's
## roster: tougher kinds only on planets deeper in the dark.
const PACKS: Array[Dictionary] = [
	{"kind": "mite", "min": 4, "max": 6, "depth": 1, "weight": 4.0},
	{"kind": "dart", "min": 2, "max": 3, "depth": 1, "weight": 2.0},
	{"kind": "spitter", "min": 2, "max": 3, "depth": 2, "weight": 1.6},
	{"kind": "brood", "min": 1, "max": 2, "depth": 2, "weight": 1.2},
	{"kind": "carapace", "min": 1, "max": 2, "depth": 3, "weight": 1.2},
	{"kind": "lancer", "min": 1, "max": 2, "depth": 3, "weight": 1.0},
]
const CACHE_CONTENTS: Array[String] = ["repair", "sparks", "flares"]


class Rock:
	var position := Vector2.ZERO
	var radius := 50.0
	## Outline points relative to the position.
	var outline := PackedVector2Array()


class Hazard:
	var position := Vector2.ZERO
	var radius := 120.0
	var outline := PackedVector2Array()


class Deposit:
	var position := Vector2.ZERO
	var hp := 6.0
	var max_hp := 6.0
	var shards := 4
	var size := 1.0
	var shape_seed := 0
	## Brightens briefly when hit.
	var flash := 0.0
	## Built on once the planet is kindled; feeds the outpost.
	var extractor := false

	func radius() -> float:
		return DEPOSIT_RADIUS * size

	func is_intact() -> bool:
		return hp > 0.0


class Cache:
	var position := Vector2.ZERO
	var contents := "sparks"
	var opened := false


var map_seed := 0
var planet_type := PlanetData.Type.ASHEN
var depth := 1
## Which ring's Gloom the sleeping packs come from (depth, shifted by darkness).
var roster_depth := 1
var bounds := Rect2(-WIDTH * 0.5, -HEIGHT * 0.5, WIDTH, HEIGHT)
var landing := Vector2.ZERO
var vein := Vector2.ZERO
var rocks: Array[Rock] = []
var hazards: Array[Hazard] = []
var deposits: Array[Deposit] = []
var caches: Array[Cache] = []
var nests: Array[Vector2] = []
## Sleeping Gloom, each {"kind": String, "count": int, "position": Vector2}.
var packs: Array[Dictionary] = []
## The walkable route from the lander to the vein.
var route := PackedVector2Array()
var astar := AStarGrid2D.new()

var _rock_grid := SpatialGrid.new(160.0)
var _rng := RandomNumberGenerator.new()


## `roster_shift` (from the darkness) brings tougher packs to shallower planets.
static func generate(seed_value: int, type: PlanetData.Type, p_depth: int, roster_shift := 0) -> SurfaceMap:
	var map := SurfaceMap.new()
	map.map_seed = seed_value
	map.planet_type = type
	map.depth = clampi(p_depth, 1, 4)
	map.roster_depth = map.depth + roster_shift
	map._rng.seed = seed_value
	map._place_endpoints()
	map._place_rocks()
	map._build_grid(true)
	map._carve_route()
	map._build_grid(false)
	map.route = map.find_path(map.landing, map.vein)
	var open := map._reachable_cells()
	map._place_hazards(open)
	map._place_deposits(open)
	map._place_nests(open)
	map._place_caches(open)
	map._place_packs(open)
	return map


func hazard_info() -> Dictionary:
	return HAZARDS[PlanetData.TYPES[planet_type]["hazard"]]


# --- Queries ---------------------------------------------------------------------

func cell_of(point: Vector2) -> Vector2i:
	return Vector2i(floori((point.x - bounds.position.x) / CELL), floori((point.y - bounds.position.y) / CELL))


func center_of(cell: Vector2i) -> Vector2:
	return bounds.position + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL


func is_open(cell: Vector2i) -> bool:
	return astar.is_in_boundsv(cell) and not astar.is_point_solid(cell)


func is_walkable(point: Vector2) -> bool:
	return is_open(cell_of(point))


## How far to move a circle so it no longer overlaps any rock.
func rock_push(point: Vector2, radius: float) -> Vector2:
	var push := Vector2.ZERO
	for rock: Rock in _rock_grid.query(point, radius + ROCK_REACH):
		var offset := point - rock.position
		var min_distance := rock.radius * ROCK_SOLIDITY + radius
		var distance := offset.length()
		if distance < min_distance and distance > 0.001:
			push += offset / distance * (min_distance - distance)
	return push


func segment_hits_rock(from: Vector2, to: Vector2, radius: float) -> bool:
	var middle := (from + to) * 0.5
	for rock: Rock in _rock_grid.query(middle, from.distance_to(to) * 0.5 + radius + ROCK_REACH):
		var closest := Geometry2D.get_closest_point_to_segment(rock.position, from, to)
		if closest.distance_to(rock.position) < rock.radius * ROCK_SOLIDITY + radius:
			return true
	return false


func hazard_at(point: Vector2) -> Hazard:
	for hazard in hazards:
		if point.distance_to(hazard.position) < hazard.radius * 0.85:
			return hazard
	return null


## A walkable path between two points as world positions (empty if none).
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := nearest_open(cell_of(from))
	var goal := nearest_open(cell_of(to))
	if start == NO_CELL or goal == NO_CELL:
		return PackedVector2Array()
	return astar.get_point_path(start, goal, true)


## The open cell closest to `cell`, searching a few rings out.
func nearest_open(cell: Vector2i) -> Vector2i:
	if is_open(cell):
		return cell
	for ring in range(1, 6):
		for dx in range(-ring, ring + 1):
			for dy in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var candidate := cell + Vector2i(dx, dy)
				if is_open(candidate):
					return candidate
	return NO_CELL


func clamp_inside(point: Vector2, margin: float) -> Vector2:
	var inner := bounds.grow(-margin)
	return point.clamp(inner.position, inner.end)


# --- Generation ------------------------------------------------------------------

func _place_endpoints() -> void:
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	landing = Vector2(-side * (WIDTH * 0.5 - 430.0), _rng.randf_range(-HEIGHT * 0.28, HEIGHT * 0.28))
	vein = Vector2(side * (WIDTH * 0.5 - 520.0), _rng.randf_range(-HEIGHT * 0.28, HEIGHT * 0.28))


## Rock fields where the noise runs high, lone boulders in the open, and a
## rocky rim around the edge.
func _place_rocks() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = map_seed
	noise.frequency = 0.0017
	noise.fractal_octaves = 3
	var threshold := 0.1
	var spacing := 118.0
	var y := bounds.position.y + spacing * 0.5
	while y < bounds.end.y:
		var x := bounds.position.x + spacing * 0.5
		while x < bounds.end.x:
			var point := Vector2(x, y) + Vector2(_rng.randf_range(-44.0, 44.0), _rng.randf_range(-44.0, 44.0))
			var value := noise.get_noise_2dv(point)
			if value > threshold:
				var strength := clampf(inverse_lerp(threshold, 0.5, value), 0.0, 1.0)
				_try_add_rock(point, lerpf(38.0, 108.0, strength) * _rng.randf_range(0.8, 1.1))
			elif _rng.randf() < 0.035:
				_try_add_rock(point, _rng.randf_range(24.0, 42.0))
			x += spacing
		y += spacing
	var step := 115.0
	var edge := 0.0
	var perimeter := (WIDTH + HEIGHT) * 2.0
	while edge < perimeter:
		_try_add_rock(_perimeter_point(edge), _rng.randf_range(80.0, 128.0))
		edge += step * _rng.randf_range(0.8, 1.2)


func _perimeter_point(distance: float) -> Vector2:
	var d := fmod(distance, (WIDTH + HEIGHT) * 2.0)
	var push := 34.0
	if d < WIDTH:
		return Vector2(bounds.position.x + d, bounds.position.y - push)
	d -= WIDTH
	if d < HEIGHT:
		return Vector2(bounds.end.x + push, bounds.position.y + d)
	d -= HEIGHT
	if d < WIDTH:
		return Vector2(bounds.end.x - d, bounds.end.y + push)
	d -= WIDTH
	return Vector2(bounds.position.x - push, bounds.end.y - d)


func _try_add_rock(point: Vector2, radius: float) -> void:
	if point.distance_to(landing) < LANDING_CLEAR + radius or point.distance_to(vein) < VEIN_CLEAR + radius:
		return
	for other: Rock in _rock_grid.query(point, radius + ROCK_REACH):
		if point.distance_to(other.position) < (radius + other.radius) * 0.62:
			return
	var rock := Rock.new()
	rock.position = point
	rock.radius = radius
	var corners := 13
	for i in corners:
		var angle := TAU * i / corners + _rng.randf_range(-0.12, 0.12)
		rock.outline.append(Vector2.from_angle(angle) * radius * _rng.randf_range(0.86, 1.12))
	rocks.append(rock)
	_rock_grid.insert(rock, point)


## Marks rock cells as solid, or (soft) just expensive, for routing.
func _build_grid(soft: bool) -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, int(WIDTH / CELL), int(HEIGHT / CELL))
	astar.cell_size = Vector2(CELL, CELL)
	astar.offset = bounds.position + Vector2(CELL, CELL) * 0.5
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	var size := astar.region.size
	for rock in rocks:
		var reach := rock.radius * ROCK_SOLIDITY + CLEARANCE
		var low := cell_of(rock.position - Vector2(reach, reach))
		var high := cell_of(rock.position + Vector2(reach, reach))
		for cx in range(maxi(low.x, 0), mini(high.x, size.x - 1) + 1):
			for cy in range(maxi(low.y, 0), mini(high.y, size.y - 1) + 1):
				var cell := Vector2i(cx, cy)
				if center_of(cell).distance_to(rock.position) < reach:
					if soft:
						astar.set_point_weight_scale(cell, 30.0)
					else:
						astar.set_point_solid(cell, true)


## Finds the cheapest way from the lander to the vein, preferring open ground,
## and clears any rock in the way (with room to spare).
func _carve_route() -> void:
	var path := astar.get_point_path(cell_of(landing), cell_of(vein))
	var doomed := {}
	for point in path:
		for rock: Rock in _rock_grid.query(point, ROCK_REACH + CELL):
			if point.distance_to(rock.position) < rock.radius * ROCK_SOLIDITY + CLEARANCE + CELL * 0.8:
				doomed[rock] = true
	if doomed.is_empty():
		return
	var kept: Array[Rock] = []
	_rock_grid.clear()
	for rock in rocks:
		if not doomed.has(rock):
			kept.append(rock)
			_rock_grid.insert(rock, rock.position)
	rocks = kept


## Every open cell the pilot can walk to from the lander.
func _reachable_cells() -> Array[Vector2i]:
	var start := nearest_open(cell_of(landing))
	var seen := {start: true}
	var frontier: Array[Vector2i] = [start]
	var result: Array[Vector2i] = []
	var steps: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		result.append(cell)
		for step in steps:
			var next := cell + step
			if not seen.has(next) and is_open(next):
				seen[next] = true
				frontier.append(next)
	return result


## Random reachable spots that pass `rule` and keep `spacing` from each other.
func _pick_spots(open: Array[Vector2i], count: int, spacing: float, rule: Callable) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	var tries := 0
	while spots.size() < count and tries < count * 80:
		tries += 1
		var point := center_of(open[_rng.randi_range(0, open.size() - 1)])
		point += Vector2(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.3, 0.3)) * CELL
		if not rule.call(point):
			continue
		var spaced := true
		for other in spots:
			if other.distance_to(point) < spacing:
				spaced = false
				break
		if spaced:
			spots.append(point)
	return spots


func _clear_of_hazards(point: Vector2, margin: float) -> bool:
	for hazard in hazards:
		if point.distance_to(hazard.position) < hazard.radius + margin:
			return false
	return true


func _place_hazards(open: Array[Vector2i]) -> void:
	var count := 4 + _rng.randi_range(0, 3)
	var spots := _pick_spots(open, count, 520.0, func(point: Vector2) -> bool:
		return point.distance_to(landing) > 650.0 and point.distance_to(vein) > 640.0)
	for point in spots:
		var hazard := Hazard.new()
		hazard.position = point
		hazard.radius = _rng.randf_range(85.0, 150.0)
		var corners := 18
		for i in corners:
			hazard.outline.append(Vector2.from_angle(TAU * i / corners) * hazard.radius * _rng.randf_range(0.82, 1.12))
		hazards.append(hazard)


func _place_deposits(open: Array[Vector2i]) -> void:
	var count := 7 + _rng.randi_range(0, 3)
	var spots := _pick_spots(open, count, 330.0, func(point: Vector2) -> bool:
		return point.distance_to(landing) > 420.0 and point.distance_to(vein) > 300.0 \
			and _clear_of_hazards(point, 50.0) and rock_push(point, DEPOSIT_RADIUS * 1.5 + 6.0) == Vector2.ZERO)
	for point in spots:
		var deposit := Deposit.new()
		deposit.position = point
		deposit.size = 1.45 if _rng.randf() < 0.25 else 1.0
		deposit.max_hp = (5.0 + depth) * deposit.size * deposit.size
		deposit.hp = deposit.max_hp
		deposit.shards = _rng.randi_range(3, 5) + (3 if deposit.size > 1.0 else 0)
		deposit.shape_seed = _rng.randi()
		deposits.append(deposit)


func _place_nests(open: Array[Vector2i]) -> void:
	var count := 3 + mini(depth, 3)
	nests = _pick_spots(open, count, 560.0, func(point: Vector2) -> bool:
		return point.distance_to(landing) > 1100.0 and point.distance_to(vein) > 720.0 \
			and _clear_of_hazards(point, 40.0) and rock_push(point, 34.0) == Vector2.ZERO \
			and _clear_of_deposits(point, 200.0))


func _clear_of_deposits(point: Vector2, margin: float) -> bool:
	for deposit in deposits:
		if point.distance_to(deposit.position) < margin:
			return false
	return true


## Caches hide off the main route, rewarding a look around.
func _place_caches(open: Array[Vector2i]) -> void:
	var candidates := _pick_spots(open, 90, 60.0, func(point: Vector2) -> bool:
		return point.distance_to(landing) > 700.0 and point.distance_to(vein) > 500.0 \
			and _clear_of_hazards(point, 40.0) and rock_push(point, 22.0) == Vector2.ZERO \
			and _clear_of_deposits(point, 120.0))
	var scored: Array[Dictionary] = []
	for point in candidates:
		var off_route := INF
		for step in route:
			off_route = minf(off_route, point.distance_to(step))
		scored.append({"point": point, "score": off_route + _rng.randf_range(0.0, 250.0)})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])
	var count := 2 + (1 if _rng.randf() < 0.5 else 0)
	var contents := CACHE_CONTENTS.duplicate()
	for i in contents.size():
		var j := _rng.randi_range(i, contents.size() - 1)
		var swap: String = contents[i]
		contents[i] = contents[j]
		contents[j] = swap
	for entry in scored:
		if caches.size() >= count:
			break
		var point: Vector2 = entry["point"]
		var spaced := true
		for cache in caches:
			if cache.position.distance_to(point) < 900.0:
				spaced = false
				break
		if not spaced:
			continue
		var cache := Cache.new()
		cache.position = point
		cache.contents = contents[caches.size() % contents.size()]
		caches.append(cache)


func _place_packs(open: Array[Vector2i]) -> void:
	var count := 4 + depth
	var spots := _pick_spots(open, count, 480.0, func(point: Vector2) -> bool:
		return point.distance_to(landing) > 850.0 and point.distance_to(vein) > 650.0 \
			and rock_push(point, 30.0) == Vector2.ZERO)
	for point in spots:
		var card := _pick_pack()
		packs.append({"kind": card["kind"], "count": _rng.randi_range(card["min"], card["max"]), "position": point})


func _pick_pack() -> Dictionary:
	var total := 0.0
	for card in PACKS:
		if roster_depth >= int(card["depth"]):
			total += float(card["weight"])
	var roll := _rng.randf() * total
	for card in PACKS:
		if roster_depth < int(card["depth"]):
			continue
		roll -= float(card["weight"])
		if roll <= 0.0:
			return card
	return PACKS[0]
