class_name SectorGenerator
extends RefCounted
## Builds a sector of irregular regions: a Voronoi diagram of scattered sites,
## clipped to a ragged circular boundary. The same seed always gives the same sector.

const BOUNDARY_POINTS := 72
const BOUNDARY_WOBBLE := 0.22
const MAX_SCATTER_ATTEMPTS := 6000

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


static func generate(sector_seed: int, tuning: SpaceTuning) -> SectorData:
	var rng := RandomNumberGenerator.new()
	rng.seed = sector_seed
	var sector := SectorData.new()
	sector.sector_seed = sector_seed
	sector.radius = tuning.sector_radius
	sector.boundary = _make_boundary(rng.randi(), tuning.sector_radius)

	var sites := _scatter_sites(rng, sector.boundary, tuning)
	var cells := voronoi_cells(sites, sector.boundary)
	for _i in tuning.relax_iterations:
		sites = _relaxed_sites(sites, cells)
		cells = voronoi_cells(sites, sector.boundary)

	_build_regions(sector, sites, cells, rng, tuning)
	_link_neighbors(sector, tuning)
	_pick_home(sector)
	_assign_depths(sector)
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


## Dart throwing with a spacing that varies across the sector, so some regions
## come out small and some large.
static func _scatter_sites(rng: RandomNumberGenerator, boundary: PackedVector2Array, tuning: SpaceTuning) -> PackedVector2Array:
	var spacing := sqrt(absf(polygon_area(boundary)) / tuning.region_count) * 0.75
	var density := FastNoiseLite.new()
	density.seed = rng.randi()
	density.frequency = 1.2 / tuning.sector_radius
	var reach := tuning.sector_radius * (1.0 + BOUNDARY_WOBBLE)
	var sites := PackedVector2Array()
	var spacing_scales := PackedFloat32Array()
	var attempts := 0
	while sites.size() < tuning.region_count and attempts < MAX_SCATTER_ATTEMPTS:
		attempts += 1
		var candidate := Vector2(rng.randf_range(-reach, reach), rng.randf_range(-reach, reach))
		if not Geometry2D.is_point_in_polygon(candidate, boundary):
			continue
		var spacing_scale := clampf(remap(density.get_noise_2dv(candidate), -0.4, 0.4, 0.7, 1.35), 0.7, 1.35)
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


static func _build_regions(sector: SectorData, sites: PackedVector2Array, cells: Array[PackedVector2Array], rng: RandomNumberGenerator, tuning: SpaceTuning) -> void:
	var names := _make_names(rng, cells.size())
	for i in cells.size():
		var cell := cells[i]
		if cell.size() < 3:
			continue
		var region := RegionData.new()
		region.id = sector.regions.size()
		region.name = names[region.id]
		region.site = sites[i]
		region.polygon = cell
		region.area = absf(polygon_area(cell))
		region.centroid = polygon_centroid(cell)
		region.beacon = region.centroid
		region.claim_seconds = claim_seconds_for_area(region.area, tuning)
		region.nebula_color = NEBULA_COLORS[rng.randi() % NEBULA_COLORS.size()]
		sector.regions.append(region)


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


static func _link_neighbors(sector: SectorData, tuning: SpaceTuning) -> void:
	for region in sector.regions:
		var shared := {}
		for k in region.polygon.size():
			var length := region.edge_length(k)
			var neighbor := -1
			if length > 0.5:
				var a := region.polygon[k]
				var b := region.polygon[(k + 1) % region.polygon.size()]
				var probe := (a + b) * 0.5 + region.edge_outward_normal(k) * 4.0
				neighbor = _region_at_excluding(sector, probe, region.id)
			region.edge_neighbors.append(neighbor)
			if neighbor >= 0:
				shared[neighbor] = float(shared.get(neighbor, 0.0)) + length
		for neighbor_id: int in shared:
			if float(shared[neighbor_id]) >= tuning.min_shared_edge:
				region.neighbors.append(neighbor_id)
	# A border that one side measured just under the minimum still links both ways.
	for region in sector.regions:
		for neighbor_id in region.neighbors:
			var other := sector.regions[neighbor_id]
			if not other.neighbors.has(region.id):
				other.neighbors.append(region.id)


static func _region_at_excluding(sector: SectorData, point: Vector2, excluded_id: int) -> int:
	for region in sector.regions:
		if region.id != excluded_id and region.contains(point):
			return region.id
	return -1


## Home is the region nearest the center, so the light spreads outward.
static func _pick_home(sector: SectorData) -> void:
	var best_distance := INF
	for region in sector.regions:
		var distance := region.centroid.length_squared()
		if distance < best_distance:
			best_distance = distance
			sector.home_id = region.id
	if sector.home_id >= 0:
		sector.regions[sector.home_id].claimed = true


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
