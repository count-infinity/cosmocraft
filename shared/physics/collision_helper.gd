class_name CollisionHelper
extends RefCounted
## Shared collision checking logic for client prediction and server physics.
## Ensures client and server use identical collision detection.

## Player collision radius (half the visual size)
const PLAYER_RADIUS: float = 12.0


## Check if a position is passable (checking corners of player hitbox)
static func is_position_passable(pos: Vector2, chunk_manager: ChunkManager) -> bool:
	# Check center and 4 corners of player hitbox
	var offsets: Array[Vector2] = [
		Vector2.ZERO,  # Center
		Vector2(-PLAYER_RADIUS, -PLAYER_RADIUS),  # Top-left
		Vector2(PLAYER_RADIUS, -PLAYER_RADIUS),   # Top-right
		Vector2(-PLAYER_RADIUS, PLAYER_RADIUS),   # Bottom-left
		Vector2(PLAYER_RADIUS, PLAYER_RADIUS),    # Bottom-right
	]

	for offset: Vector2 in offsets:
		var check_pos: Vector2 = pos + offset
		var tile_x := int(floor(check_pos.x / GameConstants.TILE_SIZE))
		var tile_y := int(floor(check_pos.y / GameConstants.TILE_SIZE))
		if not chunk_manager.is_passable(tile_x, tile_y):
			return false

	return true


## Apply movement with collision checking (sliding along walls)
## Returns the new position after applying movement with collision
static func apply_movement_with_collision(
	start_pos: Vector2,
	movement: Vector2,
	chunk_manager: ChunkManager
) -> Vector2:
	var result_pos := start_pos

	# Try X movement first
	if movement.x != 0:
		var new_x := start_pos.x + movement.x
		if is_position_passable(Vector2(new_x, start_pos.y), chunk_manager):
			result_pos.x = new_x

	# Then try Y movement
	if movement.y != 0:
		var new_y := result_pos.y + movement.y
		if is_position_passable(Vector2(result_pos.x, new_y), chunk_manager):
			result_pos.y = new_y

	return result_pos
