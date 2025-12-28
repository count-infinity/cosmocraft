class_name TerrainGenerator
extends RefCounted
## Procedural terrain generator using noise functions.
## Deterministic: same seed + coords = same terrain.

# Planet parameters
var planet_seed: int = 0
var planet_size: Vector2i = Vector2i(8000, 8000)  # In tiles

# Noise generators
var elevation_noise: FastNoiseLite
var temperature_noise: FastNoiseLite
var moisture_noise: FastNoiseLite
var detail_noise: FastNoiseLite
var feature_noise: FastNoiseLite

# Biome enum
enum Biome {
	OCEAN,
	BEACH,
	FOREST,
	PLAINS,
	DESERT,
	TUNDRA,
	ICE,
	SWAMP
}


func _init(seed: int = 0, size: Vector2i = Vector2i(8000, 8000)) -> void:
	planet_seed = seed
	planet_size = size
	_setup_noise()


func _setup_noise() -> void:
	# Elevation noise - large scale terrain features
	# Lower frequency = larger biomes (2.5x larger than before)
	elevation_noise = FastNoiseLite.new()
	elevation_noise.seed = planet_seed
	elevation_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	elevation_noise.frequency = 0.0008  # Was 0.002, now 2.5x larger
	elevation_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	elevation_noise.fractal_octaves = 4
	elevation_noise.fractal_lacunarity = 2.0
	elevation_noise.fractal_gain = 0.5

	# Temperature noise - biome determination
	temperature_noise = FastNoiseLite.new()
	temperature_noise.seed = planet_seed + 1000
	temperature_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	temperature_noise.frequency = 0.0004  # Was 0.001, now 2.5x larger
	temperature_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	temperature_noise.fractal_octaves = 2

	# Moisture noise - biome determination
	moisture_noise = FastNoiseLite.new()
	moisture_noise.seed = planet_seed + 2000
	moisture_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	moisture_noise.frequency = 0.0006  # Was 0.0015, now 2.5x larger
	moisture_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	moisture_noise.fractal_octaves = 2

	# Detail noise - small variations
	detail_noise = FastNoiseLite.new()
	detail_noise.seed = planet_seed + 3000
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail_noise.frequency = 0.05
	detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	detail_noise.fractal_octaves = 2

	# Feature noise - for placing trees, rocks, etc.
	feature_noise = FastNoiseLite.new()
	feature_noise.seed = planet_seed + 4000
	feature_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	feature_noise.frequency = 0.1


## Generate a chunk at the given chunk coordinates
func generate_chunk(chunk_x: int, chunk_y: int) -> Chunk:
	var chunk := Chunk.new(chunk_x, chunk_y)

	# Generate each tile
	for local_y in range(Chunk.SIZE):
		for local_x in range(Chunk.SIZE):
			var world_x := chunk_x * Chunk.SIZE + local_x
			var world_y := chunk_y * Chunk.SIZE + local_y

			# Get noise values
			var elev := _get_elevation(world_x, world_y)
			var temp := _get_temperature(world_x, world_y)
			var moist := _get_moisture(world_x, world_y)

			# Determine biome
			var biome := _get_biome(elev, temp, moist)

			# Get base tile for biome
			var tile_type := _get_base_tile(biome, elev)

			# Add features (trees, rocks, etc.)
			tile_type = _add_features(world_x, world_y, tile_type, biome, elev)

			# Set tile with random variant
			var variant := _get_variant(world_x, world_y, tile_type)
			chunk.set_tile_full(local_x, local_y, tile_type, variant, 0)

			# Set elevation (scale 0-255)
			var elev_byte := int((elev + 1.0) * 0.5 * 255.0)
			chunk.set_elevation(local_x, local_y, elev_byte)

	return chunk


## Get elevation at world coordinates (-1.0 to 1.0)
func _get_elevation(x: int, y: int) -> float:
	var base := elevation_noise.get_noise_2d(x, y)

	# Add detail noise
	var detail := detail_noise.get_noise_2d(x, y) * 0.1

	return clampf(base + detail, -1.0, 1.0)


## Get temperature at world coordinates (0.0 to 1.0)
func _get_temperature(x: int, y: int) -> float:
	var temp := temperature_noise.get_noise_2d(x, y)
	# Normalize from -1,1 to 0,1
	return (temp + 1.0) * 0.5


## Get moisture at world coordinates (0.0 to 1.0)
func _get_moisture(x: int, y: int) -> float:
	var moist := moisture_noise.get_noise_2d(x, y)
	# Normalize from -1,1 to 0,1
	return (moist + 1.0) * 0.5


## Determine biome from elevation, temperature, and moisture
func _get_biome(elevation: float, temperature: float, moisture: float) -> Biome:
	# Ocean - low elevation
	if elevation < -0.3:
		return Biome.OCEAN

	# Beach - near water level
	if elevation < -0.2:
		return Biome.BEACH

	# Cold biomes
	if temperature < 0.3:
		if moisture > 0.5:
			return Biome.TUNDRA
		else:
			return Biome.ICE

	# Hot biomes
	if temperature > 0.7:
		if moisture < 0.3:
			return Biome.DESERT
		elif moisture > 0.6:
			return Biome.SWAMP
		else:
			return Biome.PLAINS

	# Temperate biomes
	if moisture > 0.5:
		return Biome.FOREST
	else:
		return Biome.PLAINS


## Get base tile type for biome
func _get_base_tile(biome: Biome, elevation: float) -> int:
	match biome:
		Biome.OCEAN:
			# Water depth based on elevation:
			# -0.3 to -0.4 = shallow water (near shores)
			# -0.4 to -0.6 = normal water
			# < -0.6 = deep water
			if elevation > -0.4:
				return TileTypes.Type.WATER_SHALLOW
			elif elevation < -0.6:
				return TileTypes.Type.WATER_DEEP
			else:
				return TileTypes.Type.WATER
		Biome.BEACH:
			return TileTypes.Type.SAND
		Biome.FOREST:
			return TileTypes.Type.GRASS
		Biome.PLAINS:
			return TileTypes.Type.GRASS
		Biome.DESERT:
			return TileTypes.Type.SAND
		Biome.TUNDRA:
			return TileTypes.Type.SNOW
		Biome.ICE:
			if elevation < -0.1:
				return TileTypes.Type.ICE
			return TileTypes.Type.SNOW
		Biome.SWAMP:
			return TileTypes.Type.GRASS
		_:
			return TileTypes.Type.GRASS


## Add features (trees, rocks, etc.) based on position and biome
func _add_features(x: int, y: int, base_tile: int, biome: Biome, elevation: float) -> int:
	# Don't add features to water or special tiles
	if base_tile == TileTypes.Type.WATER or base_tile == TileTypes.Type.ICE \
		or base_tile == TileTypes.Type.WATER_SHALLOW \
		or base_tile == TileTypes.Type.WATER_DEEP:
		return base_tile

	# Use feature noise for placement
	var feature_val := feature_noise.get_noise_2d(x, y)
	var detail_val := detail_noise.get_noise_2d(x * 3, y * 3)

	match biome:
		Biome.FOREST:
			return _add_forest_features(feature_val, detail_val)
		Biome.PLAINS:
			return _add_plains_features(feature_val, detail_val)
		Biome.DESERT:
			return _add_desert_features(feature_val, detail_val)
		Biome.TUNDRA, Biome.ICE:
			return _add_tundra_features(feature_val, detail_val, base_tile)
		Biome.SWAMP:
			return _add_swamp_features(feature_val, detail_val)
		Biome.BEACH:
			return _add_beach_features(feature_val, detail_val, base_tile)
		_:
			return base_tile


func _add_forest_features(feature_val: float, detail_val: float) -> int:
	# Dense tree placement
	if feature_val > 0.7:
		if detail_val > 0.3:
			return TileTypes.Type.TREE_TRUNK
		else:
			return TileTypes.Type.TREE_LEAVES
	elif feature_val > 0.5:
		return TileTypes.Type.BUSH
	elif feature_val > 0.3:
		if detail_val > 0.5:
			return TileTypes.Type.TALL_GRASS
		elif detail_val > 0.3:
			return TileTypes.Type.FLOWER
	elif feature_val < -0.7:
		return TileTypes.Type.ROCK

	return TileTypes.Type.GRASS


func _add_plains_features(feature_val: float, detail_val: float) -> int:
	# Sparse trees, more grass
	if feature_val > 0.85:
		return TileTypes.Type.TREE_TRUNK
	elif feature_val > 0.7:
		return TileTypes.Type.BUSH
	elif feature_val > 0.2:
		if detail_val > 0.6:
			return TileTypes.Type.TALL_GRASS
		elif detail_val > 0.4:
			return TileTypes.Type.FLOWER
	elif feature_val < -0.8:
		return TileTypes.Type.ROCK

	return TileTypes.Type.GRASS


func _add_desert_features(feature_val: float, detail_val: float) -> int:
	# Cacti, rocks, dead bushes
	if feature_val > 0.85:
		return TileTypes.Type.CACTUS
	elif feature_val > 0.7:
		return TileTypes.Type.DEAD_BUSH
	elif feature_val < -0.7:
		return TileTypes.Type.ROCK

	return TileTypes.Type.SAND


func _add_tundra_features(feature_val: float, detail_val: float, base_tile: int) -> int:
	# Sparse trees, rocks
	if feature_val > 0.9:
		return TileTypes.Type.TREE_TRUNK
	elif feature_val < -0.6:
		return TileTypes.Type.ROCK

	return base_tile


func _add_swamp_features(feature_val: float, detail_val: float) -> int:
	# Water pools, dead trees
	if feature_val > 0.6:
		if detail_val > 0.5:
			return TileTypes.Type.TREE_TRUNK
		else:
			return TileTypes.Type.BUSH
	elif feature_val < -0.5:
		return TileTypes.Type.WATER
	elif feature_val > 0.2:
		return TileTypes.Type.TALL_GRASS

	return TileTypes.Type.GRASS


func _add_beach_features(feature_val: float, detail_val: float, base_tile: int) -> int:
	# Occasional rocks
	if feature_val < -0.8:
		return TileTypes.Type.ROCK

	return base_tile


## Get consistent variant for tile at position
func _get_variant(x: int, y: int, tile_type: int) -> int:
	var variant_count := TileTypes.get_variant_count(tile_type)
	if variant_count <= 1:
		return 0

	# Use simple hash for consistent variants
	var hash_val := (x * 73856093) ^ (y * 19349663) ^ planet_seed
	return absi(hash_val) % variant_count


## Get biome at world coordinates (for debugging/UI)
func get_biome_at(world_x: int, world_y: int) -> Biome:
	var elev := _get_elevation(world_x, world_y)
	var temp := _get_temperature(world_x, world_y)
	var moist := _get_moisture(world_x, world_y)
	return _get_biome(elev, temp, moist)


## Get biome name string
static func get_biome_name(biome: Biome) -> String:
	match biome:
		Biome.OCEAN:
			return "Ocean"
		Biome.BEACH:
			return "Beach"
		Biome.FOREST:
			return "Forest"
		Biome.PLAINS:
			return "Plains"
		Biome.DESERT:
			return "Desert"
		Biome.TUNDRA:
			return "Tundra"
		Biome.ICE:
			return "Ice"
		Biome.SWAMP:
			return "Swamp"
		_:
			return "Unknown"
