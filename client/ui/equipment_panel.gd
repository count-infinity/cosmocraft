class_name EquipmentPanel
extends PanelContainer
## Equipment panel showing equipped items and player stats.

const InventorySlotClass = preload("res://client/ui/inventory_slot.gd")
const ItemTooltipClass = preload("res://client/ui/item_tooltip.gd")


## Signal emitted when requesting to unequip
signal unequip_requested(equip_slot: int)


## Reference to game client
var game_client: GameClient = null

## Tooltip reference
var tooltip: ItemTooltipClass = null

## Equipment slot controls mapped by EquipSlot enum
var _equipment_slots: Dictionary = {}

## Accessory slots (2 slots)
var _accessory_slots: Array[InventorySlotClass] = []

## Stats labels
var _stat_labels: Dictionary = {}

## UI components
var _title_label: Label


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

	# Header
	var header := HBoxContainer.new()
	vbox.add_child(header)

	_title_label = Label.new()
	_title_label.text = "Equipment"
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(24, 24)
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Equipment layout
	var equip_hbox := HBoxContainer.new()
	equip_hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(equip_hbox)

	# Left column (armor)
	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 4)
	equip_hbox.add_child(left_col)

	_add_equipment_slot(left_col, ItemEnums.EquipSlot.HEAD, "Head")
	_add_equipment_slot(left_col, ItemEnums.EquipSlot.CHEST, "Chest")
	_add_equipment_slot(left_col, ItemEnums.EquipSlot.LEGS, "Legs")
	_add_equipment_slot(left_col, ItemEnums.EquipSlot.BOOTS, "Boots")

	# Right column (weapons/accessories)
	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 4)
	equip_hbox.add_child(right_col)

	_add_equipment_slot(right_col, ItemEnums.EquipSlot.MAIN_HAND, "Main")
	_add_equipment_slot(right_col, ItemEnums.EquipSlot.OFF_HAND, "Off")

	# Accessory slots
	var acc_label := Label.new()
	acc_label.text = "Accessories"
	acc_label.add_theme_font_size_override("font_size", 12)
	right_col.add_child(acc_label)

	var acc_hbox := HBoxContainer.new()
	acc_hbox.add_theme_constant_override("separation", 4)
	right_col.add_child(acc_hbox)

	for i in range(2):
		var slot: InventorySlotClass = InventorySlotClass.new()
		slot.set_slot_label("Acc %d" % (i + 1))
		slot.set_index(i)
		slot.slot_clicked.connect(_on_accessory_clicked.bind(i + 1))
		slot.slot_hovered.connect(_on_slot_hovered)
		slot.slot_unhovered.connect(_on_slot_unhovered)
		_accessory_slots.append(slot)
		acc_hbox.add_child(slot)

	# Stats section
	var stats_sep := HSeparator.new()
	vbox.add_child(stats_sep)

	var stats_label := Label.new()
	stats_label.text = "Stats"
	stats_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(stats_label)

	var stats_grid := GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 12)
	stats_grid.add_theme_constant_override("v_separation", 2)
	vbox.add_child(stats_grid)

	# Add stat displays
	_add_stat_row(stats_grid, ItemEnums.StatType.MAX_HP, "HP")
	_add_stat_row(stats_grid, ItemEnums.StatType.MAX_ENERGY, "Energy")
	_add_stat_row(stats_grid, ItemEnums.StatType.STRENGTH, "Strength")
	_add_stat_row(stats_grid, ItemEnums.StatType.FORTITUDE, "Fortitude")
	_add_stat_row(stats_grid, ItemEnums.StatType.PRECISION, "Precision")
	_add_stat_row(stats_grid, ItemEnums.StatType.EFFICIENCY, "Efficiency")


func _add_equipment_slot(parent: Control, slot_type: ItemEnums.EquipSlot, label: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	parent.add_child(hbox)

	var slot: InventorySlotClass = InventorySlotClass.new()
	slot.set_slot_label(label)
	slot.set_index(slot_type)
	slot.slot_clicked.connect(_on_equipment_slot_clicked.bind(slot_type))
	slot.slot_hovered.connect(_on_slot_hovered)
	slot.slot_unhovered.connect(_on_slot_unhovered)
	_equipment_slots[slot_type] = slot
	hbox.add_child(slot)

	var name_label := Label.new()
	name_label.text = label
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name_label)


func _add_stat_row(parent: GridContainer, stat_type: ItemEnums.StatType, label: String) -> void:
	var name_label := Label.new()
	name_label.text = label + ":"
	name_label.add_theme_font_size_override("font_size", 11)
	parent.add_child(name_label)

	var value_label := Label.new()
	value_label.text = "0"
	value_label.add_theme_font_size_override("font_size", 11)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size.x = 50
	_stat_labels[stat_type] = value_label
	parent.add_child(value_label)


## Initialize with game client reference
func initialize(client: GameClient, p_tooltip: ItemTooltipClass) -> void:
	game_client = client
	tooltip = p_tooltip

	if game_client != null:
		game_client.equipment_changed.connect(_on_equipment_changed)
		game_client.stats_changed.connect(_on_stats_changed)
		_refresh_display()


## Refresh display from game client data
func _refresh_display() -> void:
	_refresh_equipment()
	_refresh_stats()


func _refresh_equipment() -> void:
	if game_client == null or game_client.local_equipment == null:
		_clear_equipment()
		return

	var equipment := game_client.local_equipment

	# Update armor/weapon slots
	for slot_type in _equipment_slots:
		var slot: InventorySlotClass = _equipment_slots[slot_type]
		var item := equipment.get_equipped(slot_type)
		if item != null:
			# Create a temporary stack for display
			var stack := ItemStack.new(item, 1)
			slot.set_item(stack)
		else:
			slot.set_item(null)

	# Update accessory slots
	for i in range(_accessory_slots.size()):
		var slot: InventorySlotClass = _accessory_slots[i]
		var item := equipment.get_accessory(i + 1)
		if item != null:
			var stack := ItemStack.new(item, 1)
			slot.set_item(stack)
		else:
			slot.set_item(null)


func _refresh_stats() -> void:
	if game_client == null or game_client.local_stats == null:
		_clear_stats()
		return

	var stats := game_client.local_stats

	for stat_type in _stat_labels:
		var label: Label = _stat_labels[stat_type]
		var value := stats.get_stat(stat_type)

		# Format based on stat type
		if stat_type in [ItemEnums.StatType.CRIT_CHANCE]:
			label.text = "%.0f%%" % (value * 100.0)
		elif stat_type in [ItemEnums.StatType.MOVE_SPEED, ItemEnums.StatType.ATTACK_SPEED]:
			label.text = "%.2fx" % value
		else:
			label.text = "%.0f" % value


func _clear_equipment() -> void:
	for slot_type in _equipment_slots:
		_equipment_slots[slot_type].set_item(null)
	for slot in _accessory_slots:
		slot.set_item(null)


func _clear_stats() -> void:
	for stat_type in _stat_labels:
		_stat_labels[stat_type].text = "0"


func _on_equipment_changed(_slot: int) -> void:
	_refresh_equipment()


func _on_stats_changed() -> void:
	_refresh_stats()


func _on_equipment_slot_clicked(slot: InventorySlotClass, slot_type: ItemEnums.EquipSlot) -> void:
	if slot.is_empty():
		return

	# Request unequip
	unequip_requested.emit(slot_type)
	if game_client != null:
		game_client.request_unequip(slot_type)


func _on_accessory_clicked(slot: InventorySlotClass, slot_index: int) -> void:
	if slot.is_empty():
		return

	# Unequip accessory
	# Accessories use ACCESSORY enum but we need special handling
	if game_client != null:
		# TODO: Add specific accessory unequip support
		game_client.request_unequip(ItemEnums.EquipSlot.ACCESSORY)


func _on_slot_hovered(slot: InventorySlotClass) -> void:
	if tooltip != null and not slot.is_empty():
		tooltip.show_for_stack(slot.item_stack)
		tooltip.position_near(slot, get_viewport_rect().size)


func _on_slot_unhovered(_slot: InventorySlotClass) -> void:
	if tooltip != null:
		tooltip.hide()


func _on_close_pressed() -> void:
	hide()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			hide()
			get_viewport().set_input_as_handled()
