class_name ItemTooltip
extends PanelContainer
## Tooltip popup that displays detailed item information.
## Shows on hover over any item slot.


## Minimum width of the tooltip
const MIN_WIDTH: float = 200.0
const MAX_WIDTH: float = 300.0

## Colors for quality/rarity
const QUALITY_COLORS: Dictionary = {
	"crude": Color(0.6, 0.6, 0.6),      # Gray
	"normal": Color(1.0, 1.0, 1.0),     # White
	"fine": Color(0.3, 0.8, 0.3),       # Green
	"masterwork": Color(0.3, 0.5, 1.0), # Blue
}

## Colors for stat types
const STAT_POSITIVE_COLOR: Color = Color(0.3, 0.8, 0.3)
const STAT_NEGATIVE_COLOR: Color = Color(0.8, 0.3, 0.3)

var _vbox: VBoxContainer
var _name_label: Label
var _type_label: Label
var _description_label: Label
var _stats_container: VBoxContainer
var _durability_container: HBoxContainer
var _durability_label: Label
var _weight_label: Label
var _quality_label: Label


func _ready() -> void:
	_create_ui()
	hide()


func _create_ui() -> void:
	# Configure panel
	custom_minimum_size = Vector2(MIN_WIDTH, 0)

	# Add some padding via margin container
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 4)
	margin.add_child(_vbox)

	# Item name (large, colored by quality)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 16)
	_vbox.add_child(_name_label)

	# Item type and tier
	_type_label = Label.new()
	_type_label.add_theme_font_size_override("font_size", 12)
	_type_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_vbox.add_child(_type_label)

	# Separator
	var sep1 := HSeparator.new()
	_vbox.add_child(sep1)

	# Description
	_description_label = Label.new()
	_description_label.add_theme_font_size_override("font_size", 12)
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.custom_minimum_size.x = MIN_WIDTH - 16
	_vbox.add_child(_description_label)

	# Stats container
	_stats_container = VBoxContainer.new()
	_stats_container.add_theme_constant_override("separation", 2)
	_vbox.add_child(_stats_container)

	# Durability bar
	_durability_container = HBoxContainer.new()
	_durability_container.add_theme_constant_override("separation", 4)
	_vbox.add_child(_durability_container)

	var dur_icon := Label.new()
	dur_icon.text = "Durability:"
	dur_icon.add_theme_font_size_override("font_size", 11)
	_durability_container.add_child(dur_icon)

	_durability_label = Label.new()
	_durability_label.add_theme_font_size_override("font_size", 11)
	_durability_container.add_child(_durability_label)

	# Quality
	_quality_label = Label.new()
	_quality_label.add_theme_font_size_override("font_size", 11)
	_vbox.add_child(_quality_label)

	# Weight
	_weight_label = Label.new()
	_weight_label.add_theme_font_size_override("font_size", 11)
	_weight_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_vbox.add_child(_weight_label)


## Show tooltip for an ItemStack
func show_for_stack(stack: ItemStack) -> void:
	if stack == null or stack.is_empty() or stack.item == null:
		hide()
		return

	show_for_item(stack.item, stack.count)


## Show tooltip for an ItemInstance
func show_for_item(item: ItemInstance, count: int = 1) -> void:
	if item == null or item.definition == null:
		hide()
		return

	var def := item.definition

	# Item name with quality prefix
	var display_name := item.get_display_name()
	if count > 1:
		display_name += " x%d" % count
	_name_label.text = display_name
	_name_label.add_theme_color_override("font_color", _get_quality_color(item.quality))

	# Type and tier
	var type_text := _get_type_name(def.type)
	if def.tier > 0:
		type_text += " - Tier %d" % def.tier
	_type_label.text = type_text

	# Description
	if def.description.is_empty():
		_description_label.visible = false
	else:
		_description_label.visible = true
		_description_label.text = def.description

	# Stats
	_update_stats(item)

	# Durability
	if def.has_durability():
		_durability_container.visible = true
		var max_dur := item.get_max_durability()
		var cur_dur := item.current_durability
		var dur_percent := float(cur_dur) / float(max_dur) * 100.0 if max_dur > 0 else 0.0
		_durability_label.text = "%d / %d (%.0f%%)" % [cur_dur, max_dur, dur_percent]

		# Color based on durability
		if dur_percent > 50:
			_durability_label.add_theme_color_override("font_color", Color.WHITE)
		elif dur_percent > 25:
			_durability_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			_durability_label.add_theme_color_override("font_color", Color.RED)
	else:
		_durability_container.visible = false

	# Quality
	if item.quality != 1.0:
		_quality_label.visible = true
		var quality_percent := item.quality * 100.0
		_quality_label.text = "Quality: %.0f%%" % quality_percent
		_quality_label.add_theme_color_override("font_color", _get_quality_color(item.quality))
	else:
		_quality_label.visible = false

	# Weight
	var weight := def.weight * count
	_weight_label.text = "Weight: %.1f" % weight

	show()


func _update_stats(item: ItemInstance) -> void:
	# Clear old stats
	for child in _stats_container.get_children():
		child.queue_free()

	var stats := item.get_effective_stats()
	if stats.is_empty():
		_stats_container.visible = false
		return

	_stats_container.visible = true

	# Add separator before stats
	var sep := HSeparator.new()
	_stats_container.add_child(sep)

	for stat_key in stats:
		var value: float = stats[stat_key]
		if value == 0.0:
			continue

		var stat_label := Label.new()
		stat_label.add_theme_font_size_override("font_size", 12)

		var stat_name := ItemEnums.get_stat_name(stat_key)
		var value_text := ""

		# Format value based on stat type
		if stat_key in [ItemEnums.StatType.CRIT_CHANCE]:
			value_text = "%+.0f%%" % (value * 100.0)
		elif stat_key in [ItemEnums.StatType.MOVE_SPEED, ItemEnums.StatType.ATTACK_SPEED, ItemEnums.StatType.CRIT_DAMAGE]:
			value_text = "%.2fx" % value
		else:
			value_text = "%+.0f" % value

		stat_label.text = "%s: %s" % [stat_name, value_text]

		# Color based on positive/negative
		if value > 0:
			stat_label.add_theme_color_override("font_color", STAT_POSITIVE_COLOR)
		else:
			stat_label.add_theme_color_override("font_color", STAT_NEGATIVE_COLOR)

		_stats_container.add_child(stat_label)

	# Add weapon damage if applicable
	if item.definition.base_damage > 0:
		var dmg_label := Label.new()
		dmg_label.add_theme_font_size_override("font_size", 12)
		var damage := int(item.definition.base_damage * item.quality)
		dmg_label.text = "Damage: %d" % damage
		dmg_label.add_theme_color_override("font_color", STAT_POSITIVE_COLOR)
		_stats_container.add_child(dmg_label)


func _get_quality_color(quality: float) -> Color:
	if quality < 0.8:
		return QUALITY_COLORS["crude"]
	elif quality >= 1.15:
		return QUALITY_COLORS["masterwork"]
	elif quality >= 1.05:
		return QUALITY_COLORS["fine"]
	else:
		return QUALITY_COLORS["normal"]


func _get_type_name(type: ItemEnums.ItemType) -> String:
	match type:
		ItemEnums.ItemType.MATERIAL:
			return "Material"
		ItemEnums.ItemType.TOOL:
			return "Tool"
		ItemEnums.ItemType.WEAPON:
			return "Weapon"
		ItemEnums.ItemType.ARMOR:
			return "Armor"
		ItemEnums.ItemType.ACCESSORY:
			return "Accessory"
		ItemEnums.ItemType.CONSUMABLE:
			return "Consumable"
		ItemEnums.ItemType.PLACEABLE:
			return "Placeable"
		ItemEnums.ItemType.BLUEPRINT:
			return "Blueprint"
		ItemEnums.ItemType.ENCHANT_CORE:
			return "Enchant Core"
		ItemEnums.ItemType.GEM:
			return "Gem"
		ItemEnums.ItemType.KEY:
			return "Key"
		ItemEnums.ItemType.QUEST:
			return "Quest Item"
		_:
			return "Unknown"


## Position tooltip near a control without going off screen
func position_near(control: Control, viewport_size: Vector2) -> void:
	var control_rect := control.get_global_rect()
	var tooltip_size := size

	# Try to position to the right of the control
	var pos := Vector2(control_rect.end.x + 8, control_rect.position.y)

	# If it would go off the right edge, position to the left
	if pos.x + tooltip_size.x > viewport_size.x:
		pos.x = control_rect.position.x - tooltip_size.x - 8

	# If it would go off the bottom, move up
	if pos.y + tooltip_size.y > viewport_size.y:
		pos.y = viewport_size.y - tooltip_size.y - 8

	# Clamp to viewport
	pos.x = clampf(pos.x, 0, viewport_size.x - tooltip_size.x)
	pos.y = clampf(pos.y, 0, viewport_size.y - tooltip_size.y)

	global_position = pos
