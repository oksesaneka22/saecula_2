extends Node2D

const ItemDataScript = preload("res://src/data/schemas/ItemData.gd")

func _ready() -> void:
	# Підписуємося на сигнали EventBus для валідації шини
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.day_time_updated.connect(_on_day_time_updated)

	# Валідація доступу до GridManager
	assert(GridManager != null, "GridManager autoload must be available")
	var sample_path: PackedVector2Array = GridManager.get_world_path(Vector2(0, 0), Vector2(64, 64))
	print("[Main] System initialized. Sample path length: ", sample_path.size())

	# Валідація доступу до ItemDatabase (Ітерація 4.1)
	assert(ItemDatabase != null, "ItemDatabase autoload must be available")
	var wood: Resource = ItemDatabase.get_item(&"wood")
	assert(wood != null and wood.get("display_name") == "Деревина", "Item 'wood' must be registered in ItemDatabase")
	print("[Main] ItemDatabase validated: 'wood' => ", wood.get("display_name"))


func _on_game_state_changed(new_state: int, old_state: int) -> void:
	# Безпечне реагування на зміну стану
	pass


func _on_day_time_updated(hour: int, minute: int) -> void:
	pass
