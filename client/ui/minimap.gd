class_name Minimap
extends Control

# Minimap configuration
const MINIMAP_SIZE := 200  # Pixels for the minimap display
const TILE_VIEW_RADIUS := 32  # How many tiles to show in each direction
const PIXELS_PER_TILE := 3  # How many pixels per tile on minimap

# References
var chunk_manager: ChunkManager = null
var _image: Image
var _texture: ImageTexture
var _texture_rect: TextureRect
var _player_marker: ColorRect
var _border: ColorRect

# Tile colors for minimap
var _tile_colors: Dictionary = {
	TileTypes.Type.AIR: Color(0.1, 0.1, 0.15),
	TileTypes.Type.GRASS: Color(0.2, 0.6, 0.2),
	TileTypes.Type.DIRT: Color(0.5, 0.35, 0.2),
	TileTypes.Type.STONE: Color(0.5, 0.5, 0.5),
	TileTypes.Type.WATER: Color(0.2, 0.4, 0.8),
	TileTypes.Type.SAND: Color(0.9, 0.85, 0.5),
	TileTypes.Type.TREE_TRUNK: Color(0.4, 0.25, 0.1),
	TileTypes.Type.TREE_LEAVES: Color(0.1, 0.5, 0.15),
	TileTypes.Type.BUSH: Color(0.15, 0.45, 0.15),
	TileTypes.Type.ROCK: Color(0.45, 0.45, 0.45),
	TileTypes.Type.TALL_GRASS: Color(0.25, 0.55, 0.25),
	TileTypes.Type.FLOWER: Color(0.8, 0.4, 0.6),
	TileTypes.Type.PATH: Color(0.6, 0.55, 0.4),
	TileTypes.Type.WALL: Color(0.55, 0.5, 0.45),
	TileTypes.Type.FLOOR: Color(0.5, 0.45, 0.4),
	TileTypes.Type.SNOW: Color(0.95, 0.95, 0.98),
	TileTypes.Type.ICE: Color(0.7, 0.85, 0.95),
	TileTypes.Type.CACTUS: Color(0.3, 0.55, 0.2),
	TileTypes.Type.DEAD_BUSH: Color(0.5, 0.4, 0.25),
}

# Current player position (in world pixels)
var _player_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	_create_ui()


func _create_ui() -> void:
	# Calculate total minimap pixels based on view radius
	var map_pixels := TILE_VIEW_RADIUS * 2 * PIXELS_PER_TILE

	# Container for positioning in top-right corner
	custom_minimum_size = Vector2(MINIMAP_SIZE + 10, MINIMAP_SIZE + 10)

	# Border/background
	_border = ColorRect.new()
	_border.color = Color(0.1, 0.1, 0.15, 0.9)
	_border.size = Vector2(MINIMAP_SIZE + 4, MINIMAP_SIZE + 4)
	_border.position = Vector2(-2, -2)
	add_child(_border)

	# Create image and texture for the minimap
	_image = Image.create(map_pixels, map_pixels, false, Image.FORMAT_RGB8)
	_image.fill(Color(0.1, 0.1, 0.15))
	_texture = ImageTexture.create_from_image(_image)

	# TextureRect to display the minimap
	_texture_rect = TextureRect.new()
	_texture_rect.texture = _texture
	_texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_texture_rect.size = Vector2(MINIMAP_SIZE, MINIMAP_SIZE)
	add_child(_texture_rect)

	# Player marker (center dot)
	_player_marker = ColorRect.new()
	_player_marker.color = Color(1.0, 1.0, 1.0)
	_player_marker.size = Vector2(4, 4)
	_player_marker.position = Vector2(MINIMAP_SIZE / 2 - 2, MINIMAP_SIZE / 2 - 2)
	add_child(_player_marker)


func initialize(p_chunk_manager: ChunkManager) -> void:
	chunk_manager = p_chunk_manager


func update_player_position(world_pos: Vector2) -> void:
	_player_position = world_pos
	_update_minimap()


func _update_minimap() -> void:
	if chunk_manager == null:
		return

	# Calculate center tile position
	var center_tile_x := int(_player_position.x / GameConstants.TILE_SIZE)
	var center_tile_y := int(_player_position.y / GameConstants.TILE_SIZE)

	var map_pixels := TILE_VIEW_RADIUS * 2 * PIXELS_PER_TILE

	# Fill minimap with tile colors
	for dy in range(-TILE_VIEW_RADIUS, TILE_VIEW_RADIUS):
		for dx in range(-TILE_VIEW_RADIUS, TILE_VIEW_RADIUS):
			var tile_x := center_tile_x + dx
			var tile_y := center_tile_y + dy

			# Get tile type from chunk manager
			var tile_type := _get_tile_at(tile_x, tile_y)
			var color := _get_tile_color(tile_type)

			# Draw this tile as a small rectangle
			var px := (dx + TILE_VIEW_RADIUS) * PIXELS_PER_TILE
			var py := (dy + TILE_VIEW_RADIUS) * PIXELS_PER_TILE

			for py_off in range(PIXELS_PER_TILE):
				for px_off in range(PIXELS_PER_TILE):
					var img_x := px + px_off
					var img_y := py + py_off
					if img_x >= 0 and img_x < map_pixels and img_y >= 0 and img_y < map_pixels:
						_image.set_pixel(img_x, img_y, color)

	# Update texture
	_texture.update(_image)


func _get_tile_at(world_tile_x: int, world_tile_y: int) -> int:
	if chunk_manager == null:
		return TileTypes.Type.AIR

	# Calculate chunk coordinates
	var chunk_x := world_tile_x / Chunk.SIZE
	var chunk_y := world_tile_y / Chunk.SIZE

	# Handle negative coordinates
	if world_tile_x < 0 and world_tile_x % Chunk.SIZE != 0:
		chunk_x -= 1
	if world_tile_y < 0 and world_tile_y % Chunk.SIZE != 0:
		chunk_y -= 1

	var key := Chunk.make_key(chunk_x, chunk_y)
	if not chunk_manager.chunks.has(key):
		return TileTypes.Type.AIR

	var chunk: Chunk = chunk_manager.chunks[key]

	# Calculate local tile position within chunk
	var local_x := world_tile_x - chunk_x * Chunk.SIZE
	var local_y := world_tile_y - chunk_y * Chunk.SIZE

	return chunk.get_tile(local_x, local_y)


func _get_tile_color(tile_type: int) -> Color:
	if _tile_colors.has(tile_type):
		return _tile_colors[tile_type]
	return Color(0.5, 0.0, 0.5)  # Magenta for unknown tiles
