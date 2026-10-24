class_name SpaceTuning
extends Resource
## Every tunable number for the space mode in one place. Tweak these on the
## SpaceGame node in the inspector while playtesting.

## Area of one 1280x720 screen, the unit claim time is measured in.
const SCREEN_AREA := 1280.0 * 720.0

@export_group("Sector")
@export var sector_radius := 2600.0
@export var region_count := 16
@export var relax_iterations := 1
## Regions must share at least this much border to count as neighbors.
@export var min_shared_edge := 40.0

@export_group("Claim")
@export var claim_base_seconds := 15.0
## Extra hold time for each screen's worth of region area.
@export var claim_seconds_per_screen := 45.0
@export var claim_min_seconds := 30.0
@export var claim_max_seconds := 240.0
## Time you can spend outside the region before progress starts draining.
@export var claim_grace_seconds := 3.0
## Drain speed relative to the fill speed.
@export var claim_drain_rate := 2.0
## Hold time each collected spark is worth.
@export var spark_seconds := 0.3
## Progress lost when a Snuffer reaches your spark.
@export var snuff_penalty := 0.15
## Debug: speeds up every claim.
@export var claim_speed_multiplier := 1.0

@export_group("Waves")
@export var credits_per_second := 1.3
## Credit-rate multipliers at 0% and 100% progress; the siege escalates between them.
@export var ramp_start := 0.8
@export var ramp_end := 2.6
## Extra intensity for each step a region is away from home.
@export var threat_per_depth := 0.25
@export var max_alive := 70
@export var max_snuffers := 2
## Progress at which the elite Snuffer arrives.
@export var elite_threshold := 0.9
@export var max_banked_credits := 20.0

@export_group("Ship")
@export var ship_max_speed := 430.0
@export var ship_accel := 2600.0
@export var ship_decel := 1500.0
@export var dash_speed := 1150.0
@export var dash_duration := 0.16
@export var dash_iframes := 0.28
@export var dash_cooldown := 0.85
@export var fire_rate := 9.0
@export var bullet_speed := 1150.0
@export var bullet_damage := 1.0
@export var bullet_spread_degrees := 2.5
@export var max_shield := 50.0
@export var max_hull := 100.0
## Shields and hull only recharge inside your own territory.
@export var shield_regen := 30.0
@export var hull_regen := 8.0
@export var regen_delay := 1.2
@export var hit_iframes := 0.4
@export var respawn_delay := 2.0
