class_name TestWorld
extends Node2D

var background: ColorRect
var grid: Node2D
var boundary: Line2D

func _ready() -> void:
	_create_background()
	_create_grid()
	_create_boundary()

func _create_background() -> void:
	background = ColorRect.new()
	background.size = Vector2(GameConstants.WORLD_WIDTH, GameConstants.WORLD_HEIGHT)
	background.color = Color(0.05, 0.05, 0.15)  # Dark space blue
	background.z_index = -10
	add_child(background)

func _create_grid() -> void:
	grid = Node2D.new()
	grid.z_index = -5
	add_child(grid)

	var grid_color := Color(0.1, 0.1, 0.25, 0.5)
	var grid_spacing := 100.0

	# Vertical lines
	var x := 0.0
	while x <= GameConstants.WORLD_WIDTH:
		var line := Line2D.new()
		line.add_point(Vector2(x, 0))
		line.add_point(Vector2(x, GameConstants.WORLD_HEIGHT))
		line.width = 1
		line.default_color = grid_color
		grid.add_child(line)
		x += grid_spacing

	# Horizontal lines
	var y := 0.0
	while y <= GameConstants.WORLD_HEIGHT:
		var line := Line2D.new()
		line.add_point(Vector2(0, y))
		line.add_point(Vector2(GameConstants.WORLD_WIDTH, y))
		line.width = 1
		line.default_color = grid_color
		grid.add_child(line)
		y += grid_spacing

func _create_boundary() -> void:
	boundary = Line2D.new()
	boundary.add_point(Vector2(0, 0))
	boundary.add_point(Vector2(GameConstants.WORLD_WIDTH, 0))
	boundary.add_point(Vector2(GameConstants.WORLD_WIDTH, GameConstants.WORLD_HEIGHT))
	boundary.add_point(Vector2(0, GameConstants.WORLD_HEIGHT))
	boundary.add_point(Vector2(0, 0))  # Close the loop
	boundary.width = 3
	boundary.default_color = Color(0.8, 0.2, 0.2)  # Red boundary
	boundary.z_index = -1
	add_child(boundary)
