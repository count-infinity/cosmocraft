class_name HUD
extends CanvasLayer

var player_count_label: Label
var ping_label: Label
var position_label: Label

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

func update_player_count(count: int) -> void:
	player_count_label.text = "Players: %d" % count

func update_ping(ms: int) -> void:
	ping_label.text = "Ping: %d ms" % ms

func update_position(pos: Vector2) -> void:
	position_label.text = "Pos: (%.0f, %.0f)" % [pos.x, pos.y]
