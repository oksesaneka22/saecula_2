class_name ColonyRosterUI
extends Control

## ColonyRosterUI: Компактна міні-панель списку поселенців колонії (Colony Roster).
## Відображає перелік усіх жителів поселення, їхні імена, професії з кольоровими бейджами,
## поточну виконувану дію (робота, сон біля вогнища, слідування),
## а також надає кнопки швидкого наказу слідування, виклику діалогу та фокусу камери.

var _is_collapsed: bool = false
var _refresh_timer: float = 0.0

var _panel_container: PanelContainer = null
var _title_label: Label = null
var _collapse_btn: Button = null
var _scroll_container: ScrollContainer = null
var _list_vbox: VBoxContainer = null
var _empty_label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()

	if EventBus != null:
		if EventBus.has_signal("colonist_spawned"):
			EventBus.colonist_spawned.connect(_on_colonists_changed)
		if EventBus.has_signal("colonist_died"):
			EventBus.colonist_died.connect(_on_colonist_died)
		if EventBus.has_signal("colonist_profession_changed"):
			EventBus.colonist_profession_changed.connect(_on_colonists_changed)
		if EventBus.has_signal("colonist_roster_toggle_requested"):
			EventBus.colonist_roster_toggle_requested.connect(toggle_roster)

	_refresh_roster()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_K:
			toggle_roster()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _is_collapsed:
		return
	_refresh_timer += delta
	if _refresh_timer >= 0.5:
		_refresh_timer = 0.0
		_update_active_statuses()


func toggle_roster() -> void:
	set_collapsed(not _is_collapsed)


func set_collapsed(collapsed: bool) -> void:
	_is_collapsed = collapsed
	if _scroll_container != null:
		_scroll_container.visible = not _is_collapsed
	if _collapse_btn != null:
		_collapse_btn.text = "▼" if _is_collapsed else "▲"
	if not _is_collapsed:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh_roster()
	else:
		var player = get_tree().get_first_node_in_group("player")
		var is_modal: bool = player.has_method("is_any_modal_open") and player.is_any_modal_open() if player != null else false
		if not is_modal:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func is_collapsed() -> bool:
	return _is_collapsed


func _on_colonists_changed(_arg1 = null, _arg2 = null) -> void:
	_refresh_roster()


func _on_colonist_died(_col = null, _cause = "") -> void:
	_refresh_roster()


func _build_ui() -> void:
	# Розташування у лівому верхньому кутку, під індикатором режиму
	anchor_left = 0.0
	anchor_top = 0.0
	offset_left = 16.0
	offset_top = 70.0
	offset_right = 296.0
	offset_bottom = 360.0

	_panel_container = PanelContainer.new()
	_panel_container.name = "RosterPanel"
	_panel_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel_container.custom_minimum_size = Vector2(280.0, 0.0)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.1, 0.12, 0.88)
	panel_style.border_color = Color(0.35, 0.45, 0.55, 0.6)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.corner_radius_bottom_left = 6
	_panel_container.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel_container)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	_panel_container.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(root_vbox)

	# --- Заголовок з кнопкою згортання ---
	var header_hbox := HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 6)
	root_vbox.add_child(header_hbox)

	var icon_lbl := Label.new()
	icon_lbl.text = "👥"
	icon_lbl.add_theme_font_size_override("font_size", 14)
	header_hbox.add_child(icon_lbl)

	_title_label = Label.new()
	_title_label.text = "Поселенці (0)"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 13)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	header_hbox.add_child(_title_label)

	_collapse_btn = Button.new()
	_collapse_btn.text = "▲"
	_collapse_btn.flat = true
	_collapse_btn.focus_mode = Control.FOCUS_NONE
	_collapse_btn.tooltip_text = "Згорнути / розгорнути панель (Клавіша K)"
	_collapse_btn.pressed.connect(toggle_roster)
	header_hbox.add_child(_collapse_btn)

	# --- Область списку поселенців з фіксованою робочою висотою для скролу ---
	_scroll_container = ScrollContainer.new()
	_scroll_container.name = "RosterScroll"
	_scroll_container.custom_minimum_size = Vector2(264.0, 190.0)
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_scroll_container)

	_list_vbox = VBoxContainer.new()
	_list_vbox.name = "ColonistList"
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", 4)
	_scroll_container.add_child(_list_vbox)

	_empty_label = Label.new()
	_empty_label.text = "(Поселенців поки немає)"
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.add_theme_font_size_override("font_size", 11)
	_empty_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	_list_vbox.add_child(_empty_label)


func _refresh_roster() -> void:
	if _list_vbox == null or _title_label == null:
		return

	# Очищення старих карток
	for child in _list_vbox.get_children():
		_list_vbox.remove_child(child)
		child.queue_free()

	var colonists: Array[Node] = []
	if JobManager != null:
		colonists = JobManager.get_all_colonists()
	else:
		colonists = get_tree().get_nodes_in_group("colonists")

	_title_label.text = "Поселенці (%d)" % colonists.size()

	if colonists.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "(Поселенців поки немає)"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
		_list_vbox.add_child(empty_lbl)
		return

	# Додавання карток для кожного поселенця
	for col in colonists:
		if not is_instance_valid(col) or col.is_queued_for_deletion():
			continue
		var card = _create_colonist_card(col)
		_list_vbox.add_child(card)


func _create_colonist_card(colonist: Node) -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "Card_" + colonist.name
	card.set_meta("colonist_node", colonist)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.custom_minimum_size = Vector2(248.0, 44.0)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.15, 0.18, 0.85)
	card_style.border_color = Color(0.25, 0.32, 0.4, 0.5)
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.corner_radius_top_left = 4
	card_style.corner_radius_top_right = 4
	card_style.corner_radius_bottom_right = 4
	card_style.corner_radius_bottom_left = 4
	card.add_theme_stylebox_override("panel", card_style)

	var c_margin := MarginContainer.new()
	c_margin.add_theme_constant_override("margin_left", 6)
	c_margin.add_theme_constant_override("margin_top", 4)
	c_margin.add_theme_constant_override("margin_right", 6)
	c_margin.add_theme_constant_override("margin_bottom", 4)
	card.add_child(c_margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	c_margin.add_child(hbox)

	# Ліва колонка: Ім'я, професія та поточний статус
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 1)
	hbox.add_child(info_vbox)

	var top_line := HBoxContainer.new()
	top_line.add_theme_constant_override("separation", 4)
	info_vbox.add_child(top_line)

	var c_name: String = colonist.get("colonist_name") if colonist.get("colonist_name") != null and not str(colonist.get("colonist_name")).is_empty() else colonist.name
	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.text = c_name
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	top_line.add_child(name_lbl)

	var is_following: bool = colonist.get("is_following_player") == true
	var follow_lbl := Label.new()
	follow_lbl.name = "FollowIcon"
	follow_lbl.text = "🐾"
	follow_lbl.visible = is_following
	follow_lbl.add_theme_font_size_override("font_size", 10)
	top_line.add_child(follow_lbl)

	var prof_name: String = colonist.call("get_profession_name") if colonist.has_method("get_profession_name") else "Робітник"
	var prof_icon := "👤"
	var prof_val = colonist.get("profession")
	if prof_val == &"builder": prof_icon = "🔨"
	elif prof_val == &"lumberjack": prof_icon = "🪓"
	elif prof_val == &"hauler": prof_icon = "📦"
	elif prof_val == &"settler": prof_icon = "🌾"

	var prof_badge := Label.new()
	prof_badge.name = "ProfBadge"
	prof_badge.text = "[%s %s]" % [prof_icon, prof_name]
	prof_badge.add_theme_font_size_override("font_size", 10)
	prof_badge.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
	top_line.add_child(prof_badge)

	# Рядок статусу завдання
	var status_text: String = ""
	if colonist.has_method("get_status_text") and colonist.get_status_text() != "":
		status_text = colonist.get_status_text()
	elif colonist.get("_status_text") != null and str(colonist.get("_status_text")) != "":
		status_text = str(colonist.get("_status_text"))
	else:
		status_text = "☕ Вільний"
	var status_lbl := Label.new()
	status_lbl.name = "StatusLabel"
	status_lbl.text = status_text
	status_lbl.add_theme_font_size_override("font_size", 10)
	status_lbl.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
	info_vbox.add_child(status_lbl)

	# Права колонка кнопок швидких дій
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 2)
	hbox.add_child(btn_hbox)

	# Кнопка слідування
	var btn_follow := Button.new()
	btn_follow.name = "BtnFollow"
	btn_follow.text = "⏹️" if is_following else "🐾"
	btn_follow.custom_minimum_size = Vector2(26.0, 24.0)
	btn_follow.focus_mode = Control.FOCUS_NONE
	btn_follow.tooltip_text = "Зупинити слідування" if is_following else "Наказати слідувати за гравцем"
	btn_follow.pressed.connect(_on_follow_pressed.bind(colonist, btn_follow, follow_lbl))
	btn_hbox.add_child(btn_follow)

	# Кнопка відкриття діалогу та обміну
	var btn_dialog := Button.new()
	btn_dialog.name = "BtnDialog"
	btn_dialog.text = "💬"
	btn_dialog.custom_minimum_size = Vector2(26.0, 24.0)
	btn_dialog.focus_mode = Control.FOCUS_NONE
	btn_dialog.tooltip_text = "Відкрити картку та інвентар поселенця (E)"
	btn_dialog.pressed.connect(_on_dialog_pressed.bind(colonist))
	btn_hbox.add_child(btn_dialog)

	# Кнопка фокусування у світі
	var btn_focus := Button.new()
	btn_focus.name = "BtnFocus"
	btn_focus.text = "🎯"
	btn_focus.custom_minimum_size = Vector2(26.0, 24.0)
	btn_focus.focus_mode = Control.FOCUS_NONE
	btn_focus.tooltip_text = "Знайти та показати поселенця у світі"
	btn_focus.pressed.connect(_on_focus_pressed.bind(colonist))
	btn_hbox.add_child(btn_focus)

	return card


func _update_active_statuses() -> void:
	if _list_vbox == null:
		return
	var needs_refresh: bool = false
	for card in _list_vbox.get_children():
		if not is_instance_valid(card) or not card.has_meta("colonist_node"):
			continue
		var col_raw = card.get_meta("colonist_node")
		if not is_instance_valid(col_raw) or (col_raw is Node and (col_raw as Node).is_queued_for_deletion()):
			needs_refresh = true
			continue

		var col: Object = col_raw
		var status_lbl := card.find_child("StatusLabel", true, false) as Label
		if status_lbl != null:
			var st_val: String = ""
			if col.has_method("get_status_text") and col.get_status_text() != "":
				st_val = col.get_status_text()
			elif col.get("_status_text") != null and str(col.get("_status_text")) != "":
				st_val = str(col.get("_status_text"))
			else:
				st_val = "☕ Вільний"
			status_lbl.text = st_val

		var follow_lbl := card.find_child("FollowIcon", true, false) as Label
		var btn_follow := card.find_child("BtnFollow", true, false) as Button
		var is_fol: bool = col.get("is_following_player") == true
		if follow_lbl != null:
			follow_lbl.visible = is_fol
		if btn_follow != null:
			btn_follow.text = "⏹️" if is_fol else "🐾"
			btn_follow.tooltip_text = "Зупинити слідування" if is_fol else "Наказати слідувати за гравцем"

	if needs_refresh:
		_refresh_roster()


func _on_follow_pressed(colonist: Node, btn: Button, follow_icon: Label) -> void:
	if not is_instance_valid(colonist) or colonist.is_queued_for_deletion():
		_refresh_roster()
		return
	if colonist.get("is_following_player") == true:
		if colonist.has_method("order_stop_follow"):
			colonist.order_stop_follow()
		btn.text = "🐾"
		btn.tooltip_text = "Наказати слідувати за гравцем"
		follow_icon.visible = false
		if FloatingTextManager != null and colonist is Node3D:
			FloatingTextManager.spawn_info((colonist as Node3D).global_position + Vector3(0, 2.0, 0), "⏹️ Залишається тут")
	else:
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player != null and colonist.has_method("order_follow"):
			colonist.order_follow(player)
			btn.text = "⏹️"
			btn.tooltip_text = "Зупинити слідування"
			follow_icon.visible = true
			if FloatingTextManager != null and colonist is Node3D:
				FloatingTextManager.spawn_info((colonist as Node3D).global_position + Vector3(0, 2.0, 0), "🐾 Слідує за вами")


func _on_dialog_pressed(colonist: Node) -> void:
	if not is_instance_valid(colonist) or colonist.is_queued_for_deletion():
		_refresh_roster()
		return
	if EventBus != null and EventBus.has_signal("colonist_dialog_requested"):
		EventBus.colonist_dialog_requested.emit(colonist)


func _on_focus_pressed(colonist: Node) -> void:
	if not is_instance_valid(colonist) or colonist.is_queued_for_deletion() or not (colonist is Node3D):
		_refresh_roster()
		return
	var col_3d := colonist as Node3D
	var c_name: String = colonist.get("colonist_name") if colonist.get("colonist_name") != null and not str(colonist.get("colonist_name")).is_empty() else colonist.name

	# Візуальний маяк над поселенцем
	if FloatingTextManager != null:
		FloatingTextManager.spawn_text(col_3d.global_position + Vector3(0, 2.2, 0), "📍 " + c_name, Color.CYAN, 2.0, 0.8)

	# Орієнтація гравця в напрямку поселенця
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		var dir := (col_3d.global_position - player.global_position)
		var dist := dir.length()
		if FloatingTextManager != null:
			FloatingTextManager.spawn_info(player.global_position + Vector3(0, 2.0, 0), "📍 %s (%.1f м)" % [c_name, dist])

	if AudioManager != null:
		AudioManager.play_sound(&"step", -3.0, 1.2)
