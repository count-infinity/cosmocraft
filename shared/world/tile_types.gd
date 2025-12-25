class_name TileTypes
extends RefCounted
## Tile type definitions and properties for the world system.
## Shared between client and server for consistent behavior.

# Tile type IDs
enum Type {
	AIR = 0,
	GRASS = 1,
	DIRT = 2,
	STONE = 3,
	WATER = 4,
	SAND = 5,
	TREE_TRUNK = 6,
	TREE_LEAVES = 7,
	BUSH = 8,
	ROCK = 9,
	TALL_GRASS = 10,
	FLOWER = 11,
	PATH = 12,
	WALL = 13,
	FLOOR = 14,
	SNOW = 15,
	ICE = 16,
	CACTUS = 17,
	DEAD_BUSH = 18,
	# Reserve space for more types
	MAX = 4096
}

# Tile property flags (packed into upper bits)
enum Flags {
	NONE = 0,
	SOLID = 1,          # Blocks movement
	MINEABLE = 2,       # Can be harvested
	LIQUID = 4,         # Flows to adjacent tiles
	TRANSPARENT = 8,    # Light passes through
	FLAMMABLE = 16,     # Can catch fire
}

## Properties for each tile type
class TileProperties:
	var type_id: int
	var name: String
	var flags: int
	var light_emission: int      # 0-15
	var light_blocking: int      # 0-15 (0 = transparent, 15 = opaque)
	var walk_speed_mult: float   # 1.0 = normal, 0.5 = slow, 0 = impassable
	var variants: int            # Number of visual variants

	func _init(
		p_type_id: int,
		p_name: String,
		p_flags: int = 0,
		p_light_emission: int = 0,
		p_light_blocking: int = 0,
		p_walk_speed_mult: float = 1.0,
		p_variants: int = 1
	) -> void:
		type_id = p_type_id
		name = p_name
		flags = p_flags
		light_emission = p_light_emission
		light_blocking = p_light_blocking
		walk_speed_mult = p_walk_speed_mult
		variants = p_variants

	func is_solid() -> bool:
		return (flags & Flags.SOLID) != 0

	func is_mineable() -> bool:
		return (flags & Flags.MINEABLE) != 0

	func is_liquid() -> bool:
		return (flags & Flags.LIQUID) != 0

	func is_transparent() -> bool:
		return (flags & Flags.TRANSPARENT) != 0

	func is_flammable() -> bool:
		return (flags & Flags.FLAMMABLE) != 0


# Static registry of all tile properties
static var _properties: Dictionary = {}
static var _initialized: bool = false


static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	_register_tiles()


static func _register_tiles() -> void:
	# Format: type_id, name, flags, light_emit, light_block, walk_speed, variants

	# AIR - empty space
	_register(Type.AIR, "Air", Flags.TRANSPARENT, 0, 0, 1.0, 1)

	# GRASS - basic walkable ground
	_register(Type.GRASS, "Grass", Flags.TRANSPARENT, 0, 0, 1.0, 4)

	# DIRT - mineable ground
	_register(Type.DIRT, "Dirt", Flags.SOLID | Flags.MINEABLE | Flags.TRANSPARENT, 0, 0, 0.9, 2)

	# STONE - harder mineable ground
	_register(Type.STONE, "Stone", Flags.SOLID | Flags.MINEABLE, 0, 15, 0.0, 3)

	# WATER - liquid, slows movement
	_register(Type.WATER, "Water", Flags.LIQUID | Flags.TRANSPARENT, 0, 2, 0.5, 4)

	# SAND - beach/desert ground
	_register(Type.SAND, "Sand", Flags.TRANSPARENT, 0, 0, 0.8, 3)

	# TREE_TRUNK - solid obstacle
	_register(Type.TREE_TRUNK, "Tree Trunk", Flags.SOLID | Flags.MINEABLE | Flags.FLAMMABLE, 0, 15, 0.0, 2)

	# TREE_LEAVES - decorative canopy
	_register(Type.TREE_LEAVES, "Tree Leaves", Flags.TRANSPARENT | Flags.FLAMMABLE, 0, 5, 1.0, 3)

	# BUSH - decorative, walkable
	_register(Type.BUSH, "Bush", Flags.TRANSPARENT | Flags.FLAMMABLE, 0, 2, 0.9, 4)

	# ROCK - small solid obstacle
	_register(Type.ROCK, "Rock", Flags.SOLID | Flags.MINEABLE, 0, 15, 0.0, 4)

	# TALL_GRASS - decorative
	_register(Type.TALL_GRASS, "Tall Grass", Flags.TRANSPARENT | Flags.FLAMMABLE, 0, 0, 0.95, 4)

	# FLOWER - decorative
	_register(Type.FLOWER, "Flower", Flags.TRANSPARENT, 0, 0, 1.0, 6)

	# PATH - village paths, faster movement
	_register(Type.PATH, "Path", Flags.TRANSPARENT, 0, 0, 1.2, 2)

	# WALL - solid building wall
	_register(Type.WALL, "Wall", Flags.SOLID | Flags.MINEABLE, 0, 15, 0.0, 4)

	# FLOOR - indoor floor
	_register(Type.FLOOR, "Floor", Flags.TRANSPARENT, 0, 0, 1.0, 3)

	# SNOW - cold biome ground
	_register(Type.SNOW, "Snow", Flags.TRANSPARENT, 0, 0, 0.85, 3)

	# ICE - slippery frozen water
	_register(Type.ICE, "Ice", Flags.TRANSPARENT, 0, 1, 1.3, 2)  # Faster but slippery

	# CACTUS - desert obstacle
	_register(Type.CACTUS, "Cactus", Flags.SOLID | Flags.MINEABLE, 0, 10, 0.0, 2)

	# DEAD_BUSH - desert decoration
	_register(Type.DEAD_BUSH, "Dead Bush", Flags.TRANSPARENT | Flags.FLAMMABLE, 0, 0, 0.95, 3)


static func _register(
	type_id: int,
	name: String,
	flags: int,
	light_emission: int,
	light_blocking: int,
	walk_speed_mult: float,
	variants: int
) -> void:
	_properties[type_id] = TileProperties.new(
		type_id, name, flags, light_emission, light_blocking, walk_speed_mult, variants
	)


static func get_properties(type_id: int) -> TileProperties:
	_ensure_initialized()
	if _properties.has(type_id):
		return _properties[type_id]
	# Return AIR properties as fallback
	return _properties[Type.AIR]


static func is_solid(type_id: int) -> bool:
	return get_properties(type_id).is_solid()


static func is_mineable(type_id: int) -> bool:
	return get_properties(type_id).is_mineable()


static func is_liquid(type_id: int) -> bool:
	return get_properties(type_id).is_liquid()


static func is_transparent(type_id: int) -> bool:
	return get_properties(type_id).is_transparent()


static func get_walk_speed(type_id: int) -> float:
	return get_properties(type_id).walk_speed_mult


static func get_light_emission(type_id: int) -> int:
	return get_properties(type_id).light_emission


static func get_light_blocking(type_id: int) -> int:
	return get_properties(type_id).light_blocking


static func get_tile_name(type_id: int) -> String:
	return get_properties(type_id).name


static func get_variant_count(type_id: int) -> int:
	return get_properties(type_id).variants
