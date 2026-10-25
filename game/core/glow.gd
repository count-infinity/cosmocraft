class_name Glow
extends RefCounted
## The shared neon look: HDR 2D so colors above 1.0 can glow, a dark clear
## color, and a single WorldEnvironment with 2D glow for whatever mode is on
## screen (space, a planet's surface, or the homeworld).

const GROUP := "cosmocraft_glow"
const BACKGROUND := Color(0.012, 0.012, 0.03)
const LEVELS: Array[float] = [0.0, 0.5, 1.0, 0.8, 0.5, 0.2, 0.0]


## Sets up the look once; later calls find the existing environment.
static func ensure(host: Node) -> void:
	var tree := host.get_tree()
	tree.root.use_hdr_2d = true
	RenderingServer.set_default_clear_color(BACKGROUND)
	if tree.get_first_node_in_group(GROUP) != null:
		return
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CANVAS
	environment.glow_enabled = true
	environment.glow_intensity = 0.8
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 1.0
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for i in LEVELS.size():
		environment.set_glow_level(i, LEVELS[i])
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world_environment.add_to_group(GROUP)
	host.add_child(world_environment)
