extends Control

## BuildMenuUI: Інтерфейс вибору споруд та креслень (Blueprint Selector).
## Відкривається по клавіші 'B' або через кнопку інтерфейсу.
## Дозволяє переглянути вартість, опис та розпочати розміщення споруди.

@onready var panel_container: PanelContainer = $PanelContainer
@onready var buildings_list: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/BuildingsList
@onready var close_button: Button = $PanelContainer/MarginContainer/VBoxContainer/Header/CloseButton

var _inventory: InventoryComponent = null


func _ready() -> void:
	visible = false
	if close_button != null:
		close_button.pressed.connect(close)

	BuildingPlacementController.building_registered.connect(func(_b): _refresh_ui())
	BuildingPlacementController.placement_started.connect(func(_b): close())
	EventBus.game_state_changed.connect(_on_game_state_changed)

	_connect_player_inventory()
	_refresh_ui()


func _connect_player_inventory() -> void:
	if _inventory != null:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		var inv = player.get("inventory")
		if inv is InventoryComponent:
			set_inventory(inv)


func set_inventory(inv: InventoryComponent) -> void:
	_inventory = inv
	if _inventory != null and not _inventory.inventory_updated.is_connected(_refresh_ui):
		_inventory.inventory_updated.connect(_refresh_ui)
	_refresh_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_mode_toggle"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel") and visible:
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	_connect_player_inventory()
	_refresh_ui()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	if GameManager != null and GameManager.current_state == GameManager.GameState.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_game_state_changed(_new_state: int, _old_state: int) -> void:
	if visible and _new_state != GameManager.GameState.PLAYING and _new_state != GameManager.GameState.COLONY_MODE:
		close()


func _refresh_ui() -> void:
	if buildings_list == null:
		return

	for child in buildings_list.get_children():
		child.queue_free()

	var all_blds: Array[BuildingData] = BuildingPlacementController.get_all_buildings()
	if all_blds.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "Немає доступних креслень."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		buildings_list.add_child(empty_lbl)
		return

	for bld in all_blds:
		var card = _create_building_card(bld)
		buildings_list.add_child(card)


func _create_building_card(bld: BuildingData) -> Control:
	var card_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.18, 0.9)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 12
	style.content_margin_top = 8
	style.content_margin_right = 12
	style.content_margin_bottom = 8
	card_panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	card_panel.add_child(hbox)

	# Ліва частина: Інформація про будівлю
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var title_lbl = Label.new()
	title_lbl.text = "%s (%dx%d)" % [bld.display_name, bld.size_in_tiles.x, bld.size_in_tiles.y]
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.modulate = Color("E9C46A")
	info_vbox.add_child(title_lbl)

	if not bld.description.is_empty():
		var desc_lbl = Label.new()
		desc_lbl.text = bld.description
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.modulate = Color(0.8, 0.8, 0.8)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_vbox.add_child(desc_lbl)

	# Вартість будівництва
	var cost_text = _format_cost(bld)
	var cost_lbl = Label.new()
	cost_lbl.text = "Вартість: %s" % cost_text
	cost_lbl.add_theme_font_size_override("font_size", 13)
	cost_lbl.modulate = Color("A8DADC")
	info_vbox.add_child(cost_lbl)

	# Права частина: Кнопка "Обрати / Розмістити"
	var btn_vbox = VBoxContainer.new()
	btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(btn_vbox)

	var place_btn = Button.new()
	place_btn.text = "Розмістити"
	place_btn.custom_minimum_size = Vector2(120, 38)
	place_btn.pressed.connect(func():
		close()
		BuildingPlacementController.start_placement(bld)
	)
	btn_vbox.add_child(place_btn)

	return card_panel


func _format_cost(bld: BuildingData) -> String:
	if bld.construction_cost.is_empty():
		return "Безкоштовно"

	var parts: Array[String] = []
	for cost_res in bld.construction_cost:
		if cost_res != null and cost_res.get("item") != null:
			var item_obj = cost_res.get("item")
			var item_name: String = str(item_obj.get("display_name"))
			var amount: int = int(cost_res.get("amount"))
			parts.append("%s x%d" % [item_name, amount])
	return ", ".join(parts)
