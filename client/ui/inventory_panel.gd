class_name InventoryPanel
extends PanelContainer
## Main inventory panel UI.
## Displays a grid of inventory slots with weight info.

const InventorySlotClass = preload("res://client/ui/inventory_slot.gd")
const ItemTooltipClass = preload("res://client/ui/item_tooltip.gd")


## Signal emitted when an item is selected
signal item_selected(slot_index: int, stack: ItemStack)

## Signal emitted when requesting to use an item
signal use_requested(slot_index: int)

## Signal emitted when requesting to drop an item
signal drop_requested(slot_index: int, count: int)

## Signal emitted when requesting to equip an item
signal equip_requested(slot_index: int)


## Grid configuration
const GRID_COLUMNS: int = 8
const GRID_ROWS: int = 5
const SLOT_SPACING: int = 4

## Reference to game client for inventory data
var game_client: GameClient = null

## Tooltip reference
var tooltip: ItemTooltipClass = null

## Currently selected slot
var _selected_slot: InventorySlotClass = null

## All inventory slots
var _slots: Array[InventorySlotClass] = []

## UI components
var _title_label: Label
var _weight_label: Label
var _grid: GridContainer
var _context_menu: PopupMenu


func _ready() -> void:
	_create_ui()


func _create_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Header with title and close button
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	_title_label = Label.new()
	_title_label.text = "Inventory"
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(24, 24)
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Inventory grid
	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", SLOT_SPACING)
	_grid.add_theme_constant_override("v_separation", SLOT_SPACING)
	vbox.add_child(_grid)

	# Create slots
	for i in range(GRID_COLUMNS * GRID_ROWS):
		var slot: InventorySlotClass = InventorySlotClass.new()
		slot.set_index(i)
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.slot_right_clicked.connect(_on_slot_right_clicked)
		slot.slot_hovered.connect(_on_slot_hovered)
		slot.slot_unhovered.connect(_on_slot_unhovered)
		slot.item_dropped.connect(_on_item_dropped)
		_slots.append(slot)
		_grid.add_child(slot)

	# Weight display
	var weight_container := HBoxContainer.new()
	weight_container.add_theme_constant_override("separation", 4)
	vbox.add_child(weight_container)

	var weight_icon := Label.new()
	weight_icon.text = "Weight:"
	weight_icon.add_theme_font_size_override("font_size", 12)
	weight_container.add_child(weight_icon)

	_weight_label = Label.new()
	_weight_label.text = "0.0 / 100.0"
	_weight_label.add_theme_font_size_override("font_size", 12)
	weight_container.add_child(_weight_label)

	# Context menu
	_context_menu = PopupMenu.new()
	_context_menu.add_item("Use", 0)
	_context_menu.add_item("Equip", 1)
	_context_menu.add_separator()
	_context_menu.add_item("Drop", 2)
	_context_menu.add_item("Drop All", 3)
	_context_menu.id_pressed.connect(_on_context_menu_selected)
	add_child(_context_menu)


## Initialize with game client reference
func initialize(client: GameClient, p_tooltip: ItemTooltipClass) -> void:
	game_client = client
	tooltip = p_tooltip

	if game_client != null:
		game_client.inventory_changed.connect(_on_inventory_changed)
		_refresh_display()


## Refresh display from game client data
func _refresh_display() -> void:
	if game_client == null or game_client.local_inventory == null:
		_clear_slots()
		return

	var inventory := game_client.local_inventory
	var stacks := inventory.get_all_stacks()

	# Update slots with inventory contents
	for i in range(_slots.size()):
		if i < stacks.size():
			_slots[i].set_item(stacks[i])
		else:
			_slots[i].set_item(null)

	# Update weight display
	var current_weight := inventory.get_current_weight()
	var max_weight := inventory.max_weight
	_weight_label.text = "%.1f / %.1f" % [current_weight, max_weight]

	# Color weight based on capacity
	var weight_ratio := current_weight / max_weight if max_weight > 0 else 0.0
	if weight_ratio > 0.9:
		_weight_label.add_theme_color_override("font_color", Color.RED)
	elif weight_ratio > 0.7:
		_weight_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		_weight_label.add_theme_color_override("font_color", Color.WHITE)


func _clear_slots() -> void:
	for slot in _slots:
		slot.set_item(null)
	_weight_label.text = "0.0 / 100.0"


func _on_inventory_changed() -> void:
	_refresh_display()


func _on_slot_clicked(slot: InventorySlotClass) -> void:
	# Deselect previous
	if _selected_slot != null:
		_selected_slot.set_selected(false)

	# Select new
	_selected_slot = slot
	slot.set_selected(true)

	if not slot.is_empty():
		item_selected.emit(slot.slot_index, slot.item_stack)


func _on_slot_right_clicked(slot: InventorySlotClass) -> void:
	if slot.is_empty():
		return

	# Select the slot
	_on_slot_clicked(slot)

	# Show context menu
	_update_context_menu(slot)
	_context_menu.position = Vector2i(get_global_mouse_position())
	_context_menu.popup()


func _on_slot_hovered(slot: InventorySlotClass) -> void:
	if tooltip != null and not slot.is_empty():
		tooltip.show_for_stack(slot.item_stack)
		tooltip.position_near(slot, get_viewport_rect().size)


func _on_slot_unhovered(_slot: InventorySlotClass) -> void:
	if tooltip != null:
		tooltip.hide()


func _on_item_dropped(target_slot: InventorySlotClass, source_slot: InventorySlotClass) -> void:
	# Clear drop target visual
	target_slot.set_drop_target(false)

	if source_slot == target_slot:
		return

	# TODO: Send swap request to server
	# For now, just swap locally for visual feedback
	var source_stack := source_slot.item_stack
	var target_stack := target_slot.item_stack

	# This is purely visual - server is authoritative
	source_slot.set_item(target_stack)
	target_slot.set_item(source_stack)


func _update_context_menu(slot: InventorySlotClass) -> void:
	if slot.item_stack == null or slot.item_stack.item == null:
		return

	var def := slot.item_stack.item.definition
	if def == null:
		return

	# Enable/disable based on item type
	_context_menu.set_item_disabled(0, def.type != ItemEnums.ItemType.CONSUMABLE)  # Use
	_context_menu.set_item_disabled(1, not def.is_equippable())  # Equip


func _on_context_menu_selected(id: int) -> void:
	if _selected_slot == null or _selected_slot.is_empty():
		return

	var slot_index := _find_inventory_index(_selected_slot)
	if slot_index < 0:
		return

	match id:
		0:  # Use
			use_requested.emit(slot_index)
			if game_client != null:
				game_client.request_use_item(slot_index)
		1:  # Equip
			equip_requested.emit(slot_index)
			if game_client != null:
				game_client.request_equip(slot_index)
		2:  # Drop
			drop_requested.emit(slot_index, 1)
			if game_client != null:
				game_client.request_drop_item(slot_index, 1)
		3:  # Drop All
			var count: int = _selected_slot.item_stack.count if _selected_slot.item_stack else 1
			drop_requested.emit(slot_index, count)
			if game_client != null:
				game_client.request_drop_item(slot_index, count)


func _find_inventory_index(slot: InventorySlotClass) -> int:
	# Find the actual inventory index for this slot
	# Since we display stacks in order, the slot index should match
	return slot.slot_index


func _on_close_pressed() -> void:
	hide()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			hide()
			get_viewport().set_input_as_handled()
