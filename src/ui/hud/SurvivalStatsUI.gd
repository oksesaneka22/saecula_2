class_name SurvivalStatsUI
extends Control

## SurvivalStatsUI: Дві акуратні шкали показників виживання (Голод та Спрага).
## Розташовуються прямо над шкалою енергії (EnergyBarUI).
## Відображають рівень голоду (0-100) та спраги (0-100) з попередженням про виснаження.

@export var max_hunger: float = 100.0
@export var current_hunger: float = 100.0

@export var max_thirst: float = 100.0
@export var current_thirst: float = 100.0

var _display_hunger: float = 100.0
var _display_thirst: float = 100.0

var _hunger_progress: ProgressBar = null
var _hunger_label: Label = null
var _hunger_fill: StyleBoxFlat = null

var _thirst_progress: ProgressBar = null
var _thirst_label: Label = null
var _thirst_fill: StyleBoxFlat = null

var _flash_timer: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(460.0, 20.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_ui()

	if EventBus != null:
		if EventBus.has_signal("player_survival_changed"):
			EventBus.player_survival_changed.connect(_on_survival_changed)

	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		if player.has_signal("hunger_changed"):
			player.hunger_changed.connect(_on_hunger_changed)
		if player.has_signal("thirst_changed"):
			player.thirst_changed.connect(_on_thirst_changed)
		if "current_hunger" in player and "max_hunger" in player:
			_on_hunger_changed(player.current_hunger, player.max_hunger)
		if "current_thirst" in player and "max_thirst" in player:
			_on_thirst_changed(player.current_thirst, player.max_thirst)


func _setup_ui() -> void:
	var hbox := HBoxContainer.new()
	hbox.name = "HBox"
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)
	add_child(hbox)

	# 1. Смужка голоду (Hunger)
	var hunger_container := Control.new()
	hunger_container.name = "HungerContainer"
	hunger_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hunger_container.size_flags_vertical = Control.SIZE_FILL
	hunger_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(hunger_container)

	var hunger_bg := PanelContainer.new()
	hunger_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	hunger_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style_h := StyleBoxFlat.new()
	bg_style_h.bg_color = Color(0.06, 0.08, 0.11, 0.85)
	bg_style_h.border_color = Color(0.35, 0.28, 0.22, 0.75)
	bg_style_h.set_border_width_all(1)
	bg_style_h.set_corner_radius_all(4)
	bg_style_h.set_content_margin_all(2.0)
	hunger_bg.add_theme_stylebox_override("panel", bg_style_h)
	hunger_container.add_child(hunger_bg)

	_hunger_progress = ProgressBar.new()
	_hunger_progress.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hunger_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hunger_progress.show_percentage = false
	_hunger_progress.min_value = 0.0
	_hunger_progress.max_value = max_hunger
	_hunger_progress.value = current_hunger

	var empty_bg_h := StyleBoxFlat.new()
	empty_bg_h.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	_hunger_progress.add_theme_stylebox_override("background", empty_bg_h)

	_hunger_fill = StyleBoxFlat.new()
	_hunger_fill.bg_color = Color("e76f51") # Теплий теракотовий
	_hunger_fill.set_corner_radius_all(3)
	_hunger_progress.add_theme_stylebox_override("fill", _hunger_fill)
	hunger_container.add_child(_hunger_progress)

	_hunger_label = Label.new()
	_hunger_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hunger_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hunger_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hunger_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hunger_label.add_theme_font_size_override("font_size", 11)
	_hunger_label.text = "🍖 Голод: %d / %d" % [int(current_hunger), int(max_hunger)]
	hunger_container.add_child(_hunger_label)

	# 2. Смужка спраги (Thirst)
	var thirst_container := Control.new()
	thirst_container.name = "ThirstContainer"
	thirst_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thirst_container.size_flags_vertical = Control.SIZE_FILL
	thirst_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(thirst_container)

	var thirst_bg := PanelContainer.new()
	thirst_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	thirst_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style_t := StyleBoxFlat.new()
	bg_style_t.bg_color = Color(0.06, 0.08, 0.11, 0.85)
	bg_style_t.border_color = Color(0.2, 0.32, 0.42, 0.75)
	bg_style_t.set_border_width_all(1)
	bg_style_t.set_corner_radius_all(4)
	bg_style_t.set_content_margin_all(2.0)
	thirst_bg.add_theme_stylebox_override("panel", bg_style_t)
	thirst_container.add_child(thirst_bg)

	_thirst_progress = ProgressBar.new()
	_thirst_progress.set_anchors_preset(Control.PRESET_FULL_RECT)
	_thirst_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_thirst_progress.show_percentage = false
	_thirst_progress.min_value = 0.0
	_thirst_progress.max_value = max_thirst
	_thirst_progress.value = current_thirst

	var empty_bg_t := StyleBoxFlat.new()
	empty_bg_t.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	_thirst_progress.add_theme_stylebox_override("background", empty_bg_t)

	_thirst_fill = StyleBoxFlat.new()
	_thirst_fill.bg_color = Color("00b4d8") # Водяний бірюзовий
	_thirst_fill.set_corner_radius_all(3)
	_thirst_progress.add_theme_stylebox_override("fill", _thirst_fill)
	thirst_container.add_child(_thirst_progress)

	_thirst_label = Label.new()
	_thirst_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_thirst_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_thirst_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_thirst_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_thirst_label.add_theme_font_size_override("font_size", 11)
	_thirst_label.text = "💧 Спрага: %d / %d" % [int(current_thirst), int(max_thirst)]
	thirst_container.add_child(_thirst_label)


func _process(delta: float) -> void:
	# Плавне підтягування значень ProgressBar
	_display_hunger = lerpf(_display_hunger, current_hunger, delta * 8.0)
	if _hunger_progress != null:
		_hunger_progress.value = _display_hunger

	_display_thirst = lerpf(_display_thirst, current_thirst, delta * 8.0)
	if _thirst_progress != null:
		_thirst_progress.value = _display_thirst

	_flash_timer += delta

	# Оновлення кольору та напису голоду
	_update_hunger_display()
	# Оновлення кольору та напису спраги
	_update_thirst_display()


func _update_hunger_display() -> void:
	if _hunger_label == null or _hunger_fill == null:
		return

	var ratio: float = current_hunger / max_hunger if max_hunger > 0.0 else 0.0
	if current_hunger <= 0.0:
		_hunger_label.text = "💀 ГОЛОДНА СМЕРТЬ!"
		_hunger_fill.bg_color = Color("780000")
	elif ratio < 0.2:
		var flash: float = (sin(_flash_timer * 8.0) + 1.0) * 0.5
		_hunger_fill.bg_color = Color("e76f51").lerp(Color("d90429"), flash)
		_hunger_label.text = "⚠️ ГОЛОД: %d / %d" % [int(ceil(current_hunger)), int(max_hunger)]
	else:
		_hunger_fill.bg_color = Color("e76f51")
		_hunger_label.text = "🍖 Голод: %d / %d" % [int(ceil(current_hunger)), int(max_hunger)]


func _update_thirst_display() -> void:
	if _thirst_label == null or _thirst_fill == null:
		return

	var ratio: float = current_thirst / max_thirst if max_thirst > 0.0 else 0.0
	if current_thirst <= 0.0:
		_thirst_label.text = "💀 ЗНЕВОДНЕННЯ!"
		_thirst_fill.bg_color = Color("03045e")
	elif ratio < 0.2:
		var flash: float = (sin(_flash_timer * 8.0) + 1.0) * 0.5
		_thirst_fill.bg_color = Color("00b4d8").lerp(Color("d90429"), flash)
		_thirst_label.text = "⚠️ СПРАГА: %d / %d" % [int(ceil(current_thirst)), int(max_thirst)]
	else:
		_thirst_fill.bg_color = Color("00b4d8")
		_thirst_label.text = "💧 Спрага: %d / %d" % [int(ceil(current_thirst)), int(max_thirst)]


func _on_survival_changed(p_hunger: float, p_max_hunger: float, p_thirst: float, p_max_thirst: float) -> void:
	max_hunger = p_max_hunger
	current_hunger = p_hunger
	max_thirst = p_max_thirst
	current_thirst = p_thirst
	if _hunger_progress != null:
		_hunger_progress.max_value = max_hunger
	if _thirst_progress != null:
		_thirst_progress.max_value = max_thirst


func _on_hunger_changed(val: float, max_val: float) -> void:
	current_hunger = val
	max_hunger = max_val
	if _hunger_progress != null:
		_hunger_progress.max_value = max_val


func _on_thirst_changed(val: float, max_val: float) -> void:
	current_thirst = val
	max_thirst = max_val
	if _thirst_progress != null:
		_thirst_progress.max_value = max_val
