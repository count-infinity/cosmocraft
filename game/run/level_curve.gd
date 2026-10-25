class_name LevelCurve
extends RefCounted
## Experience levels where each level needs `first` experience plus `step` more
## for every level already reached. Shared by the Hearth and the pilot.


static func to_next(level: int, first: int, step: int) -> int:
	return first + step * level


static func level_for(xp: int, first: int, step: int) -> int:
	var level := 0
	var left := xp
	while left >= to_next(level, first, step):
		left -= to_next(level, first, step)
		level += 1
	return level


## Experience gathered toward the next level, and how much it needs.
static func progress_for(xp: int, first: int, step: int) -> Vector2i:
	var level := 0
	var left := xp
	while left >= to_next(level, first, step):
		left -= to_next(level, first, step)
		level += 1
	return Vector2i(left, to_next(level, first, step))
