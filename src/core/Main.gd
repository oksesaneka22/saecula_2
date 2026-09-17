extends Node2D

const ItemDataScript = preload("res://src/data/schemas/ItemData.gd")
const InventoryComponentScript = preload("res://src/systems/inventory/InventoryComponent.gd")
const WorldResourceNodeScript = preload("res://src/world/WorldResourceNode.gd")
const DroppedItemScene = preload("res://src/entities/items/DroppedItem.tscn")

func _ready() -> void:
	# Підписуємося на сигнали EventBus для валідації шини
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.day_time_updated.connect(_on_day_time_updated)

	# 1. Валідація доступу до GridManager
	assert(GridManager != null, "GridManager autoload must be available")
	var sample_path: PackedVector2Array = GridManager.get_world_path(Vector2(0, 0), Vector2(64, 64))
	print("[Main] System initialized. Sample path length: ", sample_path.size())

	# 2. Валідація доступу до ItemDatabase (Ітерація 4.1)
	assert(ItemDatabase != null, "ItemDatabase autoload must be available")
	var wood: Resource = ItemDatabase.get_item(&"wood")
	assert(wood != null and wood.get("display_name") == "Деревина", "Item 'wood' must be registered in ItemDatabase")
	print("[Main] ItemDatabase validated: 'wood' => ", wood.get("display_name"))

	# 3. Валідація InventoryComponent (Ітерація 4.2)
	_test_inventory_component(wood)

	# 4. Валідація збору ресурсів та дропу (Ітерація 4.3)
	_test_harvest_and_drop()


func _test_inventory_component(wood: Resource) -> void:
	var test_inv: Node = InventoryComponentScript.new()
	test_inv.set("slot_count", 5)
	add_child(test_inv)

	# Тест додавання 70 одиниць при max_stack = 64
	var remainder: int = test_inv.add_item(wood, 70)
	assert(remainder == 0, "70 wood should fit into 5 slots (64 and 6)")
	assert(test_inv.get_item_count(&"wood") == 70, "Total wood count must be 70")
	assert(test_inv.slots[0].count == 64, "First slot must have 64 wood")
	assert(test_inv.slots[1].count == 6, "Second slot must have 6 wood")
	assert(test_inv.has_item(&"wood", 70) == true, "has_item(70) must be true")

	# Тест часткового видалення
	var removed: bool = test_inv.remove_item(&"wood", 10)
	assert(removed == true, "Must remove 10 wood successfully")
	assert(test_inv.get_item_count(&"wood") == 60, "Remaining wood must be 60")

	test_inv.queue_free()
	print("[Main] InventoryComponent unit tests passed successfully!")


func _test_harvest_and_drop() -> void:
	# Тестова перевірка реєстрації, знищення та очищення сітки
	var test_cell = Vector2i(70, 40)
	assert(GridManager.is_cell_walkable(test_cell) == true, "Cell must be initially walkable")

	var node: StaticBody2D = WorldResourceNodeScript.new()
	node.global_position = GridManager.map_to_world(test_cell)
	node.resource_type = 0 # TREE
	node.max_health = 1.0
	node.current_health = 1.0
	node.drop_item_id = &"wood"
	add_child(node)

	# Клітинка стає зайнятою
	assert(GridManager.is_cell_solid(test_cell) == true, "ResourceNode must block cell")
	assert(GridManager.get_occupant(test_cell) == node, "GridManager occupant must be node")

	# Удар (harvest) призводить до знищення та звільнення клітинки
	node.harvest(1.0, 0)
	assert(GridManager.is_cell_walkable(test_cell) == true, "Destroyed node must free cell in GridManager")
	print("[Main] Harvest and drop mechanics unit tests passed successfully!")


func _on_game_state_changed(new_state: int, old_state: int) -> void:
	# Безпечне реагування на зміну стану
	pass


func _on_day_time_updated(hour: int, minute: int) -> void:
	pass
