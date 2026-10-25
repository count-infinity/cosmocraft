class_name AsteroidLayer
extends Node2D
## Draws the rocks in asteroid-field regions. They're solid: SpaceGame pushes
## ships and Gloom out of them and stops bullets that hit them.

const ROCK_COLOR := Color(0.07, 0.06, 0.085)
const RIM_COLOR := Color(0.55, 0.45, 0.6, 0.75)
const CRATER_COLOR := Color(0.03, 0.025, 0.04)

var _asteroids: Array[SectorData.Asteroid] = []


func build(sector: SectorData) -> void:
	_asteroids = sector.asteroids
	queue_redraw()


func _draw() -> void:
	for asteroid in _asteroids:
		var outline := PackedVector2Array()
		for point in asteroid.outline:
			outline.append(asteroid.position + point)
		draw_colored_polygon(outline, ROCK_COLOR)
		outline.append(outline[0])
		draw_polyline(outline, RIM_COLOR, 1.5)
		var crater := asteroid.outline[0].normalized().rotated(1.9) * asteroid.radius * 0.35
		draw_circle(asteroid.position + crater, asteroid.radius * 0.18, CRATER_COLOR)
		draw_circle(asteroid.position - crater * 0.8, asteroid.radius * 0.11, CRATER_COLOR)
