class_name Chunk
extends RefCounted
## A chunk is a 32x32 tile section of the world.
## Chunks are the unit of loading, generation, and network sync.

const SIZE: int = 32  # 32x32 tiles per chunk
const TILE_COUNT: int = SIZE * SIZE  # 1024 tiles

# Chunk coordinates (not tile coordinates)
var chunk_x: int = 0
var chunk_y: int = 0

# Tile data - flat array for efficiency
# Each tile is packed: type (12 bits) | variant (4 bits) | light (8 bits) | liquid (4 bits) | flags (4 bits)
var tiles: PackedInt32Array

# Track if chunk has been modified from procedural base
var is_modified: bool = false

# Track which tiles have been modified (for delta storage)
var modified_tiles: Dictionary = {}  # {local_index: original_type}

# Elevation data (0-255 per tile)
var elevation: PackedByteArray

# Light levels (calculated, not stored permanently)
var light_levels: PackedByteArray


func _init(cx: int = 0, cy: int = 0) -> void:
	chunk_x = cx
	chunk_y = cy
	tiles = PackedInt32Array()
	tiles.resize(TILE_COUNT)
	elevation = PackedByteArray()
	elevation.resize(TILE_COUNT)
	light_levels = PackedByteArray()
	light_levels.resize(TILE_COUNT)
	# Initialize with air
	for i in range(TILE_COUNT):
		tiles[i] = _pack_tile(TileTypes.Type.AIR, 0, 0, 0)
		elevation[i] = 100  # Default mid elevation
		light_levels[i] = 15  # Full ambient light


## Pack tile data into a single int32
static func _pack_tile(type_id: int, variant: int, liquid_level: int, extra_flags: int) -> int:
	# Bits 0-11: type (4096 max)
	# Bits 12-15: variant (16 max)
	# Bits 16-19: liquid level (16 max)
	# Bits 20-31: reserved/flags
	return (type_id & 0xFFF) | ((variant & 0xF) << 12) | ((liquid_level & 0xF) << 16) | ((extra_flags & 0xFFF) << 20)


## Unpack tile type from packed data
static func _unpack_type(packed: int) -> int:
	return packed & 0xFFF


## Unpack variant from packed data
static func _unpack_variant(packed: int) -> int:
	return (packed >> 12) & 0xF


## Unpack liquid level from packed data
static func _unpack_liquid(packed: int) -> int:
	return (packed >> 16) & 0xF


## Convert local tile coords (0-31, 0-31) to array index
static func coords_to_index(local_x: int, local_y: int) -> int:
	return local_y * SIZE + local_x


## Convert array index to local tile coords
static func index_to_coords(index: int) -> Vector2i:
	return Vector2i(index % SIZE, index / SIZE)


## Get world tile coordinates for a local tile
func get_world_coords(local_x: int, local_y: int) -> Vector2i:
	return Vector2i(chunk_x * SIZE + local_x, chunk_y * SIZE + local_y)


## Get tile type at local coordinates
func get_tile(local_x: int, local_y: int) -> int:
	if local_x < 0 or local_x >= SIZE or local_y < 0 or local_y >= SIZE:
		return TileTypes.Type.AIR
	var index := coords_to_index(local_x, local_y)
	return _unpack_type(tiles[index])


## Get tile variant at local coordinates
func get_variant(local_x: int, local_y: int) -> int:
	if local_x < 0 or local_x >= SIZE or local_y < 0 or local_y >= SIZE:
		return 0
	var index := coords_to_index(local_x, local_y)
	return _unpack_variant(tiles[index])


## Get liquid level at local coordinates
func get_liquid_level(local_x: int, local_y: int) -> int:
	if local_x < 0 or local_x >= SIZE or local_y < 0 or local_y >= SIZE:
		return 0
	var index := coords_to_index(local_x, local_y)
	return _unpack_liquid(tiles[index])


## Get elevation at local coordinates
func get_elevation(local_x: int, local_y: int) -> int:
	if local_x < 0 or local_x >= SIZE or local_y < 0 or local_y >= SIZE:
		return 100
	var index := coords_to_index(local_x, local_y)
	return elevation[index]


## Get light level at local coordinates
func get_light_level(local_x: int, local_y: int) -> int:
	if local_x < 0 or local_x >= SIZE or local_y < 0 or local_y >= SIZE:
		return 0
	var index := coords_to_index(local_x, local_y)
	return light_levels[index]


## Set tile at local coordinates (tracks modification)
func set_tile(local_x: int, local_y: int, type_id: int, variant: int = -1, track_modification: bool = true) -> void:
	if local_x < 0 or local_x >= SIZE or local_y < 0 or local_y >= SIZE:
		return

	var index := coords_to_index(local_x, local_y)
	var old_packed := tiles[index]
	var old_type := _unpack_type(old_packed)

	# Use existing variant if not specified, or pick random if new type
	var new_variant := variant
	if new_variant < 0:
		if type_id == old_type:
			new_variant = _unpack_variant(old_packed)
		else:
			new_variant = randi() % TileTypes.get_variant_count(type_id)

	var liquid := _unpack_liquid(old_packed)
	tiles[index] = _pack_tile(type_id, new_variant, liquid, 0)

	if track_modification and type_id != old_type:
		if not modified_tiles.has(index):
			# Store original type for delta
			modified_tiles[index] = old_type
		is_modified = true


## Set tile with all properties
func set_tile_full(local_x: int, local_y: int, type_id: int, variant: int, liquid_level: int) -> void:
	if local_x < 0 or local_x >= SIZE or local_y < 0 or local_y >= SIZE:
		return
	var index := coords_to_index(local_x, local_y)
	tiles[index] = _pack_tile(type_id, variant, liquid_level, 0)


## Set elevation at local coordinates
func set_elevation(local_x: int, local_y: int, elev: int) -> void:
	if local_x < 0 or local_x >= SIZE or local_y < 0 or local_y >= SIZE:
		return
	var index := coords_to_index(local_x, local_y)
	elevation[index] = clampi(elev, 0, 255)


## Set light level at local coordinates
func set_light_level(local_x: int, local_y: int, light: int) -> void:
	if local_x < 0 or local_x >= SIZE or local_y < 0 or local_y >= SIZE:
		return
	var index := coords_to_index(local_x, local_y)
	light_levels[index] = clampi(light, 0, 255)


## Set liquid level at local coordinates
func set_liquid_level(local_x: int, local_y: int, level: int) -> void:
	if local_x < 0 or local_x >= SIZE or local_y < 0 or local_y >= SIZE:
		return
	var index := coords_to_index(local_x, local_y)
	var old := tiles[index]
	var type_id := _unpack_type(old)
	var variant := _unpack_variant(old)
	tiles[index] = _pack_tile(type_id, variant, clampi(level, 0, 15), 0)


## Fill entire chunk with a tile type (for testing)
func fill(type_id: int, variant: int = 0) -> void:
	for i in range(TILE_COUNT):
		tiles[i] = _pack_tile(type_id, variant, 0, 0)


## Get chunk key string for dictionary lookups
func get_key() -> String:
	return "%d,%d" % [chunk_x, chunk_y]


## Static helper to create key from coordinates
static func make_key(cx: int, cy: int) -> String:
	return "%d,%d" % [cx, cy]


## Convert chunk to dictionary for serialization
func to_dict() -> Dictionary:
	var tile_data: Array = []
	for i in range(TILE_COUNT):
		tile_data.append(tiles[i])

	var elev_data: Array = []
	for i in range(TILE_COUNT):
		elev_data.append(elevation[i])

	return {
		"x": chunk_x,
		"y": chunk_y,
		"tiles": tile_data,
		"elevation": elev_data,
		"modified": is_modified
	}


## Create chunk from dictionary
static func from_dict(data: Dictionary) -> Chunk:
	var chunk := Chunk.new(data.get("x", 0), data.get("y", 0))

	var tile_data: Array = data.get("tiles", [])
	for i in range(mini(tile_data.size(), TILE_COUNT)):
		chunk.tiles[i] = tile_data[i]

	var elev_data: Array = data.get("elevation", [])
	for i in range(mini(elev_data.size(), TILE_COUNT)):
		chunk.elevation[i] = elev_data[i]

	chunk.is_modified = data.get("modified", false)
	return chunk


## Get delta (only modified tiles) for efficient storage
func get_delta() -> Dictionary:
	if not is_modified:
		return {}

	var delta: Dictionary = {}
	for index in modified_tiles:
		var coords := index_to_coords(index)
		var key := "%d,%d" % [coords.x, coords.y]
		delta[key] = {
			"type": _unpack_type(tiles[index]),
			"variant": _unpack_variant(tiles[index]),
			"liquid": _unpack_liquid(tiles[index])
		}
	return delta


## Apply delta to chunk (from saved modifications)
func apply_delta(delta: Dictionary) -> void:
	for key in delta:
		var parts: PackedStringArray = key.split(",")
		if parts.size() != 2:
			continue
		var local_x := int(parts[0])
		var local_y := int(parts[1])
		var tile_data: Dictionary = delta[key]
		set_tile_full(
			local_x,
			local_y,
			tile_data.get("type", TileTypes.Type.AIR),
			tile_data.get("variant", 0),
			tile_data.get("liquid", 0)
		)
	if delta.size() > 0:
		is_modified = true
