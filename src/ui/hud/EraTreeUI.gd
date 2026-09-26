extends Control

## EraTreeUI: Величне Меню Епох, Підепох та Дерева Досліджень (Tree/Forest Style).
## Квести та дослідження йдуть деревом/лісом від кореня/початку згори донизу гілками та листям.
## Перехід на нову підепоху відбувається ТІЛЬКИ після завершення всіх досліджень минулої.

signal tree_closed()

const TechNodeDataScript = preload("res://src/data/schemas/TechNodeData.gd")

# ------------------------------------------------------------------------------
# UI Елементи
# ------------------------------------------------------------------------------
var _backdrop: ColorRect = null
var _main_panel: PanelContainer = null

# Шапка та навігація
var _era_tab_bar: HBoxContainer = null
var _sub_era_tab_bar: HBoxContainer = null
var _era_title_label: Label = null
var _sub_era_badge_label: Label = null
var _era_desc_label: Label = null
var _progress_label: Label = null

# Canvas / Graph
var _scroll_container: ScrollContainer = null
var _graph_canvas: Control = null
var _node_cards: Dictionary = {} ## tech_id -> PanelContainer

# Інфопанель деталей праворуч
var _details_panel: PanelContainer = null
var _detail_icon_label: Label = null
var _detail_title_label: Label = null
var _detail_era_label: Label = null
var _detail_sub_era_label: Label = null
var _detail_desc_label: Label = null
var _detail_unlocks_vbox: VBoxContainer = null
var _detail_cost_vbox: VBoxContainer = null
var _btn_research: Button = null

# Стан
var _selected_tech_id: StringName = &""
var _current_view_era: int = 0
var _current_view_sub_era: StringName = &"" ## Якщо не порожньо - фільтр за підепохою
var _is_open: bool = false
var _player_inventory: Node = null

# Кольори теми
const COLOR_LOCKED = Color(0.18, 0.20, 0.25, 0.95)
const COLOR_BORDER_LOCKED = Color(0.32, 0.36, 0.44, 0.7)
const COLOR_AVAILABLE = Color(0.12, 0.22, 0.35, 0.98)
const COLOR_BORDER_AVAILABLE = Color(0.95, 0.75, 0.25, 0.95)
const COLOR_UNLOCKED = Color(0.08, 0.28, 0.22, 0.98)
const COLOR_BORDER_UNLOCKED = Color(0.2, 0.88, 0.6, 0.95)
const COLOR_LINE_UNLOCKED = Color(0.2, 0.88, 0.6, 0.9)
const COLOR_LINE_AVAILABLE = Color(0.95, 0.75, 0.25, 0.85)
const COLOR_LINE_LOCKED = Color(0.3, 0.35, 0.42, 0.45)

# ------------------------------------------------------------------------------
# Життєвий цикл
# ------------------------------------------------------------------------------
func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()

	if EraManager != null:
		EraManager.tech_tree_updated.connect(_on_tech_tree_updated)
		EraManager.era_changed.connect(_on_era_changed)
		if EraManager.has_signal("sub_era_changed"):
			EraManager.sub_era_changed.connect(_on_sub_era_changed)

	_connect_player()


func _connect_player() -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p != null and "inventory" in p:
		_player_inventory = p.inventory
		if _player_inventory != null and _player_inventory.has_signal("inventory_updated"):
			if not _player_inventory.inventory_updated.is_connected(_refresh_all):
				_player_inventory.inventory_updated.connect(_refresh_all)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("era_tree_toggle"):
		toggle()
		get_viewport().set_input_as_handled()
		return

	if not _is_open:
		return

	if event.is_action_pressed("cancel"):
		close()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------------------
# Побудова UI дерева
# ------------------------------------------------------------------------------
func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	# 1. Напівпрозоре затемнення з ефектом глибини
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = Color(0.02, 0.04, 0.07, 0.94)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(main_vbox)

	# 2. Шапка (Header)
	var header_panel := PanelContainer.new()
	var h_style := StyleBoxFlat.new()
	h_style.bg_color = Color(0.08, 0.11, 0.16, 0.95)
	h_style.border_color = Color(0.28, 0.42, 0.60, 0.8)
	h_style.set_border_width_all(2)
	h_style.set_corner_radius_all(10)
	h_style.set_content_margin_all(10.0)
	header_panel.add_theme_stylebox_override("panel", h_style)
	main_vbox.add_child(header_panel)

	var header_vbox := VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 8)
	header_panel.add_child(header_vbox)

	# Верхній рядок: Заголовок + Лічильник + Закрити
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	header_vbox.add_child(top_row)

	var title_lbl := Label.new()
	title_lbl.text = "🏛️ МЕНЮ ЕПОХ ТА ДЕРЕВО ДОСЛІДЖЕНЬ"
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.modulate = Color("E9C46A")
	top_row.add_child(title_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	_progress_label = Label.new()
	_progress_label.text = "Досліджено: 1 / 13"
	_progress_label.add_theme_font_size_override("font_size", 13)
	_progress_label.modulate = Color("A8DADC")
	top_row.add_child(_progress_label)

	var btn_close := Button.new()
	btn_close.text = " ✕ Закрити [Esc] "
	btn_close.custom_minimum_size = Vector2(110, 32)
	btn_close.pressed.connect(close)
	top_row.add_child(btn_close)

	# Рядок 1: Вкладки Епох (4 головні епохи людства)
	_era_tab_bar = HBoxContainer.new()
	_era_tab_bar.add_theme_constant_override("separation", 8)
	header_vbox.add_child(_era_tab_bar)

	# Рядок 2: Вкладки Підепох у вибраній епосі
	_sub_era_tab_bar = HBoxContainer.new()
	_sub_era_tab_bar.add_theme_constant_override("separation", 8)
	header_vbox.add_child(_sub_era_tab_bar)

	_build_era_tabs()
	_build_sub_era_tabs()

	# Інформаційний рядок активної доби та підепохи
	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 10)
	header_vbox.add_child(info_row)

	_era_title_label = Label.new()
	_era_title_label.text = "Епоха:"
	_era_title_label.add_theme_font_size_override("font_size", 14)
	_era_title_label.modulate = Color("F4A261")
	info_row.add_child(_era_title_label)

	_sub_era_badge_label = Label.new()
	_sub_era_badge_label.text = "[Підепоха]"
	_sub_era_badge_label.add_theme_font_size_override("font_size", 13)
	_sub_era_badge_label.modulate = Color("2A9D8F")
	info_row.add_child(_sub_era_badge_label)

	_era_desc_label = Label.new()
	_era_desc_label.text = ""
	_era_desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_era_desc_label.add_theme_font_size_override("font_size", 12)
	_era_desc_label.modulate = Color(0.8, 0.85, 0.9)
	info_row.add_child(_era_desc_label)

	# 3. Основна робоча зона: Вертикальне дерево-ліс зліва + Деталі справа
	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(body_hbox)

	# Полотно графа досліджень
	var graph_panel := PanelContainer.new()
	graph_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var g_style := StyleBoxFlat.new()
	g_style.bg_color = Color(0.05, 0.07, 0.10, 0.95)
	g_style.border_color = Color(0.2, 0.3, 0.45, 0.7)
	g_style.set_border_width_all(2)
	g_style.set_corner_radius_all(10)
	graph_panel.add_theme_stylebox_override("panel", g_style)
	body_hbox.add_child(graph_panel)

	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_panel.add_child(_scroll_container)

	_graph_canvas = _create_graph_canvas()
	# Вертикальний розмір під дерево, що росте вниз (10 ярусів Y)
	_graph_canvas.custom_minimum_size = Vector2(850, 1850)
	_scroll_container.add_child(_graph_canvas)

	# Панель деталей технології праворуч
	_details_panel = PanelContainer.new()
	_details_panel.custom_minimum_size = Vector2(360, 0)
	_details_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var d_style := StyleBoxFlat.new()
	d_style.bg_color = Color(0.09, 0.12, 0.17, 0.98)
	d_style.border_color = Color(0.3, 0.45, 0.65, 0.8)
	d_style.set_border_width_all(2)
	d_style.set_corner_radius_all(10)
	d_style.set_content_margin_all(14.0)
	_details_panel.add_theme_stylebox_override("panel", d_style)
	body_hbox.add_child(_details_panel)

	_build_details_sidebar()


# ------------------------------------------------------------------------------
# Побудова вкладок епох та підепох
# ------------------------------------------------------------------------------
func _build_era_tabs() -> void:
	for c in _era_tab_bar.get_children():
		c.queue_free()

	for i in range(EraManager.ERA_NAMES.size()):
		var btn := Button.new()
		var is_active_era: bool = (EraManager.current_era == i)
		var is_current_tab: bool = (_current_view_era == i)
		var icon_sym: String = EraManager.ERA_ICONS[i] if i < EraManager.ERA_ICONS.size() else "🏛️"

		btn.text = "%s Епоха %d: %s" % [icon_sym, i, EraManager.ERA_NAMES[i]]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 36)
		btn.pressed.connect(func(idx=i): _select_era_tab(idx))

		if is_current_tab:
			btn.modulate = Color(1.2, 1.1, 0.7)
		elif is_active_era:
			btn.modulate = Color(0.7, 1.2, 0.8)
		else:
			btn.modulate = Color(0.7, 0.75, 0.85)

		_era_tab_bar.add_child(btn)


func _build_sub_era_tabs() -> void:
	for c in _sub_era_tab_bar.get_children():
		c.queue_free()

	var sub_eras: Array[Dictionary] = EraManager.get_sub_eras_for_era(_current_view_era)

	# Кнопка "Усі підепохи епохи"
	var all_btn := Button.new()
	all_btn.text = "🌳 Вся епоха (Усі гілки)"
	all_btn.custom_minimum_size = Vector2(0, 30)
	all_btn.pressed.connect(func(): _select_sub_era_tab(&""))
	if _current_view_sub_era == &"":
		all_btn.modulate = Color(1.2, 1.1, 0.7)
	_sub_era_tab_bar.add_child(all_btn)

	for sub in sub_eras:
		var sub_id: StringName = sub.id
		var sub_btn := Button.new()
		var is_unlocked: bool = EraManager.is_sub_era_unlocked(sub_id)
		var is_completed: bool = EraManager.is_sub_era_completed(sub_id)
		var is_selected: bool = (_current_view_sub_era == sub_id)

		var prefix: String = "✓ " if is_completed else ("🔓 " if is_unlocked else "🔒 ")
		sub_btn.text = "%s%s %s" % [prefix, sub.icon, sub.name]
		sub_btn.custom_minimum_size = Vector2(0, 30)
		sub_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sub_btn.pressed.connect(func(s_id=sub_id): _select_sub_era_tab(s_id))

		if is_selected:
			sub_btn.modulate = Color(1.2, 1.1, 0.7)
		elif is_completed:
			sub_btn.modulate = Color(0.5, 1.0, 0.7)
		elif is_unlocked:
			sub_btn.modulate = Color(1.0, 0.9, 0.6)
		else:
			sub_btn.modulate = Color(0.6, 0.6, 0.65)

		_sub_era_tab_bar.add_child(sub_btn)


func _select_era_tab(era_index: int) -> void:
	_current_view_era = era_index
	_current_view_sub_era = &""
	_build_era_tabs()
	_build_sub_era_tabs()
	_update_era_info()
	_populate_tech_graph()
	_scroll_to_era(era_index)


func _select_sub_era_tab(sub_era_id: StringName) -> void:
	_current_view_sub_era = sub_era_id
	_build_sub_era_tabs()
	_update_era_info()
	_populate_tech_graph()


func _update_era_info() -> void:
	if _era_title_label != null:
		var name_str: String = EraManager.ERA_NAMES[_current_view_era]
		_era_title_label.text = "🏛️ %s" % name_str

	if _sub_era_badge_label != null:
		if _current_view_sub_era != &"":
			var s := EraManager.get_sub_era_by_id(_current_view_sub_era)
			var unl: bool = EraManager.is_sub_era_unlocked(_current_view_sub_era)
			var comp: bool = EraManager.is_sub_era_completed(_current_view_sub_era)
			var stat_str := " (Завершено)" if comp else (" (Доступно)" if unl else " [🔒 Блоковано]")
			_sub_era_badge_label.text = "• %s %s%s" % [s.get("icon", ""), s.get("name", ""), stat_str]
			_sub_era_badge_label.modulate = Color(0.3, 1.0, 0.6) if comp else (Color("E9C46A") if unl else Color(0.8, 0.4, 0.4))
		else:
			_sub_era_badge_label.text = "• Поточна активна підепоха: %s" % EraManager.get_current_sub_era_name()
			_sub_era_badge_label.modulate = Color("2A9D8F")

	if _era_desc_label != null:
		if _current_view_sub_era != &"":
			var s := EraManager.get_sub_era_by_id(_current_view_sub_era)
			_era_desc_label.text = s.get("description", "")
		else:
			_era_desc_label.text = EraManager.ERA_DESCRIPTIONS[_current_view_era]

	if _progress_label != null:
		_progress_label.text = "Досліджено: %d / %d технологій (Поточна епоха: %s)" % [
			EraManager.get_unlocked_tech_count(),
			EraManager.get_total_tech_count(),
			EraManager.get_current_era_name()
		]


func _scroll_to_era(era_index: int) -> void:
	if _scroll_container == null:
		return
	# Позиція за вертикаллю Y (дерево росте згори донизу)
	var target_y: float = clampf(float(era_index) * 440.0 - 20.0, 0.0, 1850.0)
	var tween := create_tween()
	tween.tween_property(_scroll_container, "scroll_vertical", int(target_y), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------------------
# Граф технологій та малювання зв'язків дерева
# ------------------------------------------------------------------------------
func _create_graph_canvas() -> Control:
	var canvas := Control.new()
	canvas.name = "GraphCanvas"
	canvas.draw.connect(func(): _draw_tech_connections(canvas))
	return canvas


func _populate_tech_graph() -> void:
	for c in _graph_canvas.get_children():
		c.queue_free()
	_node_cards.clear()

	var all_techs: Array[Resource] = EraManager.get_all_techs()

	# Відцентрування стовбура та гілок:
	# grid_pos.x: 0.5 - стовбур (центр ~300px), 0.0 - ліва гілка (~120px), 1.0 - права гілка (~480px)
	# grid_pos.y: ярус зверху вниз (Y: 0..9)
	var base_x: float = 120.0
	var col_w: float = 340.0
	var base_y: float = 40.0
	var row_h: float = 175.0

	for tech in all_techs:
		# Якщо вибрана конкретна підепоха, напівпрозоро приглушуємо інші або виділяємо поточну
		var in_filter: bool = true
		if _current_view_sub_era != &"":
			in_filter = (tech.sub_era_id == _current_view_sub_era)

		var card := _create_node_card(tech, in_filter)
		var px: float = base_x + tech.grid_pos.x * col_w
		var py: float = base_y + tech.grid_pos.y * row_h
		card.position = Vector2(px, py)
		_graph_canvas.add_child(card)
		_node_cards[tech.id] = card

	_graph_canvas.queue_redraw()


func _create_node_card(tech: Resource, in_filter: bool = true) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Node_%s" % tech.id
	card.custom_minimum_size = Vector2(250, 115)

	var is_unlocked: bool = EraManager.is_tech_unlocked(tech.id)
	var can_res: bool = EraManager.can_research(tech.id, _player_inventory)
	var is_selected: bool = (_selected_tech_id == tech.id)
	var sub_unlocked: bool = EraManager.is_sub_era_unlocked(tech.sub_era_id)

	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)

	if is_unlocked:
		style.bg_color = COLOR_UNLOCKED
		style.border_color = Color("2A9D8F") if not is_selected else Color("E9C46A")
		style.set_border_width_all(3 if is_selected else 2)
	elif can_res:
		style.bg_color = COLOR_AVAILABLE
		style.border_color = Color("E9C46A")
		style.set_border_width_all(3 if is_selected else 2)
	else:
		style.bg_color = COLOR_LOCKED
		style.border_color = Color(0.35, 0.4, 0.48, 0.6) if not is_selected else Color("E9C46A")
		style.set_border_width_all(2)

	card.add_theme_stylebox_override("panel", style)

	if not in_filter:
		card.modulate = Color(0.5, 0.5, 0.6, 0.4)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	card.add_child(vbox)

	# Заголовок ноди: Іконка + Назва
	var top_h := HBoxContainer.new()
	top_h.add_theme_constant_override("separation", 8)
	vbox.add_child(top_h)

	var sym_lbl := Label.new()
	sym_lbl.text = tech.icon_symbol
	sym_lbl.add_theme_font_size_override("font_size", 22)
	top_h.add_child(sym_lbl)

	var title_lbl := Label.new()
	title_lbl.text = tech.display_name
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_unlocked:
		title_lbl.modulate = Color("A8DADC")
	elif can_res:
		title_lbl.modulate = Color("E9C46A")
	else:
		title_lbl.modulate = Color(0.7, 0.75, 0.8)
	top_h.add_child(title_lbl)

	# Назва підепохи
	var sub_info := EraManager.get_sub_era_by_id(tech.sub_era_id)
	var sub_lbl := Label.new()
	sub_lbl.text = "%s %s" % [sub_info.get("icon", "🌿"), sub_info.get("name", "")]
	sub_lbl.add_theme_font_size_override("font_size", 10)
	sub_lbl.modulate = Color(0.6, 0.8, 0.7)
	vbox.add_child(sub_lbl)

	# Статус бейдж
	var status_lbl := Label.new()
	status_lbl.add_theme_font_size_override("font_size", 11)
	if is_unlocked:
		status_lbl.text = "✓ ДОСЛІДЖЕНО"
		status_lbl.modulate = Color(0.3, 1.0, 0.6)
	elif not sub_unlocked:
		status_lbl.text = "🔒 БЛОКОВАНО ПІДЕПОХОЮ"
		status_lbl.modulate = Color(0.85, 0.45, 0.45)
	elif can_res:
		status_lbl.text = "★ ГОТОВО ДО ВИВЧЕННЯ"
		status_lbl.modulate = Color("E9C46A")
	else:
		status_lbl.text = "🔒 ЗАБЛОКОВАНО"
		status_lbl.modulate = Color(0.75, 0.5, 0.5)
	vbox.add_child(status_lbl)

	# Клік по картці для вибору
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_tech(tech.id)
	)

	return card


func _draw_tech_connections(canvas: Control) -> void:
	var all_techs: Array[Resource] = EraManager.get_all_techs()

	for tech in all_techs:
		if not _node_cards.has(tech.id):
			continue
		var to_card: Control = _node_cards[tech.id]
		# З'єднуємо зверху донизу (дерево від кореня):
		# from_pos: знизу батьківської ноди
		# to_pos: зверху дочірньої ноди
		var to_pos: Vector2 = to_card.position + Vector2(to_card.size.x * 0.5, 0.0)

		var is_child_unlocked: bool = EraManager.is_tech_unlocked(tech.id)

		for pre_id in tech.prerequisites:
			if not _node_cards.has(pre_id):
				continue
			var from_card: Control = _node_cards[pre_id]
			var from_pos: Vector2 = from_card.position + Vector2(from_card.size.x * 0.5, from_card.size.y)

			var is_parent_unlocked: bool = EraManager.is_tech_unlocked(pre_id)

			var line_col: Color = COLOR_LINE_LOCKED
			var line_width: float = 2.0

			if is_child_unlocked:
				line_col = COLOR_LINE_UNLOCKED
				line_width = 3.5
			elif is_parent_unlocked and EraManager.is_sub_era_unlocked(tech.sub_era_id):
				line_col = COLOR_LINE_AVAILABLE
				line_width = 2.5

			# Вертикальна крива Безьє дерева від батьківської гілки вниз до дочірнього листа
			var mid_y: float = (from_pos.y + to_pos.y) * 0.5
			var cp1 := Vector2(from_pos.x, mid_y)
			var cp2 := Vector2(to_pos.x, mid_y)

			var curve := Curve2D.new()
			curve.add_point(from_pos, Vector2.ZERO, cp1 - from_pos)
			curve.add_point(to_pos, cp2 - to_pos, Vector2.ZERO)
			var points := curve.tessellate(4, 2.0)
			if points.size() > 1:
				canvas.draw_polyline(points, line_col, line_width, true)

			# Маркер-листок на вході вузла
			canvas.draw_circle(to_pos, line_width * 1.5, line_col)


# ------------------------------------------------------------------------------
# Панель деталей (Sidebar)
# ------------------------------------------------------------------------------
func _build_details_sidebar() -> void:
	for c in _details_panel.get_children():
		c.queue_free()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_details_panel.add_child(vbox)

	# Заголовок та іконка
	var head_h := HBoxContainer.new()
	head_h.add_theme_constant_override("separation", 10)
	vbox.add_child(head_h)

	_detail_icon_label = Label.new()
	_detail_icon_label.text = "🏛️"
	_detail_icon_label.add_theme_font_size_override("font_size", 30)
	head_h.add_child(_detail_icon_label)

	var title_v := VBoxContainer.new()
	title_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_h.add_child(title_v)

	_detail_title_label = Label.new()
	_detail_title_label.text = "Оберіть дослідження"
	_detail_title_label.add_theme_font_size_override("font_size", 15)
	_detail_title_label.modulate = Color("E9C46A")
	_detail_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_v.add_child(_detail_title_label)

	_detail_era_label = Label.new()
	_detail_era_label.text = ""
	_detail_era_label.add_theme_font_size_override("font_size", 12)
	_detail_era_label.modulate = Color("2A9D8F")
	title_v.add_child(_detail_era_label)

	_detail_sub_era_label = Label.new()
	_detail_sub_era_label.text = ""
	_detail_sub_era_label.add_theme_font_size_override("font_size", 11)
	_detail_sub_era_label.modulate = Color("F4A261")
	title_v.add_child(_detail_sub_era_label)

	# Опис
	_detail_desc_label = Label.new()
	_detail_desc_label.text = "Натисніть на будь-який вузол технології у дереві, щоб переглянути вимоги, бонуси та розпочати вивчення."
	_detail_desc_label.add_theme_font_size_override("font_size", 12)
	_detail_desc_label.modulate = Color(0.8, 0.85, 0.9)
	_detail_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_detail_desc_label)

	var sep1 := HSeparator.new()
	vbox.add_child(sep1)

	# Секція "Що відкриває":
	var lbl_unl := Label.new()
	lbl_unl.text = "🔓 РОЗБЛОКОВУЄ:"
	lbl_unl.add_theme_font_size_override("font_size", 12)
	lbl_unl.modulate = Color("A8DADC")
	vbox.add_child(lbl_unl)

	_detail_unlocks_vbox = VBoxContainer.new()
	_detail_unlocks_vbox.add_theme_constant_override("separation", 3)
	vbox.add_child(_detail_unlocks_vbox)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	# Секція "Вартість дослідження":
	var lbl_cst := Label.new()
	lbl_cst.text = "📦 НЕОБХІДНІ МАТЕРІАЛИ:"
	lbl_cst.add_theme_font_size_override("font_size", 12)
	lbl_cst.modulate = Color("F4A261")
	vbox.add_child(lbl_cst)

	_detail_cost_vbox = VBoxContainer.new()
	_detail_cost_vbox.add_theme_constant_override("separation", 5)
	vbox.add_child(_detail_cost_vbox)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Велика кнопка "ДОСЛІДИТИ"
	_btn_research = Button.new()
	_btn_research.text = "ДОСЛІДИТИ ТЕХНОЛОГІЮ"
	_btn_research.custom_minimum_size = Vector2(0, 48)
	_btn_research.disabled = true
	_btn_research.pressed.connect(_on_research_pressed)
	vbox.add_child(_btn_research)


func _select_tech(tech_id: StringName) -> void:
	_selected_tech_id = tech_id
	_refresh_details()
	_populate_tech_graph()


func _refresh_details() -> void:
	if _selected_tech_id == &"" or EraManager == null:
		return

	var tech: Resource = EraManager.get_tech(_selected_tech_id)
	if tech == null:
		return

	_detail_icon_label.text = tech.icon_symbol
	_detail_title_label.text = tech.display_name
	var era_name: String = EraManager.ERA_NAMES[tech.era_index] if tech.era_index < EraManager.ERA_NAMES.size() else "Епоха"
	_detail_era_label.text = "Епоха %d: %s" % [tech.era_index, era_name]

	var sub_info := EraManager.get_sub_era_by_id(tech.sub_era_id)
	var sub_unl: bool = EraManager.is_sub_era_unlocked(tech.sub_era_id)
	var sub_comp: bool = EraManager.is_sub_era_completed(tech.sub_era_id)
	var sub_state: String = " (Завершено)" if sub_comp else (" (Активна)" if sub_unl else " [🔒 Заблоковано]")
	_detail_sub_era_label.text = "Підепоха: %s %s%s" % [sub_info.get("icon", "🌿"), sub_info.get("name", ""), sub_state]
	_detail_sub_era_label.modulate = Color(0.3, 1.0, 0.6) if sub_comp else (Color("E9C46A") if sub_unl else Color(0.85, 0.45, 0.45))

	_detail_desc_label.text = tech.description

	# Очищення секції розблокувань
	for c in _detail_unlocks_vbox.get_children():
		c.queue_free()

	for r_id in tech.unlocks_recipes:
		var r = CraftingManager.get_recipe(r_id) if CraftingManager != null else null
		var r_name = r.get("display_name") if r != null else String(r_id)
		var l := Label.new()
		l.text = " • Рецепт: %s" % r_name
		l.add_theme_font_size_override("font_size", 11)
		l.modulate = Color(0.7, 0.9, 1.0)
		_detail_unlocks_vbox.add_child(l)

	for b_id in tech.unlocks_buildings:
		var b = BuildingPlacementController.get_building(b_id) if BuildingPlacementController != null else null
		var b_name = b.display_name if b != null else String(b_id)
		var l := Label.new()
		l.text = " • Споруда: %s" % b_name
		l.add_theme_font_size_override("font_size", 11)
		l.modulate = Color(0.9, 0.8, 0.6)
		_detail_unlocks_vbox.add_child(l)

	for feat in tech.unlock_features:
		var l := Label.new()
		l.text = " • %s" % feat
		l.add_theme_font_size_override("font_size", 11)
		l.modulate = Color(0.6, 1.0, 0.8)
		_detail_unlocks_vbox.add_child(l)

	if tech.unlocks_recipes.is_empty() and tech.unlocks_buildings.is_empty() and tech.unlock_features.is_empty():
		var l := Label.new()
		l.text = " • Відкриває доступ до наступного щабля прогресу."
		l.add_theme_font_size_override("font_size", 11)
		_detail_unlocks_vbox.add_child(l)

	# Очищення секції вартості
	for c in _detail_cost_vbox.get_children():
		c.queue_free()

	var is_unlocked: bool = EraManager.is_tech_unlocked(tech.id)
	var prereqs_met: bool = EraManager.is_prerequisites_met(tech.id)
	var has_all_mats: bool = true

	if tech.cost.is_empty():
		var l := Label.new()
		l.text = "✓ Безкоштовне базове дослідження"
		l.add_theme_font_size_override("font_size", 11)
		l.modulate = Color(0.4, 1.0, 0.5)
		_detail_cost_vbox.add_child(l)
	else:
		for item_id in tech.cost.keys():
			var req: int = tech.cost[item_id]
			var cur: int = _player_inventory.get_item_count(item_id) if _player_inventory != null else 0
			var has_mat: bool = cur >= req
			if not has_mat:
				has_all_mats = false

			var item_res = ItemDatabase.get_item(item_id)
			var item_name: String = item_res.display_name if item_res != null else String(item_id)

			var cost_lbl := Label.new()
			cost_lbl.text = "%s %s: %d / %d" % ["✓" if has_mat else "✗", item_name, cur, req]
			cost_lbl.add_theme_font_size_override("font_size", 11)
			cost_lbl.modulate = Color(0.4, 1.0, 0.5) if has_mat else Color(1.0, 0.4, 0.4)
			_detail_cost_vbox.add_child(cost_lbl)

	# Кнопка дослідження
	if is_unlocked:
		_btn_research.text = "✓ ДОСЛІДЖЕНО"
		_btn_research.disabled = true
		_btn_research.modulate = Color(0.5, 0.9, 0.6)
	elif not sub_unl:
		_btn_research.text = "🔒 ЗАБЛОКОВАНО ПІДЕПОХОЮ"
		_btn_research.disabled = true
		_btn_research.modulate = Color(0.85, 0.45, 0.45)
	elif not prereqs_met:
		_btn_research.text = "🔒 ПОТРІБНІ ПОПЕРЕДНІ ТЕХНОЛОГІЇ"
		_btn_research.disabled = true
		_btn_research.modulate = Color(0.8, 0.5, 0.4)
	elif not has_all_mats:
		_btn_research.text = "НЕДОСТАТНЬО МАТЕРІАЛІВ"
		_btn_research.disabled = true
		_btn_research.modulate = Color(0.9, 0.6, 0.3)
	else:
		_btn_research.text = "✨ ДОСЛІДИТИ ТЕХНОЛОГІЮ"
		_btn_research.disabled = false
		_btn_research.modulate = Color(1.2, 1.0, 0.5)


func _on_research_pressed() -> void:
	if _selected_tech_id == &"" or EraManager == null:
		return
	if EraManager.research_tech(_selected_tech_id, _player_inventory):
		_refresh_all()


# ------------------------------------------------------------------------------
# Відкриття / Закриття
# ------------------------------------------------------------------------------
func open() -> void:
	_is_open = true
	visible = true
	_connect_player()
	_current_view_era = EraManager.current_era if EraManager != null else 0
	_current_view_sub_era = &""
	_build_era_tabs()
	_build_sub_era_tabs()
	_update_era_info()
	if _selected_tech_id == &"":
		_selected_tech_id = &"primitive_survival"
	_populate_tech_graph()
	_refresh_details()
	_scroll_to_era(_current_view_era)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	_is_open = false
	visible = false
	if GameManager.current_state == GameManager.GameState.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	tree_closed.emit()


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func _on_tech_tree_updated() -> void:
	if _is_open:
		_refresh_all()


func _on_era_changed(_new_era: int, _era_name: String) -> void:
	if _is_open:
		_current_view_era = _new_era
		_refresh_all()


func _on_sub_era_changed(_new_sub: StringName, _name: String) -> void:
	if _is_open:
		_refresh_all()


func _refresh_all() -> void:
	_build_era_tabs()
	_build_sub_era_tabs()
	_update_era_info()
	_populate_tech_graph()
	_refresh_details()
