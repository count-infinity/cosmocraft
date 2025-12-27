class_name AttackTypes
extends RefCounted
## Attack type definitions for combat system.
## Provides type-safe attack type handling instead of magic strings.


## Valid attack types
enum Type {
	MELEE_ARC,     ## Wide arc melee attack (sword swing)
	MELEE_THRUST,  ## Narrow line melee attack (spear thrust)
	RANGED         ## Projectile attack hitting nearest target
}


## Convert string to attack type. Returns -1 if invalid.
static func from_string(s: String) -> int:
	match s.to_lower():
		"melee_arc":
			return Type.MELEE_ARC
		"melee_thrust":
			return Type.MELEE_THRUST
		"ranged":
			return Type.RANGED
		_:
			return -1


## Convert attack type to string
static func to_string_name(attack_type: int) -> String:
	match attack_type:
		Type.MELEE_ARC:
			return "melee_arc"
		Type.MELEE_THRUST:
			return "melee_thrust"
		Type.RANGED:
			return "ranged"
		_:
			return "unknown"


## Check if attack type is valid
static func is_valid(attack_type: int) -> bool:
	return attack_type >= 0 and attack_type <= Type.RANGED


## Check if attack type is melee (arc or thrust)
static func is_melee(attack_type: int) -> bool:
	return attack_type == Type.MELEE_ARC or attack_type == Type.MELEE_THRUST


## Check if attack type is ranged
static func is_ranged(attack_type: int) -> bool:
	return attack_type == Type.RANGED


## Convert weapon type to attack type
static func from_weapon_type(weapon_type: int) -> int:
	match weapon_type:
		ItemEnums.WeaponType.NONE:
			return Type.MELEE_ARC  # Unarmed defaults to melee arc
		ItemEnums.WeaponType.SWORD, ItemEnums.WeaponType.AXE, ItemEnums.WeaponType.MACE:
			return Type.MELEE_ARC
		ItemEnums.WeaponType.DAGGER, ItemEnums.WeaponType.SPEAR, ItemEnums.WeaponType.RAPIER:
			return Type.MELEE_THRUST
		ItemEnums.WeaponType.BOW, ItemEnums.WeaponType.CROSSBOW, ItemEnums.WeaponType.GUN, ItemEnums.WeaponType.STAFF:
			return Type.RANGED
		_:
			push_warning("AttackTypes: Unknown weapon_type %d, defaulting to MELEE_ARC" % weapon_type)
			return Type.MELEE_ARC


## Convert weapon type to effect type string for AttackEffect
static func get_effect_type_for_weapon(weapon_type: int) -> String:
	match weapon_type:
		ItemEnums.WeaponType.SWORD, ItemEnums.WeaponType.AXE, ItemEnums.WeaponType.MACE:
			return "melee"
		ItemEnums.WeaponType.DAGGER, ItemEnums.WeaponType.SPEAR, ItemEnums.WeaponType.RAPIER:
			return "thrust"
		ItemEnums.WeaponType.BOW, ItemEnums.WeaponType.CROSSBOW, ItemEnums.WeaponType.GUN, ItemEnums.WeaponType.STAFF:
			return "ranged"
		_:
			return "melee"
