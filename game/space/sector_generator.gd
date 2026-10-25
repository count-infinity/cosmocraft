class_name SectorGenerator
extends RefCounted
## Builds a sector of irregular regions. Small Voronoi cells are scattered over
## a ragged circular boundary, then neighboring cells merge into regions of one
## to four cells, so sizes (and claim times) vary a lot and big regions get
## irregular shapes. Home sits near the rim; a large cluster on the far side
## becomes the heart.
## The same seed always gives the same sector.

const BOUNDARY_POINTS := 72
const BOUNDARY_WOBBLE := 0.22
const MAX_SCATTER_ATTEMPTS := 8000
const MAX_MERGE_ATTEMPTS := 600
## Cells are grown by this much before merging so hairline gaps close.
const UNION_EPSILON := 0.75
const ASTEROID_CLEARING := 220.0
## How far around a junction to look for the regions that meet there.
const JUNCTION_PROBE := 34.0
const PLANET_NAMES: Array[String] = [
	"Cinder", "Pyre", "Tallow", "Gloam", "Ember", "Wick", "Lumen", "Vesper",
	"Halo", "Ochre", "Sable", "Umber", "Brand", "Kiln", "Soot", "Hearth",
]
const NUMERALS: Array[String] = ["I", "II", "III", "IV", "V", "VI", "VII"]

const NAME_FIRST: Array[String] = [
	"Ash", "Cinder", "Vesper", "Umbral", "Pale", "Gloam", "Murk", "Silt",
	"Wick", "Tallow", "Soot", "Dusk", "Halo", "Glass", "Hush", "Ember",
	"Lantern", "Moth", "Velvet", "Iron", "Salt", "Ghost", "Hollow", "Still",
]
const NAME_SECOND: Array[String] = [
	"Reach", "Drift", "Expanse", "Shoal", "Verge", "Deep", "Run", "Rift",
	"Fold", "Wake", "Basin", "Shelf", "Gulf", "Mire", "Strand", "Narrows",
	"Sound", "Field", "Crossing", "Veil",
]
const NEBULA_COLORS: Array[Color] = [
	Color(0.2, 0.85, 0.8), Color(1.0, 0.35, 0.55), Color(0.3, 0.55, 1.0),
	Color(1.0, 0.6, 0.2), Color(0.8, 0.4, 1.0), Color(0.35, 0.95, 0.5),
	Color(1.0, 0.45, 0.35), Color(0.6, 0.85, 1.0),
]
## Relative odds of each modifier when a region rolls one.
const MODIFIER_WEIGHTS := {
	RegionData.Modifier.NEST: 3.0,
	RegionData.Modifier.RICH: 2.0,
	RegionData.Modifier.ASTEROIDS: 3.0,
	RegionData.Modifier.NEBULA: 2.0,
}


## `theme` (from the sector's star system) can set "modifier_chance", modifier
## "weights" and the "planets" types that form there.
static func generate(sector_seed: int, tuning: SpaceTuning, theme: Dictionary = {}) -> SectorData:
	var rng := RandomNumberGenerator.new()
	rng.seed = sector_seed
	var sector := SectorData.new()
	sector.sector_seed = sector_seed
	sector.radius = tuning.sector_radius
	sector.boundary = _make_boundary(rng.randi(), tuning.sector_radius)

	var sites := _scatter_sites(rng, sector.boundary, tuning)
	var cell_polygons := voronoi_cells(sites, sector.boundary)
	for _i in tuning.relax_iterations:
		sites = _relaxed_sites(sites, cell_polygons)
		cell_polygons = voronoi_cells(sites, sector.boundary)

	var cells := _cells_as_regions(cell_polygons)
	_link_neighbors(cells, tuning.min_shared_edge)
	var home_cell := _edge_cell(cells, rng, tuning.sector_radius)
	var groups := _group_cells(rng, cells, home_cell, tuning)
	_build_regions(sector, cells, groups, rng, tuning)
	_link_neighbors(sector.regions, tuning.min_shared_edge)
	_assign_depths(sector)
	_assign_modifiers(rng, sector, tuning, theme)
	_place_planets(rng, sector, tuning, theme)
	_place_asteroids(rng, sector)
	return sector


static func claim_seconds_for_area(area: float, tuning: SpaceTuning) -> float:
	var screens := area / SpaceTuning.SCREEN_AREA
	return clampf(
		tuning.claim_base_seconds + screens * tuning.claim_seconds_per_screen,
		tuning.claim_min_seconds,
		tuning.claim_max_seconds
	)


## Signed area (shoelace formula); the sign depends on winding order.
static func polygon_area(points: PackedVector2Array) -> float:
	var sum := 0.0
	var count := points.size()
	for i in count:
		var a := points[i]
		var b := points[(i + 1) % count]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5


static func polygon_centroid(points: PackedVector2Array) -> Vector2:
	var cross_sum := 0.0
	var weighted := Vector2.ZERO
	var count := points.size()
	for i in count:
		var a := points[i]
		var b := points[(i + 1) % count]
		var cross := a.x * b.y - b.x * a.y
		cross_sum += cross
		weighted += (a + b) * cross
	if absf(cross_sum) < 0.0001:
		var average := Vector2.ZERO
		for point in points:
			average += point
		return average / maxi(count, 1)
	return weighted / (3.0 * cross_sum)


## One cell per site: the part of the boundary closer to that site than to any
## other. A site whose cell vanishes gets an empty polygon.
static func voronoi_cells(sites: PackedVector2Array, boundary: PackedVector2Array) -> Array[PackedVector2Array]:
	var extent := 0.0
	for point in boundary:
		extent = maxf(extent, point.length())
	extent *= 4.0
	var cells: Array[PackedVector2Array] = []
	for i in sites.size():
		var cell := boundary
		for j in sites.size():
			if i == j:
				continue
			cell = _clip_to_half_plane(cell, sites[i], sites[j], extent)
			if cell.is_empty():
				break
		cells.append(cell)
	return cells


# --- Cells -----------------------------------------------------------------------

static func _make_boundary(noise_seed: int, radius: float) -> PackedVector2Array:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = 1.4
	var points := PackedVector2Array()
	for i in BOUNDARY_POINTS:
		var direction := Vector2.from_angle(TAU * i / BOUNDARY_POINTS)
		var wobble := noise.get_noise_2d(direction.x, direction.y)
		points.append(direction * radius * (1.0 + BOUNDARY_WOBBLE * wobble))
	return points


## Dart throwing with a gently varying spacing, so cells are similar in size but
## not uniform. Size variety comes mostly from merging afterwards.
static func _scatter_sites(rng: RandomNumberGenerator, boundary: PackedVector2Array, tuning: SpaceTuning) -> PackedVector2Array:
	var spacing := sqrt(absf(polygon_area(boundary)) / tuning.cell_count) * 0.75
	var density := FastNoiseLite.new()
	density.seed = rng.randi()
	density.frequency = 1.2 / tuning.sector_radius
	var reach := tuning.sector_radius * (1.0 + BOUNDARY_WOBBLE)
	var sites := PackedVector2Array()
	var spacing_scales := PackedFloat32Array()
	var attempts := 0
	while sites.size() < tuning.cell_count and attempts < MAX_SCATTER_ATTEMPTS:
		attempts += 1
		var candidate := Vector2(rng.randf_range(-reach, reach), rng.randf_range(-reach, reach))
		if not Geometry2D.is_point_in_polygon(candidate, boundary):
			continue
		var spacing_scale := clampf(remap(density.get_noise_2dv(candidate), -0.4, 0.4, 0.8, 1.2), 0.8, 1.2)
		var fits := true
		for i in sites.size():
			var min_distance := spacing * (spacing_scale + spacing_scales[i]) * 0.5
			if candidate.distance_squared_to(sites[i]) < min_distance * min_distance:
				fits = false
				break
		if fits:
			sites.append(candidate)
			spacing_scales.append(spacing_scale)
	return sites


static func _relaxed_sites(sites: PackedVector2Array, cells: Array[PackedVector2Array]) -> PackedVector2Array:
	var relaxed := PackedVector2Array()
	for i in sites.size():
		relaxed.append(polygon_centroid(cells[i]) if cells[i].size() >= 3 else sites[i])
	return relaxed


## Keeps the part of the polygon closer to `own` than to `other`.
static func _clip_to_half_plane(polygon: PackedVector2Array, own: Vector2, other: Vector2, extent: float) -> PackedVector2Array:
	var middle := (own + other) * 0.5
	var toward_other := (other - own).normalized()
	var keeps_all := true
	var keeps_none := true
	for point in polygon:
		if (point - middle).dot(toward_other) > 0.0:
			keeps_all = false
		else:
			keeps_none = false
	if keeps_all:
		return polygon
	if keeps_none:
		return PackedVector2Array()
	var along := toward_other.orthogonal()
	var half_plane := PackedVector2Array([
		middle + along * extent,
		middle + along * extent - toward_other * extent,
		middle - along * extent - toward_other * extent,
		middle - along * extent,
	])
	return _largest(Geometry2D.intersect_polygons(polygon, half_plane))


static func _largest(pieces: Array[PackedVector2Array]) -> PackedVector2Array:
	var best := PackedVector2Array()
	var best_area := 0.0
	for piece in pieces:
		var area := absf(polygon_area(piece))
		if area > best_area:
			best_area = area
			best = piece
	return best


static func _cells_as_regions(cell_polygons: Array[PackedVector2Array]) -> Array[RegionData]:
	var cells: Array[RegionData] = []
	for polygon in cell_polygons:
		if polygon.size() < 3:
			continue
		var cell := RegionData.new()
		cell.id = cells.size()
		cell.polygon = polygon
		cell.area = absf(polygon_area(polygon))
		cell.centroid = polygon_centroid(polygon)
		cells.append(cell)
	return cells


## Home starts near the rim, so each run is a push across the dark toward the
## heart on the far side.
static func _edge_cell(cells: Array[RegionData], rng: RandomNumberGenerator, radius: float) -> int:
	var target := Vector2.from_angle(rng.randf() * TAU) * radius * 0.7
	var best := -1
	var best_distance := INF
	for cell in cells:
		var distance := cell.centroid.distance_squared_to(target)
		if distance < best_distance:
			best_distance = distance
			best = cell.id
	return best


# --- Grouping cells into regions ---------------------------------------------------

## Returns groups of cell ids: home first (a single cell), the heart second
## (grown from the cell farthest from home), then the rest, built by merging
## small groups into their neighbors.
static func _group_cells(rng: RandomNumberGenerator, cells: Array[RegionData], home_cell: int, tuning: SpaceTuning) -> Array[Array]:
	var groups: Array[Array] = []
	var group_of: Array[int] = []
	group_of.resize(cells.size())
	for cell in cells:
		group_of[cell.id] = cell.id
		groups.append([cell.id])

	var heart_cell := _farthest_cell(cells, home_cell)
	var heart_group := group_of[heart_cell]
	while groups[heart_group].size() < tuning.heart_cells:
		var next := _closest_free_neighbor(cells, groups[heart_group], group_of, heart_group, home_cell)
		if next < 0:
			break
		_absorb(groups, group_of, heart_group, group_of[next])

	var alive := 0
	for group in groups:
		if not group.is_empty():
			alive += 1
	var locked := [group_of[home_cell], heart_group]
	var attempts := 0
	while alive > tuning.region_count and attempts < MAX_MERGE_ATTEMPTS:
		attempts += 1
		var picked := _pick_small_group(rng, groups, locked)
		if picked < 0:
			break
		var options: Array[int] = []
		for cell_id: int in groups[picked]:
			for neighbor_cell in cells[cell_id].neighbors:
				var other := group_of[neighbor_cell]
				if other == picked or locked.has(other) or options.has(other):
					continue
				if groups[picked].size() + groups[other].size() > tuning.max_cells_per_region:
					continue
				options.append(other)
		if options.is_empty():
			continue
		_absorb(groups, group_of, picked, options[rng.randi() % options.size()])
		alive -= 1

	var result: Array[Array] = [groups[group_of[home_cell]], groups[heart_group]]
	for i in groups.size():
		if not groups[i].is_empty() and not locked.has(i):
			result.append(groups[i])
	return result


static func _absorb(groups: Array[Array], group_of: Array[int], into: int, from: int) -> void:
	for cell_id: int in groups[from]:
		group_of[cell_id] = into
	groups[into].append_array(groups[from])
	groups[from] = []


## Smaller groups are much more likely to be picked, which keeps a healthy mix
## of single-cell skirmishes and big multi-cell sieges.
static func _pick_small_group(rng: RandomNumberGenerator, groups: Array[Array], locked: Array) -> int:
	var total := 0.0
	for i in groups.size():
		if not groups[i].is_empty() and not locked.has(i):
			total += 1.0 / pow(groups[i].size(), 2.0)
	if total <= 0.0:
		return -1
	var roll := rng.randf() * total
	var last := -1
	for i in groups.size():
		if groups[i].is_empty() or locked.has(i):
			continue
		last = i
		roll -= 1.0 / pow(groups[i].size(), 2.0)
		if roll <= 0.0:
			return i
	return last


## The cell the most hops from home (ties go to the farther one in space).
static func _farthest_cell(cells: Array[RegionData], home_cell: int) -> int:
	var hops := {home_cell: 0}
	var queue: Array[int] = [home_cell]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for neighbor in cells[current].neighbors:
			if not hops.has(neighbor):
				hops[neighbor] = int(hops[current]) + 1
				queue.append(neighbor)
	var best := home_cell
	var best_score := -1.0
	for cell in cells:
		if not hops.has(cell.id):
			continue
		var score := float(hops[cell.id]) * 100000.0 + cell.centroid.length()
		if score > best_score:
			best_score = score
			best = cell.id
	return best


## A single-cell neighbor of the group, as close to the group's middle as
## possible. Home and the ring around it are off limits, so the heart never
## ends up next door.
static func _closest_free_neighbor(cells: Array[RegionData], group: Array, group_of: Array[int], group_id: int, home_cell: int) -> int:
	var near_home := cells[home_cell].neighbors
	var middle := Vector2.ZERO
	for cell_id: int in group:
		middle += cells[cell_id].centroid
	middle /= group.size()
	var best := -1
	var best_distance := INF
	for cell_id: int in group:
		for neighbor in cells[cell_id].neighbors:
			if neighbor == home_cell or near_home.has(neighbor):
				continue
			if group_of[neighbor] == group_id or group_of[neighbor] != neighbor:
				continue
			var distance := cells[neighbor].centroid.distance_squared_to(middle)
			if distance < best_distance:
				best_distance = distance
				best = neighbor
	return best


## Groups arrive as [home, heart, ...rest] from _group_cells.
static func _build_regions(sector: SectorData, cells: Array[RegionData], groups: Array[Array], rng: RandomNumberGenerator, tuning: SpaceTuning) -> void:
	var names := _make_names(rng, groups.size())
	for group in groups:
		var ordered := _connected_order(cells, group)
		var region := RegionData.new()
		region.id = sector.regions.size()
		region.name = names[region.id]
		region.cell_count = ordered.size()
		var largest: RegionData = cells[ordered[0]]
		var polygons: Array[PackedVector2Array] = []
		for cell_id in ordered:
			polygons.append(cells[cell_id].polygon)
			if cells[cell_id].area > largest.area:
				largest = cells[cell_id]
		region.polygon = polygons[0] if polygons.size() == 1 else _union(polygons)
		region.area = absf(polygon_area(region.polygon))
		region.centroid = polygon_centroid(region.polygon)
		region.anchor = largest.centroid if region.contains(largest.centroid) else region.centroid
		region.site = region.anchor
		region.beacon = region.anchor
		region.is_heart = region.id == 1
		region.claim_seconds = claim_seconds_for_area(region.area, tuning)
		if region.is_heart:
			region.claim_seconds = minf(region.claim_seconds * tuning.heart_claim_scale, tuning.claim_max_seconds)
			sector.heart_id = region.id
		region.nebula_color = NEBULA_COLORS[rng.randi() % NEBULA_COLORS.size()]
		sector.regions.append(region)
	sector.home_id = 0
	sector.regions[0].claimed = true


## Orders a group's cells so each one touches a cell before it (needed to
## union them one at a time without the shape splitting apart).
static func _connected_order(cells: Array[RegionData], group: Array) -> Array[int]:
	var ordered: Array[int] = [group[0]]
	var index := 0
	while index < ordered.size():
		for neighbor in cells[ordered[index]].neighbors:
			if group.has(neighbor) and not ordered.has(neighbor):
				ordered.append(neighbor)
		index += 1
	for cell_id: int in group:
		if not ordered.has(cell_id):
			ordered.append(cell_id)
	return ordered


static func _union(polygons: Array[PackedVector2Array]) -> PackedVector2Array:
	var merged := _grown(polygons[0], UNION_EPSILON)
	for i in range(1, polygons.size()):
		merged = _largest(Geometry2D.merge_polygons(merged, _grown(polygons[i], UNION_EPSILON)))
	return _grown(merged, -UNION_EPSILON)


static func _grown(polygon: PackedVector2Array, delta: float) -> PackedVector2Array:
	return _largest(Geometry2D.offset_polygon(polygon, delta, Geometry2D.JOIN_MITER))


static func _make_names(rng: RandomNumberGenerator, count: int) -> Array[String]:
	var combos: Array[String] = []
	for first in NAME_FIRST:
		for second in NAME_SECOND:
			combos.append("%s %s" % [first, second])
	for i in range(combos.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := combos[i]
		combos[i] = combos[j]
		combos[j] = swap
	var names: Array[String] = []
	for i in count:
		names.append(combos[i % combos.size()])
	return names


# --- Neighbors, depth, modifiers, asteroids ------------------------------------------

## Fills edge_neighbors (who is across each edge) and neighbors (who shares a
## real border) by probing just outside every edge.
static func _link_neighbors(regions: Array[RegionData], min_shared_edge: float) -> void:
	for region in regions:
		region.edge_neighbors.clear()
		region.neighbors.clear()
	for region in regions:
		var shared := {}
		for k in region.polygon.size():
			var length := region.edge_length(k)
			var neighbor := -1
			if length > 0.5:
				var a := region.polygon[k]
				var b := region.polygon[(k + 1) % region.polygon.size()]
				var probe := (a + b) * 0.5 + region.edge_outward_normal(k) * 4.0
				neighbor = _region_at_excluding(regions, probe, region.id)
			region.edge_neighbors.append(neighbor)
			if neighbor >= 0:
				shared[neighbor] = float(shared.get(neighbor, 0.0)) + length
		for neighbor_id: int in shared:
			if float(shared[neighbor_id]) >= min_shared_edge:
				region.neighbors.append(neighbor_id)
	# A border that one side measured just under the minimum still links both ways.
	for region in regions:
		for neighbor_id in region.neighbors:
			var other := regions[neighbor_id]
			if not other.neighbors.has(region.id):
				other.neighbors.append(region.id)


static func _region_at_excluding(regions: Array[RegionData], point: Vector2, excluded_id: int) -> int:
	for region in regions:
		if region.id != excluded_id and region.contains(point):
			return region.id
	return -1


static func _assign_depths(sector: SectorData) -> void:
	for region in sector.regions:
		region.depth = -1
	if sector.home_id < 0:
		return
	sector.regions[sector.home_id].depth = 0
	var queue: Array[int] = [sector.home_id]
	while not queue.is_empty():
		var current_id: int = queue.pop_front()
		var current := sector.regions[current_id]
		for neighbor_id in current.neighbors:
			var neighbor := sector.regions[neighbor_id]
			if neighbor.depth < 0:
				neighbor.depth = current.depth + 1
				queue.append(neighbor_id)


## The first ring around home stays plain so the opening is easy to read.
static func _assign_modifiers(rng: RandomNumberGenerator, sector: SectorData, tuning: SpaceTuning, theme: Dictionary) -> void:
	var weights: Dictionary = theme.get("weights", MODIFIER_WEIGHTS)
	var chance := float(theme.get("modifier_chance", tuning.modifier_chance))
	var total := 0.0
	for weight: float in weights.values():
		total += weight
	for region in sector.regions:
		if region.claimed or region.is_heart or region.depth <= 1:
			continue
		if rng.randf() >= chance:
			continue
		var roll := rng.randf() * total
		for modifier: int in weights:
			roll -= float(weights[modifier])
			if roll <= 0.0:
				region.modifier = modifier
				break


## Planets sit on junctions where three or more regions meet, away from home
## and the heart, and well apart from each other.
static func _place_planets(rng: RandomNumberGenerator, sector: SectorData, tuning: SpaceTuning, theme: Dictionary) -> void:
	var types: Array = theme.get("planets", [])
	var candidates: Array[Vector2] = []
	for region in sector.regions:
		for vertex in region.polygon:
			var around := regions_around(sector, vertex, JUNCTION_PROBE)
			if around.size() >= 3 and not around.has(sector.home_id) and not around.has(sector.heart_id):
				candidates.append(vertex)
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = swap
	for point in candidates:
		if sector.planets.size() >= tuning.planet_count:
			break
		var crowded := false
		for other in sector.planets:
			if other.position.distance_to(point) < tuning.planet_spacing:
				crowded = true
		if crowded:
			continue
		var radius := rng.randf_range(85.0, 120.0)
		var touching := regions_around(sector, point, radius + 24.0, 16)
		if touching.has(sector.home_id) or touching.has(sector.heart_id) or touching.size() < 2:
			continue
		var planet := PlanetData.new()
		planet.id = sector.planets.size()
		planet.position = point
		planet.radius = radius
		planet.touching = touching
		var roll := rng.randi()
		planet.type = (types[roll % types.size()] if not types.is_empty() else roll % PlanetData.TYPES.size()) as PlanetData.Type
		planet.surface_seed = rng.randi()
		planet.name = "%s %s" % [PLANET_NAMES[rng.randi() % PLANET_NAMES.size()], NUMERALS[rng.randi() % NUMERALS.size()]]
		for region_id in touching:
			planet.depth = maxi(planet.depth, sector.regions[region_id].depth)
		sector.planets.append(planet)


## Distinct regions found on a ring of probes around a point.
static func regions_around(sector: SectorData, point: Vector2, distance: float, probes := 12) -> Array[int]:
	var found: Array[int] = []
	for i in probes:
		var region_id := sector.region_at(point + Vector2.from_angle(TAU * i / probes) * distance)
		if region_id >= 0 and not found.has(region_id):
			found.append(region_id)
	return found


static func _place_asteroids(rng: RandomNumberGenerator, sector: SectorData) -> void:
	for region in sector.regions:
		if region.modifier != RegionData.Modifier.ASTEROIDS:
			continue
		var bounds := _bounds(region.polygon)
		var wanted := clampi(int(region.area / 80000.0), 6, 20)
		var placed: Array[SectorData.Asteroid] = []
		var tries := 0
		while placed.size() < wanted and tries < wanted * 40:
			tries += 1
			var point := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
			if not region.contains(point) or point.distance_to(region.anchor) < ASTEROID_CLEARING:
				continue
			var radius := rng.randf_range(22.0, 60.0)
			var crowded := false
			for other in placed:
				if point.distance_to(other.position) < radius + other.radius + 40.0:
					crowded = true
					break
			for planet in sector.planets:
				if point.distance_to(planet.position) < planet.radius + radius + 80.0:
					crowded = true
			if crowded:
				continue
			var asteroid := SectorData.Asteroid.new()
			asteroid.position = point
			asteroid.radius = radius
			asteroid.region_id = region.id
			var corners := rng.randi_range(8, 12)
			for i in corners:
				asteroid.outline.append(Vector2.from_angle(TAU * i / corners) * radius * rng.randf_range(0.78, 1.08))
			placed.append(asteroid)
		sector.asteroids.append_array(placed)


static func _bounds(polygon: PackedVector2Array) -> Rect2:
	var rect := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		rect = rect.expand(point)
	return rect
