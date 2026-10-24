class_name CommandInput
extends CanvasLayer
## Command input overlay for admin commands and future chat.
## Opens with ENTER, submits with ENTER, closes with ESC.


signal command_submitted(text: String)


var _is_active: bool = false
var _input_field: LineEdit
var _panel: PanelContainer


func _ready() -> void:
	_create_ui()
	visible = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER and not _is_active:
			open()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _is_active:
			close()
			get_viewport().set_input_as_handled()


func _create_ui() -> void:
	# Panel at bottom of screen
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top = -40
	_panel.offset_left = 10
	_panel.offset_right = -10
	_panel.offset_bottom = -10
	add_child(_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	_panel.add_child(hbox)

	var prompt := Label.new()
	prompt.text = "> "
	prompt.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	hbox.add_child(prompt)

	_input_field = LineEdit.new()
	_input_field.placeholder_text = "Type command (e.g., /spawn wolf)..."
	_input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_field.text_submitted.connect(_on_text_submitted)
	hbox.add_child(_input_field)


func open() -> void:
	_is_active = true
	visible = true
	_input_field.text = ""
	_input_field.grab_focus()


func close() -> void:
	_is_active = false
	visible = false
	_input_field.release_focus()


func is_active() -> bool:
	return _is_active


func _on_text_submitted(text: String) -> void:
	text = text.strip_edges()
	if not text.is_empty():
		command_submitted.emit(text)
	close()
