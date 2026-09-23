class_name AdminPanelUI
extends Control

## AdminPanelUI: Багатофункціональна панель розробника / адмін-панель (F1 або ~).
## Дозволяє миттєво видавати будь-які предмети, змінювати голод, спрагу та енергію,
## керувати часом доби, перемикати швидкість гри та тестувати всі механіки виживання.

var _is_open: bool = false
var _is_super_speed: bool = false

# UI посилання
var _panel_container: PanelContainer = null
var _tab_container: TabContainer = null

# Мітки стану
var _lbl_energy: Label = null
var _lbl_hunger: Label = null
var _lbl_thirst: Label = null
var _lbl_time: Label = null
var _btn_super_speed: Button = null

var _update_timer: float = 0.0


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_setup_ui()

	if EventBus != null and EventBus.has_signal("admin_panel_toggle_requested"):
		EventBus.admin_panel_toggle_requested.connect(toggle)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1 or event.keycode == KEY_QUOTELEFT:
			toggle()
			get_viewport().set_input_as_handled()
			return

		if _is_open and event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
			return


func _process(delta: float) -> void:
	if not _is_open:
		return
	_update_timer += delta
	if _update_timer >= 0.2:
		_update_timer = 0.0
		_refresh_display()


func open() -> void:
	_is_open = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_display()
	print("[AdminPanel] ⚙️ Адмін-панель відкрито (F1 або ~)")


func close() -> void:
	_is_open = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if GameManager != null and GameManager.current_state == GameManager.GameState.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("[AdminPanel] ⚙️ Адмін-панель закрито")


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func _setup_ui() -> void:
	# 1. Напівпрозоре затемнення екрана
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			close()
	)
	add_child(backdrop)

	# 2. Центроване вікно адмінки
	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel_container = PanelContainer.new()
	_panel_container.name = "MainPanel"
	_panel_container.custom_minimum_size = Vector2(760.0, 540.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.1, 0.14, 0.98)
	panel_style.border_color = Color(0.25, 0.45, 0.7, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.set_content_margin_all(16.0)
	_panel_container.add_theme_stylebox_override("panel", panel_style)
	center.add_child(_panel_container)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	_panel_container.add_child(main_vbox)

	# Заголовок вікна
	var header := HBoxContainer.new()
	main_vbox.add_child(header)

	var title := Label.new()
	title.text = "⚙️ АДМІН-ПАНЕЛЬ / DEBUG MENU (F1 або ~)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 16)
	title.modulate = Color("e0a96d")
	header.add_child(title)

	var btn_close := Button.new()
	btn_close.text = " ✕ Закрити "
	btn_close.pressed.connect(close)
	header.add_child(btn_close)

	# Вкладки налаштувань
	_tab_container = TabContainer.new()
	_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(_tab_container)

	# 1. Вкладка "Характеристики"
	_setup_stats_tab()

	# 2. Вкладка "Час доби"
	_setup_time_tab()

	# 3. Вкладка "Видача предметів"
	_setup_items_tab()


# ------------------------------------------------------------------------------
# 1. Вкладка характеристик гравця
# ------------------------------------------------------------------------------
func _setup_stats_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "📊 Характеристики"
	_tab_container.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(vbox)

	# Енергія
	var sec_energy := VBoxContainer.new()
	vbox.add_child(sec_energy)
	_lbl_energy = Label.new()
	_lbl_energy.add_theme_font_size_override("font_size", 14)
	sec_energy.add_child(_lbl_energy)

	var row_e := HBoxContainer.new()
	row_e.add_theme_constant_override("separation", 8)
	sec_energy.add_child(row_e)
	_create_btn(row_e, "⚡ 1000 (Повна)", func(): _set_player_energy(1000.0))
	_create_btn(row_e, "⚡ 500", func(): _set_player_energy(500.0))
	_create_btn(row_e, "⚡ 0 (Виснаження)", func(): _set_player_energy(0.0))
	_create_btn(row_e, "+100", func(): _mod_player_energy(100.0))
	_create_btn(row_e, "-100", func(): _mod_player_energy(-100.0))

	# Голод
	var sec_hunger := VBoxContainer.new()
	vbox.add_child(sec_hunger)
	_lbl_hunger = Label.new()
	_lbl_hunger.add_theme_font_size_override("font_size", 14)
	sec_hunger.add_child(_lbl_hunger)

	var row_h := HBoxContainer.new()
	row_h.add_theme_constant_override("separation", 8)
	sec_hunger.add_child(row_h)
	_create_btn(row_h, "🍖 100 (Ситий)", func(): _set_player_hunger(100.0))
	_create_btn(row_h, "🍖 50", func(): _set_player_hunger(50.0))
	_create_btn(row_h, "🍖 10 (Критичний)", func(): _set_player_hunger(10.0))
	_create_btn(row_h, "💀 0 (Смерть)", func(): _set_player_hunger(0.0))
	_create_btn(row_h, "+25", func(): _mod_player_hunger(25.0))
	_create_btn(row_h, "-25", func(): _mod_player_hunger(-25.0))

	# Спрага
	var sec_thirst := VBoxContainer.new()
	vbox.add_child(sec_thirst)
	_lbl_thirst = Label.new()
	_lbl_thirst.add_theme_font_size_override("font_size", 14)
	sec_thirst.add_child(_lbl_thirst)

	var row_t := HBoxContainer.new()
	row_t.add_theme_constant_override("separation", 8)
	sec_thirst.add_child(row_t)
	_create_btn(row_t, "💧 100 (Втамована)", func(): _set_player_thirst(100.0))
	_create_btn(row_t, "💧 50", func(): _set_player_thirst(50.0))
	_create_btn(row_t, "💧 10 (Критична)", func(): _set_player_thirst(10.0))
	_create_btn(row_t, "💀 0 (Смерть)", func(): _set_player_thirst(0.0))
	_create_btn(row_t, "+25", func(): _mod_player_thirst(25.0))
	_create_btn(row_t, "-25", func(): _mod_player_thirst(-25.0))

	# Швидкі дії
	var sec_quick := VBoxContainer.new()
	vbox.add_child(sec_quick)
	var lbl_quick := Label.new()
	lbl_quick.text = "🌟 Загальні чіти та дії:"
	lbl_quick.add_theme_font_size_override("font_size", 14)
	sec_quick.add_child(lbl_quick)

	var row_q := HBoxContainer.new()
	row_q.add_theme_constant_override("separation", 8)
	sec_quick.add_child(row_q)
	_create_btn(row_q, "❤️ Відновити ВСЕ на 100%", func(): _restore_all_stats())
	_create_btn(row_q, "🔄 Респавн на базі", func(): _respawn_player())
	_btn_super_speed = _create_btn(row_q, "🏃 Супершвидкість: Вимк", func(): _toggle_super_speed())


# ------------------------------------------------------------------------------
# 2. Вкладка часу доби
# ------------------------------------------------------------------------------
func _setup_time_tab() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "☀️ Час доби"
	_tab_container.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(vbox)

	_lbl_time = Label.new()
	_lbl_time.add_theme_font_size_override("font_size", 15)
	vbox.add_child(_lbl_time)

	# Швидке перемикання доби
	var sec_presets := VBoxContainer.new()
	vbox.add_child(sec_presets)
	var lbl_p := Label.new()
	lbl_p.text = "🕒 Встановити пору доби:"
	sec_presets.add_child(lbl_p)

	var row_p := HBoxContainer.new()
	row_p.add_theme_constant_override("separation", 8)
	sec_presets.add_child(row_p)
	_create_btn(row_p, "🌅 Ранок (06:00)", func(): _set_time_hours(6.0))
	_create_btn(row_p, "☀️ Полудень (12:00)", func(): _set_time_hours(12.0))
	_create_btn(row_p, "🌇 Захід сонця (18:00)", func(): _set_time_hours(18.0))
	_create_btn(row_p, "🌙 Північ (00:00)", func(): _set_time_hours(0.0))

	# Зсув часу
	var sec_shift := VBoxContainer.new()
	vbox.add_child(sec_shift)
	var lbl_s := Label.new()
	lbl_s.text = "⏳ Зсунути час:"
	sec_shift.add_child(lbl_s)

	var row_s := HBoxContainer.new()
	row_s.add_theme_constant_override("separation", 8)
	sec_shift.add_child(row_s)
	_create_btn(row_s, "+1 Година", func(): _shift_time_hours(1.0))
	_create_btn(row_s, "-1 Година", func(): _shift_time_hours(-1.0))
	_create_btn(row_s, "+6 Годин", func(): _shift_time_hours(6.0))
	_create_btn(row_s, "+1 День (Наступний)", func(): _advance_day())

	# Швидкість плину часу
	var sec_speed := VBoxContainer.new()
	vbox.add_child(sec_speed)
	var lbl_spd := Label.new()
	lbl_spd.text = "⚡ Швидкість гри (Time Scale):"
	sec_speed.add_child(lbl_spd)

	var row_spd := HBoxContainer.new()
	row_spd.add_theme_constant_override("separation", 8)
	sec_speed.add_child(row_spd)
	_create_btn(row_spd, "⏸️ Пауза (x0)", func(): GameManager.set_time_scale(0.0))
	_create_btn(row_spd, "▶️ Норма (x1)", func(): GameManager.set_time_scale(1.0))
	_create_btn(row_spd, "⏩ Швидко (x2)", func(): GameManager.set_time_scale(2.0))
	_create_btn(row_spd, "🚀 Турбо (x5)", func(): GameManager.set_time_scale(5.0))


# ------------------------------------------------------------------------------
# 3. Вкладка видачі предметів
# ------------------------------------------------------------------------------
func _setup_items_tab() -> void:
	var vbox_root := VBoxContainer.new()
	vbox_root.name = "🎒 Видача предметів"
	vbox_root.add_theme_constant_override("separation", 10)
	_tab_container.add_child(vbox_root)

	# Верхній блок швидких комплектів
	var row_bundles := HBoxContainer.new()
	row_bundles.add_theme_constant_override("separation", 8)
	vbox_root.add_child(row_bundles)

	_create_btn(row_bundles, "🎁 Дати по стаку (64) ВСІХ ресурсів", func(): _give_all_resources())
	_create_btn(row_bundles, "🛠️ Дати всі інструменти", func(): _give_all_tools())
	_create_btn(row_bundles, "🗑️ Очистити інвентар", func(): _clear_player_inventory())

	# Список предметів
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox_root.add_child(scroll)

	var items_vbox := VBoxContainer.new()
	items_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	items_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(items_vbox)

	var all_items: Array = ItemDatabase.get_all_items()
	for item_res in all_items:
		var item_id: StringName = StringName(item_res.get("id"))
		var dname: String = str(item_res.get("display_name"))
		var icon: Texture2D = item_res.get("icon")

		var item_row := HBoxContainer.new()
		item_row.add_theme_constant_override("separation", 8)
		items_vbox.add_child(item_row)

		# Іконка
		var tex_rect := TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(28.0, 28.0)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.texture = icon
		item_row.add_child(tex_rect)

		# Назва
		var lbl_name := Label.new()
		lbl_name.text = "%s (%s)" % [dname, item_id]
		lbl_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_row.add_child(lbl_name)

		# Кнопки видачі
		_create_btn(item_row, "+1", func(res=item_res): _give_item(res, 1))
		_create_btn(item_row, "+10", func(res=item_res): _give_item(res, 10))
		_create_btn(item_row, "+64", func(res=item_res): _give_item(res, 64))


# ------------------------------------------------------------------------------
# Допоміжні методи інтерфейсу та команд
# ------------------------------------------------------------------------------
func _create_btn(parent: Node, text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn


func _refresh_display() -> void:
	var player = _get_player()
	if player != null:
		if _lbl_energy != null and "current_energy" in player:
			_lbl_energy.text = "⚡ Енергія: %d / %d" % [int(player.current_energy), int(player.max_energy)]
		if _lbl_hunger != null and "current_hunger" in player:
			_lbl_hunger.text = "🍖 Голод: %d / %d" % [int(ceil(player.current_hunger)), int(player.max_hunger)]
		if _lbl_thirst != null and "current_thirst" in player:
			_lbl_thirst.text = "💧 Спрага: %d / %d" % [int(ceil(player.current_thirst)), int(player.max_thirst)]

	if _lbl_time != null and GameManager != null:
		var hour = GameManager.get_current_hour()
		var icon = "☀️" if (hour >= 6 and hour < 20) else "🌙"
		_lbl_time.text = "%s Поточний час: %s | День: %d (Швидкість: x%.1f)" % [
			icon, GameManager.get_time_string(), GameManager.current_day, GameManager.current_time_scale
		]


func _get_player() -> Node:
	return get_tree().get_first_node_in_group("player")


# Характеристики
func _set_player_energy(val: float) -> void:
	var player = _get_player()
	if player != null and "current_energy" in player:
		player.current_energy = clampf(val, 0.0, player.max_energy)
		player.energy_changed.emit(player.current_energy, player.max_energy)
		if EventBus != null:
			EventBus.player_stats_changed.emit(100.0, 100.0, player.current_energy, player.max_energy)
		_refresh_display()


func _mod_player_energy(delta_val: float) -> void:
	var player = _get_player()
	if player != null and "current_energy" in player:
		_set_player_energy(player.current_energy + delta_val)


func _set_player_hunger(val: float) -> void:
	var player = _get_player()
	if player != null and "current_hunger" in player:
		player.current_hunger = clampf(val, 0.0, player.max_hunger)
		player.hunger_changed.emit(player.current_hunger, player.max_hunger)
		if EventBus != null and EventBus.has_signal("player_survival_changed"):
			EventBus.player_survival_changed.emit(player.current_hunger, player.max_hunger, player.current_thirst, player.max_thirst)
		if player.current_hunger <= 0.0:
			player.die("голоду")
		_refresh_display()


func _mod_player_hunger(delta_val: float) -> void:
	var player = _get_player()
	if player != null and "current_hunger" in player:
		_set_player_hunger(player.current_hunger + delta_val)


func _set_player_thirst(val: float) -> void:
	var player = _get_player()
	if player != null and "current_thirst" in player:
		player.current_thirst = clampf(val, 0.0, player.max_thirst)
		player.thirst_changed.emit(player.current_thirst, player.max_thirst)
		if EventBus != null and EventBus.has_signal("player_survival_changed"):
			EventBus.player_survival_changed.emit(player.current_hunger, player.max_hunger, player.current_thirst, player.max_thirst)
		if player.current_thirst <= 0.0:
			player.die("спраги")
		_refresh_display()


func _mod_player_thirst(delta_val: float) -> void:
	var player = _get_player()
	if player != null and "current_thirst" in player:
		_set_player_thirst(player.current_thirst + delta_val)


func _restore_all_stats() -> void:
	var player = _get_player()
	if player != null:
		_set_player_energy(player.max_energy)
		_set_player_hunger(player.max_hunger)
		_set_player_thirst(player.max_thirst)
	print("[AdminPanel] ❤️ Всі характеристики гравця відновлено на 100%!")


func _respawn_player() -> void:
	var player = _get_player()
	if player != null and player.has_method("respawn"):
		player.respawn()
		_refresh_display()


func _toggle_super_speed() -> void:
	var player = _get_player()
	if player == null:
		return
	_is_super_speed = not _is_super_speed
	if _is_super_speed:
		player.walk_speed = 12.0
		player.sprint_speed = 22.0
		if _btn_super_speed != null:
			_btn_super_speed.text = "🏃 Супершвидкість: УВІМК"
		print("[AdminPanel] 🏃 Супершвидкість увімкнено (12.0 / 22.0 м/с)")
	else:
		player.walk_speed = 5.0
		player.sprint_speed = 7.5
		if _btn_super_speed != null:
			_btn_super_speed.text = "🏃 Супершвидкість: Вимк"
		print("[AdminPanel] 🏃 Швидкість повернуто до норми (5.0 / 7.5 м/с)")


# Час доби
func _set_time_hours(hours: float) -> void:
	if GameManager == null:
		return
	GameManager.in_game_time_seconds = hours * 3600.0
	if EventBus != null:
		EventBus.day_time_updated.emit(GameManager.get_current_hour(), GameManager.get_current_minute())
	_refresh_display()
	print("[AdminPanel] 🕒 Встановлено час доби: %02d:00" % int(hours))


func _shift_time_hours(delta_hours: float) -> void:
	if GameManager == null:
		return
	var new_time = GameManager.in_game_time_seconds + delta_hours * 3600.0
	while new_time >= GameManager.SECONDS_PER_DAY:
		new_time -= GameManager.SECONDS_PER_DAY
		GameManager.current_day += 1
		if EventBus != null:
			EventBus.day_passed.emit(GameManager.current_day)
	while new_time < 0.0:
		new_time += GameManager.SECONDS_PER_DAY
		GameManager.current_day = maxi(1, GameManager.current_day - 1)
	GameManager.in_game_time_seconds = new_time
	if EventBus != null:
		EventBus.day_time_updated.emit(GameManager.get_current_hour(), GameManager.get_current_minute())
	_refresh_display()
	print("[AdminPanel] ⏳ Зсунуто час на %+.1f год -> %s (День %d)" % [delta_hours, GameManager.get_time_string(), GameManager.current_day])


func _advance_day() -> void:
	if GameManager == null:
		return
	GameManager.current_day += 1
	if EventBus != null:
		EventBus.day_passed.emit(GameManager.current_day)
		EventBus.day_time_updated.emit(GameManager.get_current_hour(), GameManager.get_current_minute())
	_refresh_display()
	print("[AdminPanel] 📅 Перехід на День %d" % GameManager.current_day)


# Предмети
func _give_item(res: Resource, count: int) -> void:
	var player = _get_player()
	if player != null and "inventory" in player and player.inventory != null:
		var remainder: int = player.inventory.add_item(res, count)
		var added: int = count - remainder
		print("[AdminPanel] 🎒 Видано %d шт. '%s' у інвентар" % [added, res.get("display_name")])


func _give_all_resources() -> void:
	var player = _get_player()
	if player == null or player.inventory == null:
		return
	var res_ids = [&"wood", &"stone", &"berries", &"clay", &"flint", &"straw", &"voxel_wood", &"voxel_stone"]
	for rid in res_ids:
		var item = ItemDatabase.get_item(rid)
		if item != null:
			player.inventory.add_item(item, 64)
	print("[AdminPanel] 🎁 Видано по стаку (64) всіх базових матеріалів!")


func _give_all_tools() -> void:
	var player = _get_player()
	if player == null or player.inventory == null:
		return
	var tool_ids = [&"stone_axe", &"stone_pickaxe", &"scythe"]
	for tid in tool_ids:
		var item = ItemDatabase.get_item(tid)
		if item != null:
			player.inventory.add_item(item, 1)
	print("[AdminPanel] 🛠️ Видано всі інструменти (Сокира, Кайло, Коса)!")


func _clear_player_inventory() -> void:
	var player = _get_player()
	if player == null or player.inventory == null:
		return
	for slot in player.inventory.slots:
		slot.item = null
		slot.count = 0
	if player.inventory.has_signal("inventory_updated"):
		player.inventory.inventory_updated.emit()
	print("[AdminPanel] 🗑️ Інвентар гравця повністю очищено.")
