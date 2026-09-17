extends Node2D

func _ready() -> void:
	# Підписуємося на сигнали EventBus для валідації шини
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.day_time_updated.connect(_on_day_time_updated)

	# Валідація доступу до GridManager
	assert(GridManager != null, "GridManager autoload must be available")
	var sample_path: PackedVector2Array = GridManager.get_world_path(Vector2(0, 0), Vector2(64, 64))
	print("[Main] System initialized. Sample path length: ", sample_path.size())


func _on_game_state_changed(new_state: int, old_state: int) -> void:
	# Безпечне реагування на зміну стану
	pass


func _on_day_time_updated(hour: int, minute: int) -> void:
	pass
