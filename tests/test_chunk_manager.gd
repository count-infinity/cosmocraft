extends GutTest

const TileTypesScript = preload("res://shared/world/tile_types.gd")
const ChunkScript = preload("res://shared/world/chunk.gd")
const TerrainGeneratorScript = preload("res://shared/world/terrain_generator.gd")
const ChunkManagerScript = preload("res://shared/world/chunk_manager.gd")

var manager: ChunkManager

func before_each() -> void:
	manager = ChunkManager.new(12345)

func test_initial_state() -> void:
	assert_eq(manager.planet_seed, 12345, "Seed should be set")
	assert_eq(manager.get_loaded_chunk_count(), 0, "Should have no loaded chunks initially")

func test_get_chunk_loads_chunk() -> void:
	var chunk := manager.get_chunk(5, 10)

	assert_not_null(chunk, "Should return a chunk")
	assert_eq(chunk.chunk_x, 5, "Chunk X should be correct")
	assert_eq(chunk.chunk_y, 10, "Chunk Y should be correct")
	assert_eq(manager.get_loaded_chunk_count(), 1, "Should have 1 loaded chunk")

func test_get_chunk_caches_chunk() -> void:
	var chunk1 := manager.get_chunk(5, 10)
	var chunk2 := manager.get_chunk(5, 10)

	assert_eq(chunk1, chunk2, "Should return same cached chunk")
	assert_eq(manager.get_loaded_chunk_count(), 1, "Should still have 1 loaded chunk")

func test_is_chunk_loaded() -> void:
	assert_false(manager.is_chunk_loaded(5, 10), "Should not be loaded initially")

	var _chunk := manager.get_chunk(5, 10)
	assert_true(manager.is_chunk_loaded(5, 10), "Should be loaded after get")

func test_unload_chunk() -> void:
	var _chunk := manager.get_chunk(5, 10)
	assert_true(manager.is_chunk_loaded(5, 10), "Should be loaded")

	manager.unload_chunk(5, 10)
	assert_false(manager.is_chunk_loaded(5, 10), "Should not be loaded after unload")

func test_get_tile_world_coords() -> void:
	# Tile at world (160, 320) is in chunk (5, 10) at local (0, 0)
	var tile := manager.get_tile(160, 320)
	# Just verify it returns something valid
	assert_true(tile >= 0, "Should return valid tile type")

func test_set_tile_world_coords() -> void:
	manager.set_tile(160, 320, TileTypes.Type.STONE)
	var tile := manager.get_tile(160, 320)
	assert_eq(tile, TileTypes.Type.STONE, "Should be STONE after set")

func test_world_to_chunk_coords() -> void:
	assert_eq(manager.world_to_chunk_coords(0, 0), Vector2i(0, 0), "0,0 should be chunk 0,0")
	assert_eq(manager.world_to_chunk_coords(31, 31), Vector2i(0, 0), "31,31 should be chunk 0,0")
	assert_eq(manager.world_to_chunk_coords(32, 32), Vector2i(1, 1), "32,32 should be chunk 1,1")
	assert_eq(manager.world_to_chunk_coords(160, 320), Vector2i(5, 10), "160,320 should be chunk 5,10")

func test_world_to_local_coords() -> void:
	assert_eq(manager.world_to_local_coords(0, 0), Vector2i(0, 0), "0,0 should be local 0,0")
	assert_eq(manager.world_to_local_coords(31, 31), Vector2i(31, 31), "31,31 should be local 31,31")
	assert_eq(manager.world_to_local_coords(32, 32), Vector2i(0, 0), "32,32 should be local 0,0")
	assert_eq(manager.world_to_local_coords(35, 37), Vector2i(3, 5), "35,37 should be local 3,5")

func test_load_chunks_around() -> void:
	var loaded := manager.load_chunks_around(500, 500, 2)

	# Should load (2*2+1)^2 = 25 chunks
	assert_eq(loaded.size(), 25, "Should load 25 chunks (5x5 around center)")
	assert_eq(manager.get_loaded_chunk_count(), 25, "Should have 25 loaded chunks")

func test_is_passable() -> void:
	manager.set_tile(100, 100, TileTypes.Type.GRASS)
	assert_true(manager.is_passable(100, 100), "GRASS should be passable")

	manager.set_tile(100, 100, TileTypes.Type.STONE)
	assert_false(manager.is_passable(100, 100), "STONE should not be passable")

func test_get_move_speed_mult() -> void:
	manager.set_tile(100, 100, TileTypes.Type.GRASS)
	assert_eq(manager.get_move_speed_mult(100, 100), 1.0, "GRASS speed should be 1.0")

	manager.set_tile(100, 100, TileTypes.Type.WATER)
	assert_eq(manager.get_move_speed_mult(100, 100), 0.5, "WATER speed should be 0.5")

func test_save_load_deltas() -> void:
	# Make some changes
	manager.set_tile(100, 100, TileTypes.Type.STONE)
	manager.set_tile(200, 200, TileTypes.Type.WATER)

	# Save deltas
	var deltas := manager.save_deltas()
	assert_gt(deltas.size(), 0, "Should have saved deltas")

	# Create new manager and load deltas
	var manager2 := ChunkManager.new(12345)
	manager2.load_deltas(deltas)

	# Get chunks - should have deltas applied
	var tile1 := manager2.get_tile(100, 100)
	var tile2 := manager2.get_tile(200, 200)

	assert_eq(tile1, TileTypes.Type.STONE, "Delta should be applied")
	assert_eq(tile2, TileTypes.Type.WATER, "Delta should be applied")

func test_get_biome_at() -> void:
	var biome := manager.get_biome_at(0, 0)
	assert_true(biome >= 0, "Should return valid biome")

func test_get_biome_name_at() -> void:
	var name := manager.get_biome_name_at(0, 0)
	assert_true(name.length() > 0, "Should return biome name")

func test_clear() -> void:
	var _loaded := manager.load_chunks_around(500, 500, 2)
	assert_gt(manager.get_loaded_chunk_count(), 0, "Should have loaded chunks")

	manager.clear()
	assert_eq(manager.get_loaded_chunk_count(), 0, "Should have no chunks after clear")

func test_chunk_loaded_signal() -> void:
	watch_signals(manager)
	var chunk := manager.get_chunk(5, 10)
	assert_signal_emitted(manager, "chunk_loaded", "Should emit chunk_loaded signal")

func test_chunk_unloaded_signal() -> void:
	watch_signals(manager)
	var _chunk := manager.get_chunk(5, 10)
	manager.unload_chunk(5, 10)
	assert_signal_emitted(manager, "chunk_unloaded", "Should emit chunk_unloaded signal")
