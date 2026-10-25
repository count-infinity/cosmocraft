class_name WeaponSystem
extends RefCounted
## Fires every weapon on a ship (or a pilot on foot): aimed guns while the
## trigger is held, auto turrets at whatever is in range, and ammo weapons
## (torpedoes, flares) on right click. Ammo weapons only rearm inside your own
## light. The host provides fire_volley() and nearest_enemy_within().

const REARM_SECONDS := 2.5
## Closer than this to the ship, aimed guns fire along the ship's heading
## instead of converging on the cursor.
const MIN_AIM_DISTANCE := 40.0


class Mount:
	var spec: WeaponSpec
	var cooldown := 0.0
	var ammo := 0
	var rearm := 0.0


var mounts: Array[Mount] = []


## Rebuilds the mounts from a fresh set of specs (after a refit or loot pick).
func configure(specs: Array[WeaponSpec]) -> void:
	mounts.clear()
	for spec in specs:
		var mount := Mount.new()
		mount.spec = spec
		mount.ammo = spec.ammo
		mounts.append(mount)


func update(delta: float, body: Node2D, input: ShipInput, heading: Vector2, firing: bool, secondary: bool, in_light: bool, host: Node) -> void:
	var secondary_ready := secondary
	for mount in mounts:
		var spec := mount.spec
		mount.cooldown = maxf(mount.cooldown - delta, -0.05)
		var origin := body.to_global(spec.mount)
		match spec.mode:
			"aimed":
				if firing and mount.cooldown <= 0.0:
					mount.cooldown += 1.0 / spec.rate
					host.fire_volley(spec, origin, _aim_direction(input, heading, origin), null)
			"auto":
				if mount.cooldown <= 0.0:
					var target: GloomEnemy = host.nearest_enemy_within(origin, spec.target_range)
					if target != null:
						mount.cooldown += 1.0 / spec.rate
						host.fire_volley(spec, origin, (target.position - origin).normalized(), target)
					else:
						mount.cooldown = 0.0
			"secondary":
				if in_light and mount.ammo < spec.ammo:
					mount.rearm += delta
					if mount.rearm >= REARM_SECONDS:
						mount.rearm = 0.0
						mount.ammo += 1
				if secondary_ready and mount.ammo > 0 and mount.cooldown <= 0.0:
					secondary_ready = false
					mount.ammo -= 1
					mount.cooldown = 1.0 / spec.rate
					host.fire_volley(spec, origin, _aim_direction(input, heading, origin), null)


## Torpedoes left and total capacity, for the HUD.
func ammo_status() -> Vector2i:
	var status := Vector2i.ZERO
	for mount in mounts:
		if mount.spec.mode == "secondary":
			status += Vector2i(mount.ammo, mount.spec.ammo)
	return status


func _aim_direction(input: ShipInput, heading: Vector2, origin: Vector2) -> Vector2:
	var to_aim := input.get_aim_point() - origin
	return to_aim.normalized() if to_aim.length() > MIN_AIM_DISTANCE else heading
