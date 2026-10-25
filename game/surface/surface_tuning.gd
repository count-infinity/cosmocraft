class_name SurfaceTuning
extends SpaceTuning
## Every tunable number for a planet's surface. It extends SpaceTuning so the
## ground siege can reuse Claim and WaveDirector; the inherited wave numbers
## are retuned here for a pilot on foot.

@export_group("Pilot")
@export var pilot_speed := 245.0
@export var pilot_accel := 3200.0
@export var pilot_decel := 2800.0
@export var roll_speed := 720.0
@export var roll_duration := 0.2
@export var roll_iframes := 0.32
@export var roll_cooldown := 0.75
@export var pilot_health := 100.0
@export var pilot_barrier := 40.0
## Barrier recharge per second at the lander, in a flare's glow, or anywhere
## once the planet is kindled (the pylon's light doesn't heal while it charges).
@export var barrier_regen := 24.0
## Health recharge per second at the lander.
@export var lander_heal := 8.0
@export var pilot_magnet := 110.0
@export var lantern_radius := 300.0

@export_group("Surface")
## The Gloom moves slower on the ground so a pilot on foot can keep up.
@export var enemy_speed_scale := 0.75
@export var enemy_wake_range := 650.0
@export var siege_base_seconds := 40.0
@export var siege_seconds_per_depth := 8.0
## Stay this close to the pylon to keep it charging.
@export var siege_radius := 320.0
## Resources paid out when the planet is kindled.
@export var haul_base := 15
@export var haul_per_depth := 5
@export var kindle_sparks := 25
@export var hazard_dps := 10.0
## How much the Gloom slows inside the charging pylon's light, and a flare's.
@export var pylon_slow := 0.3
@export var flare_slow := 0.5


func _init() -> void:
	max_alive = 42
	max_snuffers = 2
	credits_per_second = 1.35
	ramp_start = 0.9
	ramp_end = 2.4
	elite_threshold = 0.85
	base_threat = 0.75
	threat_per_depth = 0.25
	claim_drain_rate = 1.5
	hit_iframes = 0.5
	regen_delay = 1.5


## Surface tuning that keeps the debug claim speed from space.
static func from_space(space: SpaceTuning) -> SurfaceTuning:
	var tuning := SurfaceTuning.new()
	tuning.claim_speed_multiplier = space.claim_speed_multiplier
	tuning.spark_seconds = space.spark_seconds
	return tuning


func siege_seconds(depth: int) -> float:
	return siege_base_seconds + siege_seconds_per_depth * depth


func haul(depth: int) -> int:
	return haul_base + haul_per_depth * depth
