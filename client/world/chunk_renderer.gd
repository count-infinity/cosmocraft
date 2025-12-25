class_name ChunkRenderer
extends Node2D
## Renders chunks using TileMap layers for efficient display.
## Handles visual updates when chunks are loaded/modified.

# Reference to chunk manager
var chunk_manager: ChunkManager

# TileMap for rendering
var tile_map: TileMap

# Currently rendered chunks
var rendered_chunks: Dictionary = {}  # "x,y" -> true

# Player position for determining which chunks to render
var focus_position: Vector2 = Vector2.ZERO
var render_radius: int = 5  # Chunks around player to render

# Tile atlas mapping (tile type -> atlas coords)
# For now we'll use colored rectangles, later replace with actual sprites
var _tile_colors: Dictionary = {}


func _ready() -> void:
	_setup_tile_colors()
	_create_tile_map()


func _setup_tile_colors() -> void:
	# Temporary color mapping until we have real sprites
	_tile_colors[TileTypes.Type.AIR] = Color(0.1, 0.1, 0.15, 0.0)  # Transparent
	_tile_colors[TileTypes.Type.GRASS] = Color(0.2, 0.6, 0.2)
	_tile_colors[TileTypes.Type.DIRT] = Color(0.5, 0.35, 0.2)
	_tile_colors[TileTypes.Type.STONE] = Color(0.4, 0.4, 0.45)
	_tile_colors[TileTypes.Type.WATER] = Color(0.2, 0.4, 0.8, 0.8)
	_tile_colors[TileTypes.Type.SAND] = Color(0.9, 0.85, 0.5)
	_tile_colors[TileTypes.Type.TREE_TRUNK] = Color(0.4, 0.25, 0.1)
	_tile_colors[TileTypes.Type.TREE_LEAVES] = Color(0.1, 0.5, 0.15)
	_tile_colors[TileTypes.Type.BUSH] = Color(0.15, 0.45, 0.2)
	_tile_colors[TileTypes.Type.ROCK] = Color(0.35, 0.35, 0.4)
	_tile_colors[TileTypes.Type.TALL_GRASS] = Color(0.25, 0.55, 0.25)
	_tile_colors[TileTypes.Type.FLOWER] = Color(0.9, 0.3, 0.5)
	_tile_colors[TileTypes.Type.PATH] = Color(0.6, 0.5, 0.35)
	_tile_colors[TileTypes.Type.WALL] = Color(0.5, 0.45, 0.4)
	_tile_colors[TileTypes.Type.FLOOR] = Color(0.55, 0.5, 0.4)
	_tile_colors[TileTypes.Type.SNOW] = Color(0.95, 0.95, 1.0)
	_tile_colors[TileTypes.Type.ICE] = Color(0.7, 0.85, 0.95)
	_tile_colors[TileTypes.Type.CACTUS] = Color(0.2, 0.5, 0.2)
	_tile_colors[TileTypes.Type.DEAD_BUSH] = Color(0.5, 0.4, 0.25)


func _create_tile_map() -> void:
	tile_map = TileMap.new()
	tile_map.name = "TileMap"
	add_child(tile_map)

	# Create a simple TileSet with colored tiles
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(GameConstants.TILE_SIZE, GameConstants.TILE_SIZE)

	# Add a source for our tiles
	var source := TileSetAtlasSource.new()
	source.texture = _create_tile_atlas()
	source.texture_region_size = Vector2i(GameConstants.TILE_SIZE, GameConstants.TILE_SIZE)

	# Create tiles for each type
	for type_id in _tile_colors:
		var atlas_x: int = int(type_id) % 16
		var atlas_y: int = int(type_id) / 16
		source.create_tile(Vector2i(atlas_x, atlas_y))

	tile_set.add_source(source)
	tile_map.tile_set = tile_set


func _create_tile_atlas() -> ImageTexture:
	# Create a simple atlas with colored squares for each tile type
	# 16x16 grid of tiles at TILE_SIZE pixels each
	var tile_size := GameConstants.TILE_SIZE
	var atlas_size := 16 * tile_size
	var image := Image.create(atlas_size, atlas_size, false, Image.FORMAT_RGBA8)

	for type_id in _tile_colors:
		var color: Color = _tile_colors[type_id]
		var atlas_x: int = (int(type_id) % 16) * tile_size
		var atlas_y: int = (int(type_id) / 16) * tile_size

		# Fill tile rectangle
		for y in range(tile_size):
			for x in range(tile_size):
				# Add slight variation for visual interest
				var variation := 0.05 * (sin(x * 0.5) * cos(y * 0.5))
				var varied_color := Color(
					clampf(color.r + variation, 0, 1),
					clampf(color.g + variation, 0, 1),
					clampf(color.b + variation, 0, 1),
					color.a
				)
				image.set_pixel(atlas_x + x, atlas_y + y, varied_color)

	var texture := ImageTexture.create_from_image(image)
	return texture


## Initialize with a chunk manager
func initialize(manager: ChunkManager) -> void:
	chunk_manager = manager
	chunk_manager.chunk_loaded.connect(_on_chunk_loaded)
	chunk_manager.chunk_unloaded.connect(_on_chunk_unloaded)
	chunk_manager.chunk_modified.connect(_on_chunk_modified)


## Update focus position and render nearby chunks
func set_focus(world_pos: Vector2) -> void:
	focus_position = world_pos
	_update_rendered_chunks()


## Force render a specific chunk
func render_chunk(chunk: Chunk) -> void:
	var key := chunk.get_key()
	rendered_chunks[key] = true

	var base_x := chunk.chunk_x * Chunk.SIZE
	var base_y := chunk.chunk_y * Chunk.SIZE

	for local_y in range(Chunk.SIZE):
		for local_x in range(Chunk.SIZE):
			var tile_type := chunk.get_tile(local_x, local_y)
			var atlas_coords := Vector2i(tile_type % 16, tile_type / 16)
			tile_map.set_cell(0, Vector2i(base_x + local_x, base_y + local_y), 0, atlas_coords)


## Unrender a chunk (clear tiles)
func unrender_chunk(chunk_x: int, chunk_y: int) -> void:
	var key := Chunk.make_key(chunk_x, chunk_y)
	rendered_chunks.erase(key)

	var base_x := chunk_x * Chunk.SIZE
	var base_y := chunk_y * Chunk.SIZE

	for local_y in range(Chunk.SIZE):
		for local_x in range(Chunk.SIZE):
			tile_map.erase_cell(0, Vector2i(base_x + local_x, base_y + local_y))


## Update which chunks should be rendered
func _update_rendered_chunks() -> void:
	if chunk_manager == null:
		return

	# Convert world position to tile position
	var tile_x := int(focus_position.x / GameConstants.TILE_SIZE)
	var tile_y := int(focus_position.y / GameConstants.TILE_SIZE)

	# Get center chunk
	var center_chunk := chunk_manager.world_to_chunk_coords(tile_x, tile_y)

	# Track which chunks should be rendered
	var should_render: Dictionary = {}

	# Mark chunks in radius
	for cy in range(center_chunk.y - render_radius, center_chunk.y + render_radius + 1):
		for cx in range(center_chunk.x - render_radius, center_chunk.x + render_radius + 1):
			var key := Chunk.make_key(cx, cy)
			should_render[key] = true

			# Render if not already rendered
			if not rendered_chunks.has(key):
				if chunk_manager.is_chunk_loaded(cx, cy):
					var chunk := chunk_manager.get_chunk(cx, cy)
					render_chunk(chunk)

	# Unrender chunks no longer in range
	var to_unrender: Array[String] = []
	for key in rendered_chunks:
		if not should_render.has(key):
			to_unrender.append(key)

	for key in to_unrender:
		var parts: PackedStringArray = key.split(",")
		unrender_chunk(int(parts[0]), int(parts[1]))


## Handle chunk loaded signal
func _on_chunk_loaded(chunk: Chunk) -> void:
	# Check if this chunk should be rendered
	var tile_x := int(focus_position.x / GameConstants.TILE_SIZE)
	var tile_y := int(focus_position.y / GameConstants.TILE_SIZE)
	var center_chunk := Vector2i(tile_x / Chunk.SIZE, tile_y / Chunk.SIZE)

	var dist_x := absi(chunk.chunk_x - center_chunk.x)
	var dist_y := absi(chunk.chunk_y - center_chunk.y)

	if dist_x <= render_radius and dist_y <= render_radius:
		render_chunk(chunk)


## Handle chunk unloaded signal
func _on_chunk_unloaded(chunk_x: int, chunk_y: int) -> void:
	unrender_chunk(chunk_x, chunk_y)


## Handle chunk modified signal
func _on_chunk_modified(chunk: Chunk, local_x: int, local_y: int) -> void:
	# Update single tile
	var world_x := chunk.chunk_x * Chunk.SIZE + local_x
	var world_y := chunk.chunk_y * Chunk.SIZE + local_y
	var tile_type := chunk.get_tile(local_x, local_y)
	var atlas_coords := Vector2i(tile_type % 16, tile_type / 16)
	tile_map.set_cell(0, Vector2i(world_x, world_y), 0, atlas_coords)


## Get world position from screen position
func screen_to_world(screen_pos: Vector2) -> Vector2:
	return tile_map.to_local(screen_pos)


## Get tile coordinates from world position
func world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / GameConstants.TILE_SIZE), int(world_pos.y / GameConstants.TILE_SIZE))
