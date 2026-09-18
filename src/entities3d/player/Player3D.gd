extends CharacterBody3D

## Player3D: Персонаж гравця від першої особи (First-Person Mode).
## Підтримує рух WASD, стрибки, огляд мишею, збір ресурсів через RayCast
## та містить модульний InventoryComponent (24 слоти).

signal active_slot_changed(slot_index: int)
signal player_interacted(target: Node)

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 7.5
@export var jump_velocity: float = 4.8
@export var mouse_sensitivity: float = 0.0025
@export var reach_distance: float = 3.2

var gravity: float = 18.0
var is_active: bool = true
var active_hotbar_slot: int = 0
var _swing_tween: Tween = null

@onready var head: Node3D = $Head
@onready var fps_camera: Camera3D = $Head/FPSCamera
@onready var interact_ray: RayCast3D = $Head/InteractRay
@onready var inventory: Node = $InventoryComponent
@onready var visual_body: Node3D = $VisualBody


func _ready() -> void:
	add_to_group("player")
	set_active(true)
	interact_ray.target_position = Vector3(0, 0, -reach_distance)


func set_active(active: bool) -> void:
	is_active = active
	if fps_camera != null:
		fps_camera.current = active

	if is_active:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		velocity = Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	# Огляд мишею від першої особи
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, -deg_to_rad(85.0), deg_to_rad(85.0))
		get_viewport().set_input_as_handled()
		return

	# Швидкий вибір слотів Hotbar (1-8)
	for i in range(1, 9):
		var action_name: String = "hotbar_%d" % i
		if event.is_action_pressed(action_name):
			select_hotbar_slot(i - 1)
			get_viewport().set_input_as_handled()
			return

	# Взаємодія / Удар по ресурсу від першої особи
	if event.is_action_pressed("primary_action") or event.is_action_pressed("interact"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_try_interact_or_harvest()
			get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not is_active:
		return

	# Гравітація
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Стрибок
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# Напрямок руху відносно погляду персонажа
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var move_direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var speed: float = sprint_speed if Input.is_key_pressed(KEY_SHIFT) else walk_speed
	if move_direction != Vector3.ZERO:
		velocity.x = move_direction.x * speed
		velocity.z = move_direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)

	move_and_slide()


func _try_interact_or_harvest() -> void:
	# Анімація помаху головою/камерою
	_play_swing_animation()

	if interact_ray == null or not interact_ray.is_colliding():
		return

	var collider = interact_ray.get_collider()
	if collider == null:
		return

	player_interacted.emit(collider)

	if collider.has_method("harvest"):
		var equipped_tool_type: int = _get_active_tool_type()
		var tool_damage: float = _get_active_tool_damage()
		collider.harvest(tool_damage, equipped_tool_type)


func _play_swing_animation() -> void:
	if fps_camera == null:
		return
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	fps_camera.rotation_degrees.x = 0.0
	_swing_tween = create_tween()
	_swing_tween.tween_property(fps_camera, "rotation_degrees:x", -2.5, 0.04)
	_swing_tween.tween_property(fps_camera, "rotation_degrees:x", 0.0, 0.08)


func select_hotbar_slot(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < 8:
		active_hotbar_slot = slot_index
		active_slot_changed.emit(active_hotbar_slot)


func _get_active_tool_type() -> int:
	if inventory == null or not inventory.has_method("get_slot"):
		return 0
	var slot = inventory.get_slot(active_hotbar_slot)
	if slot != null and slot.item != null:
		var raw_val = slot.item.get("tool_type")
		return int(raw_val) if raw_val != null else 0
	return 0


func _get_active_tool_damage() -> float:
	if inventory == null or not inventory.has_method("get_slot"):
		return 1.0
	var slot = inventory.get_slot(active_hotbar_slot)
	if slot != null and slot.item != null:
		var raw_eff = slot.item.get("tool_efficiency")
		if raw_eff == null:
			raw_eff = slot.item.get("efficiency")
		var efficiency: float = float(raw_eff) if raw_eff != null else 1.0
		return maxf(efficiency, 1.0)
	return 1.0


## Повертає поточну клітинку сітки у 3D світі (X-Z площина)
func get_current_cell_3d() -> Vector2i:
	return GridManager.world_to_map_3d(global_position)
