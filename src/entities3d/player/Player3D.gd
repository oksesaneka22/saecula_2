extends CharacterBody3D

## Player3D: Контролер гравця у 3D світі гри з видом від 1-ї особи (First-Person).
## Керується за допомогою WASD, огляд мишею через Head/Camera3D, взаємодія та збір ресурсів через RayCast3D.
## Підтримує будівництво воксельних блоків (Minecraft-style) на ПКМ та видобуток на ЛКМ.

signal active_slot_changed(slot_index: int)
signal player_interacted(target: Node)

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 7.5
@export var jump_velocity: float = 7.0
@export var mouse_sensitivity: float = 0.0025
@export var reach_distance: float = 4.5

var gravity: float = 18.0
var is_active: bool = true
var active_hotbar_slot: int = 0
var _swing_tween: Tween = null

const BlockGhost3DScript = preload("res://src/world3d/blocks/BlockGhost3D.gd")
var block_ghost: Node3D = null

@onready var head: Node3D = $Head
@onready var fps_camera: Camera3D = $Head/FPSCamera
@onready var interact_ray: RayCast3D = $Head/InteractRay
@onready var inventory: Node = $InventoryComponent
@onready var visual_body: Node3D = $VisualBody


func _ready() -> void:
	add_to_group("player")
	set_active(true)
	interact_ray.target_position = Vector3(0, 0, -reach_distance)

	block_ghost = BlockGhost3DScript.new()
	block_ghost.name = "BlockGhost3D"
	block_ghost.top_level = true
	add_child(block_ghost)
	block_ghost.hide_ghost()

	if EventBus != null:
		EventBus.hotbar_slot_selected.connect(_on_hotbar_slot_selected)

	# Надаємо гравцю стартовий комплект інструментів та матеріалів:
	# Слот 1 (Wood) та Слот 2 (Stone) для миттєвого тестування будівництва на ПКМ!
	if inventory != null:
		if inventory.get_item_count(&"wood") == 0:
			inventory.add_item_by_id(&"stone_axe", 1)
			inventory.add_item_by_id(&"stone_pickaxe", 1)
			inventory.add_item_by_id(&"wood", 64)
			inventory.add_item_by_id(&"stone", 64)
			inventory.add_item_by_id(&"straw", 64)


func _on_hotbar_slot_selected(slot_index: int) -> void:
	if active_hotbar_slot != slot_index:
		active_hotbar_slot = slot_index
		active_slot_changed.emit(active_hotbar_slot)


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

	# Прокручування хотбару колесом миші (як у Minecraft)
	if event.is_action_pressed("zoom_in"):
		var prev_slot: int = (active_hotbar_slot - 1 + 8) % 8
		select_hotbar_slot(prev_slot)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("zoom_out"):
		var next_slot: int = (active_hotbar_slot + 1) % 8
		select_hotbar_slot(next_slot)
		get_viewport().set_input_as_handled()
		return

	# Швидкий вибір слотів Hotbar (1-8)
	for i in range(1, 9):
		var action_name: String = "hotbar_%d" % i
		if event.is_action_pressed(action_name):
			select_hotbar_slot(i - 1)
			get_viewport().set_input_as_handled()
			return

	# Встановлення воксельного блоку (ПКМ як у Minecraft)
	if event.is_action_pressed("secondary_action"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			if _try_place_block():
				get_viewport().set_input_as_handled()
				return

	# Взаємодія / Збір ресурсів / Будівництво (ЛКМ або E)
	if event.is_action_pressed("primary_action") or event.is_action_pressed("interact"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_try_interact_or_harvest()
			get_viewport().set_input_as_handled()
			return


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
	_update_block_ghost()


func select_hotbar_slot(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < 8:
		active_hotbar_slot = slot_index
		active_slot_changed.emit(active_hotbar_slot)
		if EventBus != null:
			EventBus.hotbar_slot_selected.emit(active_hotbar_slot)


func _try_interact_or_harvest() -> void:
	# Анімація помаху головою/камерою
	_play_swing_animation()

	if interact_ray == null or not interact_ray.is_colliding():
		return

	var collider = interact_ray.get_collider()
	if collider == null:
		return

	player_interacted.emit(collider)

	# 1. Якщо це модульний блок (ModularPiece3D) або будівельний майданчик (ConstructionSite3D)
	if collider.has_method("interact_construct"):
		if collider.get("is_built") == true:
			if collider.has_method("interact"):
				collider.interact(self)
				return
		collider.interact_construct(inventory)
		return

	# 2. Якщо це споруда зі сховищем / склад (BuildingEntity3D)
	if collider.has_method("interact_storage"):
		collider.interact_storage(self)
		return

	# 3. Якщо це природний ресурс (WorldResourceNode3D) або блок (WorldBlock3D)
	if collider.has_method("harvest"):
		var equipped_tool_type: int = _get_active_tool_type()
		var tool_damage: float = _get_active_tool_damage()
		collider.harvest(tool_damage, equipped_tool_type)
		return

	# 4. Загальна взаємодія з об'єктом
	if collider.has_method("interact"):
		collider.interact(self)
		return


func _play_swing_animation() -> void:
	if fps_camera == null:
		return
	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()
	fps_camera.rotation_degrees.x = 0.0
	_swing_tween = create_tween()
	_swing_tween.tween_property(fps_camera, "rotation_degrees:x", -2.5, 0.04)
	_swing_tween.tween_property(fps_camera, "rotation_degrees:x", 0.0, 0.08)


func _get_active_tool_type() -> int:
	if inventory == null:
		return 0
	var slot = null
	if inventory.has_method("get_slot"):
		slot = inventory.get_slot(active_hotbar_slot)
	elif "slots" in inventory and active_hotbar_slot < inventory.slots.size():
		slot = inventory.slots[active_hotbar_slot]
	if slot != null and slot.item != null:
		var raw_val = slot.item.get("tool_type")
		return int(raw_val) if raw_val != null else 0
	return 0


func _get_active_tool_damage() -> float:
	if inventory == null:
		return 1.0
	var slot = null
	if inventory.has_method("get_slot"):
		slot = inventory.get_slot(active_hotbar_slot)
	elif "slots" in inventory and active_hotbar_slot < inventory.slots.size():
		slot = inventory.slots[active_hotbar_slot]
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


func _try_place_block() -> bool:
	var active_item_id: StringName = _get_active_item_id()
	if not BlockManager.is_placeable_block(active_item_id):
		return false
	if inventory == null or inventory.get_item_count(active_item_id) <= 0:
		return false
	if interact_ray == null or not interact_ray.is_colliding():
		return false

	var hit_point: Vector3 = interact_ray.get_collision_point()
	var hit_normal: Vector3 = interact_ray.get_collision_normal()
	var place_pos: Vector3 = hit_point + hit_normal * 0.5
	var target_coord: Vector3i = BlockManager.world_to_block_coord(place_pos)

	if not BlockManager.can_place_block_at(target_coord, get_player_aabb()):
		return false

	var removed: bool = inventory.remove_item(active_item_id, 1)
	if not removed:
		return false

	var block = BlockManager.place_block(active_item_id, target_coord)
	_play_swing_animation()
	print("[Player3D] Встановлено блок '%s' на позиції %s" % [active_item_id, str(target_coord)])
	return true


func _update_block_ghost() -> void:
	if block_ghost == null:
		return
	if not is_active or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		block_ghost.hide_ghost()
		return

	var active_item_id: StringName = _get_active_item_id()
	if not BlockManager.is_placeable_block(active_item_id):
		block_ghost.hide_ghost()
		return

	if interact_ray == null or not interact_ray.is_colliding():
		block_ghost.hide_ghost()
		return

	var hit_point: Vector3 = interact_ray.get_collision_point()
	var hit_normal: Vector3 = interact_ray.get_collision_normal()
	var place_pos: Vector3 = hit_point + hit_normal * 0.5
	var target_coord: Vector3i = BlockManager.world_to_block_coord(place_pos)
	var can_place: bool = BlockManager.can_place_block_at(target_coord, get_player_aabb())
	block_ghost.show_at(target_coord, can_place)


func _get_active_item_id() -> StringName:
	if inventory == null:
		return &""
	var slot = null
	if inventory.has_method("get_slot"):
		slot = inventory.get_slot(active_hotbar_slot)
	elif "slots" in inventory and active_hotbar_slot < inventory.slots.size():
		slot = inventory.slots[active_hotbar_slot]
	if slot != null and slot.item != null:
		return slot.item.id
	return &""


func get_player_aabb() -> AABB:
	return AABB(global_position - Vector3(0.3, 0.0, 0.3), Vector3(0.6, 1.8, 0.6))
