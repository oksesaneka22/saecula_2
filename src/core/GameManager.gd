extends Node

## GameManager: Центральний контролер життєвого циклу та глобального стану гри.
## Керує станами гри (пауза, пряме керування гравцем, менеджмент колонії, режим будівництва),
## швидкістю плину часу та глобальним днем/ніччю.

# ------------------------------------------------------------------------------
# Переліки (Enums)
# ------------------------------------------------------------------------------
enum GameState {
	INITIALIZING,   ## Завантаження та ініціалізація компонентів гри
	PLAYING,        ## Пряме керування гравцем (Player Direct Control)
	COLONY_MODE,    ## Режим огляду/керування колонією (уповільнений час, Tab key)
	BUILDING_MODE,  ## Активний режим встановлення креслення/споруди
	PAUSED,         ## Повна пауза гри (меню налаштувань тощо)
	GAME_OVER       ## Смерть або завершення гри
}

enum NotificationType {
	INFO,
	SUCCESS,
	WARNING,
	ERROR
}

# ------------------------------------------------------------------------------
# Змінні стану (State Variables)
# ------------------------------------------------------------------------------
@export var default_time_scale: float = 1.0
@export var colony_mode_time_scale: float = 0.5

var current_state: GameState = GameState.INITIALIZING:
	get:
		return current_state

var previous_state: GameState = GameState.INITIALIZING:
	get:
		return previous_state

var current_time_scale: float = 1.0:
	get:
		return current_time_scale

# Симуляція часу доби
var in_game_time_seconds: float = 8.0 * 3600.0 # Починаємо о 08:00 ранку
var current_day: int = 1
const SECONDS_PER_DAY: float = 86400.0
const TIME_ACCELERATION: float = 60.0 # 1 реальна секунда = 1 ігрова хвилина (доба = 24 реальні хвилини)

# ------------------------------------------------------------------------------
# Життєвий цикл рушія (Engine Lifecycle)
# ------------------------------------------------------------------------------
func _ready() -> void:
	# Дозволяємо GameManager обробляти ввід навіть при повній системній паузі
	process_mode = Node.PROCESS_MODE_ALWAYS
	_initialize_game()


func _process(delta: float) -> void:
	if current_state == GameState.PAUSED or current_state == GameState.INITIALIZING:
		return

	_update_in_game_time(delta)


func _unhandled_input(event: InputEvent) -> void:
	# 1. Обробка кнопки Cancel (Escape)
	if event.is_action_pressed("cancel"):
		match current_state:
			GameState.BUILDING_MODE:
				# Скасовуємо привид розміщення будівлі
				EventBus.building_placement_canceled.emit()
				change_state(previous_state if previous_state != GameState.BUILDING_MODE else GameState.PLAYING)
				get_viewport().set_input_as_handled()

			GameState.COLONY_MODE:
				# Вихід з режиму огляду поселення назад у звичайну гру
				change_state(GameState.PLAYING)
				get_viewport().set_input_as_handled()

			GameState.PLAYING:
				# Вихід у системну паузу
				toggle_pause()
				get_viewport().set_input_as_handled()

			GameState.PAUSED:
				# Повернення з паузи
				toggle_pause()
				get_viewport().set_input_as_handled()

	# 2. Перемикання режиму керування поселенням за клавішею Tab (colony_mode_toggle)
	if event.is_action_pressed("colony_mode_toggle"):
		if current_state == GameState.PLAYING:
			change_state(GameState.COLONY_MODE)
			get_viewport().set_input_as_handled()
		elif current_state == GameState.COLONY_MODE:
			change_state(GameState.PLAYING)
			get_viewport().set_input_as_handled()

	# 3. Відкриття / закриття вікна інвентаря за клавішею I (inventory_toggle)
	if event.is_action_pressed("inventory_toggle"):
		if current_state == GameState.PLAYING or current_state == GameState.COLONY_MODE:
			EventBus.inventory_window_toggle_requested.emit()
			get_viewport().set_input_as_handled()


# ------------------------------------------------------------------------------
# Керування станом гри (State Management)
# ------------------------------------------------------------------------------
func change_state(new_state: GameState) -> void:
	if current_state == new_state:
		return

	var old_state: GameState = current_state
	previous_state = old_state
	current_state = new_state

	_apply_state_side_effects(new_state, old_state)
	EventBus.game_state_changed.emit(new_state, old_state)


func _apply_state_side_effects(new_state: GameState, old_state: GameState) -> void:
	match new_state:
		GameState.PLAYING:
			get_tree().paused = false
			set_time_scale(default_time_scale)

		GameState.COLONY_MODE:
			get_tree().paused = false
			# У режимі огляду поселення час сповільнюється (згідно з docs/UI.md)
			set_time_scale(colony_mode_time_scale)

		GameState.BUILDING_MODE:
			get_tree().paused = false
			set_time_scale(default_time_scale)

		GameState.PAUSED:
			get_tree().paused = true

		GameState.GAME_OVER:
			get_tree().paused = true


func toggle_pause() -> void:
	if current_state == GameState.PAUSED:
		change_state(previous_state if previous_state != GameState.PAUSED else GameState.PLAYING)
	else:
		change_state(GameState.PAUSED)


func set_time_scale(new_scale: float) -> void:
	var clamped_scale: float = clampf(new_scale, 0.0, 5.0)
	current_time_scale = clamped_scale
	Engine.time_scale = clamped_scale
	EventBus.game_speed_changed.emit(clamped_scale)


# ------------------------------------------------------------------------------
# Симуляція часу доби (In-Game Time)
# ------------------------------------------------------------------------------
func _update_in_game_time(delta: float) -> void:
	var old_minute: int = get_current_minute()
	in_game_time_seconds += delta * TIME_ACCELERATION

	if in_game_time_seconds >= SECONDS_PER_DAY:
		in_game_time_seconds -= SECONDS_PER_DAY
		current_day += 1
		EventBus.day_passed.emit(current_day)

	var new_minute: int = get_current_minute()
	if new_minute != old_minute:
		EventBus.day_time_updated.emit(get_current_hour(), new_minute)


func get_current_hour() -> int:
	return int(in_game_time_seconds / 3600.0) % 24


func get_current_minute() -> int:
	return int(fmod(in_game_time_seconds, 3600.0) / 60.0)


func get_time_string() -> String:
	return "%02d:%02d" % [get_current_hour(), get_current_minute()]


# ------------------------------------------------------------------------------
# Допоміжні методи та ініціалізація
# ------------------------------------------------------------------------------
func _initialize_game() -> void:
	current_day = 1
	in_game_time_seconds = 8.0 * 3600.0 # 08:00
	change_state(GameState.PLAYING)
