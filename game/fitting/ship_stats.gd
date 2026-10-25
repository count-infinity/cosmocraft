class_name ShipStats
extends RefCounted
## Everything a loadout adds up to: the numbers the ship actually flies with.

var max_hull := 100.0
var max_shield := 20.0
var speed := 430.0
var magnet := 90.0
var dash_cooldown := 0.85
var claim_speed := 1.0
var point_defense := 0.0
var dark_regen := 0.0
var power_used := 0
var power_capacity := 0
var radius := 11.0
var weapons: Array[WeaponSpec] = []


func total_dps() -> float:
	var total := 0.0
	for weapon in weapons:
		if weapon.mode != "secondary":
			total += weapon.dps()
	return total
