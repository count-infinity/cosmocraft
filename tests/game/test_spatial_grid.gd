extends GutTest

var grid: SpatialGrid


func before_each() -> void:
	grid = SpatialGrid.new(100.0)


func test_finds_items_in_the_same_cell() -> void:
	var item := RefCounted.new()
	grid.insert(item, Vector2(50, 50))
	assert_has(grid.query(Vector2(60, 60), 5.0), item, "Same cell")


func test_finds_items_across_cell_borders() -> void:
	var item := RefCounted.new()
	grid.insert(item, Vector2(105, 50))
	assert_has(grid.query(Vector2(95, 50), 20.0), item, "Neighboring cell within reach")


func test_skips_far_items() -> void:
	var item := RefCounted.new()
	grid.insert(item, Vector2(1000, 1000))
	assert_does_not_have(grid.query(Vector2(0, 0), 50.0), item, "Far away")


func test_handles_negative_coordinates() -> void:
	var item := RefCounted.new()
	grid.insert(item, Vector2(-30, -30))
	assert_has(grid.query(Vector2(-10, -10), 5.0), item, "Negative cell")
	assert_does_not_have(grid.query(Vector2(30, 30), 5.0), item, "Positive cell is separate")


func test_clear_empties_the_grid() -> void:
	grid.insert(RefCounted.new(), Vector2.ZERO)
	grid.clear()
	assert_eq(grid.query(Vector2.ZERO, 10.0).size(), 0, "Nothing left after clear")
