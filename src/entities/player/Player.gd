extends CharacterBody2D

## Player: Основний контролер персонажа гравця під прямим керуванням.
## Підтримує плавний 8-напрямний рух (WASD), визначення вектора погляду,
## взаємодію з ресурсами у світі ('E' або лівий клік миші),
## реакцію на стан гри (GameManager.GameState), роботу з тайловою сіткою
## та компонент інвентаря гравця.

# ------------------------------------------------------------------------------
# Константи та експортні змінні
# ------------------------------------------------------------------------------
@export var move_speed: float = 140.0
@export var acceleration: float = 1200.0
@export var friction: float = 1400.0

@onready var inventory: Node = $InventoryComponent

var facing_direction: Vector2 = Vector2.DOWN:
	get:
		return facing_direction

var is_moving: bool = false:
	get:
		return velocity.length_squared() > 1.0

# ------------------------------------------------------------------------------
# Життєвий цикл
# ------------------------------------------------------------------------------
func _ready() -> void:
	add_to_group("player")


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	# Взаємодія з ресурсом перед гравцем через клавішу 'E'
	if event.is_action_pressed("interact"):
		interact_with_target_cell(get_interaction_cell())
	# Взаємодія кліком миші (первинна дія)
	elif event.is_action_pressed("primary_action"):
		var mouse_world: Vector2 = get_global_mouse_position()
		var mouse_cell: Vector2i = GridManager.world_to_map(mouse_world)
		var player_cell: Vector2i = get_current_cell()
		# Дозволяємо збір у радіусі 2 тайлів від гравця
		if Vector2(player_cell).distance_to(Vector2(mouse_cell)) <= 2.5:
			interact_with_target_cell(mouse_cell)


func _physics_process(delta: float) -> void:
	# Якщо гра на системній паузі або в режимі огляду колонії — гравець не рухається
	if GameManager.current_state != GameManager.GameState.PLAYING and GameManager.current_state != GameManager.GameState.BUILDING_MODE:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return

	_handle_movement(delta)


# ------------------------------------------------------------------------------
# Логіка пересування (WASD Movement)
# ------------------------------------------------------------------------------
func _handle_movement(delta: float) -> void:
	# Отримуємо вектор вводу від Input Map (WASD)
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_vector != Vector2.ZERO:
		# Оновлюємо вектор погляду гравця (нормалізований)
		facing_direction = input_vector.normalized()
		# Плавний розгін до максимальної швидкості
		velocity = velocity.move_toward(input_vector * move_speed, acceleration * delta)
	else:
		# Плавна зупинка без ковзання
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()


# ------------------------------------------------------------------------------
# Взаємодія з об'єктами світу (Harvesting / Interaction)
# ------------------------------------------------------------------------------
func interact_with_target_cell(target_cell: Vector2i) -> void:
	var occupant: Node = GridManager.get_occupant(target_cell)
	if occupant != null and occupant.has_method("harvest"):
		occupant.harvest(1.0, 0) # Базовий удар руками / інструментом


# ------------------------------------------------------------------------------
# Допоміжні методи для інтеграції зі світом
# ------------------------------------------------------------------------------
## Отримує поточну клітинку сітки під ногами гравця
func get_current_cell() -> Vector2i:
	return GridManager.world_to_map(global_position)


## Отримує координати клітинки, на яку безпосередньо дивиться гравець
func get_interaction_cell() -> Vector2i:
	var interaction_pos: Vector2 = global_position + (facing_direction * float(GridManager.TILE_SIZE))
	return GridManager.world_to_map(interaction_pos)
