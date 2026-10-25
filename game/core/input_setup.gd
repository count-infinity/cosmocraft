class_name InputSetup
extends RefCounted
## Adds the input actions every mode uses at runtime, so project.godot stays
## untouched. Safe to call more than once.


static func register() -> void:
	_add_action("fire", [_mouse_event(MOUSE_BUTTON_LEFT)])
	_add_action("fire_secondary", [_mouse_event(MOUSE_BUTTON_RIGHT)])
	_add_action("dash", [_key_event(KEY_SPACE), _key_event(KEY_SHIFT)])
	_add_action("kindle", [_key_event(KEY_E)])
	_add_action("map", [_key_event(KEY_TAB), _key_event(KEY_M)])
	_add_action("refit", [_key_event(KEY_F)])


static func _add_action(action: StringName, events: Array[InputEvent]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for event in events:
		InputMap.action_add_event(action, event)


static func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event


static func _mouse_event(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event
