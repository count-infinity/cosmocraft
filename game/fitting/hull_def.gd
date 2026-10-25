class_name HullDef
extends RefCounted
## A ship hull: the shape of its fitting grid, where its hardpoints are, and its
## base numbers. Bigger hull classes fit bigger parts, like Stars Without
## Number's fighter, frigate and cruiser classes.
##
## Grid rows read nose (top) to stern (bottom): "." is no cell, "#" an open
## cell, "H" a hardpoint where weapons can mount.

enum Cell { VOID, OPEN, HARDPOINT }

## Pixels between mount points on the ship sprite, per grid cell.
const MOUNT_SPACING := 5.0

var id := ""
var display_name := ""
var hull_class := 1
var rows: Array[String] = []
var base_hull := 100.0
var base_shield := 20.0
var power := 4
var speed_scale := 1.0
## Collision radius and sprite scale in the world.
var radius := 11.0
var sprite_scale := 1.0


static func skiff() -> HullDef:
	var hull := HullDef.new()
	hull.id = "skiff"
	hull.display_name = "Skiff"
	hull.hull_class = 1
	hull.rows = [
		"..H..",
		".###.",
		"H###H",
		"#####",
		"#...#",
	]
	hull.base_hull = 100.0
	hull.base_shield = 20.0
	hull.power = 4
	return hull


static func corvette() -> HullDef:
	var hull := HullDef.new()
	hull.id = "corvette"
	hull.display_name = "Corvette"
	hull.hull_class = 2
	hull.rows = [
		"...H...",
		"..###..",
		".H###H.",
		"#######",
		"H#####H",
		"#######",
		".#...#.",
	]
	hull.base_hull = 150.0
	hull.base_shield = 30.0
	hull.power = 7
	hull.speed_scale = 0.94
	hull.radius = 14.0
	hull.sprite_scale = 1.3
	return hull


static func by_id(hull_id: String) -> HullDef:
	return corvette() if hull_id == "corvette" else skiff()


func size() -> Vector2i:
	return Vector2i(rows[0].length(), rows.size())


func cell(c: Vector2i) -> Cell:
	if c.y < 0 or c.y >= rows.size() or c.x < 0 or c.x >= rows[c.y].length():
		return Cell.VOID
	match rows[c.y][c.x]:
		"#":
			return Cell.OPEN
		"H":
			return Cell.HARDPOINT
	return Cell.VOID


func open_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in rows.size():
		for x in rows[y].length():
			if cell(Vector2i(x, y)) != Cell.VOID:
				cells.append(Vector2i(x, y))
	return cells


## Where a grid position sits on the ship sprite (ship faces +x).
func mount_offset(grid_center: Vector2) -> Vector2:
	var grid := Vector2(size())
	return Vector2(grid.y * 0.5 - grid_center.y, grid_center.x - grid.x * 0.5) * MOUNT_SPACING * sprite_scale
