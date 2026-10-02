extends Node3D

## RTSCamera3D: Камера стратегічного виду зверху (Top-Down RTS) у стилі Dota 2 / Factorio.
## Забезпечує панорамування WASD, масштабування (зум) коліщатком миші,
## вибір клітинок/об'єктів у 3D світі, та пакетний наказ на збір рамкою (Box Selection).

signal cell_clicked(cell: Vector2i, world_pos: Vector3)
signal object_clicked(object: Node)

@export_group("Movement")
@export var pan_speed: float = 28.0
@export var zoom_step: float = 4.0
@export var min_zoom_height: float = 10.0
@export var max_zoom_height: float = 65.0
@export var default_zoom_height: float = 26.0

@export_group("State")
@export var is_active: bool = false
var is_harvest_order_mode: bool = false

var current_zoom_height: float = 26.0
var _target_zoom_height: float = 26.0

# Рамка виділення для пакетного наказу збору (Box Selection / Drag-to-Harvest)
var _is_dragging_harvest: bool = false
var _drag_start_screen: Vector2 = Vector2.ZERO
var _drag_current_screen: Vector2 = Vector2.ZERO
var _selection_canvas: CanvasLayer = null
var _selection_drawer: Control = null

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	current_zoom_height = default_zoom_height
	_target_zoom_height = default_zoom_height
	_apply_camera_offset()

	_setup_selection_drawer()
	set_active(is_active)

	if EventBus != null and EventBus.has_signal("order_harvest_requested"):
		EventBus.order_harvest_requested.connect(_on_order_harvest_requested)


func _setup_selection_drawer() -> void:
	if _selection_canvas == null:
		_selection_canvas = CanvasLayer.new()
		_selection_canvas.name = "RTSSelectionCanvas"
		_selection_canvas.layer = 50
		add_child(_selection_canvas)

	if _selection_drawer == null:
		_selection_drawer = Control.new()
		_selection_drawer.name = "SelectionBoxDrawer"
		_selection_drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_selection_drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
		_selection_drawer.draw.connect(_on_selection_drawer_draw)
		_selection_canvas.add_child(_selection_drawer)


func _on_selection_drawer_draw() -> void:
	if not _is_dragging_harvest or _selection_drawer == null:
		return
	var rect := Rect2(_drag_start_screen, _drag_current_screen - _drag_start_screen).abs()
	if rect.size.x >= 3.0 and rect.size.y >= 3.0:
		# Напівпрозоре зелене заповнення та виразний акцентний контур
		_selection_drawer.draw_rect(rect, Color(0.2, 0.9, 0.45, 0.18), true)
		_selection_drawer.draw_rect(rect, Color(0.2, 0.95, 0.45, 0.85), false, 2.0)


## Вмикає або вимикає RTS камеру
func set_active(active: bool) -> void:
	is_active = active
	_cancel_box_selection()
	if not active and is_harvest_order_mode:
		set_harvest_order_mode(false)
	if _selection_canvas != null:
		_selection_canvas.visible = active
	set_process_unhandled_input(active)
	set_physics_process(active)
	set_process(active)

	if camera != null:
		camera.current = active

	if is_active:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Фокусує камеру на вказаній світовій позиції
func focus_on_position(pos: Vector3) -> void:
	global_position = Vector3(pos.x, 0.0, pos.z)


func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	# 1. Обробка активного перетягування рамки збору
	if _is_dragging_harvest:
		if event is InputEventMouseMotion:
			_drag_current_screen = event.position
			if _selection_drawer != null:
				_selection_drawer.queue_redraw()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_released("primary_action"):
			_finish_box_selection()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("cancel") or event.is_action_pressed("secondary_action"):
			_cancel_box_selection()
			get_viewport().set_input_as_handled()
			return

	# 2. Перевірка режиму розміщення креслення (Building Placement)
	if BuildingPlacementController != null and BuildingPlacementController.is_placing():
		var is_rotate_action: bool = event.is_action_pressed("rotate_building")
		var is_r_key: bool = event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_R or event.keycode == KEY_R)
		if is_rotate_action or is_r_key:
			var step: int = -1 if ((event is InputEventWithModifiers and event.shift_pressed) or Input.is_key_pressed(KEY_SHIFT)) else 1
			BuildingPlacementController.rotate_placement(step)
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("cancel") or event.is_action_pressed("secondary_action"):
			BuildingPlacementController.cancel_placement()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("primary_action"):
			if BuildingPlacementController.confirm_placement():
				get_viewport().set_input_as_handled()
				return

	# 3. Режим виділення збору ресурсів або затиснута клавіша [H]
	var is_h_held: bool = Input.is_action_pressed("order_harvest") or Input.is_key_pressed(KEY_H)
	if is_harvest_order_mode or is_h_held:
		if event.is_action_pressed("cancel") or event.is_action_pressed("secondary_action"):
			if is_harvest_order_mode:
				set_harvest_order_mode(false)
				get_viewport().set_input_as_handled()
				return
		elif event.is_action_pressed("primary_action"):
			_is_dragging_harvest = true
			_drag_start_screen = get_viewport().get_mouse_position()
			_drag_current_screen = _drag_start_screen
			get_viewport().set_input_as_handled()
			return

	# 4. Зум коліщатком миші
	if event.is_action_pressed("zoom_in"):
		_target_zoom_height = clampf(_target_zoom_height - zoom_step, min_zoom_height, max_zoom_height)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("zoom_out"):
		_target_zoom_height = clampf(_target_zoom_height + zoom_step, min_zoom_height, max_zoom_height)
		get_viewport().set_input_as_handled()
		return

	# 5. Демонтаж на клавішу X під курсором миші в режимі RTS
	var is_demolish_action: bool = event.is_action_pressed("demolish_building")
	var is_x_key: bool = event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.physical_keycode == KEY_X or event.keycode == KEY_X)
	if is_demolish_action or is_x_key:
		if _handle_demolish_at_mouse():
			get_viewport().set_input_as_handled()
			return

	# 6. Наказ на збір ресурсу на клавішу H під курсором миші або перемикання режиму виділення
	var is_harvest_action: bool = event.is_action_pressed("order_harvest")
	var is_h_key: bool = event is InputEventKey and event.is_pressed() and not event.is_echo() and (event.physical_keycode == KEY_H or event.keycode == KEY_H)
	if is_harvest_action or is_h_key:
		if _handle_order_harvest_at_mouse():
			get_viewport().set_input_as_handled()
			return
		else:
			set_harvest_order_mode(not is_harvest_order_mode)
			get_viewport().set_input_as_handled()
			return

	# 7. Стандартний клік мишкою у 3D просторі
	if event.is_action_pressed("primary_action"):
		_handle_mouse_click()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not is_active or camera == null:
		return

	if BuildingPlacementController != null and BuildingPlacementController.is_placing():
		var cell: Vector2i = _get_hovered_ground_cell()
		if cell.x != -9999:
			BuildingPlacementController.update_hover(cell)


func _physics_process(delta: float) -> void:
	if not is_active:
		return

	# Плавне наближення/віддалення зуму
	if not is_equal_approx(current_zoom_height, _target_zoom_height):
		current_zoom_height = lerpf(current_zoom_height, _target_zoom_height, delta * 10.0)
		_apply_camera_offset()

	# Переміщення камери WASD по площині землі
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir != Vector2.ZERO:
		var move_vec: Vector3 = Vector3(input_dir.x, 0.0, input_dir.y).normalized()
		global_position += move_vec * pan_speed * delta


func _apply_camera_offset() -> void:
	if camera == null:
		return
	var z_offset: float = current_zoom_height * 0.7
	camera.position = Vector3(0.0, current_zoom_height, z_offset)
	camera.rotation_degrees = Vector3(-55.0, 0.0, 0.0)


func _get_hovered_ground_cell() -> Vector2i:
	if camera == null:
		return Vector2i(-9999, -9999)

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_normal: Vector3 = camera.project_ray_normal(mouse_pos)

	if absf(ray_normal.y) > 0.0001:
		var t: float = -ray_origin.y / ray_normal.y
		if t > 0.0:
			var ground_point: Vector3 = ray_origin + (ray_normal * t)
			return GridManager.world_to_map_3d(ground_point)

	return Vector2i(-9999, -9999)


func _handle_mouse_click() -> void:
	if camera == null:
		return

	if BuildingPlacementController != null and BuildingPlacementController.is_placing():
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_normal: Vector3 = camera.project_ray_normal(mouse_pos)

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + (ray_normal * 200.0))
	var result = space_state.intersect_ray(query)

	if result.is_empty():
		if absf(ray_normal.y) > 0.0001:
			var t: float = -ray_origin.y / ray_normal.y
			if t > 0.0:
				var ground_point: Vector3 = ray_origin + (ray_normal * t)
				var cell: Vector2i = GridManager.world_to_map_3d(ground_point)
				cell_clicked.emit(cell, ground_point)
		return

	var hit_collider = result.get("collider")
	var hit_pos: Vector3 = result.get("position")
	var hit_cell: Vector2i = GridManager.world_to_map_3d(hit_pos)

	if hit_collider != null:
		object_clicked.emit(hit_collider)
		if hit_collider.has_method("harvest"):
			hit_collider.harvest(1.0, 0)
		elif hit_collider.has_method("interact_construct"):
			var player_node = get_tree().get_first_node_in_group("player")
			var player_inv = player_node.inventory if player_node != null and "inventory" in player_node else null
			hit_collider.interact_construct(player_inv)
		elif hit_collider.has_method("interact_storage"):
			hit_collider.interact_storage()
		elif hit_collider.has_method("interact"):
			var player_node = get_tree().get_first_node_in_group("player")
			hit_collider.interact(player_node)

	cell_clicked.emit(hit_cell, hit_pos)


func _handle_demolish_at_mouse() -> bool:
	if camera == null:
		return false
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_normal: Vector3 = camera.project_ray_normal(mouse_pos)

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + (ray_normal * 200.0))
	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return false

	var collider = result.get("collider")
	var target = collider
	while target != null and not target.has_method("demolish") and target.get_parent() != null and not (target.name == "Buildings" or target.name == "ModularContainer" or target.name == "World3D"):
		target = target.get_parent()

	if target != null and target.has_method("demolish"):
		var player_node = get_tree().get_first_node_in_group("player")
		var player_inv = player_node.inventory if player_node != null and "inventory" in player_node else null
		var res: Dictionary = target.demolish(player_inv)
		if res.get("success", false) and player_node != null and "current_energy" in player_node and player_node.current_energy > 0.0:
			if player_node.has_method("consume_energy"):
				player_node.consume_energy(2.0)
		return true
	return false


# ------------------------------------------------------------------------------
# Створення завдання збору для конкретного ресурсного вузла
# ------------------------------------------------------------------------------
func _create_harvest_job_for_node(target: Node) -> bool:
	if target == null or not is_instance_valid(target) or target.is_queued_for_deletion():
		return false
	if not target.is_in_group("resource_nodes") and not target.has_method("harvest"):
		return false
	if JobManager == null:
		return false
	if JobManager.has_method("has_job_for_target") and JobManager.has_job_for_target(target):
		return false

	var res_type = target.get("resource_type")
	var prof: StringName = &""
	if res_type != null:
		match int(res_type):
			0:
				prof = &"lumberjack"
			_:
				prof = &""

	var job_pos: Vector3 = target.global_position if target is Node3D else global_position
	JobManager.create_job(Job.JobType.HARVEST, job_pos, target, 2, prof, { "resource_type": res_type })
	return true


func _handle_order_harvest_at_mouse() -> bool:
	if camera == null:
		return false
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_normal: Vector3 = camera.project_ray_normal(mouse_pos)

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + (ray_normal * 200.0))
	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return false

	var collider = result.get("collider")
	var target = collider
	while target != null and not target.is_in_group("resource_nodes") and not target.has_method("harvest") and target.get_parent() != null and not (target.name == "World3D" or target.name == "ChunkManager3D"):
		target = target.get_parent()

	if target == null or (not target.is_in_group("resource_nodes") and not target.has_method("harvest")):
		return false

	if JobManager == null:
		return false

	if JobManager.has_method("has_job_for_target") and JobManager.has_job_for_target(target):
		if FloatingTextManager != null:
			FloatingTextManager.spawn_info(target.global_position + Vector3(0, 1.2, 0), "⚠️ Завдання вже призначено")
		return true

	var res_type = target.get("resource_type")
	var res_name: String = "ресурс"
	if res_type != null:
		match int(res_type):
			0: res_name = "Дерево"
			1: res_name = "Камінь"
			2: res_name = "Ягоди"
			3: res_name = "Глину"
			4: res_name = "Кремінь"
			5: res_name = "Траву"
	elif "display_name" in target:
		res_name = str(target.display_name)

	var success: bool = _create_harvest_job_for_node(target)
	if success:
		if AudioManager != null:
			AudioManager.play_sound(&"click", -2.0, 1.1)
		var job_pos: Vector3 = target.global_position if target is Node3D else global_position
		if FloatingTextManager != null:
			FloatingTextManager.spawn_info(job_pos + Vector3(0, 1.2, 0), "📋 Призначено збір: %s" % res_name)
		return true

	return false


# ------------------------------------------------------------------------------
# Пакетний наказ на збір рамкою (Box Selection / Drag-to-Harvest)
# ------------------------------------------------------------------------------
func _cancel_box_selection() -> void:
	if _is_dragging_harvest:
		_is_dragging_harvest = false
		if _selection_drawer != null:
			_selection_drawer.queue_redraw()


func _finish_box_selection() -> void:
	if not _is_dragging_harvest:
		return
	_is_dragging_harvest = false
	if _selection_drawer != null:
		_selection_drawer.queue_redraw()

	var drag_dist: float = _drag_start_screen.distance_to(_drag_current_screen)
	if drag_dist > 8.0:
		_order_harvest_in_box(_drag_start_screen, _drag_current_screen)
	else:
		_handle_order_harvest_at_mouse()


func _order_harvest_in_box(start_pos: Vector2, end_pos: Vector2) -> int:
	if camera == null or JobManager == null:
		return 0

	var rect := Rect2(start_pos, end_pos - start_pos).abs()
	if rect.size.x < 4.0 or rect.size.y < 4.0:
		return 0

	var candidates: Array[Node] = get_tree().get_nodes_in_group("resource_nodes")
	var ordered_count: int = 0
	var already_assigned_count: int = 0
	var selected_positions: Array[Vector3] = []

	for node in candidates:
		var node3d := node as Node3D
		if node3d == null or not is_instance_valid(node3d) or node3d.is_queued_for_deletion():
			continue

		var base_pos := node3d.global_position
		if camera.is_position_behind(base_pos):
			continue

		var screen_base := camera.unproject_position(base_pos)
		var screen_top := camera.unproject_position(base_pos + Vector3(0.0, 1.2, 0.0))

		if rect.has_point(screen_base) or rect.has_point(screen_top):
			if JobManager.has_method("has_job_for_target") and JobManager.has_job_for_target(node3d):
				already_assigned_count += 1
			else:
				if _create_harvest_job_for_node(node3d):
					ordered_count += 1
					selected_positions.append(base_pos)

	if ordered_count > 0:
		if AudioManager != null:
			AudioManager.play_sound(&"click", -1.0, 1.25)
		var center_3d: Vector3 = Vector3.ZERO
		for p in selected_positions:
			center_3d += p
		center_3d /= float(selected_positions.size())
		if FloatingTextManager != null:
			FloatingTextManager.spawn_info(center_3d + Vector3(0, 1.6, 0), "📋 Призначено збір: %d ресурсів!" % ordered_count, Color("55E6C1"))
	elif already_assigned_count > 0:
		var center_screen := rect.get_center()
		var center_3d := _screen_to_ground(center_screen)
		if FloatingTextManager != null:
			FloatingTextManager.spawn_info(center_3d + Vector3(0, 1.6, 0), "⚠️ Усі виділені ресурси (%d) вже призначено" % already_assigned_count, Color("F8EFBA"))

	return ordered_count


func _screen_to_ground(screen_pos: Vector2) -> Vector3:
	if camera == null:
		return global_position
	var ray_origin: Vector3 = camera.project_ray_origin(screen_pos)
	var ray_normal: Vector3 = camera.project_ray_normal(screen_pos)
	if absf(ray_normal.y) > 0.0001:
		var t: float = -ray_origin.y / ray_normal.y
		if t > 0.0:
			return ray_origin + (ray_normal * t)
	return global_position


func _on_order_harvest_requested() -> void:
	if not is_active:
		return
	if _handle_order_harvest_at_mouse():
		return
	set_harvest_order_mode(not is_harvest_order_mode)


func set_harvest_order_mode(active: bool) -> void:
	if is_harvest_order_mode == active:
		return
	is_harvest_order_mode = active
	_cancel_box_selection()

	if EventBus != null and EventBus.has_signal("order_harvest_mode_toggled"):
		EventBus.order_harvest_mode_toggled.emit(is_harvest_order_mode)

	if FloatingTextManager != null:
		if is_harvest_order_mode:
			FloatingTextManager.spawn_info(global_position + Vector3(0, 3.0, 0), "🌾 Режим виділення: клікайте або виділяйте рамкою (ПКМ/Esc для виходу)", Color("55E6C1"))
		else:
			FloatingTextManager.spawn_info(global_position + Vector3(0, 3.0, 0), "🌾 Режим виділення збору вимкнено", Color("BDC581"))
