class_name SpaceHud
extends CanvasLayer
## Heads-up display for the space mode: claim progress, shields and hull,
## territory, prompts, banners, and arrows pointing at things off screen.

const GOLD := Color(1.0, 0.78, 0.4)
const DIM := Color(0.78, 0.75, 0.88)
const RED := Color(1.0, 0.4, 0.34)
const ORANGE := Color(1.0, 0.65, 0.3)
const CYAN := Color(0.45, 0.9, 1.0)
const VIOLET := Color(0.85, 0.45, 1.0)

const HELP_TEXT := "WASD move  ·  mouse aim  ·  hold left click to fire  ·  Space/Shift dash\nE kindle  ·  Tab/M map  ·  Esc pause  ·  H hide help\nF1 debug  ·  F2 claim speed  ·  F3 god mode  ·  F4 new sector  ·  F5 mute  ·  F11 fullscreen"

var _canvas: HudCanvas
var _claim_name: Label
var _claim_status: Label
var _territory: Label
var _prompt: Label
var _banner: Label
var _banner_sub: Label
var _help: Label
var _debug: Label
var _banner_tween: Tween


func _ready() -> void:
	layer = 10
	_canvas = HudCanvas.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_canvas)
	_claim_name = _add_label(20, GOLD, HORIZONTAL_ALIGNMENT_CENTER, Control.PRESET_TOP_WIDE, 24.0)
	_claim_status = _add_label(15, GOLD, HORIZONTAL_ALIGNMENT_CENTER, Control.PRESET_TOP_WIDE, 82.0)
	_territory = _add_label(16, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, Control.PRESET_TOP_WIDE, 16.0)
	_territory.offset_right = -22.0
	_prompt = _add_label(16, DIM, HORIZONTAL_ALIGNMENT_CENTER, Control.PRESET_BOTTOM_WIDE, -118.0)
	_banner = _add_label(42, GOLD, HORIZONTAL_ALIGNMENT_CENTER, Control.PRESET_TOP_WIDE, 150.0)
	_banner_sub = _add_label(19, DIM, HORIZONTAL_ALIGNMENT_CENTER, Control.PRESET_TOP_WIDE, 206.0)
	_help = _add_label(13, Color(0.7, 0.68, 0.8, 0.85), HORIZONTAL_ALIGNMENT_RIGHT, Control.PRESET_BOTTOM_WIDE, -66.0)
	_help.offset_right = -18.0
	_help.text = HELP_TEXT
	_debug = _add_label(13, Color(0.6, 1.0, 0.7), HORIZONTAL_ALIGNMENT_LEFT, Control.PRESET_TOP_WIDE, 14.0)
	_debug.offset_left = 18.0
	_banner.modulate.a = 0.0
	_banner_sub.modulate.a = 0.0
	hide_claim()


func set_claim(region_name: String, progress: float, status: String, status_color: Color, elite_mark: float) -> void:
	_claim_name.visible = true
	_claim_status.visible = true
	_claim_name.text = region_name
	_claim_status.text = status
	_claim_status.label_settings.font_color = status_color
	_canvas.claim_visible = true
	_canvas.claim_progress = progress
	_canvas.claim_color = status_color
	_canvas.elite_mark = elite_mark


func hide_claim() -> void:
	_claim_name.visible = false
	_claim_status.visible = false
	_canvas.claim_visible = false


func set_vitals(shield_ratio: float, hull_ratio: float, dash_ready: float) -> void:
	_canvas.shield_ratio = shield_ratio
	_canvas.hull_ratio = hull_ratio
	_canvas.dash_ready = dash_ready


func set_territory(claimed: int, total: int) -> void:
	_territory.text = "TERRITORY  %d / %d" % [claimed, total]


func set_prompt(text: String) -> void:
	_prompt.text = text


func set_indicators(indicators: Array[Dictionary]) -> void:
	_canvas.indicators = indicators


func set_debug(text: String) -> void:
	_debug.text = text


func toggle_help() -> void:
	_help.visible = not _help.visible


func show_banner(title: String, subtitle := "", color := GOLD, duration := 2.2) -> void:
	_banner.text = title
	_banner.label_settings.font_color = color
	_banner_sub.text = subtitle
	if _banner_tween != null:
		_banner_tween.kill()
	_banner.modulate.a = 0.0
	_banner_sub.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.15)
	_banner_tween.parallel().tween_property(_banner_sub, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_interval(duration)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.5)
	_banner_tween.parallel().tween_property(_banner_sub, "modulate:a", 0.0, 0.5)


func hide_banner() -> void:
	if _banner_tween != null:
		_banner_tween.kill()
	_banner.modulate.a = 0.0
	_banner_sub.modulate.a = 0.0


func _add_label(font_size: int, color: Color, align: HorizontalAlignment, preset: Control.LayoutPreset, top: float) -> Label:
	var label := Label.new()
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = color
	settings.outline_size = maxi(4, int(font_size * 0.25))
	settings.outline_color = Color(0.0, 0.0, 0.0, 0.85)
	label.label_settings = settings
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(preset)
	label.offset_top = top
	label.offset_bottom = top + font_size * 4.5
	add_child(label)
	return label
