extends Node3D

## RTSCamera3D: Камера огляду та менеджменту поселення зверху (Top-Down RTS / Dota / Factorio).
## Підтримує переміщення WASD по карті, плавний зум коліщатком миші,
## та вибір об'єктів/клітинок кліком курсора миші через 3D Raycast.

signal cell_clicked(cell: Vector2i, world_pos: Vector3)
signal object_clicked(object: Node)

@export var pan_speed: float = 18.0
@export var min_zoom_height: float = 8.0
@export var max_zoom_height: float = 36.0
@export var current_zoom_height: float = 20.0
@export var zoom_step: float = 3.0

var is_active: bool = false
var _target_zoom_height: float = 20.0

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	_target_zoom_height = current_zoom_height
	_apply_camera_offset()


func set_active(active: bool) -> void:
	is_active = active
	if camera != null:
		camera.current = active

	if is_active:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Фокусує камеру на вказаній світовій позиції (наприклад, на гравцеві при переході)
func focus_on_position(pos: Vector3) -> void:
	global_position = Vector3(pos.x, 0.0, pos.z)


func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	# Зум коліщатком миші
	if event.is_action_pressed("zoom_in"):
		_target_zoom_height = clampf(_target_zoom_height - zoom_step, min_zoom_height, max_zoom_height)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("zoom_out"):
		_target_zoom_height = clampf(_target_zoom_height + zoom_step, min_zoom_height, max_zoom_height)
		get_viewport().set_input_as_handled()
		return

	# Клік мишкою у 3D просторі (вибір об'єкта або клітинки сітки)
	if event.is_action_pressed("primary_action"):
		_handle_mouse_click()
		get_viewport().set_input_as_handled()


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
	# Кут нахилу камери ~55 градусів (Dota 2 / RTS стиль)
	var z_offset: float = current_zoom_height * 0.7
	camera.position = Vector3(0.0, current_zoom_height, z_offset)
	camera.rotation_degrees = Vector3(-55.0, 0.0, 0.0)


func _handle_mouse_click() -> void:
	if camera == null:
		return

	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = camera.project_ray_origin(mouse_pos)
	var ray_normal: Vector3 = camera.project_ray_normal(mouse_pos)

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + (ray_normal * 200.0))
	var result = space_state.intersect_ray(query)

	if result.is_empty():
		# Якщо промінь не перетнув меш колізії, перетинаємо з площиною Y = 0
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
		# Якщо клікнули по ресурсу в RTS режимі — завдаємо удару
		if hit_collider.has_method("harvest"):
			hit_collider.harvest(1.0, 0)

	cell_clicked.emit(hit_cell, hit_pos)
