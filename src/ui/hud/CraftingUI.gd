extends Control

const TextureHelper = preload("res://src/core3d/TextureHelper.gd")

## CraftingUI: Вікно крафту предметів та інструментів.
## Відкривається та закривається клавішею 'C'.
## Відображає доступні рецепти, перевіряє матеріали в реальному часі (зелена/сіра кнопка),
## показує необхідні інгредієнти та дозволяє миттєво створити предмет в інвентарі.

signal crafting_window_toggled(is_open: bool)

var _is_open: bool = false
var _inventory: Node = null
var _recipe_list_container: VBoxContainer = null


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_setup_ui()
	_connect_player_inventory()
	if EventBus != null and EventBus.has_signal("crafting_ui_requested"):
		EventBus.crafting_ui_requested.connect(open_crafting)


func _setup_ui() -> void:
	# 1. Затемнення фону
	var backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0.0, 0.0, 0.0, 0.45)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	# 2. Центроване вікно
	var center = CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel = PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(520, 420)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.16, 0.96)
	style.border_color = Color(0.4, 0.48, 0.6, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(18.0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Заголовок
	var title = Label.new()
	title.text = "Меню крафту [Кам'яний вік]"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	vbox.add_child(title)

	# Прокручувана область для списку рецептів
	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.custom_minimum_size = Vector2(480, 310)
	vbox.add_child(scroll)

	_recipe_list_container = VBoxContainer.new()
	_recipe_list_container.name = "RecipeList"
	_recipe_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_recipe_list_container.add_theme_constant_override("separation", 8)
	scroll.add_child(_recipe_list_container)

	# Підказка знизу
	var hint = Label.new()
	hint.text = "Натисніть 'C' або 'Escape', щоб закрити вікно"
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
				_inventory.connect("inventory_updated", _refresh_recipes_ui)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("crafting_toggle"):
		toggle_crafting()
		get_viewport().set_input_as_handled()
	elif _is_open and event.is_action_pressed("cancel"):
		close_crafting()
		get_viewport().set_input_as_handled()


func toggle_crafting() -> void:
	if _is_open:
		close_crafting()
	else:
		open_crafting()


func open_crafting() -> void:
	_is_open = true
	visible = true
	_refresh_recipes_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	crafting_window_toggled.emit(true)


func close_crafting() -> void:
	_is_open = false
	visible = false
	if GameManager.current_state == GameManager.GameState.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	crafting_window_toggled.emit(false)


func _refresh_recipes_ui() -> void:
	if _recipe_list_container == null or CraftingManager == null:
		return

	# Очищаємо попередній список
	for child in _recipe_list_container.get_children():
		child.queue_free()

	# Отримуємо рецепти поточної епохи
	var recipes: Array[Resource] = CraftingManager.get_all_recipes()

	for recipe in recipes:
		var row: Control = _create_recipe_row(recipe)
		_recipe_list_container.add_child(row)


func _create_recipe_row(recipe: Resource) -> Control:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.17, 0.22, 0.85)
	style.border_color = Color(0.25, 0.3, 0.38, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8.0)
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# Іконка результату крафту
	var result_item: Resource = recipe.get("result_item")
	var res_tex: Texture2D = null
	if result_item != null:
		var raw_icon = result_item.get("icon")
		if raw_icon is Texture2D:
			res_tex = raw_icon
		else:
			res_tex = TextureHelper.get_texture(TextureHelper.get_item_texture_path(result_item.get("id")))

	if res_tex != null:
		var tr := TextureRect.new()
		tr.custom_minimum_size = Vector2(36, 36)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture = res_tex
		hbox.add_child(tr)

	# Інформація про предмет та інгредієнти
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = str(recipe.get("display_name"))
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	info_vbox.add_child(name_label)

	# Список інгредієнтів
	var ing_text: String = "Потрібно: "
	var ingredients: Array = recipe.get("ingredients")
	var can_craft: bool = CraftingManager.can_craft(recipe, _inventory)

	for i in range(ingredients.size()):
		var cost = ingredients[i]
		var item: Resource = cost.get("item")
		var amount: int = cost.get("amount") if cost.get("amount") != null else 1
		var item_name: String = str(item.get("display_name")) if item != null else "Ресурс"
		var current_has: int = _inventory.get_item_count(StringName(item.get("id"))) if (_inventory != null and item != null) else 0

		ing_text += "%s: %d/%d" % [item_name, current_has, amount]
		if i < ingredients.size() - 1:
			ing_text += " | "

	var req_label = Label.new()
	req_label.text = ing_text
	req_label.add_theme_font_size_override("font_size", 12)
	req_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9) if can_craft else Color(0.85, 0.45, 0.45))
	info_vbox.add_child(req_label)

	# Перевірка статусу дослідження в Дереві Епох
	var is_unlocked: bool = CraftingManager.is_recipe_unlocked(recipe) if CraftingManager != null else true

	if not is_unlocked:
		panel.modulate = Color(0.65, 0.65, 0.7, 0.7)
		req_label.text = "🔒 Потрібно дослідити у Дереві Епох [T]"
		req_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.35))

	# Кнопка скрафтити
	var craft_btn = Button.new()
	if not is_unlocked:
		craft_btn.text = "🔒 Заблоковано"
		craft_btn.disabled = true
	else:
		craft_btn.text = "Скрафтити"
		craft_btn.disabled = not can_craft

	craft_btn.custom_minimum_size = Vector2(120, 36)

	craft_btn.pressed.connect(func():
		if is_unlocked and _inventory != null and CraftingManager.craft_item(recipe, _inventory):
			_refresh_recipes_ui()
	)
	hbox.add_child(craft_btn)

	# Кнопка замовлення виготовлення на верстаку для колоністів
	var workbenches = get_tree().get_nodes_in_group("workbenches")
	var active_workbench: Node = null
	for wb in workbenches:
		if is_instance_valid(wb) and not wb.is_queued_for_deletion():
			active_workbench = wb
			break
	if active_workbench != null and is_unlocked:
		var order_btn := Button.new()
		order_btn.name = "OrderBtn"
		order_btn.text = "🔨 Замовити"
		order_btn.custom_minimum_size = Vector2(110, 36)
		var can_order_bench: bool = true
		if LogisticsManager != null:
			for cost in ingredients:
				var cost_item: Resource = cost.get("item")
				var cost_amt: int = cost.get("amount") if cost.get("amount") != null else 1
				if cost_item != null:
					var itm_id: StringName = StringName(cost_item.get("id"))
					if LogisticsManager.get_total_item_count(itm_id) < cost_amt:
						can_order_bench = false
						break
		order_btn.disabled = not can_order_bench
		order_btn.tooltip_text = "Колоніст візьме матеріали зі складу та виготовить предмет на верстаку"
		order_btn.pressed.connect(func():
			if active_workbench != null and is_instance_valid(active_workbench):
				var r_id: StringName = StringName(recipe.get("id"))
				if JobManager != null:
					JobManager.create_craft_job(active_workbench, r_id, 1)
					if FloatingTextManager != null and active_workbench is Node3D:
						FloatingTextManager.spawn_info((active_workbench as Node3D).global_position + Vector3(0, 1.8, 0), "🔨 Замовлення створено!", Color(0.4, 0.8, 1.0))
					close_crafting()
		)
		hbox.add_child(order_btn)

	return panel
