class_name GalaxyData
extends RefCounted
## The conquest map: a handful of star systems, each a cluster of sectors
## linked by lanes, with gate lanes between neighboring systems. You start with
## your home sector lit. Any dark sector on a lane from your territory can be
## invaded; burning out its heart conquers it for good. Conquer every sector in
## a system and the system falls; conquer them all and the galaxy is yours.
## A sector's tier (lanes from home) sets how hard it is.

## Systems in the order they sit on the map. Each theme shapes its sectors:
## which modifiers regions roll (and how often) and what kinds of planets form.
const SYSTEMS: Array[Dictionary] = [
	{"name": "Ember Reach", "color": Color(1.0, 0.62, 0.3), "blurb": "Home. Mild, mixed sectors.",
		"theme": {"modifier_chance": 0.4, "planets": [PlanetData.Type.ASHEN, PlanetData.Type.MAGMA, PlanetData.Type.VERDANT]}},
	{"name": "Hollow Expanse", "color": Color(0.5, 0.75, 1.0), "blurb": "Nebulae everywhere: it's dark until you light it.",
		"theme": {"modifier_chance": 0.55, "weights": {RegionData.Modifier.NEBULA: 6.0, RegionData.Modifier.RICH: 1.0, RegionData.Modifier.NEST: 1.0, RegionData.Modifier.ASTEROIDS: 1.0}, "planets": [PlanetData.Type.FROST, PlanetData.Type.CRYSTAL]}},
	{"name": "Verdant Tangle", "color": Color(0.45, 1.0, 0.55), "blurb": "Nests breed in every corner. More Gloom, more sparks.",
		"theme": {"modifier_chance": 0.55, "weights": {RegionData.Modifier.NEST: 6.0, RegionData.Modifier.RICH: 2.0, RegionData.Modifier.NEBULA: 1.0, RegionData.Modifier.ASTEROIDS: 1.0}, "planets": [PlanetData.Type.VERDANT, PlanetData.Type.FUNGAL]}},
	{"name": "Shard Fields", "color": Color(0.85, 0.55, 1.0), "blurb": "Asteroid belts to fight through and hide behind.",
		"theme": {"modifier_chance": 0.6, "weights": {RegionData.Modifier.ASTEROIDS: 6.0, RegionData.Modifier.RICH: 1.5, RegionData.Modifier.NEST: 1.0, RegionData.Modifier.NEBULA: 1.0}, "planets": [PlanetData.Type.CRYSTAL, PlanetData.Type.FROST]}},
	{"name": "Ashen Drift", "color": Color(1.0, 0.45, 0.25), "blurb": "Rich regions, and the nests that guard them.",
		"theme": {"modifier_chance": 0.6, "weights": {RegionData.Modifier.RICH: 5.0, RegionData.Modifier.NEST: 3.0, RegionData.Modifier.ASTEROIDS: 1.0, RegionData.Modifier.NEBULA: 1.0}, "planets": [PlanetData.Type.ASHEN, PlanetData.Type.MAGMA]}},
	{"name": "The Deep Fold", "color": Color(0.35, 0.95, 0.85), "blurb": "Nebulae and asteroid belts tangled together.",
		"theme": {"modifier_chance": 0.65, "weights": {RegionData.Modifier.NEBULA: 4.0, RegionData.Modifier.ASTEROIDS: 4.0, RegionData.Modifier.NEST: 2.0, RegionData.Modifier.RICH: 1.0}, "planets": [PlanetData.Type.FUNGAL, PlanetData.Type.FROST, PlanetData.Type.MAGMA]}},
	{"name": "The Smother", "color": Color(1.0, 0.35, 0.65), "blurb": "The heart of the dark. Everything, everywhere.",
		"theme": {"modifier_chance": 0.8}},
]
## Where systems sit on the map (0..1 of its width and height) and which are
## joined by gate lanes. The home system is first, the Smother last.
const LAYOUT: Array[Vector2] = [
	Vector2(0.1, 0.5), Vector2(0.3, 0.24), Vector2(0.3, 0.76), Vector2(0.52, 0.5),
	Vector2(0.72, 0.22), Vector2(0.72, 0.78), Vector2(0.9, 0.5),
]
const GATES: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 3), Vector2i(2, 3), Vector2i(1, 4),
	Vector2i(3, 4), Vector2i(3, 5), Vector2i(2, 5), Vector2i(4, 6), Vector2i(5, 6),
]
const MAP_SIZE := Vector2(1000.0, 560.0)
const ROMAN := ["I", "II", "III", "IV", "V", "VI", "VII"]


class Sector:
	var id := -1
	var system_id := -1
	var name := ""
	## Position on the star map (MAP_SIZE coordinates).
	var position := Vector2.ZERO
	var sector_seed := 0
	## Lanes from home: 0 for home, 1 next door, and so on.
	var tier := 0
	var neighbors: Array[int] = []


class StarSystem:
	var id := -1
	var name := ""
	var blurb := ""
	var color := Color.WHITE
	var position := Vector2.ZERO
	var theme: Dictionary = {}
	var sectors: Array[int] = []


var galaxy_seed := 0
var systems: Array[StarSystem] = []
var sectors: Array[Sector] = []
var home_id := 0


static func generate(seed_value: int) -> GalaxyData:
	var galaxy := GalaxyData.new()
	galaxy.galaxy_seed = seed_value
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in SYSTEMS.size():
		var system := StarSystem.new()
		system.id = i
		system.name = SYSTEMS[i]["name"]
		system.blurb = SYSTEMS[i]["blurb"]
		system.color = SYSTEMS[i]["color"]
		system.theme = SYSTEMS[i]["theme"]
		system.position = LAYOUT[i] * MAP_SIZE + Vector2(rng.randf_range(-25.0, 25.0), rng.randf_range(-20.0, 20.0))
		galaxy.systems.append(system)
		var count := 4 if i == 0 else rng.randi_range(4, 6)
		var turn := rng.randf() * TAU
		var first := galaxy.sectors.size()
		for k in count:
			var sector := Sector.new()
			sector.id = galaxy.sectors.size()
			sector.system_id = i
			sector.name = "%s %s" % [system.name.trim_prefix("The "), ROMAN[k]]
			var angle := turn + TAU * k / count + rng.randf_range(-0.25, 0.25)
			sector.position = system.position + Vector2.from_angle(angle) * rng.randf_range(48.0, 66.0) * Vector2(1.15, 1.0)
			sector.sector_seed = rng.randi_range(1, 999999)
			galaxy.sectors.append(sector)
			system.sectors.append(sector.id)
		# Sectors in a system form a ring, with one lane across it.
		for k in count:
			galaxy._link(first + k, first + (k + 1) % count)
		galaxy._link(first, first + count / 2)
	# Home is the home system's sector farthest from the rest of the galaxy.
	var home_system := galaxy.systems[0]
	var best := -INF
	for id in home_system.sectors:
		var score := -galaxy.sectors[id].position.x
		if score > best:
			best = score
			galaxy.home_id = id
	galaxy.sectors[galaxy.home_id].name = "Hearthhold"
	for gate in GATES:
		galaxy._link_systems(gate.x, gate.y)
	galaxy._assign_tiers()
	return galaxy


func get_sector(id: int) -> Sector:
	return sectors[id] if id >= 0 and id < sectors.size() else null


func system_of(id: int) -> StarSystem:
	return systems[sectors[id].system_id]


## Dark sectors on a lane from your territory: where you can invade next.
func frontier(conquered: Dictionary) -> Array[int]:
	var ids: Array[int] = []
	for sector in sectors:
		if can_invade(sector.id, conquered):
			ids.append(sector.id)
	return ids


func can_invade(id: int, conquered: Dictionary) -> bool:
	if conquered.has(id):
		return false
	for neighbor in sectors[id].neighbors:
		if conquered.has(neighbor):
			return true
	return false


## Dark sectors next to `id`, easiest first (where a run can push on to).
func dark_neighbors(id: int, conquered: Dictionary) -> Array[int]:
	var ids: Array[int] = []
	for neighbor in sectors[id].neighbors:
		if not conquered.has(neighbor):
			ids.append(neighbor)
	ids.sort_custom(func(a: int, b: int) -> bool: return sectors[a].tier < sectors[b].tier)
	return ids


func system_conquered(system_id: int, conquered: Dictionary) -> bool:
	for id in systems[system_id].sectors:
		if not conquered.has(id):
			return false
	return true


func systems_conquered(conquered: Dictionary) -> int:
	var count := 0
	for system in systems:
		if system_conquered(system.id, conquered):
			count += 1
	return count


func galaxy_conquered(conquered: Dictionary) -> bool:
	return conquered.size() >= sectors.size()


func _link(a: int, b: int) -> void:
	if a == b or sectors[a].neighbors.has(b):
		return
	sectors[a].neighbors.append(b)
	sectors[b].neighbors.append(a)


## A gate lane between the two closest sectors of two systems.
func _link_systems(a: int, b: int) -> void:
	var best_a := -1
	var best_b := -1
	var best := INF
	for id_a in systems[a].sectors:
		for id_b in systems[b].sectors:
			var distance := sectors[id_a].position.distance_to(sectors[id_b].position)
			if distance < best:
				best = distance
				best_a = id_a
				best_b = id_b
	_link(best_a, best_b)


func _assign_tiers() -> void:
	for sector in sectors:
		sector.tier = -1
	sectors[home_id].tier = 0
	var frontier_ids: Array[int] = [home_id]
	while not frontier_ids.is_empty():
		var id: int = frontier_ids.pop_front()
		for neighbor in sectors[id].neighbors:
			if sectors[neighbor].tier < 0:
				sectors[neighbor].tier = sectors[id].tier + 1
				frontier_ids.append(neighbor)
