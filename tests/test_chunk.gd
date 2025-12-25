extends GutTest

const TileTypesScript = preload("res://shared/world/tile_types.gd")
const ChunkScript = preload("res://shared/world/chunk.gd")

var chunk: Chunk

func before_each() -> void:
	chunk = Chunk.new(5, 10)

func test_initial_state() -> void:
	assert_eq(chunk.chunk_x, 5, "Chunk X should be 5")
	assert_eq(chunk.chunk_y, 10, "Chunk Y should be 10")
	assert_eq(chunk.tiles.size(), Chunk.TILE_COUNT, "Should have correct tile count")
	assert_false(chunk.is_modified, "Should not be modified initially")

func test_chunk_size() -> void:
	assert_eq(Chunk.SIZE, 32, "Chunk size should be 32")
	assert_eq(Chunk.TILE_COUNT, 1024, "Tile count should be 1024")

func test_coords_to_index() -> void:
	assert_eq(Chunk.coords_to_index(0, 0), 0, "0,0 should be index 0")
	assert_eq(Chunk.coords_to_index(1, 0), 1, "1,0 should be index 1")
	assert_eq(Chunk.coords_to_index(0, 1), 32, "0,1 should be index 32")
	assert_eq(Chunk.coords_to_index(31, 31), 1023, "31,31 should be index 1023")

func test_index_to_coords() -> void:
	assert_eq(Chunk.index_to_coords(0), Vector2i(0, 0), "Index 0 should be 0,0")
	assert_eq(Chunk.index_to_coords(1), Vector2i(1, 0), "Index 1 should be 1,0")
	assert_eq(Chunk.index_to_coords(32), Vector2i(0, 1), "Index 32 should be 0,1")
	assert_eq(Chunk.index_to_coords(1023), Vector2i(31, 31), "Index 1023 should be 31,31")

func test_get_world_coords() -> void:
	var world := chunk.get_world_coords(5, 10)
	assert_eq(world.x, 5 * 32 + 5, "World X should be chunk*32 + local")
	assert_eq(world.y, 10 * 32 + 10, "World Y should be chunk*32 + local")

func test_get_set_tile() -> void:
	assert_eq(chunk.get_tile(5, 5), TileTypes.Type.AIR, "Default tile should be AIR")

	chunk.set_tile(5, 5, TileTypes.Type.GRASS)
	assert_eq(chunk.get_tile(5, 5), TileTypes.Type.GRASS, "Should be GRASS after set")

func test_get_tile_out_of_bounds() -> void:
	assert_eq(chunk.get_tile(-1, 0), TileTypes.Type.AIR, "Out of bounds should return AIR")
	assert_eq(chunk.get_tile(32, 0), TileTypes.Type.AIR, "Out of bounds should return AIR")
	assert_eq(chunk.get_tile(0, -1), TileTypes.Type.AIR, "Out of bounds should return AIR")
	assert_eq(chunk.get_tile(0, 32), TileTypes.Type.AIR, "Out of bounds should return AIR")

func test_set_tile_tracks_modification() -> void:
	assert_false(chunk.is_modified, "Should not be modified initially")

	chunk.set_tile(5, 5, TileTypes.Type.GRASS)
	assert_true(chunk.is_modified, "Should be modified after set")

func test_set_tile_same_type_no_modification() -> void:
	chunk.set_tile(5, 5, TileTypes.Type.GRASS, -1, false)
	chunk.is_modified = false
	chunk.modified_tiles.clear()

	chunk.set_tile(5, 5, TileTypes.Type.GRASS)
	assert_false(chunk.is_modified, "Setting same type should not mark modified")

func test_elevation() -> void:
	assert_eq(chunk.get_elevation(0, 0), 100, "Default elevation should be 100")

	chunk.set_elevation(5, 5, 200)
	assert_eq(chunk.get_elevation(5, 5), 200, "Elevation should be updated")

func test_elevation_clamping() -> void:
	chunk.set_elevation(0, 0, 300)
	assert_eq(chunk.get_elevation(0, 0), 255, "Elevation should be clamped to 255")

	chunk.set_elevation(0, 0, -50)
	assert_eq(chunk.get_elevation(0, 0), 0, "Elevation should be clamped to 0")

func test_light_level() -> void:
	assert_eq(chunk.get_light_level(0, 0), 15, "Default light should be 15")

	chunk.set_light_level(5, 5, 8)
	assert_eq(chunk.get_light_level(5, 5), 8, "Light level should be updated")

func test_liquid_level() -> void:
	assert_eq(chunk.get_liquid_level(0, 0), 0, "Default liquid should be 0")

	chunk.set_liquid_level(5, 5, 10)
	assert_eq(chunk.get_liquid_level(5, 5), 10, "Liquid level should be updated")

func test_fill() -> void:
	chunk.fill(TileTypes.Type.STONE)

	for i in range(Chunk.TILE_COUNT):
		var coords := Chunk.index_to_coords(i)
		assert_eq(chunk.get_tile(coords.x, coords.y), TileTypes.Type.STONE, "All tiles should be STONE")

func test_get_key() -> void:
	assert_eq(chunk.get_key(), "5,10", "Key should be 'chunk_x,chunk_y'")

func test_make_key_static() -> void:
	assert_eq(Chunk.make_key(3, 7), "3,7", "Static make_key should work")

func test_to_dict() -> void:
	chunk.set_tile(5, 5, TileTypes.Type.GRASS)
	chunk.set_elevation(5, 5, 150)

	var dict := chunk.to_dict()
	assert_eq(dict["x"], 5, "Dict should have correct x")
	assert_eq(dict["y"], 10, "Dict should have correct y")
	assert_true(dict.has("tiles"), "Dict should have tiles")
	assert_true(dict.has("elevation"), "Dict should have elevation")
	assert_true(dict["modified"], "Dict should show modified")

func test_from_dict() -> void:
	chunk.set_tile(5, 5, TileTypes.Type.WATER)
	chunk.set_elevation(5, 5, 50)

	var dict := chunk.to_dict()
	var restored := Chunk.from_dict(dict)

	assert_eq(restored.chunk_x, 5, "Restored X should match")
	assert_eq(restored.chunk_y, 10, "Restored Y should match")
	assert_eq(restored.get_tile(5, 5), TileTypes.Type.WATER, "Restored tile should match")
	assert_eq(restored.get_elevation(5, 5), 50, "Restored elevation should match")

func test_get_delta_empty() -> void:
	var delta := chunk.get_delta()
	assert_eq(delta.size(), 0, "Unmodified chunk should have empty delta")

func test_get_delta_with_changes() -> void:
	chunk.set_tile(5, 5, TileTypes.Type.GRASS)
	chunk.set_tile(10, 10, TileTypes.Type.STONE)

	var delta := chunk.get_delta()
	assert_eq(delta.size(), 2, "Delta should have 2 entries")
	assert_true(delta.has("5,5"), "Delta should have 5,5")
	assert_true(delta.has("10,10"), "Delta should have 10,10")

func test_apply_delta() -> void:
	var delta := {
		"3,3": {"type": TileTypes.Type.WATER, "variant": 0, "liquid": 15},
		"7,7": {"type": TileTypes.Type.SAND, "variant": 2, "liquid": 0}
	}

	chunk.apply_delta(delta)

	assert_eq(chunk.get_tile(3, 3), TileTypes.Type.WATER, "Applied tile should be WATER")
	assert_eq(chunk.get_tile(7, 7), TileTypes.Type.SAND, "Applied tile should be SAND")
	assert_true(chunk.is_modified, "Chunk should be marked modified")

func test_variant_persistence() -> void:
	chunk.set_tile_full(5, 5, TileTypes.Type.FLOWER, 3, 0)
	assert_eq(chunk.get_variant(5, 5), 3, "Variant should be 3")

	# Changing to same type should preserve variant if not specified
	chunk.set_tile(5, 5, TileTypes.Type.FLOWER)
	assert_eq(chunk.get_variant(5, 5), 3, "Variant should still be 3")
