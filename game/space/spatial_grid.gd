class_name SpatialGrid
extends RefCounted
## Buckets items by position so nearby lookups don't scan everything.
## Rebuild it each frame; callers do the exact distance test on the results.

var cell_size: float

var _cells: Dictionary = {}  # Vector2i -> Array


func _init(p_cell_size: float = 96.0) -> void:
	cell_size = p_cell_size


func clear() -> void:
	_cells.clear()


func insert(item: Object, point: Vector2) -> void:
	var key := _key(point)
	if not _cells.has(key):
		_cells[key] = []
	_cells[key].append(item)


## Items in every cell the circle touches.
func query(point: Vector2, radius: float) -> Array:
	var result: Array = []
	var low := _key(point - Vector2(radius, radius))
	var high := _key(point + Vector2(radius, radius))
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			var bucket: Variant = _cells.get(Vector2i(x, y))
			if bucket != null:
				result.append_array(bucket)
	return result


func _key(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / cell_size), floori(point.y / cell_size))
