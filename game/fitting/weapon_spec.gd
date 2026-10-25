class_name WeaponSpec
extends RefCounted
## A fitted weapon's final numbers after its mark, neighboring lenses and coils,
## and permanent upgrades are applied. WeaponSystem fires from these.

var component_id := ""
var mode := "aimed"
var style := "bolt"
var rate := 1.0
var damage := 1.0
var speed := 1000.0
var life := 1.0
var count := 1
var spread := 0.0
var parallel := 0.0
var pierce := 0
var homing := 0.0
var aoe := 0.0
var target_range := 0.0
var ammo := 0
var knockback := 0.0
## Where the shots leave the ship, in ship-local space.
var mount := Vector2.ZERO


static func from_weapon(component_id: String, weapon: Dictionary) -> WeaponSpec:
	var spec := WeaponSpec.new()
	spec.component_id = component_id
	spec.mode = weapon.get("mode", "aimed")
	spec.style = weapon.get("style", "bolt")
	spec.rate = weapon.get("rate", 1.0)
	spec.damage = weapon.get("damage", 1.0)
	spec.speed = weapon.get("speed", 1000.0)
	spec.life = weapon.get("life", 1.0)
	spec.count = weapon.get("count", 1)
	spec.spread = weapon.get("spread", 0.0)
	spec.parallel = weapon.get("parallel", 0.0)
	spec.pierce = weapon.get("pierce", 0)
	spec.homing = weapon.get("homing", 0.0)
	spec.aoe = weapon.get("aoe", 0.0)
	spec.target_range = weapon.get("range", 0.0)
	spec.ammo = weapon.get("ammo", 0)
	spec.knockback = weapon.get("knockback", 0.0)
	return spec


func dps() -> float:
	return rate * damage * count
