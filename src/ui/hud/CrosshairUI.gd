extends Control

## CrosshairUI: Приціл для режиму гри від першої особи (First-Person).
## Відображається лише в режимі прямого керування гравцем (PLAYING)
## та ховається при відкритому інвентарі, меню крафту або переході в режим поселення (RTS).
## Надає детальні контекстні підказки при наведенні на поселенців, вогнище, будівлі та ресурси.

@export var dot_radius: float = 2.5
@export var dot_color: Color = Color(1.0, 1.0, 1.0, 0.75)
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 0.5)

var _interact_label: Label = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.game_state_changed.connect(_on_game_state_changed)
	_setup_interact_hint()
	_update_visibility()


func _setup_interact_hint() -> void:
	_interact_label = Label.new()
	_interact_label.name = "InteractHint"
	_interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_interact_label.set_anchors_preset(Control.PRESET_CENTER)
	_interact_label.offset_top = 22.0
	_interact_label.offset_bottom = 82.0
	_interact_label.offset_left = -320.0
	_interact_label.offset_right = 320.0
	_interact_label.add_theme_font_size_override("font_size", 13)
	_interact_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6, 0.95))
	_interact_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	_interact_label.add_theme_constant_override("outline_size", 4)
	_interact_label.add_theme_constant_override("line_spacing", 2)
	_interact_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interact_label.visible = false
	add_child(_interact_label)


func _process(_delta: float) -> void:
	# Якщо курсор захоплено і стан PLAYING - приціл активний
	var should_be_visible: bool = (
		GameManager.current_state == GameManager.GameState.PLAYING and
		Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	)
	if visible != should_be_visible:
		visible = should_be_visible
	if visible:
		_check_interact_target()


func _on_game_state_changed(_new_state: int, _old_state: int) -> void:
	_update_visibility()


func _update_visibility() -> void:
	visible = (
		GameManager.current_state == GameManager.GameState.PLAYING and
		Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	)


func _draw() -> void:
	var center: Vector2 = size / 2.0
	# Зовнішнє напівпрозоре коло
	draw_circle(center, dot_radius + 1.0, outline_color)
	# Внутрішня біла точка прицілу
	draw_circle(center, dot_radius, dot_color)


func _check_interact_target() -> void:
	if _interact_label == null:
		return
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not is_instance_valid(player):
		_interact_label.visible = false
		return
	var ray = player.get("interact_ray") as RayCast3D
	if ray != null and ray.is_colliding():
		var collider = ray.get_collider()
		if collider != null:
			var player_pos: Vector3 = player.global_position
			var hit_dist: float = player_pos.distance_to(collider.global_position) if collider is Node3D else ray.get_collision_point().distance_to(player_pos)

			# 1. Поселенці (Colonist3D): Ім'я, професія, дистанція, здоров'я, статус роботи
			if collider.is_in_group("colonists"):
				var c_name: String = collider.colonist_name if "colonist_name" in collider and collider.colonist_name != "" else "Поселенець"
				var c_prof: String = collider.get_profession_name() if collider.has_method("get_profession_name") else ""
				var prof_icon := "🌾"
				var raw_prof = collider.get("profession")
				match raw_prof:
					&"builder": prof_icon = "🔨"
					&"lumberjack": prof_icon = "🪓"
					&"hauler": prof_icon = "📦"
					&"settler": prof_icon = "🌾"

				var cur_hp: int = int(collider.get("current_health")) if "current_health" in collider else 100
				var max_hp: int = int(collider.get("max_health")) if "max_health" in collider else 100

				var status_text: String = ""
				if collider.get("is_following_player") == true:
					status_text = "🐾 Слідує за вами"
				elif collider.has_method("is_resting") and collider.is_resting():
					status_text = "💤 Спить біля вогнища"
				elif collider.has_method("get_status_text") and collider.get_status_text() != "":
					status_text = collider.get_status_text()
				elif "status_text" in collider and collider.status_text != "":
					status_text = str(collider.status_text)
				elif "_status_text" in collider and collider._status_text != "":
					status_text = str(collider._status_text)
				else:
					status_text = "Вільний"

				_interact_label.text = "%s %s [%s] • %.1fм • ❤️ %d/%d HP\n%s  |  [E] Говорити / Інвентар" % [
					prof_icon, c_name, c_prof, hit_dist, cur_hp, max_hp, status_text
				]
				_interact_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5, 0.98))
				_interact_label.visible = true
				return

			# 2. Табірне вогнище (BuildingEntity3D)
			var is_campfire := false
			if collider.is_in_group("campfires") or collider.has_method("interact_campfire"):
				is_campfire = true
			elif "building_data" in collider and collider.building_data != null and collider.building_data.id == &"campfire":
				is_campfire = true

			if is_campfire:
				var is_night: bool = GameManager.is_night() if GameManager != null and GameManager.has_method("is_night") else false
				if is_night:
					_interact_label.text = "🔥 Табірне вогнище • %.1fм (Ніч)\n[E] Спати до ранку (Відновити енергію)  |  [X] Знести" % hit_dist
				else:
					_interact_label.text = "🔥 Табірне вогнище • %.1fм\n[E] Відпочити біля вогню  |  [X] Знести" % hit_dist
				_interact_label.add_theme_color_override("font_color", Color(1.0, 0.68, 0.28, 0.98))
				_interact_label.visible = true
				return

			# 3. Інші споруди колонії (склади, скрині тощо)
			if collider.is_in_group("buildings") or collider.has_method("interact_storage") or "building_data" in collider:
				var bld_name: String = "Споруда"
				if "building_data" in collider and collider.building_data != null and collider.building_data.display_name != "":
					bld_name = collider.building_data.display_name

				if collider.has_method("interact_storage") or ("inventory" in collider and collider.inventory != null):
					_interact_label.text = "🏛️ %s • %.1fм\n[E] Відкрити сховище  |  [X] Знести" % [bld_name, hit_dist]
				else:
					_interact_label.text = "🏛️ %s • %.1fм\n[X] Знести" % [bld_name, hit_dist]
				_interact_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55, 0.98))
				_interact_label.visible = true
				return

			# 4. Модульні конструкції хатини (Going Medieval)
			if collider.is_in_group("modular_pieces") or collider.has_method("demolish"):
				var is_built: bool = collider.get("is_built") if "is_built" in collider else false
				if is_built:
					var p_type = collider.get("piece_type")
					if p_type == &"modular_door":
						var is_open: bool = collider.get("is_door_open")
						_interact_label.text = "[E] %s • %.1fм  |  [X] Демонтувати" % [("Зачинити" if is_open else "Відчинити"), hit_dist]
					else:
						var cost_str: String = collider.get_cost_text() if collider.has_method("get_cost_text") else ""
						var refund_suffix: String = " (+%s)" % cost_str if cost_str != "" else ""
						_interact_label.text = "[X] Демонтувати%s • %.1fм" % [refund_suffix, hit_dist]
					_interact_label.add_theme_color_override("font_color", Color("FFD166"))
				else:
					_interact_label.text = "[E]/[ЛКМ] Будувати  |  [X] Скасувати креслення • %.1fм" % hit_dist
					_interact_label.add_theme_color_override("font_color", Color("06D6A0"))
				_interact_label.visible = true
				return

			# 5. Будівельні майданчики (ConstructionSite3D)
			if collider.is_in_group("construction_sites") or collider.has_method("interact_construct"):
				var site_name: String = "Будмайданчик"
				if "building_data" in collider and collider.building_data != null and collider.building_data.display_name != "":
					site_name = collider.building_data.display_name
				_interact_label.text = "🔨 %s • %.1fм\n[E]/[ЛКМ] Будувати молотком" % [site_name, hit_dist]
				_interact_label.add_theme_color_override("font_color", Color("48CAE4"))
				_interact_label.visible = true
				return

			# 6. Природні ресурси світу (дерева, скелі, глина, кремінь, трава)
			if collider.is_in_group("resource_nodes") or collider.has_method("harvest"):
				var res_name: String = "Ресурс"
				var r_type = collider.get("resource_type")
				if r_type != null:
					match int(r_type):
						0: res_name = "Дерево"
						1: res_name = "Скеля (Камінь)"
						2: res_name = "Кущ ягід"
						3: res_name = "Поклади глини"
						4: res_name = "Кремінь"
						5: res_name = "Дика трава"
						_: res_name = "Природний ресурс"
				elif "display_name" in collider:
					res_name = str(collider.display_name)

				var cur_hp: int = int(collider.get("current_health")) if "current_health" in collider else 1
				var max_hp: int = int(collider.get("max_health")) if "max_health" in collider else 1
				_interact_label.text = "⛏️ %s • %.1fм • Міцність: %d/%d\n[ЛКМ]/[E] Видобути ресурс" % [res_name, hit_dist, cur_hp, max_hp]
				_interact_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.65, 0.98))
				_interact_label.visible = true
				return

	_interact_label.visible = false
