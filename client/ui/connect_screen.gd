class_name ConnectScreen
extends Control

signal connect_requested(address: String, port: int, player_name: String)

var address_input: LineEdit
var port_input: LineEdit
var name_input: LineEdit
var connect_button: Button
var status_label: Label

func _ready() -> void:
	_create_ui()

func _create_ui() -> void:
	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Main panel
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 300)
	center.add_child(panel)

	# Vertical layout
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "COSMOCRAFT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	# Name input
	var name_box := HBoxContainer.new()
	vbox.add_child(name_box)
	var name_label := Label.new()
	name_label.text = "Name:"
	name_label.custom_minimum_size = Vector2(80, 0)
	name_box.add_child(name_label)
	name_input = LineEdit.new()
	name_input.text = "Player"
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_child(name_input)

	# Address input
	var addr_box := HBoxContainer.new()
	vbox.add_child(addr_box)
	var addr_label := Label.new()
	addr_label.text = "Server:"
	addr_label.custom_minimum_size = Vector2(80, 0)
	addr_box.add_child(addr_label)
	address_input = LineEdit.new()
	address_input.text = "localhost"
	address_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	addr_box.add_child(address_input)

	# Port input
	var port_box := HBoxContainer.new()
	vbox.add_child(port_box)
	var port_label := Label.new()
	port_label.text = "Port:"
	port_label.custom_minimum_size = Vector2(80, 0)
	port_box.add_child(port_label)
	port_input = LineEdit.new()
	port_input.text = str(GameConstants.DEFAULT_PORT)
	port_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	port_box.add_child(port_input)

	# Connect button
	connect_button = Button.new()
	connect_button.text = "Connect"
	connect_button.pressed.connect(_on_connect_pressed)
	vbox.add_child(connect_button)

	# Status label
	status_label = Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(status_label)

func _on_connect_pressed() -> void:
	var address := address_input.text.strip_edges()
	var port := int(port_input.text.strip_edges())
	var player_name := name_input.text.strip_edges()

	if address.is_empty():
		status_label.text = "Please enter a server address"
		return

	if port <= 0 or port > 65535:
		status_label.text = "Invalid port number"
		return

	if player_name.is_empty():
		player_name = "Player"

	status_label.text = "Connecting..."
	connect_button.disabled = true
	connect_requested.emit(address, port, player_name)

func set_status(text: String) -> void:
	status_label.text = text

func enable_connect() -> void:
	connect_button.disabled = false
