class_name ComponentLibrary
extends RefCounted
## Every ship part in the game. Numbers are Mk I; marks scale them.
##
## Weapon keys: mode (aimed / auto / secondary), rate (volleys per second),
## damage, speed, life, count, spread (degrees), parallel (px between twin
## shots), pierce, homing (turn rate), aoe (blast radius), range (auto
## targeting), ammo, knockback, style.
##
## Stat keys: max_hull, max_shield, speed (fraction), magnet (px),
## dash_cooldown (fraction off), claim_speed (fraction), point_defense
## (zaps per second), dark_regen (shield per second outside your light).

const WEAPON_COLOR := Color(1.0, 0.62, 0.3)
const DEFENSE_COLOR := Color(0.4, 0.82, 1.0)
const UTILITY_COLOR := Color(0.55, 0.95, 0.55)
const POWER_COLOR := Color(1.0, 0.9, 0.35)

static var _defs: Dictionary = {}


static func get_def(id: String) -> ComponentDef:
	_ensure_loaded()
	return _defs.get(id)


static func all() -> Array[ComponentDef]:
	_ensure_loaded()
	var result: Array[ComponentDef] = []
	for def: ComponentDef in _defs.values():
		result.append(def)
	return result


static func _ensure_loaded() -> void:
	if not _defs.is_empty():
		return
	# Weapons
	_add("pulse_laser", "Pulse Laser", "Fast, accurate bolts. The Kindler's standard gun.",
		ComponentDef.Category.WEAPON, ComponentDef.Rarity.COMMON, [Vector2i(0, 0)], 1, "PL",
		{}, {}, {"mode": "aimed", "rate": 7.0, "damage": 1.0, "speed": 1150.0, "life": 0.9, "count": 1, "spread": 2.5, "style": "bolt"})
	_add("twin_laser", "Twin Laser", "Two parallel bolts per shot.",
		ComponentDef.Category.WEAPON, ComponentDef.Rarity.UNCOMMON, [Vector2i(0, 0), Vector2i(0, 1)], 2, "TL",
		{}, {}, {"mode": "aimed", "rate": 6.0, "damage": 1.0, "speed": 1150.0, "life": 0.9, "count": 2, "parallel": 8.0, "spread": 1.5, "style": "bolt"})
	_add("scattergun", "Scattergun", "A wide, short-ranged blast that shoves enemies back.",
		ComponentDef.Category.WEAPON, ComponentDef.Rarity.COMMON, [Vector2i(0, 0), Vector2i(1, 0)], 2, "SG",
		{}, {}, {"mode": "aimed", "rate": 2.2, "damage": 1.0, "speed": 900.0, "life": 0.38, "count": 6, "spread": 30.0, "knockback": 160.0, "style": "pellet"})
	_add("lance", "Lance", "A slow, heavy beam that pierces everything in its path.",
		ComponentDef.Category.WEAPON, ComponentDef.Rarity.RARE, [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)], 3, "LN",
		{}, {}, {"mode": "aimed", "rate": 1.4, "damage": 5.0, "speed": 2000.0, "life": 0.7, "count": 1, "spread": 0.0, "pierce": 99, "style": "lance"}, 2)
	_add("seeker_pod", "Seeker Pod", "Fires homing missiles at nearby enemies on its own.",
		ComponentDef.Category.WEAPON, ComponentDef.Rarity.UNCOMMON, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], 2, "SK",
		{}, {}, {"mode": "auto", "rate": 0.7, "damage": 3.0, "speed": 520.0, "life": 2.6, "count": 2, "spread": 50.0, "homing": 5.0, "aoe": 40.0, "range": 700.0, "style": "missile"})
	_add("flak_turret", "Flak Turret", "Auto-aims at the nearest enemy and bursts in a small blast.",
		ComponentDef.Category.WEAPON, ComponentDef.Rarity.UNCOMMON, [Vector2i(0, 0)], 2, "FK",
		{}, {}, {"mode": "auto", "rate": 1.5, "damage": 1.5, "speed": 700.0, "life": 0.6, "count": 1, "spread": 0.0, "aoe": 70.0, "range": 420.0, "style": "flak"})
	_add("torpedo_bay", "Torpedo Bay", "Right click fires a heavy torpedo. Rearms inside your light.",
		ComponentDef.Category.WEAPON, ComponentDef.Rarity.RARE, [Vector2i(0, 0), Vector2i(0, 1)], 1, "TP",
		{}, {}, {"mode": "secondary", "rate": 1.5, "damage": 18.0, "speed": 600.0, "life": 2.0, "count": 1, "spread": 0.0, "aoe": 140.0, "ammo": 3, "style": "torpedo"})
	# Defense
	_add("shield_generator", "Shield Generator", "+30 shield.",
		ComponentDef.Category.DEFENSE, ComponentDef.Rarity.COMMON, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], 2, "SH",
		{"max_shield": 30.0})
	_add("armor_plate", "Armor Plate", "+30 hull, slightly slower.",
		ComponentDef.Category.DEFENSE, ComponentDef.Rarity.COMMON, [Vector2i(0, 0), Vector2i(0, 1)], 0, "AR",
		{"max_hull": 30.0, "speed": -0.04})
	_add("point_defense", "Point Defense", "Zaps enemy shots that come close.",
		ComponentDef.Category.DEFENSE, ComponentDef.Rarity.UNCOMMON, [Vector2i(0, 0)], 2, "PD",
		{"point_defense": 2.0})
	_add("field_capacitor", "Field Capacitor", "Shields slowly recharge even in the dark.",
		ComponentDef.Category.DEFENSE, ComponentDef.Rarity.RARE, [Vector2i(0, 0)], 2, "FC",
		{"dark_regen": 4.0})
	# Utility
	_add("magnet_coil", "Magnet Coil", "Pulls sparks in from farther away.",
		ComponentDef.Category.UTILITY, ComponentDef.Rarity.COMMON, [Vector2i(0, 0)], 1, "MG",
		{"magnet": 55.0})
	_add("thruster", "Thruster", "+12% speed.",
		ComponentDef.Category.UTILITY, ComponentDef.Rarity.COMMON, [Vector2i(0, 0), Vector2i(0, 1)], 1, "TH",
		{"speed": 0.12})
	_add("dash_capacitor", "Dash Capacitor", "Dash recharges 25% faster.",
		ComponentDef.Category.UTILITY, ComponentDef.Rarity.COMMON, [Vector2i(0, 0)], 1, "DC",
		{"dash_cooldown": 0.25})
	_add("kindler_array", "Kindler Array", "Claims fill 15% faster.",
		ComponentDef.Category.UTILITY, ComponentDef.Rarity.UNCOMMON, [Vector2i(0, 0), Vector2i(1, 0)], 2, "KA",
		{"claim_speed": 0.15})
	_add("focusing_lens", "Focusing Lens", "Weapons touching it deal 30% more damage.",
		ComponentDef.Category.UTILITY, ComponentDef.Rarity.UNCOMMON, [Vector2i(0, 0)], 1, "LS",
		{}, {"damage": 0.3})
	_add("overclock_coil", "Overclock Coil", "Weapons touching it fire 25% faster.",
		ComponentDef.Category.UTILITY, ComponentDef.Rarity.UNCOMMON, [Vector2i(0, 0)], 1, "OC",
		{}, {"rate": 0.25})
	# Power
	_add("reactor", "Reactor", "Supplies 4 power (+1 per mark).",
		ComponentDef.Category.POWER, ComponentDef.Rarity.COMMON, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)], -4, "RX")


static func _add(id: String, display_name: String, description: String, category: ComponentDef.Category,
		rarity: ComponentDef.Rarity, shape: Array[Vector2i], power: int, glyph: String,
		stats: Dictionary = {}, adjacency: Dictionary = {}, weapon: Dictionary = {}, min_hull_class := 1) -> void:
	var def := ComponentDef.new()
	def.id = id
	def.display_name = display_name
	def.description = description
	def.category = category
	def.rarity = rarity
	def.shape = shape
	def.power = power
	def.glyph = glyph
	def.stats = stats
	def.adjacency = adjacency
	def.weapon = weapon
	def.needs_hardpoint = not weapon.is_empty()
	def.min_hull_class = min_hull_class
	match category:
		ComponentDef.Category.WEAPON:
			def.color = WEAPON_COLOR
		ComponentDef.Category.DEFENSE:
			def.color = DEFENSE_COLOR
		ComponentDef.Category.POWER:
			def.color = POWER_COLOR
		_:
			def.color = UTILITY_COLOR
	_defs[id] = def
