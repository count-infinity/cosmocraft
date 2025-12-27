class_name StatsPanel
extends PanelContainer
## Stats panel showing all player stats with base + bonus breakdown.
## Updates automatically when equipment or skills change.

const PlayerStatsClass = preload("res://shared/items/player_stats.gd")
const ItemEnumsClass = preload("res://shared/items/item_enums.gd")


## Reference to game client
var game_client: GameClient = null

## UI components
var _title_label: Label
var _scroll_container: ScrollContainer
var _stats_container: VBoxContainer

## Stat row labels: stat_type -> {name: Label, base: Label, bonus: Label, total: Label}
var _stat_rows: Dictionary = {}

## Categories of stats for organization
const STAT_CATEGORIES: Dictionary = {
	"Core": [
		ItemEnums.StatType.MAX_HP,
		ItemEnums.StatType.HP_REGEN,
		ItemEnums.StatType.MAX_ENERGY,
		ItemEnums.StatType.ENERGY_REGEN,
	],
	"Attributes": [
		ItemEnums.StatType.STRENGTH,
		ItemEnums.StatType.PRECISION,
		ItemEnums.StatType.FORTITUDE,
		ItemEnums.StatType.EFFICIENCY,
		ItemEnums.StatType.LUCK,
	],
	"Combat": [
		ItemEnums.StatType.MOVE_SPEED,
		ItemEnums.StatType.ATTACK_SPEED,
		ItemEnums.StatType.CRIT_CHANCE,
		ItemEnums.StatType.CRIT_DAMAGE,
	],
	"Resistances": [
		ItemEnums.StatType.HEAT_RESIST,
		ItemEnums.StatType.COLD_RESIST,
		ItemEnums.StatType.RADIATION_RESIST,
		ItemEnums.StatType.TOXIC_RESIST,
		ItemEnums.StatType.PRESSURE_RESIST,
	],
}


func _ready() -> void:
	_create_ui()


func _create_ui() -> void:
	custom_minimum_size = Vector2(320, 420)

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
	_title_label.text = "Player Stats"
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

	# Column headers
	var header_row := _create_header_row()
	vbox.add_child(header_row)

	# Scrollable stats container
	_scroll_container = ScrollContainer.new()
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_scroll_container)

	_stats_container = VBoxContainer.new()
	_stats_container.add_theme_constant_override("separation", 4)
	_stats_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.add_child(_stats_container)

	# Create stat rows organized by category
	_create_stat_rows()


func _create_header_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	# Stat name column
	var name_label := Label.new()
	name_label.text = "Stat"
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	name_label.custom_minimum_size.x = 110
	row.add_child(name_label)

	# Base column
	var base_label := Label.new()
	base_label.text = "Base"
	base_label.add_theme_font_size_override("font_size", 11)
	base_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	base_label.custom_minimum_size.x = 50
	base_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(base_label)

	# Bonus column
	var bonus_label := Label.new()
	bonus_label.text = "Bonus"
	bonus_label.add_theme_font_size_override("font_size", 11)
	bonus_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	bonus_label.custom_minimum_size.x = 60
	bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(bonus_label)

	# Total column
	var total_label := Label.new()
	total_label.text = "Total"
	total_label.add_theme_font_size_override("font_size", 11)
	total_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	total_label.custom_minimum_size.x = 60
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(total_label)

	return row


func _create_stat_rows() -> void:
	for category_name in STAT_CATEGORIES:
		# Category header
		var cat_label := Label.new()
		cat_label.text = category_name
		cat_label.add_theme_font_size_override("font_size", 13)
		cat_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
		_stats_container.add_child(cat_label)

		# Stats in this category
		var stats: Array = STAT_CATEGORIES[category_name]
		for stat_type in stats:
			var row := _create_stat_row(stat_type)
			_stats_container.add_child(row)

		# Spacer between categories
		var spacer := Control.new()
		spacer.custom_minimum_size.y = 8
		_stats_container.add_child(spacer)


func _create_stat_row(stat_type: ItemEnums.StatType) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	# Stat name
	var name_label := Label.new()
	name_label.text = ItemEnums.get_stat_name(stat_type)
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.custom_minimum_size.x = 110
	row.add_child(name_label)

	# Base value
	var base_label := Label.new()
	base_label.text = "0"
	base_label.add_theme_font_size_override("font_size", 11)
	base_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	base_label.custom_minimum_size.x = 50
	base_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(base_label)

	# Bonus value
	var bonus_label := Label.new()
	bonus_label.text = "+0"
	bonus_label.add_theme_font_size_override("font_size", 11)
	bonus_label.custom_minimum_size.x = 60
	bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(bonus_label)

	# Total value
	var total_label := Label.new()
	total_label.text = "0"
	total_label.add_theme_font_size_override("font_size", 11)
	total_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	total_label.custom_minimum_size.x = 60
	total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(total_label)

	# Store references
	_stat_rows[stat_type] = {
		"name": name_label,
		"base": base_label,
		"bonus": bonus_label,
		"total": total_label,
	}

	return row


## Initialize with game client reference
func initialize(client: GameClient) -> void:
	game_client = client

	if game_client != null:
		game_client.equipment_changed.connect(_on_equipment_changed)
		game_client.stats_changed.connect(_on_stats_changed)
		_refresh_display()


## Refresh the entire stats display
func _refresh_display() -> void:
	if game_client == null or game_client.local_stats == null:
		_clear_display()
		return

	var stats: PlayerStats = game_client.local_stats
	var equipment: EquipmentSlots = game_client.local_equipment

	for stat_type in _stat_rows:
		_update_stat_row(stat_type, stats, equipment)


## Update a single stat row
func _update_stat_row(stat_type: ItemEnums.StatType, stats: PlayerStats, equipment: EquipmentSlots) -> void:
	var row_data: Dictionary = _stat_rows[stat_type]

	# Get base value from PlayerStats.BASE_STATS
	var base_value: float = PlayerStats.BASE_STATS.get(stat_type, 0.0)

	# Get total value from calculated stats
	var total_value: float = stats.get_stat(stat_type)

	# Calculate equipment bonus
	var equip_bonus: float = 0.0
	if equipment != null:
		var equip_stats := equipment.get_total_stats()
		equip_bonus = equip_stats.get(stat_type, 0.0)

	# Bonus includes equipment and any other sources
	var bonus_value: float = total_value - base_value

	# Format values based on stat type
	var base_text: String = _format_stat_value(stat_type, base_value)
	var bonus_text: String = _format_bonus_value(stat_type, bonus_value)
	var total_text: String = _format_stat_value(stat_type, total_value)

	# Update labels
	row_data["base"].text = base_text
	row_data["bonus"].text = bonus_text
	row_data["total"].text = total_text

	# Color the bonus based on positive/negative
	var bonus_label: Label = row_data["bonus"]
	if bonus_value > 0.001:
		bonus_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))  # Green
	elif bonus_value < -0.001:
		bonus_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))  # Red
	else:
		bonus_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))  # Gray


## Format a stat value for display
func _format_stat_value(stat_type: ItemEnums.StatType, value: float) -> String:
	match stat_type:
		ItemEnums.StatType.CRIT_CHANCE:
			return "%.0f%%" % (value * 100.0)
		ItemEnums.StatType.CRIT_DAMAGE:
			return "%.1fx" % value
		ItemEnums.StatType.MOVE_SPEED, ItemEnums.StatType.ATTACK_SPEED:
			return "%.2fx" % value
		ItemEnums.StatType.HEAT_RESIST, ItemEnums.StatType.COLD_RESIST, \
		ItemEnums.StatType.RADIATION_RESIST, ItemEnums.StatType.TOXIC_RESIST, \
		ItemEnums.StatType.PRESSURE_RESIST:
			return "%.0f%%" % (value * 100.0)
		ItemEnums.StatType.HP_REGEN, ItemEnums.StatType.ENERGY_REGEN:
			return "%.1f/s" % value
		_:
			if value == floorf(value):
				return "%.0f" % value
			else:
				return "%.1f" % value


## Format a bonus value for display (with +/- sign)
func _format_bonus_value(stat_type: ItemEnums.StatType, value: float) -> String:
	var sign_str: String = "+" if value >= 0 else ""

	match stat_type:
		ItemEnums.StatType.CRIT_CHANCE:
			return "%s%.0f%%" % [sign_str, value * 100.0]
		ItemEnums.StatType.CRIT_DAMAGE:
			return "%s%.2f" % [sign_str, value]
		ItemEnums.StatType.MOVE_SPEED, ItemEnums.StatType.ATTACK_SPEED:
			return "%s%.2f" % [sign_str, value]
		ItemEnums.StatType.HEAT_RESIST, ItemEnums.StatType.COLD_RESIST, \
		ItemEnums.StatType.RADIATION_RESIST, ItemEnums.StatType.TOXIC_RESIST, \
		ItemEnums.StatType.PRESSURE_RESIST:
			return "%s%.0f%%" % [sign_str, value * 100.0]
		ItemEnums.StatType.HP_REGEN, ItemEnums.StatType.ENERGY_REGEN:
			return "%s%.1f" % [sign_str, value]
		_:
			if absf(value) == floorf(absf(value)):
				return "%s%.0f" % [sign_str, value]
			else:
				return "%s%.1f" % [sign_str, value]


## Clear all stat displays
func _clear_display() -> void:
	for stat_type in _stat_rows:
		var row_data: Dictionary = _stat_rows[stat_type]
		row_data["base"].text = "0"
		row_data["bonus"].text = "+0"
		row_data["total"].text = "0"
		row_data["bonus"].add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))


func _on_equipment_changed(_slot: int) -> void:
	_refresh_display()


func _on_stats_changed() -> void:
	_refresh_display()


func _on_close_pressed() -> void:
	hide()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			hide()
			get_viewport().set_input_as_handled()
