class_name InventorySlot
extends Control
## A single inventory/equipment/hotbar slot that displays an item.
## Handles mouse interaction, drag-drop, and visual feedback.


## Signal emitted when slot is left-clicked
signal slot_clicked(slot: Control)

## Signal emitted when slot is right-clicked
signal slot_right_clicked(slot: Control)

## Signal emitted when mouse enters slot
signal slot_hovered(slot: Control)

## Signal emitted when mouse exits slot
signal slot_unhovered(slot: Control)

## Signal emitted when drag starts from this slot
signal drag_started(slot: Control)

## Signal emitted when an item is dropped on this slot
signal item_dropped(target_slot: Control, source_slot: Control)


## Slot size in pixels
const SLOT_SIZE: Vector2 = Vector2(48, 48)

## Colors
const COLOR_EMPTY: Color = Color(0.2, 0.2, 0.2, 0.8)
const COLOR_FILLED: Color = Color(0.25, 0.25, 0.25, 0.9)
const COLOR_HOVER: Color = Color(0.35, 0.35, 0.35, 0.9)
const COLOR_SELECTED: Color = Color(0.3, 0.5, 0.7, 0.9)
const COLOR_DRAG_TARGET: Color = Color(0.4, 0.6, 0.3, 0.9)
const DURABILITY_LOW_COLOR: Color = Color(1.0, 0.3, 0.3)
const DURABILITY_MED_COLOR: Color = Color(1.0, 0.8, 0.3)
const DURABILITY_HIGH_COLOR: Color = Color(0.3, 0.8, 0.3)


## The item stack in this slot (can be null)
var item_stack: ItemStack = null

## Slot index (for inventory grid)
var slot_index: int = -1

## Whether this slot is currently selected
var is_selected: bool = false

## Whether this slot is a valid drop target
var is_drop_target: bool = false

## Whether mouse is hovering over this slot
var _is_hovered: bool = false

## Background panel
var _background: ColorRect

## Item icon (placeholder colored rect for now)
var _icon: ColorRect

## Stack count label
var _count_label: Label

## Durability bar
var _durability_bar: ColorRect
var _durability_bg: ColorRect

## Slot label (for equipment slots showing slot name)
var _slot_label: Label


func _init() -> void:
	custom_minimum_size = SLOT_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_create_ui()


func _ready() -> void:
	_update_display()


func _create_ui() -> void:
	# Background
	_background = ColorRect.new()
	_background.color = COLOR_EMPTY
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	# Item icon (centered, slightly smaller than slot)
	_icon = ColorRect.new()
	_icon.custom_minimum_size = Vector2(40, 40)
	_icon.position = Vector2(4, 4)
	_icon.size = Vector2(40, 40)
	_icon.visible = false
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)

	# Durability bar background
	_durability_bg = ColorRect.new()
	_durability_bg.color = Color(0.1, 0.1, 0.1, 0.8)
	_durability_bg.position = Vector2(4, 40)
	_durability_bg.size = Vector2(40, 4)
	_durability_bg.visible = false
	_durability_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_durability_bg)

	# Durability bar
	_durability_bar = ColorRect.new()
	_durability_bar.color = DURABILITY_HIGH_COLOR
	_durability_bar.position = Vector2(4, 40)
	_durability_bar.size = Vector2(40, 4)
	_durability_bar.visible = false
	_durability_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_durability_bar)

	# Stack count
	_count_label = Label.new()
	_count_label.add_theme_font_size_override("font_size", 12)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count_label.position = Vector2(0, 0)
	_count_label.size = Vector2(SLOT_SIZE.x - 4, SLOT_SIZE.y - 4)
	_count_label.visible = false
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count_label)

	# Slot label (for equipment slots)
	_slot_label = Label.new()
	_slot_label.add_theme_font_size_override("font_size", 10)
	_slot_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_slot_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slot_label.visible = false
	_slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_slot_label)


## Set the item stack for this slot
func set_item(stack: ItemStack) -> void:
	item_stack = stack
	_update_display()


## Set the slot index
func set_index(index: int) -> void:
	slot_index = index


## Set selected state
func set_selected(selected: bool) -> void:
	is_selected = selected
	_update_background_color()


## Set as drop target
func set_drop_target(is_target: bool) -> void:
	is_drop_target = is_target
	_update_background_color()


## Set slot label (for equipment slots)
func set_slot_label(text: String) -> void:
	_slot_label.text = text
	_slot_label.visible = not text.is_empty() and (item_stack == null or item_stack.is_empty())


## Check if slot is empty
func is_empty() -> bool:
	return item_stack == null or item_stack.is_empty()


func _update_display() -> void:
	if item_stack == null or item_stack.is_empty():
		_show_empty()
	else:
		_show_item()
	_update_background_color()


func _show_empty() -> void:
	_icon.visible = false
	_count_label.visible = false
	_durability_bar.visible = false
	_durability_bg.visible = false
	_slot_label.visible = not _slot_label.text.is_empty()


func _show_item() -> void:
	_slot_label.visible = false

	if item_stack.item == null or item_stack.item.definition == null:
		_show_empty()
		return

	var def := item_stack.item.definition

	# Show icon with type-based color (placeholder until we have real icons)
	_icon.visible = true
	_icon.color = _get_type_color(def.type)

	# Show count if stackable and more than 1
	if item_stack.count > 1:
		_count_label.visible = true
		_count_label.text = str(item_stack.count)
	else:
		_count_label.visible = false

	# Show durability bar if applicable
	if def.has_durability() and item_stack.item != null:
		var max_dur := item_stack.item.get_max_durability()
		var cur_dur := item_stack.item.current_durability
		if max_dur > 0:
			var dur_percent := float(cur_dur) / float(max_dur)
			_durability_bg.visible = true
			_durability_bar.visible = true
			_durability_bar.size.x = 40.0 * dur_percent

			# Color based on durability
			if dur_percent > 0.5:
				_durability_bar.color = DURABILITY_HIGH_COLOR
			elif dur_percent > 0.25:
				_durability_bar.color = DURABILITY_MED_COLOR
			else:
				_durability_bar.color = DURABILITY_LOW_COLOR
		else:
			_durability_bg.visible = false
			_durability_bar.visible = false
	else:
		_durability_bg.visible = false
		_durability_bar.visible = false


func _update_background_color() -> void:
	if is_drop_target:
		_background.color = COLOR_DRAG_TARGET
	elif is_selected:
		_background.color = COLOR_SELECTED
	elif _is_hovered:
		_background.color = COLOR_HOVER
	elif item_stack != null and not item_stack.is_empty():
		_background.color = COLOR_FILLED
	else:
		_background.color = COLOR_EMPTY


func _get_type_color(type: ItemEnums.ItemType) -> Color:
	match type:
		ItemEnums.ItemType.MATERIAL:
			return Color(0.6, 0.5, 0.4)  # Brown
		ItemEnums.ItemType.TOOL:
			return Color(0.5, 0.5, 0.6)  # Gray-blue
		ItemEnums.ItemType.WEAPON:
			return Color(0.7, 0.3, 0.3)  # Red
		ItemEnums.ItemType.ARMOR:
			return Color(0.4, 0.5, 0.7)  # Steel blue
		ItemEnums.ItemType.ACCESSORY:
			return Color(0.7, 0.6, 0.3)  # Gold
		ItemEnums.ItemType.CONSUMABLE:
			return Color(0.5, 0.7, 0.5)  # Green
		ItemEnums.ItemType.PLACEABLE:
			return Color(0.5, 0.4, 0.3)  # Dark brown
		ItemEnums.ItemType.BLUEPRINT:
			return Color(0.3, 0.6, 0.7)  # Cyan
		ItemEnums.ItemType.ENCHANT_CORE:
			return Color(0.7, 0.3, 0.7)  # Purple
		ItemEnums.ItemType.GEM:
			return Color(0.8, 0.4, 0.8)  # Magenta
		ItemEnums.ItemType.KEY:
			return Color(0.8, 0.7, 0.2)  # Yellow
		ItemEnums.ItemType.QUEST:
			return Color(0.9, 0.8, 0.3)  # Bright yellow
		_:
			return Color(0.5, 0.5, 0.5)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				slot_clicked.emit(self)
				accept_event()
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				slot_right_clicked.emit(self)
				accept_event()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			_is_hovered = true
			_update_background_color()
			slot_hovered.emit(self)
		NOTIFICATION_MOUSE_EXIT:
			_is_hovered = false
			_update_background_color()
			slot_unhovered.emit(self)


## Get drag data for this slot
func _get_drag_data(_at_position: Vector2) -> Variant:
	if is_empty():
		return null

	# Create drag preview - use get_script() to avoid class_name resolution issues
	var preview: Control = (get_script() as Script).new()
	preview.set_item(item_stack)
	preview.modulate.a = 0.7
	set_drag_preview(preview)

	drag_started.emit(self)
	return self


## Check if we can drop here
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# Check if data is from the same script type
	if data != null and data is Control and data.get_script() == get_script():
		set_drop_target(true)
		return true
	return false


## Handle drop
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	set_drop_target(false)
	if data != null and data is Control and data.get_script() == get_script():
		item_dropped.emit(self, data)
