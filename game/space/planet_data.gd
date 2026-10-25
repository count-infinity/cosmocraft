class_name PlanetData
extends RefCounted
## A dormant planet where several regions meet. Claim every region around it
## and it wakes; land on it and kindle it, and it becomes one of your outposts.

enum Type { ASHEN, MAGMA, VERDANT, FUNGAL, FROST, CRYSTAL }

## Per type: display name, resource it yields, surface colors, and the hazard
## pools found on its surface.
const TYPES := {
	Type.ASHEN: {"name": "Ashen", "resource": "ore", "base": Color(0.3, 0.27, 0.25), "accent": Color(1.0, 0.55, 0.25), "hazard": "embers"},
	Type.MAGMA: {"name": "Magma", "resource": "ore", "base": Color(0.28, 0.1, 0.07), "accent": Color(1.0, 0.38, 0.12), "hazard": "lava"},
	Type.VERDANT: {"name": "Verdant", "resource": "biomass", "base": Color(0.1, 0.26, 0.17), "accent": Color(0.4, 1.0, 0.55), "hazard": "acid"},
	Type.FUNGAL: {"name": "Fungal", "resource": "biomass", "base": Color(0.2, 0.12, 0.24), "accent": Color(0.7, 1.0, 0.4), "hazard": "spores"},
	Type.FROST: {"name": "Frost", "resource": "crystal", "base": Color(0.2, 0.27, 0.38), "accent": Color(0.55, 0.88, 1.0), "hazard": "cryo"},
	Type.CRYSTAL: {"name": "Crystal", "resource": "crystal", "base": Color(0.2, 0.13, 0.3), "accent": Color(0.85, 0.5, 1.0), "hazard": "shards"},
}
const RESOURCE_NAMES := {"ore": "Ore", "crystal": "Crystal", "biomass": "Biomass"}
const RESOURCE_COLORS := {"ore": Color(2.2, 0.62, 0.32), "crystal": Color(0.7, 1.5, 2.6), "biomass": Color(0.75, 2.2, 0.8)}
const RESOURCE_ORDER: Array[String] = ["ore", "crystal", "biomass"]

var id := -1
var name := ""
var position := Vector2.ZERO
var radius := 100.0
var type := Type.ASHEN
var surface_seed := 0
## Regions the planet's disk overlaps; all of them must be claimed to wake it.
var touching: Array[int] = []
## Deepest of the touching regions; sets how dangerous the surface is.
var depth := 1
var kindled := false
## Its bastion has fallen: landing again skips the assault.
var assaulted := false
## Extractors built on its surface; each makes its outpost mine faster.
var extractors := 0


func info() -> Dictionary:
	return TYPES[type]


func type_name() -> String:
	return TYPES[type]["name"]


func resource() -> String:
	return TYPES[type]["resource"]


func claimed_around(sector: SectorData) -> int:
	var count := 0
	for region_id in touching:
		if sector.regions[region_id].claimed:
			count += 1
	return count


func is_awake(sector: SectorData) -> bool:
	return claimed_around(sector) == touching.size()
