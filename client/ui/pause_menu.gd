class_name PauseMenu
extends CanvasLayer

signal resume_requested
signal quit_requested

var panel: PanelContainer
var resume_button: Button
var quit_button: Button


func _ready() -> void:
	_create_ui()
	# Pause the game tree but allow this menu to process
	process_mode = Node.PROCESS_MODE_ALWAYS


func _create_ui() -> void:
	# Semi-transparent background
	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.5)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Panel
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(200, 150)
	center.add_child(panel)

	# VBox for content
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	# Resume button
	resume_button = Button.new()
	resume_button.text = "Resume"
	resume_button.pressed.connect(_on_resume_pressed)
	vbox.add_child(resume_button)

	# Quit button
	quit_button = Button.new()
	quit_button.text = "Quit"
	quit_button.pressed.connect(_on_quit_pressed)
	vbox.add_child(quit_button)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# ESC pressed while menu is open - resume
		_on_resume_pressed()
		get_viewport().set_input_as_handled()


func _on_resume_pressed() -> void:
	resume_requested.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()
