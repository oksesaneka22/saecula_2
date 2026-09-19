extends Control

## BuildMenuUI: Інтерфейс вибору споруд та креслень (Factorio Blueprint Selector).
## Відкривається по клавіші 'B' або через кнопку інтерфейсу.
## Дозволяє переглянути параметри, вартість матеріалів та розпочати встановлення креслення споруди.

const TextureHelper = preload("res://src/core3d/TextureHelper.gd")

@onready var dim_overlay: ColorRect = $DimOverlay
@onready var panel_container: PanelContainer = $PanelContainer
@onready var category_tabs: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/CategoryTabs
@onready var buildings_list: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/BuildingsList
@onready var close_button: Button = $PanelContainer/MarginContainer/VBoxContainer/Header/CloseButton

var _inventory: InventoryComponent = null
var _current_filter: StringName = &"all"
var _tab_buttons: Dictionary = {} # StringName -> Button


func _ready() -> void:
	visible = false

	if close_button != null:
		close_button.pressed.connect(close)

	if dim_overlay != null:
		dim_overlay.gui_input.connect(_on_dim_overlay_input)

	_setup_category_tabs()

	BuildingPlacementController.building_registered.connect(func(_b): _refresh_ui())
	BuildingPlacementController.placement_started.connect(func(_b): close())
	EventBus.game_state_changed.connect(_on_game_state_changed)

	if EventBus.has_signal("colony_storage_updated"):
		EventBus.colony_storage_updated.connect(func(_id, _cnt): _refresh_ui())

	_connect_player_inventory()
	_refresh_ui()


func _setup_category_tabs() -> void:
	if category_tabs == null:
		return

	for c in category_tabs.get_children():
		c.queue_free()

	_tab_buttons.clear()

	var categories = [
		{"id": &"all", "label": " Усі споруди "},
		{"id": &"modular", "label": " 🏛️ Модульні (Going Medieval) "},
		{"id": &"base", "label": " 🔥 Базові "},
		{"id": &"storage", "label": " 📦 Сховища "},
		{"id": &"living", "label": " 🏠 Житло & Праця "}
	]

	for cat in categories:
		var cat_id: StringName = cat["id"]
		var btn = Button.new()
		btn.text = cat["label"]
		btn.custom_minimum_size = Vector2(120, 32)
		btn.pressed.connect(func(): _select_category(cat_id))
		category_tabs.add_child(btn)
		_tab_buttons[cat_id] = btn

	_update_tab_styles()


func _select_category(cat_id: StringName) -> void:
	_current_filter = cat_id
	_update_tab_styles()
	_refresh_ui()


func _update_tab_styles() -> void:
	for cat_id in _tab_buttons.keys():
		var btn: Button = _tab_buttons[cat_id]
		if cat_id == _current_filter:
			btn.modulate = Color("F4A261")
		else:
			btn.modulate = Color(0.85, 0.85, 0.85, 1.0)


func _on_dim_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		close()


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


func _get_building_category(bld: BuildingData) -> StringName:
	if bld == null:
		return &"base"
	if bld.id.begins_with("modular_"):
		return &"modular"
	if bld.storage_slots > 0 or bld.id == &"stockpile":
		return &"storage"
	if bld.job_type_provided != &"" or bld.id == &"wooden_hut":
		return &"living"
	return &"base"


func _refresh_ui() -> void:
	if buildings_list == null:
		return

	for child in buildings_list.get_children():
		child.queue_free()

	var all_blds: Array[BuildingData] = BuildingPlacementController.get_all_buildings()
	var filtered_blds: Array[BuildingData] = []

	for bld in all_blds:
		if _current_filter == &"all" or _get_building_category(bld) == _current_filter:
			filtered_blds.append(bld)

	if filtered_blds.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "Немає доступних споруд у цій категорії."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.modulate = Color(0.7, 0.7, 0.7)
		buildings_list.add_child(empty_lbl)
		return

	for bld in filtered_blds:
		var card = _create_building_card(bld)
		buildings_list.add_child(card)


func _create_building_card(bld: BuildingData) -> Control:
	var card_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.14, 0.18, 0.95)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.28, 0.45, 0.65, 0.6)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	card_panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	card_panel.add_child(hbox)

	# 1. Ліва колонка: Іконка / Мініатюра споруди
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(56, 56)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

	var bld_tex: Texture2D = bld.icon
	if bld_tex == null:
		var tex_path = _get_building_texture_path(bld.id)
		bld_tex = TextureHelper.get_texture(tex_path)
	if bld_tex != null:
		icon_rect.texture = bld_tex
	hbox.add_child(icon_rect)

	# 2. Центральна колонка: Інформація про споруду
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(info_vbox)

	# Рядок заголовка
	var title_hbox = HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 8)
	info_vbox.add_child(title_hbox)

	var title_lbl = Label.new()
	title_lbl.text = bld.display_name
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.modulate = Color("E9C46A")
	title_hbox.add_child(title_lbl)

	var size_badge = Label.new()
	var m_x: int = int(round(float(bld.size_in_tiles.x) * GridManager.TILE_SIZE_3D))
	var m_y: int = int(round(float(bld.size_in_tiles.y) * GridManager.TILE_SIZE_3D))
	size_badge.text = "[%dx%d тайлів / %dx%dм]" % [bld.size_in_tiles.x, bld.size_in_tiles.y, m_x, m_y]
	size_badge.add_theme_font_size_override("font_size", 12)
	size_badge.modulate = Color("2A9D8F")
	title_hbox.add_child(size_badge)

	# Роль / Особливість
	var feature_text: String = _get_feature_text(bld)
	if not feature_text.is_empty():
		var feat_lbl = Label.new()
		feat_lbl.text = feature_text
		feat_lbl.add_theme_font_size_override("font_size", 11)
		feat_lbl.modulate = Color("F4A261")
		info_vbox.add_child(feat_lbl)

	# Опис
	if not bld.description.is_empty():
		var desc_lbl = Label.new()
		desc_lbl.text = bld.description
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.modulate = Color(0.8, 0.85, 0.9)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_vbox.add_child(desc_lbl)

	# Матеріали для побудови
	var cost_vbox = _build_cost_display(bld)
	info_vbox.add_child(cost_vbox)

	# 3. Права колонка: Кнопка розміщення креслення
	var btn_vbox = VBoxContainer.new()
	btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(btn_vbox)

	var place_btn = Button.new()
	place_btn.text = "📐 Встановити\nкреслення"
	place_btn.custom_minimum_size = Vector2(140, 48)
	place_btn.pressed.connect(func():
		close()
		BuildingPlacementController.start_placement(bld)
	)
	btn_vbox.add_child(place_btn)

	return card_panel


func _get_feature_text(bld: BuildingData) -> String:
	var features: Array[String] = []
	if bld.storage_slots > 0:
		features.append("📦 Сховище: %d слотів" % bld.storage_slots)
	if not bld.is_solid:
		features.append("🚶 Прохідний майданчик")
	if bld.job_type_provided != &"":
		features.append("⚒️ Робоче місце: %s" % str(bld.job_type_provided))
	elif bld.id == &"wooden_hut":
		features.append("🏠 Житло колоністів та майстерня будівельника")
	elif bld.id == &"campfire":
		features.append("🔥 Зона обігріву та світла")
	return " | ".join(features)


func _get_building_texture_path(bld_id: StringName) -> String:
	match bld_id:
		&"campfire":
			return TextureHelper.PATH_BLD_CAMPFIRE_STONE
		&"stockpile":
			return TextureHelper.PATH_BLD_WOOD_PLANKS
		&"wooden_hut":
			return TextureHelper.PATH_BLD_HUT_WALL
		_:
			return TextureHelper.PATH_BLD_GENERIC


func _build_cost_display(bld: BuildingData) -> Control:
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 12)

	var title = Label.new()
	title.text = "Матеріали:"
	title.add_theme_font_size_override("font_size", 12)
	title.modulate = Color("A8DADC")
	container.add_child(title)

	if bld.construction_cost.is_empty():
		var free_lbl = Label.new()
		free_lbl.text = "Безкоштовно"
		free_lbl.add_theme_font_size_override("font_size", 12)
		free_lbl.modulate = Color(0.5, 1.0, 0.5)
		container.add_child(free_lbl)
		return container

	for cost_res in bld.construction_cost:
		if cost_res == null or cost_res.get("item") == null:
			continue
		var item_obj = cost_res.get("item")
		var item_id: StringName = item_obj.id if "id" in item_obj else StringName(str(item_obj))
		var item_name: String = str(item_obj.get("display_name"))
		var req_amount: int = int(cost_res.get("amount"))

		var player_count: int = _inventory.get_item_count(item_id) if _inventory != null else 0
		var colony_count: int = LogisticsManager.get_available_item_count(item_id) if LogisticsManager != null else 0
		var total_available: int = player_count + colony_count

		var is_ready: bool = total_available >= req_amount

		var item_lbl = Label.new()
		item_lbl.text = "%s: %d (в наявності: %d)" % [item_name, req_amount, total_available]
		item_lbl.add_theme_font_size_override("font_size", 12)
		item_lbl.modulate = Color(0.4, 1.0, 0.5) if is_ready else Color(0.95, 0.75, 0.3)
		container.add_child(item_lbl)

	return container
