class_name HUD
extends CanvasLayer

const InventoryPanelClass = preload("res://client/ui/inventory_panel.gd")
const EquipmentPanelClass = preload("res://client/ui/equipment_panel.gd")
const HotbarUIClass = preload("res://client/ui/hotbar_ui.gd")
const ItemTooltipClass = preload("res://client/ui/item_tooltip.gd")
const CraftingPanelClass = preload("res://client/ui/crafting_panel.gd")
const StatsPanelClass = preload("res://client/ui/stats_panel.gd")
const HealthBarClass = preload("res://client/ui/health_bar.gd")

var player_count_label: Label
var ping_label: Label
var position_label: Label
var minimap_hint_label: Label
var keybind_hint_label: Label

# Minimap
var minimap: Minimap = null
var MinimapScene: PackedScene = preload("res://client/ui/minimap.tscn")
var _minimap_visible: bool = false

# Inventory UI components
var inventory_panel: InventoryPanelClass = null
var equipment_panel: EquipmentPanelClass = null
var hotbar_ui: HotbarUIClass = null
var item_tooltip: ItemTooltipClass = null
var crafting_panel: CraftingPanelClass = null
var stats_panel: StatsPanelClass = null
var health_bar: HealthBarClass = null

var InventoryPanelScene: PackedScene = preload("res://client/ui/inventory_panel.tscn")
var EquipmentPanelScene: PackedScene = preload("res://client/ui/equipment_panel.tscn")
var HotbarScene: PackedScene = preload("res://client/ui/hotbar_ui.tscn")
var TooltipScene: PackedScene = preload("res://client/ui/item_tooltip.tscn")
var CraftingPanelScene: PackedScene = preload("res://client/ui/crafting_panel.tscn")
var StatsPanelScene: PackedScene = preload("res://client/ui/stats_panel.tscn")
var HealthBarScene: PackedScene = preload("res://client/ui/health_bar.tscn")

# Death overlay
var death_overlay: ColorRect = null
var death_label: Label = null

# Reference to game client
var _game_client: GameClient = null


func _ready() -> void:
	_create_ui()


func _create_ui() -> void:
	# Top-left info panel
	var panel := PanelContainer.new()
	panel.position = Vector2(10, 10)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	# Player count
	player_count_label = Label.new()
	player_count_label.text = "Players: 0"
	vbox.add_child(player_count_label)

	# Ping
	ping_label = Label.new()
	ping_label.text = "Ping: --"
	vbox.add_child(ping_label)

	# Position (for debugging)
	position_label = Label.new()
	position_label.text = "Pos: (0, 0)"
	vbox.add_child(position_label)

	# Keybind hints
	minimap_hint_label = Label.new()
	minimap_hint_label.text = "[M] Map"
	minimap_hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(minimap_hint_label)

	keybind_hint_label = Label.new()
	keybind_hint_label.text = "[I/Tab] Inventory  [C] Equipment  [K] Crafting  [P] Stats"
	keybind_hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	keybind_hint_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(keybind_hint_label)

	# Create minimap (hidden by default)
	_create_minimap()

	# Create inventory UI components
	_create_inventory_ui()


func _create_minimap() -> void:
	minimap = MinimapScene.instantiate()
	minimap.visible = false

	# Position in top-right corner
	var anchor_container := Control.new()
	anchor_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	anchor_container.position = Vector2(-220, 10)
	add_child(anchor_container)
	anchor_container.add_child(minimap)


func _create_inventory_ui() -> void:
	# Create tooltip (shared by all inventory UIs)
	item_tooltip = TooltipScene.instantiate()
	item_tooltip.z_index = 100  # Ensure tooltip is on top
	add_child(item_tooltip)

	# Create health bar (top-left, below info panel)
	health_bar = HealthBarScene.instantiate()
	var health_anchor := Control.new()
	health_anchor.set_anchors_preset(Control.PRESET_TOP_LEFT)
	health_anchor.position = Vector2(10, 130)  # Below the info panel
	add_child(health_anchor)
	health_anchor.add_child(health_bar)

	# Create death overlay (hidden by default, full screen)
	_create_death_overlay()

	# Create inventory panel (hidden by default, centered)
	inventory_panel = InventoryPanelScene.instantiate()
	inventory_panel.visible = false
	var inv_anchor := Control.new()
	inv_anchor.set_anchors_preset(Control.PRESET_CENTER)
	inv_anchor.position = Vector2(-200, -150)
	add_child(inv_anchor)
	inv_anchor.add_child(inventory_panel)

	# Create equipment panel (hidden by default, to the right of inventory)
	equipment_panel = EquipmentPanelScene.instantiate()
	equipment_panel.visible = false
	var equip_anchor := Control.new()
	equip_anchor.set_anchors_preset(Control.PRESET_CENTER)
	equip_anchor.position = Vector2(220, -150)
	add_child(equip_anchor)
	equip_anchor.add_child(equipment_panel)

	# Create hotbar (visible, bottom center)
	hotbar_ui = HotbarScene.instantiate()
	var hotbar_anchor := Control.new()
	hotbar_anchor.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar_anchor.position = Vector2(-220, -80)  # Centered horizontally, above bottom
	add_child(hotbar_anchor)
	hotbar_anchor.add_child(hotbar_ui)

	# Create crafting panel (hidden by default, centered)
	crafting_panel = CraftingPanelScene.instantiate()
	crafting_panel.visible = false
	var craft_anchor := Control.new()
	craft_anchor.set_anchors_preset(Control.PRESET_CENTER)
	craft_anchor.position = Vector2(-300, -200)
	add_child(craft_anchor)
	craft_anchor.add_child(crafting_panel)

	# Create stats panel (hidden by default, left of center)
	stats_panel = StatsPanelScene.instantiate()
	stats_panel.visible = false
	var stats_anchor := Control.new()
	stats_anchor.set_anchors_preset(Control.PRESET_CENTER)
	stats_anchor.position = Vector2(-460, -210)
	add_child(stats_anchor)
	stats_anchor.add_child(stats_panel)


## Initialize HUD with game client for inventory data
func initialize_game_client(game_client: GameClient) -> void:
	_game_client = game_client

	# Initialize inventory UI components with game client
	if inventory_panel != null:
		inventory_panel.initialize(game_client, item_tooltip)

	if equipment_panel != null:
		equipment_panel.initialize(game_client, item_tooltip)

	if hotbar_ui != null:
		hotbar_ui.initialize(game_client, item_tooltip)

	if crafting_panel != null:
		crafting_panel.initialize(game_client, item_tooltip)

	if stats_panel != null:
		stats_panel.initialize(game_client)

	# Initialize health bar
	if health_bar != null:
		health_bar.initialize(game_client)
		health_bar.player_died.connect(_on_player_died)
		health_bar.player_respawned.connect(_on_player_respawned)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_M:
				toggle_minimap()
				get_viewport().set_input_as_handled()
			KEY_I, KEY_TAB:
				toggle_inventory()
				get_viewport().set_input_as_handled()
			KEY_C:
				toggle_equipment()
				get_viewport().set_input_as_handled()
			KEY_K:
				toggle_crafting()
				get_viewport().set_input_as_handled()
			KEY_P:
				toggle_stats()
				get_viewport().set_input_as_handled()


func toggle_minimap() -> void:
	_minimap_visible = not _minimap_visible
	if minimap:
		minimap.visible = _minimap_visible


func toggle_inventory() -> void:
	if inventory_panel:
		inventory_panel.visible = not inventory_panel.visible
		# Hide tooltip when closing
		if not inventory_panel.visible and item_tooltip:
			item_tooltip.hide()


func toggle_equipment() -> void:
	if equipment_panel:
		equipment_panel.visible = not equipment_panel.visible
		# Hide tooltip when closing
		if not equipment_panel.visible and item_tooltip:
			item_tooltip.hide()


func toggle_crafting() -> void:
	if crafting_panel:
		crafting_panel.visible = not crafting_panel.visible
		# Hide tooltip when closing
		if not crafting_panel.visible and item_tooltip:
			item_tooltip.hide()


func toggle_stats() -> void:
	if stats_panel:
		stats_panel.visible = not stats_panel.visible


func show_crafting() -> void:
	if crafting_panel:
		crafting_panel.visible = true


func hide_crafting() -> void:
	if crafting_panel:
		crafting_panel.visible = false
		if item_tooltip:
			item_tooltip.hide()


func show_inventory() -> void:
	if inventory_panel:
		inventory_panel.visible = true


func hide_inventory() -> void:
	if inventory_panel:
		inventory_panel.visible = false
		if item_tooltip:
			item_tooltip.hide()


func show_equipment() -> void:
	if equipment_panel:
		equipment_panel.visible = true


func hide_equipment() -> void:
	if equipment_panel:
		equipment_panel.visible = false
		if item_tooltip:
			item_tooltip.hide()


func show_stats() -> void:
	if stats_panel:
		stats_panel.visible = true


func hide_stats() -> void:
	if stats_panel:
		stats_panel.visible = false


func initialize_minimap(chunk_manager: ChunkManager) -> void:
	if minimap:
		minimap.initialize(chunk_manager)


func update_player_count(count: int) -> void:
	player_count_label.text = "Players: %d" % count


func update_ping(ms: int) -> void:
	ping_label.text = "Ping: %d ms" % ms


func update_position(pos: Vector2) -> void:
	position_label.text = "Pos: (%.0f, %.0f)" % [pos.x, pos.y]
	# Update minimap with player position
	if minimap and _minimap_visible:
		minimap.update_player_position(pos)


# =============================================================================
# Death overlay
# =============================================================================

func _create_death_overlay() -> void:
	# Full screen semi-transparent overlay
	death_overlay = ColorRect.new()
	death_overlay.color = Color(0.0, 0.0, 0.0, 0.7)
	death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_overlay.visible = false
	death_overlay.z_index = 90  # Below tooltips, above everything else
	add_child(death_overlay)

	# "YOU DIED" message
	death_label = Label.new()
	death_label.text = "YOU DIED\n\nRespawning..."
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_label.add_theme_font_size_override("font_size", 48)
	death_label.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	death_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_overlay.add_child(death_label)


func _on_player_died() -> void:
	if death_overlay != null:
		death_overlay.visible = true


func _on_player_respawned() -> void:
	if death_overlay != null:
		death_overlay.visible = false
