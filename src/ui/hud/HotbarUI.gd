extends Control

## HotbarUI: Панель швидкого доступу на 8 слотів.
## Розташовується по центру внизу екрана (Anchor Preset Bottom Center).
## Дозволяє обирати активний слот цифрами 1-8 або кліком,
## синхронізується з першими 8 слотами інвентаря гравця та Player3D.

const ItemSlotUIScript = preload("res://src/ui/hud/ItemSlotUI.gd")

const SLOT_COUNT: int = 8

var _is_updating_externally: bool = false

@export var selected_slot_index: int = 0:
	set(val):
		var clamped: int = clampi(val, 0, SLOT_COUNT - 1)
		if selected_slot_index != clamped or _slot_nodes.is_empty():
			selected_slot_index = clamped
			_update_selection()
			if not _is_updating_externally and EventBus != null:
				EventBus.hotbar_slot_selected.emit(selected_slot_index)

var _slot_nodes: Array[Control] = []
var _inventory: Node = null


func _ready() -> void:
	# Налаштовуємо адаптивні якорі: Bottom Wide / Bottom Center
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN

	_setup_ui()
	_connect_player_inventory()

	if EventBus != null:
		EventBus.hotbar_slot_selected.connect(_on_external_slot_selected)


func _on_external_slot_selected(idx: int) -> void:
	if selected_slot_index != idx:
		_is_updating_externally = true
		selected_slot_index = idx
		_is_updating_externally = false


func _setup_ui() -> void:
	# Створюємо фонову підкладку
	var panel = PanelContainer.new()
	panel.name = "Panel"
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.75)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(6.0)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var hbox = HBoxContainer.new()
	hbox.name = "HBox"
	hbox.add_theme_constant_override("separation", 6)
	panel.add_child(hbox)

	_slot_nodes.clear()
	for i in range(SLOT_COUNT):
		var slot_ui = ItemSlotUIScript.new()
		slot_ui.name = "Slot_%d" % (i + 1)
		slot_ui.slot_index = i
		slot_ui.hotkey_number = i + 1
		slot_ui.slot_clicked.connect(_on_slot_clicked)
		hbox.add_child(slot_ui)
		_slot_nodes.append(slot_ui)

	_update_selection()


func _connect_player_inventory() -> void:
	# Шукаємо гравця
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		var inv: Node = player.get("inventory")
		if inv != null:
			_inventory = inv
			if _inventory.has_signal("inventory_updated"):
				_inventory.connect("inventory_updated", _refresh_hotbar)
			_refresh_hotbar()


func _refresh_hotbar() -> void:
	if _inventory == null:
		return

	for i in range(SLOT_COUNT):
		if i < _slot_nodes.size():
			var slot_data = null
			if _inventory.has_method("get_slot"):
				slot_data = _inventory.get_slot(i)
			elif "slots" in _inventory and i < _inventory.slots.size():
				slot_data = _inventory.slots[i]

			if slot_data != null and not slot_data.is_empty():
				_slot_nodes[i].set_slot_data(slot_data.item, slot_data.count)
			else:
				_slot_nodes[i].set_slot_data(null, 0)


func _unhandled_input(event: InputEvent) -> void:
	# Обробка цифр 1-8 для швидкого вибору слота
	for i in range(SLOT_COUNT):
		var action_name: String = "hotbar_%d" % (i + 1)
		if event.is_action_pressed(action_name):
			selected_slot_index = i
			get_viewport().set_input_as_handled()
			return


func _on_slot_clicked(idx: int) -> void:
	selected_slot_index = idx


func _update_selection() -> void:
	for i in range(_slot_nodes.size()):
		_slot_nodes[i].is_selected = (i == selected_slot_index)
