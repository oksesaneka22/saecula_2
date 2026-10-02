extends Control

## InventoryUI: Повне вікно інвентаря гравця (сітка 6 колонок x 4 ряди = 24 слоти).
## Відкривається та закривається на клавіші 'I'.
## Підтримує інтерактивну організацію речей: вибір, переміщення, об'єднання стеків, перенесення по 1 шт. на ПКМ.
## Центрується на екрані (Anchor Preset Center) з підтримкою 1080p та 1440p.

const ItemSlotUIScript = preload("res://src/ui/hud/ItemSlotUI.gd")

var _slot_nodes: Array[Control] = []
var _inventory: Node = null
var _is_open: bool = false
var _selected_slot_index: int = -1
var _hint_label: Label = null


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_setup_ui()
	_connect_player_inventory()


func _setup_ui() -> void:
	# Темне затемнення фону
	var backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.0, 0.0, 0.0, 0.5)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			close_inventory()
	)
	add_child(backdrop)

	# Центральна панель вікна інвентаря
	var center_container = CenterContainer.new()
	center_container.name = "CenterContainer"
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center_container)

	var panel = PanelContainer.new()
	panel.name = "Panel"
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.15, 0.96)
	style.border_color = Color(0.35, 0.45, 0.55, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18.0)
	panel.add_theme_stylebox_override("panel", style)
	center_container.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Заголовок вікна
	var header_hbox = HBoxContainer.new()
	vbox.add_child(header_hbox)

	var title = Label.new()
	title.text = "🎒 Інвентар гравця [24 слоти]"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.6))
	header_hbox.add_child(title)

	var close_btn = Button.new()
	close_btn.text = " ✕ "
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close_inventory)
	header_hbox.add_child(close_btn)

	var sub_label = Label.new()
	sub_label.text = "⭐ Слоти 1-8 (верхній рядок) закріплені за панеллю швидкого доступу (Hotbar)"
	sub_label.add_theme_font_size_override("font_size", 11)
	sub_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.82))
	vbox.add_child(sub_label)

	# Сітка слотів 6x4
	var grid = GridContainer.new()
	grid.name = "Grid"
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(grid)

	_slot_nodes.clear()
	for i in range(24):
		var slot_ui = ItemSlotUIScript.new()
		slot_ui.name = "Slot_%d" % i
		slot_ui.slot_index = i
		if i < 8:
			slot_ui.hotkey_number = i + 1
		slot_ui.slot_clicked.connect(_on_slot_clicked)
		if slot_ui.has_signal("slot_secondary_clicked"):
			slot_ui.slot_secondary_clicked.connect(_on_slot_secondary_clicked)
		grid.add_child(slot_ui)
		_slot_nodes.append(slot_ui)

	# Підказка знизу
	_hint_label = Label.new()
	_reset_hint_text()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
	vbox.add_child(_hint_label)


func _reset_hint_text() -> void:
	if _hint_label != null:
		_hint_label.text = "💡 ЛКМ: обрати / поміняти місцями  •  ПКМ: перенести 1 шт.  •  'I' або 'Esc': закрити"


func _connect_player_inventory() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		var inv: Node = player.get("inventory")
		if inv != null:
			_inventory = inv
			if _inventory.has_signal("inventory_updated"):
				_inventory.connect("inventory_updated", _refresh_inventory)
			_refresh_inventory()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory_toggle"):
		toggle_inventory()
		get_viewport().set_input_as_handled()
	elif _is_open and event.is_action_pressed("cancel"):
		close_inventory()
		get_viewport().set_input_as_handled()


func toggle_inventory() -> void:
	if _is_open:
		close_inventory()
	else:
		open_inventory()


func open_inventory() -> void:
	_is_open = true
	visible = true
	_selected_slot_index = -1
	_reset_hint_text()
	_refresh_inventory()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_inventory() -> void:
	_is_open = false
	visible = false
	if _selected_slot_index != -1 and _selected_slot_index < _slot_nodes.size():
		_slot_nodes[_selected_slot_index].is_selected = false
	_selected_slot_index = -1
	_reset_hint_text()
	if GameManager.current_state == GameManager.GameState.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _refresh_inventory() -> void:
	if _inventory == null:
		return

	var total_slots: int = _inventory.slots.size()
	for i in range(_slot_nodes.size()):
		if i < total_slots:
			var slot_data = _inventory.get_slot(i)
			if slot_data != null and not slot_data.is_empty():
				_slot_nodes[i].set_slot_data(slot_data.item, slot_data.count)
			else:
				_slot_nodes[i].set_slot_data(null, 0)
		else:
			_slot_nodes[i].set_slot_data(null, 0)
		_slot_nodes[i].is_selected = (i == _selected_slot_index)


## Лівий клік по слоту: вибір або переміщення/обмін
func _on_slot_clicked(slot_index: int) -> void:
	if _inventory == null or slot_index < 0 or slot_index >= _inventory.slots.size():
		return

	if _selected_slot_index == -1:
		var slot = _inventory.get_slot(slot_index)
		if slot == null or slot.is_empty():
			return
		_selected_slot_index = slot_index
		_slot_nodes[slot_index].is_selected = true
		var item_name: String = slot.item.get("display_name") if "display_name" in slot.item else str(slot.get_item_id())
		_hint_label.text = "🟡 Обрано: %s (%d шт.). Клікніть інший слот для переміщення" % [item_name, slot.count]
	elif _selected_slot_index == slot_index:
		# Зняття вибору
		_slot_nodes[_selected_slot_index].is_selected = false
		_selected_slot_index = -1
		_reset_hint_text()
	else:
		# Переміщення / обмін між слотами
		if _inventory.has_method("swap_slots"):
			_inventory.swap_slots(_selected_slot_index, slot_index)
		if _selected_slot_index < _slot_nodes.size():
			_slot_nodes[_selected_slot_index].is_selected = false
		_selected_slot_index = -1
		_reset_hint_text()


## Правий клік по слоту: відокремлення 1 штуки
func _on_slot_secondary_clicked(slot_index: int) -> void:
	if _inventory == null or slot_index < 0 or slot_index >= _inventory.slots.size():
		return

	if _selected_slot_index != -1 and _selected_slot_index != slot_index:
		var src_slot = _inventory.get_slot(_selected_slot_index)
		var dst_slot = _inventory.get_slot(slot_index)
		if src_slot != null and not src_slot.is_empty():
			var max_stack: int = 64
			if "max_stack" in src_slot.item and src_slot.item.max_stack > 0:
				max_stack = src_slot.item.max_stack

			if dst_slot.is_empty():
				dst_slot.item = src_slot.item
				dst_slot.count = 1
				src_slot.count -= 1
				if src_slot.count <= 0:
					src_slot.clear()
					_slot_nodes[_selected_slot_index].is_selected = false
					_selected_slot_index = -1
					_reset_hint_text()
				_inventory.inventory_updated.emit()
			elif dst_slot.get_item_id() == src_slot.get_item_id() and dst_slot.count < max_stack:
				dst_slot.count += 1
				src_slot.count -= 1
				if src_slot.count <= 0:
					src_slot.clear()
					_slot_nodes[_selected_slot_index].is_selected = false
					_selected_slot_index = -1
					_reset_hint_text()
				_inventory.inventory_updated.emit()
	elif _selected_slot_index == -1:
		_on_slot_clicked(slot_index)
