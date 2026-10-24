class_name RegionData
extends RefCounted
## One claimable polygon of space.

var id := -1
var name := ""
var site := Vector2.ZERO
var polygon := PackedVector2Array()
var area := 0.0
var centroid := Vector2.ZERO
var neighbors: Array[int] = []
## Neighbor across each edge (polygon[i] to polygon[i + 1]), or -1 on the sector rim.
var edge_neighbors: Array[int] = []
## Steps from the home region. Deeper regions are more dangerous.
var depth := 0
var claim_seconds := 60.0
var claimed := false
## Where the region's spark was ignited; drawn as a beacon once claimed.
var beacon := Vector2.ZERO
var nebula_color := Color.WHITE


func contains(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, polygon)


## Unit normal of edge i, pointing out of the region.
func edge_outward_normal(i: int) -> Vector2:
	var a := polygon[i]
	var b := polygon[(i + 1) % polygon.size()]
	var normal := (b - a).orthogonal().normalized()
	if contains((a + b) * 0.5 + normal * 2.0):
		normal = -normal
	return normal


func edge_length(i: int) -> float:
	return polygon[i].distance_to(polygon[(i + 1) % polygon.size()])
