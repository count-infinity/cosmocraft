class_name HUD
extends CanvasLayer

var player_count_label: Label
var ping_label: Label
var position_label: Label
var minimap_hint_label: Label

# Minimap
var minimap: Minimap = null
var MinimapScene: PackedScene = preload("res://client/ui/minimap.tscn")
var _minimap_visible: bool = false

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

	# Minimap hint
	minimap_hint_label = Label.new()
	minimap_hint_label.text = "[M] Map"
	minimap_hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(minimap_hint_label)

	# Create minimap (hidden by default)
	_create_minimap()


func _create_minimap() -> void:
	minimap = MinimapScene.instantiate()
	minimap.visible = false

	# Position in top-right corner
	var anchor_container := Control.new()
	anchor_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	anchor_container.position = Vector2(-220, 10)
	add_child(anchor_container)
	anchor_container.add_child(minimap)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			toggle_minimap()
			get_viewport().set_input_as_handled()


func toggle_minimap() -> void:
	_minimap_visible = not _minimap_visible
	if minimap:
		minimap.visible = _minimap_visible


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
