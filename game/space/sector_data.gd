class_name SectorData
extends RefCounted
## A generated sector: its ragged boundary, the regions inside it, and the
## asteroids scattered through asteroid-field regions.


class Asteroid:
	var position := Vector2.ZERO
	var radius := 30.0
	## Outline relative to position.
	var outline := PackedVector2Array()
	var region_id := -1


var sector_seed := 0
var radius := 0.0
var boundary := PackedVector2Array()
var regions: Array[RegionData] = []
var asteroids: Array[Asteroid] = []
var planets: Array[PlanetData] = []
var home_id := -1
var heart_id := -1


func get_region(id: int) -> RegionData:
	if id < 0 or id >= regions.size():
		return null
	return regions[id]


func home() -> RegionData:
	return get_region(home_id)


func heart() -> RegionData:
	return get_region(heart_id)


## Id of the region containing the point, or -1 outside the sector.
func region_at(point: Vector2) -> int:
	for region in regions:
		if region.contains(point):
			return region.id
	return -1


## A region can be claimed when it is still dark and borders your territory.
func is_frontier(id: int) -> bool:
	var region := get_region(id)
	if region == null or region.claimed:
		return false
	for neighbor_id in region.neighbors:
		if regions[neighbor_id].claimed:
			return true
	return false


func claimed_count() -> int:
	var count := 0
	for region in regions:
		if region.claimed:
			count += 1
	return count


## Fewest claims needed to reach the heart from current territory (0 once it's
## claimed, or -1 if unreachable).
func steps_to_heart() -> int:
	if heart_id < 0:
		return -1
	if regions[heart_id].claimed:
		return 0
	var distance := {}
	var queue: Array[int] = []
	for region in regions:
		if region.claimed:
			distance[region.id] = 0
			queue.append(region.id)
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for neighbor_id in regions[current].neighbors:
			if distance.has(neighbor_id):
				continue
			distance[neighbor_id] = int(distance[current]) + 1
			if neighbor_id == heart_id:
				return int(distance[neighbor_id])
			queue.append(neighbor_id)
	return -1
