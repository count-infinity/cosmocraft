extends GutTest

const TileTypesScript = preload("res://shared/world/tile_types.gd")

func test_tile_type_enum_values() -> void:
	assert_eq(TileTypes.Type.AIR, 0, "AIR should be 0")
	assert_eq(TileTypes.Type.GRASS, 1, "GRASS should be 1")
	assert_eq(TileTypes.Type.WATER, 4, "WATER should be 4")

func test_get_properties_returns_valid_properties() -> void:
	var props := TileTypes.get_properties(TileTypes.Type.GRASS)
	assert_not_null(props, "Should return properties for GRASS")
	assert_eq(props.name, "Grass", "Name should be Grass")
	assert_eq(props.type_id, TileTypes.Type.GRASS, "Type ID should match")

func test_get_properties_fallback_for_invalid() -> void:
	var props := TileTypes.get_properties(9999)
	assert_not_null(props, "Should return fallback for invalid type")
	assert_eq(props.type_id, TileTypes.Type.AIR, "Fallback should be AIR")

func test_is_solid() -> void:
	assert_false(TileTypes.is_solid(TileTypes.Type.AIR), "AIR should not be solid")
	assert_false(TileTypes.is_solid(TileTypes.Type.GRASS), "GRASS should not be solid")
	assert_true(TileTypes.is_solid(TileTypes.Type.STONE), "STONE should be solid")
	assert_true(TileTypes.is_solid(TileTypes.Type.TREE_TRUNK), "TREE_TRUNK should be solid")

func test_is_mineable() -> void:
	assert_false(TileTypes.is_mineable(TileTypes.Type.AIR), "AIR should not be mineable")
	assert_true(TileTypes.is_mineable(TileTypes.Type.DIRT), "DIRT should be mineable")
	assert_true(TileTypes.is_mineable(TileTypes.Type.STONE), "STONE should be mineable")

func test_is_liquid() -> void:
	assert_false(TileTypes.is_liquid(TileTypes.Type.GRASS), "GRASS should not be liquid")
	assert_true(TileTypes.is_liquid(TileTypes.Type.WATER), "WATER should be liquid")

func test_is_transparent() -> void:
	assert_true(TileTypes.is_transparent(TileTypes.Type.AIR), "AIR should be transparent")
	assert_true(TileTypes.is_transparent(TileTypes.Type.GRASS), "GRASS should be transparent")
	assert_false(TileTypes.is_transparent(TileTypes.Type.STONE), "STONE should not be transparent")

func test_walk_speed() -> void:
	assert_eq(TileTypes.get_walk_speed(TileTypes.Type.GRASS), 1.0, "GRASS walk speed should be 1.0")
	assert_eq(TileTypes.get_walk_speed(TileTypes.Type.WATER), 0.5, "WATER walk speed should be 0.5")
	assert_eq(TileTypes.get_walk_speed(TileTypes.Type.STONE), 0.0, "STONE walk speed should be 0.0 (impassable)")

func test_light_properties() -> void:
	assert_eq(TileTypes.get_light_emission(TileTypes.Type.GRASS), 0, "GRASS should not emit light")
	assert_eq(TileTypes.get_light_blocking(TileTypes.Type.STONE), 15, "STONE should block all light")
	assert_eq(TileTypes.get_light_blocking(TileTypes.Type.WATER), 2, "WATER should partially block light")

func test_variant_count() -> void:
	assert_gt(TileTypes.get_variant_count(TileTypes.Type.GRASS), 0, "GRASS should have variants")
	assert_gt(TileTypes.get_variant_count(TileTypes.Type.FLOWER), 1, "FLOWER should have multiple variants")

func test_tile_name() -> void:
	assert_eq(TileTypes.get_tile_name(TileTypes.Type.GRASS), "Grass", "Should return correct name")
	assert_eq(TileTypes.get_tile_name(TileTypes.Type.WATER), "Water", "Should return correct name")
