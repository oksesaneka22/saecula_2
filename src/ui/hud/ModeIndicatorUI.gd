extends PanelContainer

## ModeIndicatorUI: Верхня панель статусу та індикатор ігрового режиму.
## Відображає поточний режим гри (1st Person, RTS, Будівництво),
## назву поточної епохи, лічильник населення (усього / зайнятих / вільних робітників)
## та стабільний FPS-монітор з адаптивною адаптацією під будь-які роздільності екрана.

@onready var label: Label = $MarginContainer/Label

var _fps_timer: float = 0.0
var _current_fps: int = 60

func _process(delta: float) -> void:
	_fps_timer += delta
	if _fps_timer >= 0.4:
		_fps_timer = 0.0
		_current_fps = Engine.get_frames_per_second()
		_update_label(GameManager.current_state)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.game_state_changed.connect(_on_game_state_changed)
	if EraManager != null:
		if EraManager.has_signal("era_changed"):
			EraManager.era_changed.connect(func(_idx, _name): _update_label(GameManager.current_state))
		if EraManager.has_signal("sub_era_changed"):
			EraManager.sub_era_changed.connect(func(_id, _name): _update_label(GameManager.current_state))
	_update_label(GameManager.current_state)

func _on_game_state_changed(new_state: int, _old_state: int) -> void:
	_update_label(new_state)

func _update_label(state: int) -> void:
	if label == null:
		return

	# Отримуємо назву епохи
	var era_str: String = ""
	if EraManager != null and EraManager.has_method("get_current_era_name"):
		era_str = "🏛️ " + EraManager.get_current_era_name()

	# Отримуємо дані поселення (населення, зайнятість)
	var pop_str: String = ""
	if JobManager != null:
		var total_pop: int = JobManager.get_colonists_count() if JobManager.has_method("get_colonists_count") else 0
		var active_workers: int = 0
		var all_colonists: Array = JobManager.get_all_colonists() if JobManager.has_method("get_all_colonists") else []
		for c in all_colonists:
			if c != null and is_instance_valid(c) and c.get("current_job") != null:
				active_workers += 1
		var idle_workers: int = maxi(0, total_pop - active_workers)
		pop_str = "👥 Жителів: %d (🔨 %d | 💤 %d)" % [total_pop, active_workers, idle_workers]

	var meta_part: String = ""
	if not era_str.is_empty():
		meta_part += era_str + " • "
	if not pop_str.is_empty():
		meta_part += pop_str + " • "

	match state:
		GameManager.GameState.PLAYING:
			label.text = "%s🎯 РЕЖИМ ГРАВЦЯ (1st Person) • [Tab] Колонія (RTS) • FPS: %d" % [meta_part, _current_fps]
			label.modulate = Color("A8DADC")
		GameManager.GameState.COLONY_MODE:
			var rts_cam = get_tree().get_first_node_in_group("rts_camera")
			var selected_col = rts_cam.get_selected_colonist() if (rts_cam != null and rts_cam.has_method("get_selected_colonist")) else null
			if selected_col != null and is_instance_valid(selected_col):
				var col_name: String = selected_col.get("colonist_name") if "colonist_name" in selected_col else "Колоніст"
				var col_status: String = selected_col.get_status_text() if selected_col.has_method("get_status_text") else ""
				label.text = "%s🏰 RTS [Обрано: %s | %s] • [ПКМ] Наказ • [Z] Стоп • [C] Наступний • [E] Картка • [Esc] Скинути • FPS: %d" % [meta_part, col_name, col_status, _current_fps]
				label.modulate = Color("E9C46A")
			else:
				label.text = "%s🏰 РЕЖИМ ПОСЕЛЕННЯ (RTS) • [WASD] Камера • [C] Колоніст • [H] Збір • [B] Будівництво • [Tab] Гравець • FPS: %d" % [meta_part, _current_fps]
				label.modulate = Color("F4A261")
		GameManager.GameState.BUILDING_MODE:
			label.text = "%s🔨 РЕЖИМ БУДІВНИЦТВА • [ЛКМ] Розмістити | [Esc] Скасувати • FPS: %d" % [meta_part, _current_fps]
			label.modulate = Color("2A9D8F")
		_:
			label.text = ""
