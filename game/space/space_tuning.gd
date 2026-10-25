class_name SpaceTuning
extends Resource
## Every tunable number for the space mode in one place. Tweak these on the
## SpaceGame node in the inspector while playtesting.

## Area of one 1280x720 screen, the unit claim time is measured in.
const SCREEN_AREA := 1280.0 * 720.0

@export_group("Sector")
@export var sector_radius := 2600.0
## Voronoi cells scattered first; neighbors then merge into bigger regions.
@export var cell_count := 34
@export var region_count := 16
@export var max_cells_per_region := 4
## Cells merged into the heart, the run's final siege.
@export var heart_cells := 5
@export var relax_iterations := 1
## Regions must share at least this much border to count as neighbors.
@export var min_shared_edge := 40.0
## Chance that a region beyond the first ring gets a modifier.
@export var modifier_chance := 0.45
@export var planet_count := 2
@export var planet_spacing := 1400.0

@export_group("Claim")
@export var claim_base_seconds := 10.0
## Extra hold time for each screen's worth of region area.
@export var claim_seconds_per_screen := 50.0
@export var claim_min_seconds := 25.0
@export var claim_max_seconds := 300.0
@export var heart_claim_scale := 1.0
## Regions you must hold before the heart can be kindled.
@export var heart_requires_claims := 5
## Time you can spend outside the region before progress starts draining.
@export var claim_grace_seconds := 3.0
## Drain speed relative to the fill speed.
@export var claim_drain_rate := 2.0
## Progress lost when a Snuffer reaches your spark.
@export var snuff_penalty := 0.15
## Debug: speeds up every claim.
@export var claim_speed_multiplier := 1.0

@export_group("Sparks")
## Hold time each collected spark is worth.
@export var spark_seconds := 0.2
@export var magnet_radius := 90.0
@export var nest_credit_scale := 1.8
@export var nest_drop_scale := 1.5
@export var rich_bonus_sparks := 40

@export_group("Waves")
@export var credits_per_second := 1.3
## Pressure in the first ring of regions around home; each step deeper adds
## threat_per_depth (the heart adds 0.5 on top).
@export var base_threat := 0.7
## Credit-rate multipliers at 0% and 100% progress; the siege escalates between them.
@export var ramp_start := 0.8
@export var ramp_end := 2.6
## Extra intensity for each step a region is away from home.
@export var threat_per_depth := 0.3
## Gloom health grows this much per step past the second ring (and is lower
## in the first).
@export var health_per_depth := 0.15
## In the deepest regions (depth 4 and beyond) a spawn may come as elites.
@export var deep_elite_chance := 0.12
@export var max_alive := 70
## Fewer Gloom may be alive at once near home: this many plus alive_per_depth
## for each step out, up to max_alive.
@export var alive_base := 24
@export var alive_per_depth := 12
## Long claims earn credits slower (by the square root of how much longer than
## pace_seconds they are), so a big region is a longer siege, not a denser one.
@export var pace_seconds := 60.0
@export var min_pace := 0.45
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
## Weapons, hull and shield capacity come from the fitted loadout.
## Shields and hull only recharge inside your own territory.
@export var shield_regen := 30.0
@export var hull_regen := 8.0
@export var regen_delay := 1.2
@export var hit_iframes := 0.4
@export var respawn_delay := 2.0


## Wave pressure for a region (or planet) `depth` steps from home.
func threat_for(depth: int) -> float:
	return base_threat + threat_per_depth * maxi(depth - 1, 0)


## How many Gloom may be alive at once in a claim `depth` steps from home.
func alive_cap(depth: int) -> int:
	return mini(max_alive, alive_base + alive_per_depth * depth)


## Credit-rate multiplier for a claim that takes `claim_seconds` to fill.
func pace_for(claim_seconds: float) -> float:
	return clampf(sqrt(pace_seconds / maxf(claim_seconds, 1.0)), min_pace, 1.0)


## Gloom health multiplier `depth` steps from home.
func health_scale(depth: int) -> float:
	return maxf(1.0 + health_per_depth * (depth - 2), 0.7)
