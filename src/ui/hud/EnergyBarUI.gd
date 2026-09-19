class_name EnergyBarUI
extends Control

## EnergyBarUI: Велика шкала енергії гравця (HUD).
## Відображає запас сил (1000 одиниць на повний ігровий день),
## витрати на біг, видобуток та будівництво, а також статус виснаження.

@export var max_energy: float = 1000.0
@export var current_energy: float = 1000.0

var _display_energy: float = 1000.0
var _label: Label = null
var _progress_bar: ProgressBar = null
var _flash_timer: float = 0.0
var _is_warning_flashing: bool = false
var _fill_style: StyleBoxFlat = null


func _ready() -> void:
	custom_minimum_size = Vector2(460.0, 22.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_ui()

	if EventBus != null:
		EventBus.player_stats_changed.connect(_on_player_stats_changed)
		if EventBus.has_signal("energy_depleted_action_attempted"):
			EventBus.energy_depleted_action_attempted.connect(_on_depleted_attempt)

	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_signal("energy_changed"):
		player.energy_changed.connect(_on_energy_changed)
		if "current_energy" in player and "max_energy" in player:
			_on_energy_changed(player.current_energy, player.max_energy)


func _setup_ui() -> void:
	# 1. Задній фон
	var bg_panel := PanelContainer.new()
	bg_panel.name = "BackgroundPanel"
	bg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.08, 0.11, 0.85)
	bg_style.border_color = Color(0.3, 0.4, 0.52, 0.75)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(5)
	bg_style.set_content_margin_all(2.0)
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	add_child(bg_panel)

	# 2. ProgressBar
	_progress_bar = ProgressBar.new()
	_progress_bar.name = "ProgressBar"
	_progress_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_bar.show_percentage = false
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = max_energy
	_progress_bar.value = current_energy

	var empty_style := StyleBoxFlat.new()
	empty_style.bg_color = Color(0.12, 0.14, 0.18, 0.4)
	empty_style.set_corner_radius_all(4)
	_progress_bar.add_theme_stylebox_override("background", empty_style)

	_fill_style = StyleBoxFlat.new()
	_fill_style.bg_color = Color(0.95, 0.72, 0.15, 0.92) # Golden amber energy
	_fill_style.set_corner_radius_all(4)
	_progress_bar.add_theme_stylebox_override("fill", _fill_style)
	bg_panel.add_child(_progress_bar)

	# 3. Текстовий Label
	_label = Label.new()
	_label.name = "Label"
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)

	_update_visuals()


func _process(delta: float) -> void:
	if absf(_display_energy - current_energy) > 0.1:
		_display_energy = lerpf(_display_energy, current_energy, 12.0 * delta)
		_update_visuals()

	if _is_warning_flashing:
		_flash_timer += delta * 10.0
		if _flash_timer >= 6.0:
			_is_warning_flashing = false
			_flash_timer = 0.0
			_update_visuals()
		else:
			var flash: bool = sin(_flash_timer) > 0.0
			if _fill_style != null:
				_fill_style.bg_color = Color(1.0, 0.2, 0.2, 0.95) if flash else Color(0.4, 0.1, 0.1, 0.8)
			if _label != null:
				_label.text = "⚡ ВИСНАЖЕННЯ! НЕМАЄ ЕНЕРГІЇ (0 / %d)" % int(max_energy)


func _on_player_stats_changed(_hp: float, _max_hp: float, cur_stamina: float, max_stamina: float) -> void:
	_on_energy_changed(cur_stamina, max_stamina)


func _on_energy_changed(cur: float, max_val: float) -> void:
	max_energy = maxf(1.0, max_val)
	current_energy = clampf(cur, 0.0, max_energy)
	if _progress_bar != null:
		_progress_bar.max_value = max_energy
	if not _is_warning_flashing:
		_update_visuals()


func _on_depleted_attempt() -> void:
	_is_warning_flashing = true
	_flash_timer = 0.0


func _update_visuals() -> void:
	if _progress_bar != null:
		_progress_bar.value = _display_energy

	var ratio: float = _display_energy / max_energy
	if _fill_style != null and not _is_warning_flashing:
		if ratio > 0.4:
			_fill_style.bg_color = Color(0.95, 0.72, 0.15, 0.92) # Golden amber
		elif ratio > 0.15:
			_fill_style.bg_color = Color(0.95, 0.45, 0.1, 0.92)  # Orange alert
		else:
			_fill_style.bg_color = Color(0.85, 0.2, 0.15, 0.92)  # Critical red

	if _label != null and not _is_warning_flashing:
		if current_energy <= 0.01:
			_label.text = "⚡ ВИСНАЖЕННЯ: 0 / %d" % int(max_energy)
			_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		else:
			_label.text = "⚡ Енергія: %d / %d" % [int(round(_display_energy)), int(max_energy)]
			_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
