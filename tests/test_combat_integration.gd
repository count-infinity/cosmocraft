extends GutTest
## Integration tests for the complete combat system.
## Tests weapon->attack type->combat component->attack resolver flow.


const AttackTypesScript = preload("res://shared/combat/attack_types.gd")
const AttackControllerScript = preload("res://client/player/attack_controller.gd")


# =============================================================================
# Test Fixtures
# =============================================================================

var _item_registry: ItemRegistry
var _sword_def: ItemDefinition
var _dagger_def: ItemDefinition
var _bow_def: ItemDefinition
var _spear_def: ItemDefinition


func before_each() -> void:
	_setup_registries()
	_setup_weapons()


func _setup_registries() -> void:
	_item_registry = ItemRegistry.new()


func _setup_weapons() -> void:
	# Sword - melee arc weapon
	_sword_def = ItemDefinition.new()
	_sword_def.id = "iron_sword"
	_sword_def.name = "Iron Sword"
	_sword_def.type = ItemEnums.ItemType.WEAPON
	_sword_def.equip_slot = ItemEnums.EquipSlot.MAIN_HAND
	_sword_def.weapon_type = ItemEnums.WeaponType.SWORD
	_sword_def.base_damage = 15
	_sword_def.attack_speed = 1.0
	_sword_def.attack_range = 60.0
	_sword_def.attack_arc = 1.57  # ~90 degrees
	_item_registry.register_item(_sword_def)

	# Dagger - melee thrust weapon
	_dagger_def = ItemDefinition.new()
	_dagger_def.id = "iron_dagger"
	_dagger_def.name = "Iron Dagger"
	_dagger_def.type = ItemEnums.ItemType.WEAPON
	_dagger_def.equip_slot = ItemEnums.EquipSlot.MAIN_HAND
	_dagger_def.weapon_type = ItemEnums.WeaponType.DAGGER
	_dagger_def.base_damage = 8
	_dagger_def.attack_speed = 1.5
	_dagger_def.attack_range = 40.0
	_dagger_def.attack_arc = 0.5  # Narrow thrust
	_item_registry.register_item(_dagger_def)

	# Bow - ranged weapon
	_bow_def = ItemDefinition.new()
	_bow_def.id = "wooden_bow"
	_bow_def.name = "Wooden Bow"
	_bow_def.type = ItemEnums.ItemType.WEAPON
	_bow_def.equip_slot = ItemEnums.EquipSlot.MAIN_HAND
	_bow_def.weapon_type = ItemEnums.WeaponType.BOW
	_bow_def.base_damage = 12
	_bow_def.attack_speed = 0.8
	_bow_def.attack_range = 200.0
	_bow_def.attack_arc = 0.0
	_item_registry.register_item(_bow_def)

	# Spear - melee thrust weapon
	_spear_def = ItemDefinition.new()
	_spear_def.id = "iron_spear"
	_spear_def.name = "Iron Spear"
	_spear_def.type = ItemEnums.ItemType.WEAPON
	_spear_def.equip_slot = ItemEnums.EquipSlot.MAIN_HAND
	_spear_def.weapon_type = ItemEnums.WeaponType.SPEAR
	_spear_def.base_damage = 14
	_spear_def.attack_speed = 0.9
	_spear_def.attack_range = 80.0
	_spear_def.attack_arc = 0.4
	_item_registry.register_item(_spear_def)


# =============================================================================
# AttackTypesScript.from_weapon_type Tests
# =============================================================================

func test_weapon_type_to_attack_type_sword() -> void:
	var attack_type := AttackTypesScript.from_weapon_type(ItemEnums.WeaponType.SWORD)
	assert_eq(attack_type, AttackTypesScript.Type.MELEE_ARC)


func test_weapon_type_to_attack_type_axe() -> void:
	var attack_type := AttackTypesScript.from_weapon_type(ItemEnums.WeaponType.AXE)
	assert_eq(attack_type, AttackTypesScript.Type.MELEE_ARC)


func test_weapon_type_to_attack_type_mace() -> void:
	var attack_type := AttackTypesScript.from_weapon_type(ItemEnums.WeaponType.MACE)
	assert_eq(attack_type, AttackTypesScript.Type.MELEE_ARC)


func test_weapon_type_to_attack_type_dagger() -> void:
	var attack_type := AttackTypesScript.from_weapon_type(ItemEnums.WeaponType.DAGGER)
	assert_eq(attack_type, AttackTypesScript.Type.MELEE_THRUST)


func test_weapon_type_to_attack_type_spear() -> void:
	var attack_type := AttackTypesScript.from_weapon_type(ItemEnums.WeaponType.SPEAR)
	assert_eq(attack_type, AttackTypesScript.Type.MELEE_THRUST)


func test_weapon_type_to_attack_type_rapier() -> void:
	var attack_type := AttackTypesScript.from_weapon_type(ItemEnums.WeaponType.RAPIER)
	assert_eq(attack_type, AttackTypesScript.Type.MELEE_THRUST)


func test_weapon_type_to_attack_type_bow() -> void:
	var attack_type := AttackTypesScript.from_weapon_type(ItemEnums.WeaponType.BOW)
	assert_eq(attack_type, AttackTypesScript.Type.RANGED)


func test_weapon_type_to_attack_type_crossbow() -> void:
	var attack_type := AttackTypesScript.from_weapon_type(ItemEnums.WeaponType.CROSSBOW)
	assert_eq(attack_type, AttackTypesScript.Type.RANGED)


func test_weapon_type_to_attack_type_gun() -> void:
	var attack_type := AttackTypesScript.from_weapon_type(ItemEnums.WeaponType.GUN)
	assert_eq(attack_type, AttackTypesScript.Type.RANGED)


func test_weapon_type_to_attack_type_staff() -> void:
	var attack_type := AttackTypesScript.from_weapon_type(ItemEnums.WeaponType.STAFF)
	assert_eq(attack_type, AttackTypesScript.Type.RANGED)


func test_weapon_type_to_attack_type_none() -> void:
	var attack_type := AttackTypesScript.from_weapon_type(ItemEnums.WeaponType.NONE)
	assert_eq(attack_type, AttackTypesScript.Type.MELEE_ARC)


func test_weapon_type_to_attack_type_unknown() -> void:
	var attack_type := AttackTypesScript.from_weapon_type(999)
	assert_eq(attack_type, AttackTypesScript.Type.MELEE_ARC)


# =============================================================================
# AttackTypesScript.get_effect_type_for_weapon Tests
# =============================================================================

func test_effect_type_for_sword() -> void:
	var effect_type := AttackTypesScript.get_effect_type_for_weapon(ItemEnums.WeaponType.SWORD)
	assert_eq(effect_type, "melee")


func test_effect_type_for_dagger() -> void:
	var effect_type := AttackTypesScript.get_effect_type_for_weapon(ItemEnums.WeaponType.DAGGER)
	assert_eq(effect_type, "thrust")


func test_effect_type_for_spear() -> void:
	var effect_type := AttackTypesScript.get_effect_type_for_weapon(ItemEnums.WeaponType.SPEAR)
	assert_eq(effect_type, "thrust")


func test_effect_type_for_bow() -> void:
	var effect_type := AttackTypesScript.get_effect_type_for_weapon(ItemEnums.WeaponType.BOW)
	assert_eq(effect_type, "ranged")


func test_effect_type_for_staff() -> void:
	var effect_type := AttackTypesScript.get_effect_type_for_weapon(ItemEnums.WeaponType.STAFF)
	assert_eq(effect_type, "ranged")


func test_effect_type_for_none() -> void:
	var effect_type := AttackTypesScript.get_effect_type_for_weapon(ItemEnums.WeaponType.NONE)
	assert_eq(effect_type, "melee")


# =============================================================================
# AttackController Configuration Tests
# =============================================================================

func test_attack_controller_default_unarmed() -> void:
	var controller := AttackControllerScript.new()

	assert_eq(controller.current_weapon_type, ItemEnums.WeaponType.NONE)
	assert_eq(controller.get_effect_type(), "melee")


func test_attack_controller_configure_from_sword() -> void:
	var controller := AttackControllerScript.new()
	controller.configure_from_item(_sword_def)

	assert_eq(controller.current_weapon_type, ItemEnums.WeaponType.SWORD)
	assert_eq(controller.get_effect_type(), "melee")


func test_attack_controller_configure_from_dagger() -> void:
	var controller := AttackControllerScript.new()
	controller.configure_from_item(_dagger_def)

	assert_eq(controller.current_weapon_type, ItemEnums.WeaponType.DAGGER)
	assert_eq(controller.get_effect_type(), "thrust")


func test_attack_controller_configure_from_bow() -> void:
	var controller := AttackControllerScript.new()
	controller.configure_from_item(_bow_def)

	assert_eq(controller.current_weapon_type, ItemEnums.WeaponType.BOW)
	assert_eq(controller.get_effect_type(), "ranged")


func test_attack_controller_configure_from_null_resets_to_unarmed() -> void:
	var controller := AttackControllerScript.new()
	controller.configure_from_item(_sword_def)  # First configure with sword
	controller.configure_from_item(null)  # Then unequip

	assert_eq(controller.current_weapon_type, ItemEnums.WeaponType.NONE)
	assert_eq(controller.get_effect_type(), "melee")


func test_attack_controller_unarmed_constants() -> void:
	var controller := AttackControllerScript.new()

	assert_eq(controller.UNARMED_DAMAGE, 5.0)
	assert_eq(controller.UNARMED_SPEED, 1.0)
	assert_eq(controller.UNARMED_RANGE, 50.0)
	assert_eq(controller.UNARMED_ARC, 90.0)


# =============================================================================
# Attack Type to Combat Attack Type Mapping Tests
# =============================================================================

func test_melee_arc_maps_to_combat_melee() -> void:
	# Verify MELEE_ARC (0) maps to CombatComponent.MELEE (0)
	assert_true(AttackTypesScript.is_melee(AttackTypesScript.Type.MELEE_ARC))
	assert_false(AttackTypesScript.is_ranged(AttackTypesScript.Type.MELEE_ARC))


func test_melee_thrust_maps_to_combat_melee() -> void:
	# Verify MELEE_THRUST (1) maps to CombatComponent.MELEE (0) - NOT ranged!
	assert_true(AttackTypesScript.is_melee(AttackTypesScript.Type.MELEE_THRUST))
	assert_false(AttackTypesScript.is_ranged(AttackTypesScript.Type.MELEE_THRUST))


func test_ranged_maps_to_combat_ranged() -> void:
	# Verify RANGED (2) maps to CombatComponent.RANGED (1)
	assert_false(AttackTypesScript.is_melee(AttackTypesScript.Type.RANGED))
	assert_true(AttackTypesScript.is_ranged(AttackTypesScript.Type.RANGED))


# =============================================================================
# ItemDefinition Weapon Fields Tests
# =============================================================================

func test_item_definition_has_weapon_fields() -> void:
	var sword := ItemDefinition.new()
	sword.weapon_type = ItemEnums.WeaponType.SWORD
	sword.attack_range = 60.0
	sword.attack_arc = 1.57

	assert_eq(sword.weapon_type, ItemEnums.WeaponType.SWORD)
	assert_eq(sword.attack_range, 60.0)
	assert_almost_eq(sword.attack_arc, 1.57, 0.01)


func test_item_definition_serialization_includes_weapon_fields() -> void:
	var sword := ItemDefinition.new()
	sword.id = "test_sword"
	sword.weapon_type = ItemEnums.WeaponType.SWORD
	sword.attack_range = 60.0
	sword.attack_arc = 1.57

	var data := sword.to_dict()

	assert_eq(data["weapon_type"], ItemEnums.WeaponType.SWORD)
	assert_eq(data["attack_range"], 60.0)
	assert_almost_eq(data["attack_arc"], 1.57, 0.01)


func test_item_definition_deserialization_loads_weapon_fields() -> void:
	var data := {
		"id": "test_sword",
		"weapon_type": ItemEnums.WeaponType.SPEAR,
		"attack_range": 80.0,
		"attack_arc": 0.4,
	}

	var sword := ItemDefinition.from_dict(data)

	assert_eq(sword.weapon_type, ItemEnums.WeaponType.SPEAR)
	assert_eq(sword.attack_range, 80.0)
	assert_almost_eq(sword.attack_arc, 0.4, 0.01)


# =============================================================================
# ItemEnums.WeaponType Tests
# =============================================================================

func test_weapon_type_enum_values() -> void:
	assert_eq(ItemEnums.WeaponType.NONE, 0)
	assert_eq(ItemEnums.WeaponType.SWORD, 1)
	assert_eq(ItemEnums.WeaponType.AXE, 2)
	assert_eq(ItemEnums.WeaponType.MACE, 3)
	assert_eq(ItemEnums.WeaponType.DAGGER, 4)
	assert_eq(ItemEnums.WeaponType.SPEAR, 5)
	assert_eq(ItemEnums.WeaponType.RAPIER, 6)
	assert_eq(ItemEnums.WeaponType.BOW, 7)
	assert_eq(ItemEnums.WeaponType.CROSSBOW, 8)
	assert_eq(ItemEnums.WeaponType.GUN, 9)
	assert_eq(ItemEnums.WeaponType.STAFF, 10)


func test_weapon_type_name_sword() -> void:
	var name := ItemEnums.get_weapon_type_name(ItemEnums.WeaponType.SWORD)
	assert_eq(name, "Sword")


func test_weapon_type_name_bow() -> void:
	var name := ItemEnums.get_weapon_type_name(ItemEnums.WeaponType.BOW)
	assert_eq(name, "Bow")


func test_weapon_type_name_none() -> void:
	var name := ItemEnums.get_weapon_type_name(ItemEnums.WeaponType.NONE)
	assert_eq(name, "None")


func test_weapon_type_name_unknown() -> void:
	var name := ItemEnums.get_weapon_type_name(999)
	assert_eq(name, "Unknown")


# =============================================================================
# Attack Type Consistency Tests
# =============================================================================

func test_all_melee_arc_weapons_give_melee_effect() -> void:
	var melee_arc_weapons := [
		ItemEnums.WeaponType.SWORD,
		ItemEnums.WeaponType.AXE,
		ItemEnums.WeaponType.MACE,
	]

	for weapon_type in melee_arc_weapons:
		var attack_type := AttackTypesScript.from_weapon_type(weapon_type)
		var effect_type := AttackTypesScript.get_effect_type_for_weapon(weapon_type)
		assert_eq(attack_type, AttackTypesScript.Type.MELEE_ARC, "Weapon %d should be MELEE_ARC" % weapon_type)
		assert_eq(effect_type, "melee", "Weapon %d should have melee effect" % weapon_type)


func test_all_thrust_weapons_give_thrust_effect() -> void:
	var thrust_weapons := [
		ItemEnums.WeaponType.DAGGER,
		ItemEnums.WeaponType.SPEAR,
		ItemEnums.WeaponType.RAPIER,
	]

	for weapon_type in thrust_weapons:
		var attack_type := AttackTypesScript.from_weapon_type(weapon_type)
		var effect_type := AttackTypesScript.get_effect_type_for_weapon(weapon_type)
		assert_eq(attack_type, AttackTypesScript.Type.MELEE_THRUST, "Weapon %d should be MELEE_THRUST" % weapon_type)
		assert_eq(effect_type, "thrust", "Weapon %d should have thrust effect" % weapon_type)


func test_all_ranged_weapons_give_ranged_effect() -> void:
	var ranged_weapons := [
		ItemEnums.WeaponType.BOW,
		ItemEnums.WeaponType.CROSSBOW,
		ItemEnums.WeaponType.GUN,
		ItemEnums.WeaponType.STAFF,
	]

	for weapon_type in ranged_weapons:
		var attack_type := AttackTypesScript.from_weapon_type(weapon_type)
		var effect_type := AttackTypesScript.get_effect_type_for_weapon(weapon_type)
		assert_eq(attack_type, AttackTypesScript.Type.RANGED, "Weapon %d should be RANGED" % weapon_type)
		assert_eq(effect_type, "ranged", "Weapon %d should have ranged effect" % weapon_type)
