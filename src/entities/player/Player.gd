extends CharacterBody2D

## Player: Основний контролер персонажа гравця під прямим керуванням.
## Підтримує плавний 8-напрямний рух (WASD), визначення вектора погляду,
## реакцію на стан гри (GameManager.GameState) та роботу з тайловою сіткою.

# ------------------------------------------------------------------------------
# Константи та експортні змінні
# ------------------------------------------------------------------------------
@export var move_speed: float = 140.0
@export var acceleration: float = 1200.0
@export var friction: float = 1400.0

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
# Допоміжні методи для інтеграції зі світом
# ------------------------------------------------------------------------------
## Отримує поточну клітинку сітки під ногами гравця
func get_current_cell() -> Vector2i:
	return GridManager.world_to_map(global_position)


## Отримує координати клітинки, на яку безпосередньо дивиться гравець
func get_interaction_cell() -> Vector2i:
	var interaction_pos: Vector2 = global_position + (facing_direction * float(GridManager.TILE_SIZE))
	return GridManager.world_to_map(interaction_pos)
