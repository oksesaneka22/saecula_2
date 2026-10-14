extends Node

const TestRunner = preload("res://src/core/TestRunner.gd")

@export var run_unit_tests: bool = false


func _ready() -> void:
	# Підписуємося на сигнали EventBus для валідації шини
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.day_time_updated.connect(_on_day_time_updated)

	var cmd_args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	var force_tests := run_unit_tests or ("--run-tests" in cmd_args) or ("--test" in cmd_args)
	var skip_tests := ("--skip-tests" in cmd_args) or ("--no-tests" in cmd_args)
	var is_headless := DisplayServer.get_name() == "headless"

	var should_run_tests: bool = (force_tests or (is_headless and not skip_tests)) and not skip_tests
	if should_run_tests:
		print("[Main] === ЗАПУСК АВТОМАТИЧНИХ ТЕСТІВ (Unit Tests) ===")
		TestRunner.run_all_tests(self)
		print("[Main] === УСІ ТЕСТИ УСПІШНО ПРОЙДЕНО ===")
	else:
		print("[Main] 🎮 Запуск гри у звичайному режимі (юніт-тести пропущено).")


func _on_game_state_changed(new_state: int, old_state: int) -> void:
	print("[Main] Стан гри змінився: %s -> %s" % [old_state, new_state])


func _on_day_time_updated(hour: int, minute: int) -> void:
	# Тільки для логування важливих переходів
	if hour % 6 == 0 and minute == 0:
		print("[Main] День %d, час: %02d:%02d" % [GameManager.current_day, hour, minute])
