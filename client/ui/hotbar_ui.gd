class_name HotbarUI
extends PanelContainer
## Hotbar UI showing 8 quick-access slots at bottom of screen.
## Slots can be selected with number keys 1-8.

const InventorySlotClass = preload("res://client/ui/inventory_slot.gd")
const ItemTooltipClass = preload("res://client/ui/item_tooltip.gd")


## Signal emitted when a slot is used
signal slot_used(slot_index: int)


## Number of hotbar slots (matches Hotbar.SLOT_COUNT)
const SLOT_COUNT: int = 8
const SLOT_SPACING: int = 4

## Reference to game client
var game_client: GameClient = null

## Tooltip reference
var tooltip: ItemTooltipClass = null

## Hotbar slots
var _slots: Array[InventorySlotClass] = []

## Key labels above slots
var _key_labels: Array[Label] = []

## Currently selected slot
var _selected_index: int = 0


func _ready() -> void:
	_create_ui()


func _create_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", SLOT_SPACING)
	margin.add_child(hbox)

	# Create slots with key labels
	for i in range(SLOT_COUNT):
		var slot_container := VBoxContainer.new()
		slot_container.add_theme_constant_override("separation", 2)
		hbox.add_child(slot_container)

		# Key label (1-8)
		var key_label := Label.new()
		key_label.text = str(i + 1)
		key_label.add_theme_font_size_override("font_size", 10)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_key_labels.append(key_label)
		slot_container.add_child(key_label)

		# Slot
		var slot: InventorySlotClass = InventorySlotClass.new()
		slot.set_index(i)
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.slot_hovered.connect(_on_slot_hovered)
		slot.slot_unhovered.connect(_on_slot_unhovered)
		_slots.append(slot)
		slot_container.add_child(slot)

	# Select first slot by default
	_update_selection()


## Initialize with game client reference
func initialize(client: GameClient, p_tooltip: ItemTooltipClass) -> void:
	game_client = client
	tooltip = p_tooltip

	if game_client != null:
		game_client.hotbar_changed.connect(_on_hotbar_changed)
		_refresh_display()


## Refresh display from game client data
func _refresh_display() -> void:
	if game_client == null or game_client.local_hotbar == null:
		_clear_slots()
		return

	var hotbar := game_client.local_hotbar

	for i in range(_slots.size()):
		var stack := hotbar.get_slot(i)
		_slots[i].set_item(stack)

	_selected_index = hotbar.selected_slot
	_update_selection()


func _clear_slots() -> void:
	for slot in _slots:
		slot.set_item(null)


func _update_selection() -> void:
	for i in range(_slots.size()):
		var is_selected := (i == _selected_index)
		_slots[i].set_selected(is_selected)

		# Update key label color
		if is_selected:
			_key_labels[i].add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
		else:
			_key_labels[i].add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))


func _on_hotbar_changed() -> void:
	_refresh_display()


func _on_slot_clicked(slot: InventorySlotClass) -> void:
	_select_slot(slot.slot_index)


func _select_slot(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return

	_selected_index = index
	_update_selection()

	# Update hotbar selection in game client
	if game_client != null and game_client.local_hotbar != null:
		game_client.local_hotbar.select_slot(index)


func _use_selected_slot() -> void:
	if game_client == null or game_client.local_hotbar == null:
		return

	var stack := game_client.local_hotbar.get_slot(_selected_index)
	if stack == null or stack.is_empty():
		return

	# Find the slot in inventory and use it
	# For now, emit signal - the HUD can handle the request
	slot_used.emit(_selected_index)


func _on_slot_hovered(slot: InventorySlotClass) -> void:
	if tooltip != null and not slot.is_empty():
		tooltip.show_for_stack(slot.item_stack)
		tooltip.position_near(slot, get_viewport_rect().size)


func _on_slot_unhovered(_slot: InventorySlotClass) -> void:
	if tooltip != null:
		tooltip.hide()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Number keys 1-8 select hotbar slots
		var key_code: Key = event.keycode
		if key_code >= KEY_1 and key_code <= KEY_8:
			var hotbar_slot_index: int = key_code - KEY_1
			_select_slot(hotbar_slot_index)
			get_viewport().set_input_as_handled()

		# Mouse wheel to cycle slots
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select_slot((_selected_index - 1 + SLOT_COUNT) % SLOT_COUNT)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select_slot((_selected_index + 1) % SLOT_COUNT)


## Get the currently selected slot index
func get_selected_index() -> int:
	return _selected_index


## Get the item in the currently selected slot
func get_selected_item() -> ItemStack:
	if _selected_index < 0 or _selected_index >= _slots.size():
		return null
	return _slots[_selected_index].item_stack
