class_name ChunkManager
extends RefCounted
## Manages chunk loading, unloading, and generation.
## Used by both server (authoritative) and client (cache).

signal chunk_loaded(chunk: Chunk)
signal chunk_unloaded(chunk_x: int, chunk_y: int)
signal chunk_modified(chunk: Chunk, local_x: int, local_y: int)

# Planet info
var planet_seed: int = 0
var planet_size: Vector2i = Vector2i(8000, 8000)  # In tiles
var planet_size_chunks: Vector2i = Vector2i(250, 250)  # In chunks

# Terrain generator
var generator: TerrainGenerator

# Loaded chunks
var chunks: Dictionary = {}  # "x,y" -> Chunk

# Modified chunk deltas (for persistence)
var chunk_deltas: Dictionary = {}  # "x,y" -> delta dict

# Configuration
var max_loaded_chunks: int = 256  # Max chunks to keep in memory
var unload_distance: int = 10  # Chunks beyond this distance get unloaded


func _init(seed: int = 0, size: Vector2i = Vector2i(8000, 8000)) -> void:
	planet_seed = seed
	planet_size = size
	planet_size_chunks = Vector2i(
		ceili(float(size.x) / Chunk.SIZE),
		ceili(float(size.y) / Chunk.SIZE)
	)
	generator = TerrainGenerator.new(seed, size)


## Get or generate a chunk at chunk coordinates
func get_chunk(chunk_x: int, chunk_y: int) -> Chunk:
	var key := Chunk.make_key(chunk_x, chunk_y)

	# Return cached chunk if available
	if chunks.has(key):
		return chunks[key]

	# Generate new chunk
	var chunk := generator.generate_chunk(chunk_x, chunk_y)

	# Apply any saved deltas
	if chunk_deltas.has(key):
		chunk.apply_delta(chunk_deltas[key])

	# Cache it
	chunks[key] = chunk
	chunk_loaded.emit(chunk)

	return chunk


## Check if chunk is loaded
func is_chunk_loaded(chunk_x: int, chunk_y: int) -> bool:
	return chunks.has(Chunk.make_key(chunk_x, chunk_y))


## Unload a chunk (saves delta if modified)
func unload_chunk(chunk_x: int, chunk_y: int) -> void:
	var key := Chunk.make_key(chunk_x, chunk_y)
	if not chunks.has(key):
		return

	var chunk: Chunk = chunks[key]

	# Save delta if modified
	if chunk.is_modified:
		chunk_deltas[key] = chunk.get_delta()

	chunks.erase(key)
	chunk_unloaded.emit(chunk_x, chunk_y)


## Get tile at world coordinates
func get_tile(world_x: int, world_y: int) -> int:
	var chunk_x := world_x / Chunk.SIZE
	var chunk_y := world_y / Chunk.SIZE
	var local_x := world_x % Chunk.SIZE
	var local_y := world_y % Chunk.SIZE

	# Handle negative coordinates
	if world_x < 0:
		chunk_x -= 1
		local_x = Chunk.SIZE + (world_x % Chunk.SIZE)
		if local_x == Chunk.SIZE:
			local_x = 0
			chunk_x += 1
	if world_y < 0:
		chunk_y -= 1
		local_y = Chunk.SIZE + (world_y % Chunk.SIZE)
		if local_y == Chunk.SIZE:
			local_y = 0
			chunk_y += 1

	var chunk := get_chunk(chunk_x, chunk_y)
	return chunk.get_tile(local_x, local_y)


## Set tile at world coordinates
func set_tile(world_x: int, world_y: int, tile_type: int) -> void:
	var chunk_x := world_x / Chunk.SIZE
	var chunk_y := world_y / Chunk.SIZE
	var local_x := world_x % Chunk.SIZE
	var local_y := world_y % Chunk.SIZE

	# Handle negative coordinates
	if world_x < 0:
		chunk_x -= 1
		local_x = Chunk.SIZE + (world_x % Chunk.SIZE)
		if local_x == Chunk.SIZE:
			local_x = 0
			chunk_x += 1
	if world_y < 0:
		chunk_y -= 1
		local_y = Chunk.SIZE + (world_y % Chunk.SIZE)
		if local_y == Chunk.SIZE:
			local_y = 0
			chunk_y += 1

	var chunk := get_chunk(chunk_x, chunk_y)
	chunk.set_tile(local_x, local_y, tile_type)
	chunk_modified.emit(chunk, local_x, local_y)


## Get elevation at world coordinates
func get_elevation(world_x: int, world_y: int) -> int:
	var chunk_coords := world_to_chunk_coords(world_x, world_y)
	var local_coords := world_to_local_coords(world_x, world_y)
	var chunk := get_chunk(chunk_coords.x, chunk_coords.y)
	return chunk.get_elevation(local_coords.x, local_coords.y)


## Convert world coords to chunk coords
func world_to_chunk_coords(world_x: int, world_y: int) -> Vector2i:
	var chunk_x := world_x / Chunk.SIZE
	var chunk_y := world_y / Chunk.SIZE
	if world_x < 0 and world_x % Chunk.SIZE != 0:
		chunk_x -= 1
	if world_y < 0 and world_y % Chunk.SIZE != 0:
		chunk_y -= 1
	return Vector2i(chunk_x, chunk_y)


## Convert world coords to local coords within chunk
func world_to_local_coords(world_x: int, world_y: int) -> Vector2i:
	var local_x := world_x % Chunk.SIZE
	var local_y := world_y % Chunk.SIZE
	if local_x < 0:
		local_x += Chunk.SIZE
	if local_y < 0:
		local_y += Chunk.SIZE
	return Vector2i(local_x, local_y)


## Load chunks around a position (in world coordinates)
func load_chunks_around(world_x: int, world_y: int, radius: int = 5) -> Array[Chunk]:
	var center_chunk := world_to_chunk_coords(world_x, world_y)
	var loaded: Array[Chunk] = []

	for cy in range(center_chunk.y - radius, center_chunk.y + radius + 1):
		for cx in range(center_chunk.x - radius, center_chunk.x + radius + 1):
			# Skip if out of planet bounds
			if cx < 0 or cy < 0 or cx >= planet_size_chunks.x or cy >= planet_size_chunks.y:
				continue

			var chunk := get_chunk(cx, cy)
			loaded.append(chunk)

	return loaded


## Unload chunks far from any given positions
func unload_distant_chunks(positions: Array[Vector2]) -> void:
	var chunks_to_keep: Dictionary = {}

	# Mark chunks near any position as needed
	for pos in positions:
		var center := world_to_chunk_coords(int(pos.x / 16), int(pos.y / 16))
		for cy in range(center.y - unload_distance, center.y + unload_distance + 1):
			for cx in range(center.x - unload_distance, center.x + unload_distance + 1):
				chunks_to_keep[Chunk.make_key(cx, cy)] = true

	# Unload chunks not needed
	var to_unload: Array[String] = []
	for key in chunks:
		if not chunks_to_keep.has(key):
			to_unload.append(key)

	for key in to_unload:
		var parts := key.split(",")
		unload_chunk(int(parts[0]), int(parts[1]))


## Get all loaded chunks
func get_loaded_chunks() -> Array[Chunk]:
	var result: Array[Chunk] = []
	for chunk in chunks.values():
		result.append(chunk)
	return result


## Get count of loaded chunks
func get_loaded_chunk_count() -> int:
	return chunks.size()


## Check if a world position is passable (not solid)
func is_passable(world_x: int, world_y: int) -> bool:
	var tile := get_tile(world_x, world_y)
	return not TileTypes.is_solid(tile)


## Get movement speed multiplier at world position
func get_move_speed_mult(world_x: int, world_y: int) -> float:
	var tile := get_tile(world_x, world_y)
	return TileTypes.get_walk_speed(tile)


## Save all chunk deltas to dictionary (for persistence)
func save_deltas() -> Dictionary:
	# First, collect deltas from all currently loaded chunks
	for key in chunks:
		var chunk: Chunk = chunks[key]
		if chunk.is_modified:
			chunk_deltas[key] = chunk.get_delta()

	return chunk_deltas.duplicate(true)


## Load chunk deltas from dictionary
func load_deltas(deltas: Dictionary) -> void:
	chunk_deltas = deltas.duplicate(true)


## Clear all loaded chunks
func clear() -> void:
	for key in chunks.keys():
		var parts: PackedStringArray = key.split(",")
		unload_chunk(int(parts[0]), int(parts[1]))
	chunks.clear()


## Get biome at world position
func get_biome_at(world_x: int, world_y: int) -> int:
	return generator.get_biome_at(world_x, world_y)


## Get biome name at world position
func get_biome_name_at(world_x: int, world_y: int) -> String:
	var biome := generator.get_biome_at(world_x, world_y)
	return TerrainGenerator.get_biome_name(biome)
