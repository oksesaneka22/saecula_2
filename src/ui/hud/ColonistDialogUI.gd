class_name ColonistDialogUI
extends Control

## ColonistDialogUI: Інтерфейс живої взаємодії з поселенцем Saecula.
## Відкривається при натисканні E на поселенця або виклику EventBus.colonist_dialog_requested.
## Містить:
## - Панель інформації (Ім'я, Професія, Поточна дія)
## - Кнопки швидких наказів: "Слідувати за мною" / "Зупинитися"
## - Вибір фаху (Будівельник, Лісоруб, Вантажник, Поселенець)
## - Двосторонній обмін інвентарем (Інвентар гравця 24 слоти <-> Інвентар поселенця 8 слотів)
## - Кнопки "Передати все" / "Забрати все"

const ItemSlotUIScript = preload("res://src/ui/hud/ItemSlotUI.gd")

var _target_colonist: CharacterBody3D = null
var _colonist_inventory: Node = null
var _player_inventory: Node = null

var _player_slots: Array[Control] = []
var _colonist_slots: Array[Control] = []

var _opened_at_msec: int = 0
var _hp_label: Label = null
var _name_label: Label = null
var _status_label: Label = null
var _follow_btn: Button = null
var _prof_option_btn: OptionButton = null

var _player_capacity_label: Label = null
var _colonist_capacity_label: Label = null
var _player_grid: GridContainer = null
var _colonist_grid: GridContainer = null


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_ui_layout()

	EventBus.colonist_dialog_requested.connect(open_dialog)
	EventBus.inventory_window_toggle_requested.connect(_on_inventory_toggle_requested)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		close_dialog()
		get_viewport().set_input_as_handled()


func _on_inventory_toggle_requested() -> void:
	if visible:
		close_dialog()


func _build_ui_layout() -> void:
	# 1. Затемнення фону
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if Time.get_ticks_msec() - _opened_at_msec > 180:
				close_dialog()
	)
	add_child(backdrop)

	# 2. Центральне вікно
	var center := CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)

	var main_panel := PanelContainer.new()
	main_panel.name = "MainPanel"
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.09, 0.11, 0.14, 0.96)
	panel_style.border_color = Color(0.35, 0.45, 0.55, 0.85)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(20.0)
	main_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(main_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 14)
	main_panel.add_child(root_vbox)

	# 3. Верхній заголовок та кнопка закриття
	var header_hbox := HBoxContainer.new()
	root_vbox.add_child(header_hbox)

	_name_label = Label.new()
	_name_label.text = "👤 Поселенець"
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	header_hbox.add_child(_name_label)

	_hp_label = Label.new()
	_hp_label.text = "❤️ 100/100 HP"
	_hp_label.add_theme_font_size_override("font_size", 14)
	_hp_label.add_theme_color_override("font_color", Color(0.9, 0.35, 0.35))
	header_hbox.add_child(_hp_label)

	var close_btn := Button.new()
	close_btn.text = " ✕ "
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close_dialog)
	header_hbox.add_child(close_btn)

	# 4. Рядок статусу та швидких наказів
	var status_panel := PanelContainer.new()
	var sp_style := StyleBoxFlat.new()
	sp_style.bg_color = Color(0.14, 0.17, 0.22, 0.8)
	sp_style.set_border_width_all(1)
	sp_style.border_color = Color(0.25, 0.35, 0.45, 0.7)
	sp_style.set_corner_radius_all(6)
	sp_style.set_content_margin_all(10.0)
	status_panel.add_theme_stylebox_override("panel", sp_style)
	root_vbox.add_child(status_panel)

	var status_hbox := HBoxContainer.new()
	status_hbox.add_theme_constant_override("separation", 16)
	status_panel.add_child(status_hbox)

	var status_col := VBoxContainer.new()
	status_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_hbox.add_child(status_col)

	var st_title := Label.new()
	st_title.text = "Поточна діяльність:"
	st_title.add_theme_font_size_override("font_size", 12)
	st_title.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	status_col.add_child(st_title)

	_status_label = Label.new()
	_status_label.text = "Очікує завдань колонії"
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	status_col.add_child(_status_label)

	# Вибір професії
	var prof_col := VBoxContainer.new()
	status_hbox.add_child(prof_col)

	var prof_title := Label.new()
	prof_title.text = "Фах робітника:"
	prof_title.add_theme_font_size_override("font_size", 12)
	prof_title.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	prof_col.add_child(prof_title)

	_prof_option_btn = OptionButton.new()
	_prof_option_btn.focus_mode = Control.FOCUS_NONE
	_prof_option_btn.add_item("🌾 Поселенець (Універсал)", 0)
	_prof_option_btn.add_item("🔨 Будівельник", 1)
	_prof_option_btn.add_item("🪓 Лісоруб", 2)
	_prof_option_btn.add_item("📦 Вантажник", 3)
	_prof_option_btn.item_selected.connect(_on_profession_selected)
	prof_col.add_child(_prof_option_btn)

	# Кнопка слідування
	_follow_btn = Button.new()
	_follow_btn.custom_minimum_size = Vector2(140, 36)
	_follow_btn.focus_mode = Control.FOCUS_NONE
	_follow_btn.text = "🐾 Слідувати за мною"
	_follow_btn.pressed.connect(_on_toggle_follow_pressed)
	status_hbox.add_child(_follow_btn)

	# 5. Двоколонковий блок інвентарів: Гравець (зліва) та Поселенець (справа)
	var columns_hbox := HBoxContainer.new()
	columns_hbox.add_theme_constant_override("separation", 20)
	root_vbox.add_child(columns_hbox)

	# --- ЛІВА КОЛОНКА: Інвентар гравця ---
	var player_vbox := VBoxContainer.new()
	player_vbox.add_theme_constant_override("separation", 8)
	columns_hbox.add_child(player_vbox)

	var p_hdr := HBoxContainer.new()
	player_vbox.add_child(p_hdr)

	var p_title := Label.new()
	p_title.text = "🎒 Інвентар гравця"
	p_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p_title.add_theme_font_size_override("font_size", 14)
	p_title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	p_hdr.add_child(p_title)

	_player_capacity_label = Label.new()
	_player_capacity_label.text = "0/24"
	_player_capacity_label.add_theme_font_size_override("font_size", 12)
	_player_capacity_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	p_hdr.add_child(_player_capacity_label)

	_player_grid = GridContainer.new()
	_player_grid.columns = 6
	_player_grid.add_theme_constant_override("h_separation", 6)
	_player_grid.add_theme_constant_override("v_separation", 6)
	player_vbox.add_child(_player_grid)

	var give_all_btn := Button.new()
	give_all_btn.text = "➡ Передати все поселенцю"
	give_all_btn.focus_mode = Control.FOCUS_NONE
	give_all_btn.pressed.connect(_on_give_all_pressed)
	player_vbox.add_child(give_all_btn)

	# Розділювач
	var v_sep := VSeparator.new()
	columns_hbox.add_child(v_sep)

	# --- ПРАВА КОЛОНКА: Інвентар поселенця (8 слотів) ---
	var col_vbox := VBoxContainer.new()
	col_vbox.add_theme_constant_override("separation", 8)
	columns_hbox.add_child(col_vbox)

	var c_hdr := HBoxContainer.new()
	col_vbox.add_child(c_hdr)

	var c_title := Label.new()
	c_title.text = "👝 Речі поселенця"
	c_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c_title.add_theme_font_size_override("font_size", 14)
	c_title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	c_hdr.add_child(c_title)

	_colonist_capacity_label = Label.new()
	_colonist_capacity_label.text = "0/8"
	_colonist_capacity_label.add_theme_font_size_override("font_size", 12)
	_colonist_capacity_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	c_hdr.add_child(_colonist_capacity_label)

	_colonist_grid = GridContainer.new()
	_colonist_grid.columns = 4
	_colonist_grid.add_theme_constant_override("h_separation", 6)
	_colonist_grid.add_theme_constant_override("v_separation", 6)
	col_vbox.add_child(_colonist_grid)

	var take_all_btn := Button.new()
	take_all_btn.text = "⬅ Забрати все собі"
	take_all_btn.focus_mode = Control.FOCUS_NONE
	take_all_btn.pressed.connect(_on_take_all_pressed)
	col_vbox.add_child(take_all_btn)

	# Створюємо 24 слоти гравця
	_player_slots.clear()
	for i in range(24):
		var slot_ui: Control = ItemSlotUIScript.new()
		slot_ui.name = "PlayerSlot_%d" % i
		slot_ui.set("slot_index", i)
		if slot_ui.has_signal("slot_clicked"):
			slot_ui.slot_clicked.connect(_on_player_slot_clicked)
		_player_grid.add_child(slot_ui)
		_player_slots.append(slot_ui)

	# Створюємо 8 слотів колоніста
	_colonist_slots.clear()
	for i in range(8):
		var slot_ui: Control = ItemSlotUIScript.new()
		slot_ui.name = "ColonistSlot_%d" % i
		slot_ui.set("slot_index", i)
		if slot_ui.has_signal("slot_clicked"):
			slot_ui.slot_clicked.connect(_on_colonist_slot_clicked)
		_colonist_grid.add_child(slot_ui)
		_colonist_slots.append(slot_ui)


func open_dialog(colonist_node: Node) -> void:
	if colonist_node == null:
		return

	_target_colonist = colonist_node as CharacterBody3D
	_colonist_inventory = _target_colonist.get("inventory") if _target_colonist != null else null
	_find_player_inventory()

	if _colonist_inventory == null:
		print("[ColonistDialogUI] Помилка: поселенець не має InventoryComponent")
		return

	if not _colonist_inventory.inventory_updated.is_connected(refresh_ui):
		_colonist_inventory.inventory_updated.connect(refresh_ui)
	if _player_inventory != null and not _player_inventory.inventory_updated.is_connected(refresh_ui):
		_player_inventory.inventory_updated.connect(refresh_ui)

	_opened_at_msec = Time.get_ticks_msec()
	_update_colonist_info()

	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh_ui()


func close_dialog() -> void:
	if not visible:
		return

	visible = false

	if _colonist_inventory != null and _colonist_inventory.inventory_updated.is_connected(refresh_ui):
		_colonist_inventory.inventory_updated.disconnect(refresh_ui)
	if _player_inventory != null and _player_inventory.inventory_updated.is_connected(refresh_ui):
		_player_inventory.inventory_updated.disconnect(refresh_ui)

	_target_colonist = null
	_colonist_inventory = null

	var player_3d = get_tree().get_first_node_in_group("player")
	if player_3d != null and player_3d.has_method("is_active") and player_3d.is_active():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if EventBus != null and EventBus.has_signal("colonist_dialog_closed"):
		EventBus.colonist_dialog_closed.emit()


func _update_colonist_info() -> void:
	if _target_colonist == null:
		return

	var c_name: String = _target_colonist.colonist_name if "colonist_name" in _target_colonist else "Поселенець"
	var c_prof: String = _target_colonist.get_profession_name() if _target_colonist.has_method("get_profession_name") else ""
	_name_label.text = "👤 %s [%s]" % [c_name, c_prof]

	var cur_status: String = ""
	if _target_colonist.has_method("get_status_text") and _target_colonist.get_status_text() != "":
		cur_status = _target_colonist.get_status_text()
	elif "_status_text" in _target_colonist and _target_colonist._status_text != "":
		cur_status = _target_colonist._status_text
	else:
		cur_status = "Вільний"
	_status_label.text = cur_status

	if _hp_label != null:
		var cur_hp: int = int(_target_colonist.get("current_health")) if "current_health" in _target_colonist else 100
		var max_hp: int = int(_target_colonist.get("max_health")) if "max_health" in _target_colonist else 100
		_hp_label.text = "❤️ %d/%d HP" % [cur_hp, max_hp]

	# Вибір поточного індексу професії
	var p_code: StringName = _target_colonist.profession if "profession" in _target_colonist else &"settler"
	match p_code:
		&"settler":
			_prof_option_btn.select(0)
		&"builder":
			_prof_option_btn.select(1)
		&"lumberjack":
			_prof_option_btn.select(2)
		&"hauler":
			_prof_option_btn.select(3)
		_:
			_prof_option_btn.select(0)

	# Стан кнопки слідування
	var is_following: bool = _target_colonist.is_following_player if "is_following_player" in _target_colonist else false
	if is_following:
		_follow_btn.text = "🛑 Зупинити слідування"
		_follow_btn.modulate = Color(1.0, 0.6, 0.6)
	else:
		_follow_btn.text = "🐾 Слідувати за мною"
		_follow_btn.modulate = Color(0.6, 1.0, 0.7)


func _on_profession_selected(index: int) -> void:
	if _target_colonist == null:
		return
	var prof_ids: Array[StringName] = [&"settler", &"builder", &"lumberjack", &"hauler"]
	if index >= 0 and index < prof_ids.size():
		var chosen_prof: StringName = prof_ids[index]
		if _target_colonist.has_method("set_profession"):
			_target_colonist.set_profession(chosen_prof)
		_update_colonist_info()


func _on_toggle_follow_pressed() -> void:
	if _target_colonist == null:
		return

	var player = get_tree().get_first_node_in_group("player") as Node3D
	var is_following: bool = _target_colonist.is_following_player if "is_following_player" in _target_colonist else false

	if is_following:
		if _target_colonist.has_method("order_stop_follow"):
			_target_colonist.order_stop_follow()
	else:
		if player != null and _target_colonist.has_method("order_follow"):
			_target_colonist.order_follow(player)

	_update_colonist_info()


func refresh_ui() -> void:
	_update_colonist_info()

	# Оновлення слотів гравця
	if _player_inventory != null:
		var p_items: Array = _player_inventory.get_all_items()
		var p_used: int = 0
		for i in range(_player_slots.size()):
			var slot_ui: Control = _player_slots[i]
			if i < p_items.size():
				var s = p_items[i]
				slot_ui.set_slot_data(s.item, s.count)
				if s.item != null and s.count > 0:
					p_used += 1
			else:
				slot_ui.set_slot_data(null, 0)
		_player_capacity_label.text = "%d/%d" % [p_used, _player_inventory.slot_count]

	# Оновлення слотів поселенця
	if _colonist_inventory != null:
		var c_items: Array = _colonist_inventory.get_all_items()
		var c_used: int = 0
		for i in range(_colonist_slots.size()):
			var slot_ui: Control = _colonist_slots[i]
			if i < c_items.size():
				var s = c_items[i]
				slot_ui.set_slot_data(s.item, s.count)
				if s.item != null and s.count > 0:
					c_used += 1
			else:
				slot_ui.set_slot_data(null, 0)
		_colonist_capacity_label.text = "%d/%d" % [c_used, _colonist_inventory.slot_count]


func _on_player_slot_clicked(slot_index: int) -> void:
	if _player_inventory == null or _colonist_inventory == null:
		return
	if slot_index < 0 or slot_index >= _player_inventory.slots.size():
		return

	var slot = _player_inventory.slots[slot_index]
	if slot == null or slot.item == null or slot.count <= 0:
		return

	var transfer_amount: int = slot.count
	var item_to_give: Resource = slot.item
	var leftover: int = _colonist_inventory.add_item(item_to_give, transfer_amount)
	var transferred: int = transfer_amount - leftover

	if transferred > 0:
		slot.count -= transferred
		if slot.count <= 0:
			slot.clear()
		_player_inventory.inventory_updated.emit()
		_colonist_inventory.inventory_updated.emit()


func _on_colonist_slot_clicked(slot_index: int) -> void:
	if _player_inventory == null or _colonist_inventory == null:
		return
	if slot_index < 0 or slot_index >= _colonist_inventory.slots.size():
		return

	var slot = _colonist_inventory.slots[slot_index]
	if slot == null or slot.item == null or slot.count <= 0:
		return

	var transfer_amount: int = slot.count
	var item_to_take: Resource = slot.item
	var leftover: int = _player_inventory.add_item(item_to_take, transfer_amount)
	var transferred: int = transfer_amount - leftover

	if transferred > 0:
		slot.count -= transferred
		if slot.count <= 0:
			slot.clear()
		_colonist_inventory.inventory_updated.emit()
		_player_inventory.inventory_updated.emit()


func _on_give_all_pressed() -> void:
	if _player_inventory == null or _colonist_inventory == null:
		return
	var p_slots: Array = _player_inventory.slots
	var any_changed := false
	for i in range(p_slots.size()):
		var slot = p_slots[i]
		if slot.item != null and slot.count > 0:
			var leftover: int = _colonist_inventory.add_item(slot.item, slot.count)
			var transferred: int = slot.count - leftover
			if transferred > 0:
				slot.count -= transferred
				if slot.count <= 0:
					slot.clear()
				any_changed = true
	if any_changed:
		_player_inventory.inventory_updated.emit()
		_colonist_inventory.inventory_updated.emit()


func _on_take_all_pressed() -> void:
	if _player_inventory == null or _colonist_inventory == null:
		return
	var c_slots: Array = _colonist_inventory.slots
	var any_changed := false
	for i in range(c_slots.size()):
		var slot = c_slots[i]
		if slot.item != null and slot.count > 0:
			var leftover: int = _player_inventory.add_item(slot.item, slot.count)
			var transferred: int = slot.count - leftover
			if transferred > 0:
				slot.count -= transferred
				if slot.count <= 0:
					slot.clear()
				any_changed = true
	if any_changed:
		_colonist_inventory.inventory_updated.emit()
		_player_inventory.inventory_updated.emit()


func _find_player_inventory() -> void:
	if _player_inventory != null:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player != null and "inventory" in player:
		_player_inventory = player.inventory
