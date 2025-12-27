class_name CraftingPanel
extends PanelContainer
## Crafting panel UI that displays available recipes and allows crafting.
## Shows recipe list on the left, selected recipe details on the right.

const InventorySlotClass = preload("res://client/ui/inventory_slot.gd")
const ItemTooltipClass = preload("res://client/ui/item_tooltip.gd")


## Signal emitted when a craft is requested
signal craft_requested(recipe_id: String)


## Reference to game client for inventory and crafting data
var game_client: GameClient = null

## Tooltip reference
var tooltip: ItemTooltipClass = null

## Currently selected recipe
var _selected_recipe: RecipeDefinition = null

## All recipe list items (recipe_id -> Button)
var _recipe_buttons: Dictionary = {}

## Current category filter (empty = show all)
var _current_category: String = ""

## Current search filter
var _search_text: String = ""

## UI components - Left side (recipe list)
var _title_label: Label
var _search_field: LineEdit
var _category_tabs: TabBar
var _recipe_list: VBoxContainer
var _recipe_scroll: ScrollContainer

## UI components - Right side (recipe details)
var _detail_panel: VBoxContainer
var _detail_name_label: Label
var _detail_description_label: Label
var _materials_container: VBoxContainer
var _station_label: Label
var _skill_label: Label
var _output_container: HBoxContainer
var _craft_button: Button
var _craft_status_label: Label


func _ready() -> void:
	_create_ui()


func _create_ui() -> void:
	custom_minimum_size = Vector2(600, 400)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(main_vbox)

	# Header with title and close button
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	main_vbox.add_child(header)

	_title_label = Label.new()
	_title_label.text = "Crafting"
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(24, 24)
	close_btn.pressed.connect(_on_close_pressed)
	header.add_child(close_btn)

	var sep := HSeparator.new()
	main_vbox.add_child(sep)

	# Main content area (horizontal split)
	var content_hbox := HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 16)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_hbox)

	# Left side - Recipe list
	_create_recipe_list_panel(content_hbox)

	# Vertical separator
	var vsep := VSeparator.new()
	content_hbox.add_child(vsep)

	# Right side - Recipe details
	_create_recipe_detail_panel(content_hbox)


func _create_recipe_list_panel(parent: Control) -> void:
	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 8)
	left_vbox.custom_minimum_size.x = 220
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(left_vbox)

	# Search bar
	_search_field = LineEdit.new()
	_search_field.placeholder_text = "Search recipes..."
	_search_field.clear_button_enabled = true
	_search_field.text_changed.connect(_on_search_changed)
	left_vbox.add_child(_search_field)

	# Category tabs
	_category_tabs = TabBar.new()
	_category_tabs.tab_changed.connect(_on_category_changed)
	left_vbox.add_child(_category_tabs)

	# Recipe list (scrollable)
	_recipe_scroll = ScrollContainer.new()
	_recipe_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_recipe_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(_recipe_scroll)

	_recipe_list = VBoxContainer.new()
	_recipe_list.add_theme_constant_override("separation", 4)
	_recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipe_scroll.add_child(_recipe_list)


func _create_recipe_detail_panel(parent: Control) -> void:
	_detail_panel = VBoxContainer.new()
	_detail_panel.add_theme_constant_override("separation", 8)
	_detail_panel.custom_minimum_size.x = 280
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(_detail_panel)

	# Recipe name
	_detail_name_label = Label.new()
	_detail_name_label.add_theme_font_size_override("font_size", 16)
	_detail_name_label.text = "Select a recipe"
	_detail_panel.add_child(_detail_name_label)

	# Recipe description
	_detail_description_label = Label.new()
	_detail_description_label.add_theme_font_size_override("font_size", 11)
	_detail_description_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_detail_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_description_label.custom_minimum_size.y = 40
	_detail_panel.add_child(_detail_description_label)

	# Separator
	var sep1 := HSeparator.new()
	_detail_panel.add_child(sep1)

	# Materials header
	var materials_header := Label.new()
	materials_header.text = "Required Materials:"
	materials_header.add_theme_font_size_override("font_size", 12)
	_detail_panel.add_child(materials_header)

	# Materials list
	_materials_container = VBoxContainer.new()
	_materials_container.add_theme_constant_override("separation", 2)
	_detail_panel.add_child(_materials_container)

	# Station requirement
	_station_label = Label.new()
	_station_label.add_theme_font_size_override("font_size", 11)
	_station_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))
	_detail_panel.add_child(_station_label)

	# Skill requirement
	_skill_label = Label.new()
	_skill_label.add_theme_font_size_override("font_size", 11)
	_skill_label.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
	_detail_panel.add_child(_skill_label)

	# Separator
	var sep2 := HSeparator.new()
	_detail_panel.add_child(sep2)

	# Output header
	var output_header := Label.new()
	output_header.text = "Creates:"
	output_header.add_theme_font_size_override("font_size", 12)
	_detail_panel.add_child(output_header)

	# Output items
	_output_container = HBoxContainer.new()
	_output_container.add_theme_constant_override("separation", 8)
	_detail_panel.add_child(_output_container)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(spacer)

	# Craft status label
	_craft_status_label = Label.new()
	_craft_status_label.add_theme_font_size_override("font_size", 11)
	_craft_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_panel.add_child(_craft_status_label)

	# Craft button
	_craft_button = Button.new()
	_craft_button.text = "Craft"
	_craft_button.custom_minimum_size = Vector2(0, 36)
	_craft_button.disabled = true
	_craft_button.pressed.connect(_on_craft_pressed)
	_detail_panel.add_child(_craft_button)


## Initialize with game client reference
func initialize(client: GameClient, p_tooltip: ItemTooltipClass) -> void:
	game_client = client
	tooltip = p_tooltip

	if game_client != null:
		game_client.inventory_changed.connect(_on_inventory_changed)
		game_client.craft_response_received.connect(_on_craft_response)
		_refresh_categories()
		_refresh_recipe_list()


## Refresh category tabs from available recipes
func _refresh_categories() -> void:
	_category_tabs.clear_tabs()
	_category_tabs.add_tab("All")

	if game_client == null:
		return

	var crafting := game_client.client_registries.crafting_system
	var categories := crafting.get_categories()
	categories.sort()

	for category in categories:
		_category_tabs.add_tab(category.capitalize())


## Refresh the recipe list based on filters
func _refresh_recipe_list() -> void:
	# Clear existing
	for child in _recipe_list.get_children():
		child.queue_free()
	_recipe_buttons.clear()

	if game_client == null:
		return

	var crafting := game_client.client_registries.crafting_system
	var recipes := crafting.get_discovered_recipes()

	# Filter by category
	if not _current_category.is_empty():
		var filtered: Array[RecipeDefinition] = []
		for recipe in recipes:
			if recipe.category == _current_category:
				filtered.append(recipe)
		recipes = filtered

	# Filter by search text
	if not _search_text.is_empty():
		var search_lower := _search_text.to_lower()
		var filtered: Array[RecipeDefinition] = []
		for recipe in recipes:
			if recipe.name.to_lower().contains(search_lower):
				filtered.append(recipe)
		recipes = filtered

	# Sort alphabetically
	recipes.sort_custom(func(a: RecipeDefinition, b: RecipeDefinition) -> bool:
		return a.name < b.name
	)

	# Create buttons for each recipe
	for recipe in recipes:
		var btn := Button.new()
		btn.text = recipe.name
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 28)
		btn.pressed.connect(_on_recipe_selected.bind(recipe))

		# Check if can craft and style accordingly
		var can_craft := _can_craft_recipe(recipe)
		if can_craft:
			btn.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
		else:
			btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

		_recipe_list.add_child(btn)
		_recipe_buttons[recipe.id] = btn


## Check if a recipe can be crafted with current inventory
func _can_craft_recipe(recipe: RecipeDefinition) -> bool:
	if game_client == null or game_client.local_inventory == null:
		return false

	var crafting := game_client.client_registries.crafting_system
	var inventory := game_client.local_inventory

	# For now, use empty skill levels and no station
	var skill_levels: Dictionary = {}
	var current_station: String = ""

	return crafting.can_craft(recipe, inventory, skill_levels, current_station)


## Update the detail panel for the selected recipe
func _refresh_detail_panel() -> void:
	# Clear materials list
	for child in _materials_container.get_children():
		child.queue_free()

	# Clear output list
	for child in _output_container.get_children():
		child.queue_free()

	if _selected_recipe == null:
		_detail_name_label.text = "Select a recipe"
		_detail_description_label.text = ""
		_station_label.text = ""
		_skill_label.text = ""
		_craft_status_label.text = ""
		_craft_button.disabled = true
		return

	# Update name and description
	_detail_name_label.text = _selected_recipe.name
	_detail_description_label.text = _selected_recipe.description

	# Update materials list
	var inventory := game_client.local_inventory if game_client != null else null

	for input in _selected_recipe.inputs:
		var item_id: String = input.get("item_id", "")
		var required: int = input.get("count", 1)
		var have: int = 0

		if inventory != null:
			have = inventory.get_item_count(item_id)

		# Get item name from registry
		var item_name := item_id
		if game_client != null:
			var def := game_client.client_registries.item_registry.get_item(item_id)
			if def != null:
				item_name = def.name

		var mat_label := Label.new()
		mat_label.add_theme_font_size_override("font_size", 11)

		if have >= required:
			mat_label.text = "  [%d/%d] %s" % [have, required, item_name]
			mat_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		else:
			mat_label.text = "  [%d/%d] %s" % [have, required, item_name]
			mat_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))

		_materials_container.add_child(mat_label)

	# Update station requirement
	if _selected_recipe.station_type.is_empty():
		_station_label.text = "Station: Anywhere"
	else:
		_station_label.text = "Station: %s" % _selected_recipe.station_type.capitalize()

	# Update skill requirement
	if _selected_recipe.required_skill.is_empty():
		_skill_label.text = ""
	else:
		_skill_label.text = "Skill: %s Lv.%d" % [
			_selected_recipe.required_skill.capitalize(),
			_selected_recipe.required_skill_level
		]

	# Update outputs
	for output in _selected_recipe.outputs:
		var item_id: String = output.get("item_id", "")
		var count: int = output.get("count", 1)

		var item_name := item_id
		if game_client != null:
			var def := game_client.client_registries.item_registry.get_item(item_id)
			if def != null:
				item_name = def.name

		var output_label := Label.new()
		output_label.add_theme_font_size_override("font_size", 12)
		if count > 1:
			output_label.text = "%s x%d" % [item_name, count]
		else:
			output_label.text = item_name
		output_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
		_output_container.add_child(output_label)

	# Update craft button state
	var can_craft := _can_craft_recipe(_selected_recipe)
	_craft_button.disabled = not can_craft

	if can_craft:
		_craft_status_label.text = ""
		_craft_button.text = "Craft"
	else:
		var crafting := game_client.client_registries.crafting_system
		var error := crafting.get_craft_error(
			_selected_recipe,
			game_client.local_inventory if game_client != null else null,
			{},  # skill_levels
			""   # current_station
		)
		_craft_status_label.text = error
		_craft_status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		_craft_button.text = "Cannot Craft"


func _on_search_changed(new_text: String) -> void:
	_search_text = new_text
	_refresh_recipe_list()


func _on_category_changed(tab_index: int) -> void:
	if tab_index == 0:
		_current_category = ""  # "All" tab
	else:
		# Get category name from crafting system
		if game_client != null:
			var crafting := game_client.client_registries.crafting_system
			var categories := crafting.get_categories()
			categories.sort()
			if tab_index - 1 < categories.size():
				_current_category = categories[tab_index - 1]

	_refresh_recipe_list()


func _on_recipe_selected(recipe: RecipeDefinition) -> void:
	_selected_recipe = recipe

	# Update button highlights
	for btn_id in _recipe_buttons:
		var btn: Button = _recipe_buttons[btn_id]
		if btn_id == recipe.id:
			btn.add_theme_stylebox_override("normal", _create_selected_style())
		else:
			btn.remove_theme_stylebox_override("normal")

	_refresh_detail_panel()


func _create_selected_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.4, 0.5, 0.5)
	style.set_corner_radius_all(4)
	return style


func _on_craft_pressed() -> void:
	if _selected_recipe == null:
		return

	if game_client != null:
		game_client.request_craft(_selected_recipe.id)
		craft_requested.emit(_selected_recipe.id)


func _on_inventory_changed() -> void:
	_refresh_recipe_list()
	_refresh_detail_panel()


func _on_craft_response(
	success: bool,
	recipe_id: String,
	_items_created: Array,
	xp_gained: int,
	error: String
) -> void:
	if success:
		_craft_status_label.text = "Crafted! +%d XP" % xp_gained
		_craft_status_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	else:
		_craft_status_label.text = "Failed: %s" % error
		_craft_status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))

	# Refresh to update material counts
	_refresh_recipe_list()
	_refresh_detail_panel()


func _on_close_pressed() -> void:
	hide()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			hide()
			get_viewport().set_input_as_handled()
