class_name SectorData
extends RefCounted
## A generated sector: its ragged boundary and the regions inside it.

var sector_seed := 0
var radius := 0.0
var boundary := PackedVector2Array()
var regions: Array[RegionData] = []
var home_id := -1


func get_region(id: int) -> RegionData:
	if id < 0 or id >= regions.size():
		return null
	return regions[id]


func home() -> RegionData:
	return get_region(home_id)


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
