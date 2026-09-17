extends Node2D

func _ready() -> void:
	# Підписуємося на тестовий сигнал EventBus для валідації шини
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.day_time_updated.connect(_on_day_time_updated)


func _on_game_state_changed(new_state: int, old_state: int) -> void:
	# Безпечне реагування на зміну стану
	pass


func _on_day_time_updated(hour: int, minute: int) -> void:
	pass
