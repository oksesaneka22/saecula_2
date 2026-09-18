extends Control

## InventoryUI: Повне вікно інвентаря гравця (сітка 6 колонок x 4 ряди = 24 слоти).
## Відкривається та закривається на клавіші 'I'.
## Центрується на екрані (Anchor Preset Center) з підтримкою 1080p та 1440p.

const ItemSlotUIScript = preload("res://src/ui/hud/ItemSlotUI.gd")

var _slot_nodes: Array[Control] = []
var _inventory: Node = null
var _is_open: bool = false


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_setup_ui()
	_connect_player_inventory()


func _setup_ui() -> void:
	# Темне затемнення фону
	var backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.0, 0.0, 0.0, 0.45)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	# Центральна панель вікна інвентаря
	var center_container = CenterContainer.new()
	center_container.name = "CenterContainer"
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center_container)

	var panel = PanelContainer.new()
	panel.name = "Panel"
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16, 0.95)
	style.border_color = Color(0.35, 0.42, 0.52, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16.0)
	panel.add_theme_stylebox_override("panel", style)
	center_container.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Заголовок вікна
	var title = Label.new()
	title.text = "Інвентар гравця [24 слоти]"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	vbox.add_child(title)

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
		grid.add_child(slot_ui)
		_slot_nodes.append(slot_ui)

	# Підказка знизу
	var hint = Label.new()
	hint.text = "Натисніть 'I' або 'Escape', щоб закрити"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	vbox.add_child(hint)


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
	_refresh_inventory()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_inventory() -> void:
	_is_open = false
	visible = false
	if GameManager.current_state == GameManager.GameState.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _refresh_inventory() -> void:
	if _inventory == null:
		return

	var total_slots = _inventory.slots.size()
	for i in range(_slot_nodes.size()):
		if i < total_slots:
			var slot_data = _inventory.get_slot(i)
			if slot_data != null and not slot_data.is_empty():
				_slot_nodes[i].set_slot_data(slot_data.item, slot_data.count)
			else:
				_slot_nodes[i].set_slot_data(null, 0)
