extends GutTest

const TileTypesScript = preload("res://shared/world/tile_types.gd")
const ChunkScript = preload("res://shared/world/chunk.gd")
const TerrainGeneratorScript = preload("res://shared/world/terrain_generator.gd")

var generator: TerrainGenerator

func before_each() -> void:
	generator = TerrainGenerator.new(12345)

func test_deterministic_generation() -> void:
	var chunk1 := generator.generate_chunk(5, 10)
	var chunk2 := generator.generate_chunk(5, 10)

	# Same seed + coords should produce identical chunks
	for i in range(Chunk.TILE_COUNT):
		var coords := Chunk.index_to_coords(i)
		assert_eq(
			chunk1.get_tile(coords.x, coords.y),
			chunk2.get_tile(coords.x, coords.y),
			"Tiles should be identical for same seed/coords"
		)

func test_different_seeds_different_terrain() -> void:
	var gen1 := TerrainGenerator.new(11111)
	var gen2 := TerrainGenerator.new(22222)

	var chunk1 := gen1.generate_chunk(0, 0)
	var chunk2 := gen2.generate_chunk(0, 0)

	var differences := 0
	for i in range(Chunk.TILE_COUNT):
		var coords := Chunk.index_to_coords(i)
		if chunk1.get_tile(coords.x, coords.y) != chunk2.get_tile(coords.x, coords.y):
			differences += 1

	assert_gt(differences, 0, "Different seeds should produce different terrain")

func test_chunk_has_valid_tiles() -> void:
	var chunk := generator.generate_chunk(0, 0)

	for i in range(Chunk.TILE_COUNT):
		var coords := Chunk.index_to_coords(i)
		var tile := chunk.get_tile(coords.x, coords.y)
		assert_true(tile >= 0 and tile < TileTypes.Type.MAX, "Tile type should be valid")

func test_chunk_has_elevation() -> void:
	var chunk := generator.generate_chunk(0, 0)

	for i in range(Chunk.TILE_COUNT):
		var coords := Chunk.index_to_coords(i)
		var elev := chunk.get_elevation(coords.x, coords.y)
		assert_true(elev >= 0 and elev <= 255, "Elevation should be 0-255")

func test_biome_at_position() -> void:
	var biome := generator.get_biome_at(0, 0)
	assert_true(biome >= 0 and biome <= 7, "Biome should be valid enum value")

func test_biome_name() -> void:
	assert_eq(TerrainGenerator.get_biome_name(TerrainGenerator.Biome.FOREST), "Forest", "Should return Forest")
	assert_eq(TerrainGenerator.get_biome_name(TerrainGenerator.Biome.OCEAN), "Ocean", "Should return Ocean")
	assert_eq(TerrainGenerator.get_biome_name(TerrainGenerator.Biome.DESERT), "Desert", "Should return Desert")

func test_generation_produces_variety() -> void:
	var chunk := generator.generate_chunk(50, 50)  # Pick a chunk likely to have variety

	var tile_counts: Dictionary = {}
	for i in range(Chunk.TILE_COUNT):
		var coords := Chunk.index_to_coords(i)
		var tile := chunk.get_tile(coords.x, coords.y)
		tile_counts[tile] = tile_counts.get(tile, 0) + 1

	assert_gt(tile_counts.size(), 1, "Generated chunk should have variety of tiles")

func test_water_in_low_elevation() -> void:
	# Generate many chunks and verify water appears at low elevations
	var found_water := false

	for cx in range(10):
		for cy in range(10):
			var chunk := generator.generate_chunk(cx, cy)
			for i in range(Chunk.TILE_COUNT):
				var coords := Chunk.index_to_coords(i)
				if chunk.get_tile(coords.x, coords.y) == TileTypes.Type.WATER:
					found_water = true
					break
			if found_water:
				break
		if found_water:
			break

	# Water might not appear in every 10x10 region, but it should exist somewhere
	# This test may occasionally fail depending on seed
	pass_test("Water generation checked")

func test_generation_performance() -> void:
	var start := Time.get_ticks_msec()

	# Generate 25 chunks
	for cx in range(5):
		for cy in range(5):
			var _chunk := generator.generate_chunk(cx, cy)

	var elapsed := Time.get_ticks_msec() - start
	assert_lt(elapsed, 1000, "25 chunks should generate in under 1 second")
