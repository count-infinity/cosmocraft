class_name RegionData
extends RefCounted
## One claimable polygon of space. Regions are built from one or more Voronoi
## cells, so bigger ones can be irregular and non-convex.

enum Modifier { NONE, NEST, RICH, ASTEROIDS, NEBULA }

const MODIFIER_NAMES := {
	Modifier.NONE: "",
	Modifier.NEST: "NEST",
	Modifier.RICH: "RICH",
	Modifier.ASTEROIDS: "ASTEROIDS",
	Modifier.NEBULA: "NEBULA",
}
const MODIFIER_HINTS := {
	Modifier.NONE: "",
	Modifier.NEST: "twice the Gloom, more sparks",
	Modifier.RICH: "better loot when it ignites",
	Modifier.ASTEROIDS: "rocks block shots and ships",
	Modifier.NEBULA: "you can barely see until it's lit",
}

var id := -1
var name := ""
var site := Vector2.ZERO
var polygon := PackedVector2Array()
var area := 0.0
var centroid := Vector2.ZERO
## A point guaranteed to be inside the region (the centroid of a merged
## region can fall outside it). Used for markers, labels and the beacon.
var anchor := Vector2.ZERO
var cell_count := 1
var neighbors: Array[int] = []
## Neighbor across each edge (polygon[i] to polygon[i + 1]), or -1 on the sector rim.
var edge_neighbors: Array[int] = []
## Steps from the home region. Deeper regions are more dangerous.
var depth := 0
var claim_seconds := 60.0
var claimed := false
var modifier := Modifier.NONE
## The run's goal: the biggest region deep in the dark, guarded by a boss.
var is_heart := false
## Where the region's spark was ignited; drawn as a beacon once claimed.
var beacon := Vector2.ZERO
var nebula_color := Color.WHITE


func contains(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, polygon)


func modifier_name() -> String:
	return MODIFIER_NAMES[modifier]


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
