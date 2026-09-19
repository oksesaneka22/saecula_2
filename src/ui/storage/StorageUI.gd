extends Control

## StorageUI: Інтерфейс взаємодії зі складом ресурсів та контейнерами поселення (Ітерація 7.1).
## Відображає подвійну панель: Інвентар гравця (ліворуч) та Сховище складу (праворуч).
## Дозволяє перекладати предмети кліком по слоту, або швидко переносити ресурси кнопками
## "Покласти все" / "Забрати все", підтримує адаптивне масштабування під 1080p/1440p.

const ItemSlotUIScript = preload("res://src/ui/hud/ItemSlotUI.gd")

var _target_stockpile: Node = null
var _stockpile_inventory: Node = null
var _player_inventory: Node = null

var _player_slots: Array[Control] = []
var _stockpile_slots: Array[Control] = []

var _title_label: Label = null
var _stockpile_capacity_label: Label = null
var _player_capacity_label: Label = null
var _stockpile_grid: GridContainer = null
var _player_grid: GridContainer = null


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_ui_layout()

	EventBus.storage_ui_requested.connect(open_storage)
	EventBus.inventory_window_toggle_requested.connect(_on_inventory_toggle_requested)


func _build_ui_layout() -> void:
	# 1. Затемнення заднього плану
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(_on_backdrop_gui_input)
	add_child(backdrop)

	# 2. Центральне вікно сховища
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
	root_vbox.add_theme_constant_override("separation", 16)
	main_panel.add_child(root_vbox)

	# 3. Верхній заголовок вікна та кнопка закриття
	var header_hbox := HBoxContainer.new()
	root_vbox.add_child(header_hbox)

	_title_label = Label.new()
	_title_label.text = "📦 Склад ресурсів поселення"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.6))
	header_hbox.add_child(_title_label)

	var close_btn := Button.new()
	close_btn.text = " ✕ "
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close_storage)
	header_hbox.add_child(close_btn)

	# 4. Основна область: Дві колонки (Гравець | Розділювач | Склад)
	var columns_hbox := HBoxContainer.new()
	columns_hbox.add_theme_constant_override("separation", 24)
	root_vbox.add_child(columns_hbox)

	# --- ЛІВА ПАНЕЛЬ: Інвентар гравця ---
	var player_vbox := VBoxContainer.new()
	player_vbox.add_theme_constant_override("separation", 8)
	columns_hbox.add_child(player_vbox)

	var player_header := HBoxContainer.new()
	player_vbox.add_child(player_header)

	var player_title := Label.new()
	player_title.text = "🎒 Інвентар гравця"
	player_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_title.add_theme_font_size_override("font_size", 14)
	player_title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	player_header.add_child(player_title)

	_player_capacity_label = Label.new()
	_player_capacity_label.text = "0/24"
	_player_capacity_label.add_theme_font_size_override("font_size", 12)
	_player_capacity_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	player_header.add_child(_player_capacity_label)

	_player_grid = GridContainer.new()
	_player_grid.columns = 6
	_player_grid.add_theme_constant_override("h_separation", 6)
	_player_grid.add_theme_constant_override("v_separation", 6)
	player_vbox.add_child(_player_grid)

	var deposit_all_btn := Button.new()
	deposit_all_btn.text = "⬇ Покласти все на склад"
	deposit_all_btn.focus_mode = Control.FOCUS_NONE
	deposit_all_btn.pressed.connect(_on_deposit_all_pressed)
	player_vbox.add_child(deposit_all_btn)

	# --- РОЗДІЛЮВАЧ ---
	var v_sep := VSeparator.new()
	columns_hbox.add_child(v_sep)

	# --- ПРАВА ПАНЕЛЬ: Сховище складу ---
	var stockpile_vbox := VBoxContainer.new()
	stockpile_vbox.add_theme_constant_override("separation", 8)
	columns_hbox.add_child(stockpile_vbox)

	var stockpile_header := HBoxContainer.new()
	stockpile_vbox.add_child(stockpile_header)

	var stockpile_title := Label.new()
	stockpile_title.text = "🏛 Сховище складу"
	stockpile_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stockpile_title.add_theme_font_size_override("font_size", 14)
	stockpile_title.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	stockpile_header.add_child(stockpile_title)

	_stockpile_capacity_label = Label.new()
	_stockpile_capacity_label.text = "0/32"
	_stockpile_capacity_label.add_theme_font_size_override("font_size", 12)
	_stockpile_capacity_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	stockpile_header.add_child(_stockpile_capacity_label)

	_stockpile_grid = GridContainer.new()
	_stockpile_grid.columns = 8
	_stockpile_grid.add_theme_constant_override("h_separation", 6)
	_stockpile_grid.add_theme_constant_override("v_separation", 6)
	stockpile_vbox.add_child(_stockpile_grid)

	var take_all_btn := Button.new()
	take_all_btn.text = "⬆ Забрати все в інвентар"
	take_all_btn.focus_mode = Control.FOCUS_NONE
	take_all_btn.pressed.connect(_on_take_all_pressed)
	stockpile_vbox.add_child(take_all_btn)

	# 5. Створення початкових слотів гравця (24 слоти)
	_player_slots.clear()
	for i in range(24):
		var slot_ui: Control = ItemSlotUIScript.new()
		slot_ui.name = "PlayerSlot_%d" % i
		slot_ui.set("slot_index", i)
		slot_ui.set("slot_clicked", _on_player_slot_clicked)
		if slot_ui.has_signal("slot_clicked"):
			slot_ui.slot_clicked.connect(_on_player_slot_clicked)
		_player_grid.add_child(slot_ui)
		_player_slots.append(slot_ui)


## Відкриває інтерфейс взаємодії зі складом
func open_storage(stockpile_node: Node) -> void:
	if stockpile_node == null:
		return

	_target_stockpile = stockpile_node
	_stockpile_inventory = _get_node_inventory(_target_stockpile)
	_find_player_inventory()

	if _stockpile_inventory == null:
		print("[StorageUI] Помилка: цільовий об'єкт не містить InventoryComponent.")
		return

	# Підключаємо сигнали оновлення
	if not _stockpile_inventory.inventory_updated.is_connected(refresh_ui):
		_stockpile_inventory.inventory_updated.connect(refresh_ui)
	if _player_inventory != null and not _player_inventory.inventory_updated.is_connected(refresh_ui):
		_player_inventory.inventory_updated.connect(refresh_ui)

	# Оновлюємо заголовок
	var bld_name: String = "Склад ресурсів"
	if "building_data" in _target_stockpile and _target_stockpile.building_data != null:
		bld_name = _target_stockpile.building_data.display_name
	elif "display_name" in _target_stockpile:
		bld_name = _target_stockpile.display_name
	_title_label.text = "📦 %s" % bld_name

	# Створюємо потрібну кількість слотів для складу
	_rebuild_stockpile_slots()

	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh_ui()


## Закриває інтерфейс сховища
func close_storage() -> void:
	if not visible:
		return

	visible = false

	if _stockpile_inventory != null and _stockpile_inventory.inventory_updated.is_connected(refresh_ui):
		_stockpile_inventory.inventory_updated.disconnect(refresh_ui)
	if _player_inventory != null and _player_inventory.inventory_updated.is_connected(refresh_ui):
		_player_inventory.inventory_updated.disconnect(refresh_ui)

	_target_stockpile = null
	_stockpile_inventory = null

	# Відновлення захоплення миші, якщо у грі активний гравець першої особи
	var player_3d = get_tree().get_first_node_in_group("player")
	if player_3d != null and player_3d.has_method("is_active") and player_3d.is_active():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	EventBus.storage_ui_closed.emit()


## Оновлює вміст слотів на обох панелях
func refresh_ui() -> void:
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

	# Оновлення слотів складу
	if _stockpile_inventory != null:
		var s_items: Array = _stockpile_inventory.get_all_items()
		var s_used: int = 0
		for i in range(_stockpile_slots.size()):
			var slot_ui: Control = _stockpile_slots[i]
			if i < s_items.size():
				var s = s_items[i]
				slot_ui.set_slot_data(s.item, s.count)
				if s.item != null and s.count > 0:
					s_used += 1
			else:
				slot_ui.set_slot_data(null, 0)
		_stockpile_capacity_label.text = "%d/%d" % [s_used, _stockpile_inventory.slot_count]


func _rebuild_stockpile_slots() -> void:
	var total_slots: int = _stockpile_inventory.slot_count if _stockpile_inventory != null else 32
	if _stockpile_slots.size() == total_slots:
		return

	# Очищення старих слотів
	for child in _stockpile_grid.get_children():
		child.queue_free()
	_stockpile_slots.clear()

	# Динамічні колонки
	if total_slots <= 16:
		_stockpile_grid.columns = 4
	elif total_slots <= 24:
		_stockpile_grid.columns = 6
	else:
		_stockpile_grid.columns = 8

	for i in range(total_slots):
		var slot_ui: Control = ItemSlotUIScript.new()
		slot_ui.name = "StockpileSlot_%d" % i
		slot_ui.set("slot_index", i)
		if slot_ui.has_signal("slot_clicked"):
			slot_ui.slot_clicked.connect(_on_stockpile_slot_clicked)
		_stockpile_grid.add_child(slot_ui)
		_stockpile_slots.append(slot_ui)


## Клік по слоту гравця -> перенесення ресурсу на склад
func _on_player_slot_clicked(slot_index: int) -> void:
	if _player_inventory == null or _stockpile_inventory == null:
		return
	if slot_index < 0 or slot_index >= _player_inventory.slots.size():
		return

	var slot = _player_inventory.slots[slot_index]
	if slot == null or slot.item == null or slot.count <= 0:
		return

	var item_res: Resource = slot.item
	var count_to_move: int = slot.count

	# Додаємо на склад
	var remainder: int = _stockpile_inventory.add_item(item_res, count_to_move)
	var moved: int = count_to_move - remainder

	if moved > 0:
		slot.count -= moved
		if slot.count <= 0:
			slot.clear()
		_player_inventory.inventory_updated.emit()
		_stockpile_inventory.inventory_updated.emit()


## Клік по слоту складу -> перенесення ресурсу до інвентаря гравця
func _on_stockpile_slot_clicked(slot_index: int) -> void:
	if _player_inventory == null or _stockpile_inventory == null:
		return
	if slot_index < 0 or slot_index >= _stockpile_inventory.slots.size():
		return

	var slot = _stockpile_inventory.slots[slot_index]
	if slot == null or slot.item == null or slot.count <= 0:
		return

	var item_res: Resource = slot.item
	var count_to_move: int = slot.count

	# Додаємо гравцеві
	var remainder: int = _player_inventory.add_item(item_res, count_to_move)
	var moved: int = count_to_move - remainder

	if moved > 0:
		slot.count -= moved
		if slot.count <= 0:
			slot.clear()
		_stockpile_inventory.inventory_updated.emit()
		_player_inventory.inventory_updated.emit()


## Перекласти всі ресурси з гравця на склад
func _on_deposit_all_pressed() -> void:
	if _player_inventory == null or _stockpile_inventory == null:
		return

	var changed: bool = false
	for slot in _player_inventory.slots:
		if slot != null and slot.item != null and slot.count > 0:
			var item_res: Resource = slot.item
			var count: int = slot.count
			var remainder: int = _stockpile_inventory.add_item(item_res, count)
			var moved: int = count - remainder
			if moved > 0:
				slot.count -= moved
				if slot.count <= 0:
					slot.clear()
				changed = true

	if changed:
		_player_inventory.inventory_updated.emit()
		_stockpile_inventory.inventory_updated.emit()


## Забрати всі ресурси зі складу в інвентар гравця
func _on_take_all_pressed() -> void:
	if _player_inventory == null or _stockpile_inventory == null:
		return

	var changed: bool = false
	for slot in _stockpile_inventory.slots:
		if slot != null and slot.item != null and slot.count > 0:
			var item_res: Resource = slot.item
			var count: int = slot.count
			var remainder: int = _player_inventory.add_item(item_res, count)
			var moved: int = count - remainder
			if moved > 0:
				slot.count -= moved
				if slot.count <= 0:
					slot.clear()
				changed = true

	if changed:
		_stockpile_inventory.inventory_updated.emit()
		_player_inventory.inventory_updated.emit()


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_storage()


func _on_inventory_toggle_requested() -> void:
	if visible:
		close_storage()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("cancel") or event.is_action_pressed("interact") or event.is_action_pressed("inventory_toggle"):
		close_storage()
		get_viewport().set_input_as_handled()


func _find_player_inventory() -> void:
	if _player_inventory != null:
		return

	var player_node: Node = get_tree().get_first_node_in_group("player")
	if player_node != null:
		_player_inventory = _get_node_inventory(player_node)


func _get_node_inventory(node: Node) -> Node:
	if node == null:
		return null
	if "inventory" in node and node.inventory != null:
		return node.inventory
	if node.has_node("InventoryComponent"):
		return node.get_node("InventoryComponent")
	if node.has_node("BuildingInventory"):
		return node.get_node("BuildingInventory")
	return null
