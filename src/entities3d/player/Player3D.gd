extends CharacterBody3D

## Player3D: Контролер гравця у 3D світі гри з видом від 1-ї особи (First-Person).
## Керується за допомогою WASD, огляд мишею через Head/Camera3D, взаємодія та збір ресурсів через RayCast3D.
## Підтримує будівництво воксельних блоків (Minecraft-style) на ПКМ та видобуток на ЛКМ.
## Містить повноцінну систему енергії (1000 од. на день) з витратами на біг, видобуток та будівництво.

signal active_slot_changed(slot_index: int)
signal player_interacted(target: Node)
signal energy_changed(current: float, max_val: float)

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 7.5
@export var jump_velocity: float = 7.0
@export var mouse_sensitivity: float = 0.0025
@export var reach_distance: float = 6.0

## Параметри системи енергії
@export var max_energy: float = 1000.0
@export var current_energy: float = 1000.0
@export var sprint_energy_per_sec: float = 0.0
@export var harvest_energy_cost: float = 2.5
@export var construct_energy_cost: float = 6.0
@export var place_block_energy_cost: float = 3.0
@export var rest_regen_rate: float = 0.0

var gravity: float = 18.0
var is_active: bool = true
var is_sleeping: bool = false
var _sleep_tween: Tween = null
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
		EventBus.day_passed.connect(func(_day): restore_energy(max_energy))

	energy_changed.emit(current_energy, max_energy)
	if EventBus != null:
		EventBus.player_stats_changed.emit(100.0, 100.0, current_energy, max_energy)

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

	# Під час сну блокуються будь-які дії та рухи
	if is_sleeping:
		return

	# Керування камерою мишею від 1-ї особи
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		if head != null:
			head.rotate_x(-event.relative.y * mouse_sensitivity)
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
		return

	# Прокручування хотбару колесом миші (як у Minecraft)
	var wheel_delta: int = 0
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			wheel_delta = -1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			wheel_delta = 1

	if event.is_action_pressed("zoom_in"):
		wheel_delta = -1
	elif event.is_action_pressed("zoom_out"):
		wheel_delta = 1

	if wheel_delta != 0:
		var target_slot: int = (active_hotbar_slot + wheel_delta + 8) % 8
		select_hotbar_slot(target_slot)
		get_viewport().set_input_as_handled()
		return

	# Швидкий вибір слотів Hotbar (1-8)
	for i in range(1, 9):
		var action_name: String = "hotbar_%d" % i
		if event.is_action_pressed(action_name):
			select_hotbar_slot(i - 1)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode >= KEY_1 and event.keycode <= KEY_8:
			select_hotbar_slot(event.keycode - KEY_1)
			get_viewport().set_input_as_handled()
			return

	# Вживання їжі (ягоди на ПКМ) або встановлення воксельного блоку (ПКМ як у Minecraft)
	if event.is_action_pressed("secondary_action"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not is_sleeping:
			if _try_consume_food():
				get_viewport().set_input_as_handled()
				return
			if _try_place_block():
				get_viewport().set_input_as_handled()
				return

	# Взаємодія / Збір ресурсів / Будівництво / Сон біля вогнища (ЛКМ або клавіша E як взаємодія зі стореджом)
	if event.is_action_pressed("primary_action") or event.is_action_pressed("interact"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not is_sleeping:
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

	var wants_sprint: bool = Input.is_key_pressed(KEY_SHIFT) and move_direction != Vector3.ZERO
	var can_sprint: bool = current_energy > 0.0

	var speed: float = walk_speed
	if wants_sprint and can_sprint:
		speed = sprint_speed

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


## Витрачає вказану кількість енергії гравця. Повертає true якщо енергія була успішно знята.
func consume_energy(amount: float) -> bool:
	if current_energy <= 0.0:
		return false
	current_energy = maxf(0.0, current_energy - amount)
	energy_changed.emit(current_energy, max_energy)
	if EventBus != null:
		EventBus.player_stats_changed.emit(100.0, 100.0, current_energy, max_energy)
	return true


## Відновлює вказану кількість енергії гравця.
func restore_energy(amount: float) -> void:
	if current_energy >= max_energy:
		return
	current_energy = minf(max_energy, current_energy + amount)
	energy_changed.emit(current_energy, max_energy)
	if EventBus != null:
		EventBus.player_stats_changed.emit(100.0, 100.0, current_energy, max_energy)


## Перевіряє наявність достатньої кількості енергії
func has_energy(amount: float) -> bool:
	return current_energy >= amount


func _show_energy_warning() -> void:
	if EventBus != null and EventBus.has_signal("energy_depleted_action_attempted"):
		EventBus.energy_depleted_action_attempted.emit()
	print("[Player3D] Виснаження! Недостатньо енергії для дії.")


func _try_consume_food() -> bool:
	var active_item_id: StringName = _get_active_item_id()
	if active_item_id == &"berries" and current_energy < max_energy:
		if inventory != null and inventory.get_item_count(&"berries") > 0:
			if inventory.remove_item(&"berries", 1):
				restore_energy(25.0)
				_play_swing_animation()
				print("[Player3D] З'їдено ягоди! Енергію відновлено: +25 (%d/%d)" % [int(current_energy), int(max_energy)])
				return true
	return false


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
		if current_energy < construct_energy_cost:
			_show_energy_warning()
			if collider.has_method("show_temporary_message"):
				collider.show_temporary_message("Недостатньо енергії!", Color(1.0, 0.3, 0.3))
			return
		if collider.interact_construct(inventory):
			consume_energy(construct_energy_cost)
		return

	# 2. Якщо це табірне вогнище (BuildingEntity3D) — взаємодія на E як зі сховищем запускає сон
	if collider.has_method("interact_campfire"):
		collider.interact_campfire(self)
		return

	# 3. Якщо це споруда зі сховищем / склад (BuildingEntity3D)
	if collider.has_method("interact_storage"):
		collider.interact_storage(self)
		return

	# 4. Якщо це природний ресурс (WorldResourceNode3D) або воксельний блок (WorldBlock3D)
	if collider.has_method("harvest"):
		if current_energy < harvest_energy_cost:
			_show_energy_warning()
			return
		var equipped_tool_type: int = _get_active_tool_type()
		var tool_damage: float = _get_active_tool_damage()
		consume_energy(harvest_energy_cost)
		collider.harvest(tool_damage, equipped_tool_type)
		return

	# 5. Загальна взаємодія з об'єктом
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
	if current_energy < place_block_energy_cost:
		_show_energy_warning()
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
	consume_energy(place_block_energy_cost)
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


func is_campfire_built() -> bool:
	var campfires = get_tree().get_nodes_in_group("campfires")
	for c in campfires:
		if is_instance_valid(c) and not c.is_queued_for_deletion():
			return true
	return false


## Запуск сну гравця біля вогнища: плавна анімація камери та відновлення всієї шкали енергії
func start_sleep(duration: float = 2.8) -> void:
	if is_sleeping:
		return

	is_sleeping = true
	velocity = Vector3.ZERO

	if _sleep_tween != null and _sleep_tween.is_valid():
		_sleep_tween.kill()

	_sleep_tween = create_tween()

	if fps_camera != null:
		_sleep_tween.parallel().tween_property(fps_camera, "rotation:x", deg_to_rad(-18.0), duration * 0.4)
		_sleep_tween.parallel().tween_property(fps_camera, "position:y", -0.25, duration * 0.4)

	_sleep_tween.parallel().tween_method(
		func(val: float):
			current_energy = val
			energy_changed.emit(current_energy, max_energy)
			if EventBus != null:
				EventBus.player_stats_changed.emit(100.0, 100.0, current_energy, max_energy),
		current_energy,
		max_energy,
		duration * 0.8
	)

	if fps_camera != null:
		_sleep_tween.chain().tween_property(fps_camera, "rotation:x", 0.0, duration * 0.4)
		_sleep_tween.parallel().tween_property(fps_camera, "position:y", 0.0, duration * 0.4)

	_sleep_tween.tween_callback(complete_sleep)

	if EventBus != null and EventBus.has_signal("player_sleep_started"):
		EventBus.player_sleep_started.emit(duration)

	print("[Player3D] Гравець ліг спати біля багаття на %.1f сек. Енергію повністю відновлено!" % duration)


## Завершення сну: гарантоване повернення камери та зняття блокування
func complete_sleep() -> void:
	is_sleeping = false
	current_energy = max_energy
	if fps_camera != null:
		fps_camera.position = Vector3.ZERO
		fps_camera.rotation = Vector3.ZERO
	energy_changed.emit(current_energy, max_energy)
	if EventBus != null:
		EventBus.player_stats_changed.emit(100.0, 100.0, current_energy, max_energy)
		if EventBus.has_signal("player_sleep_finished"):
			EventBus.player_sleep_finished.emit()


## Обробка взаємодії
func _handle_interact_or_sleep() -> void:
	_try_interact_or_harvest()


func get_player_aabb() -> AABB:
	return AABB(global_position - Vector3(0.3, 0.0, 0.3), Vector3(0.6, 1.8, 0.6))
