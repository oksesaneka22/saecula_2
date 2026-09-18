extends Node

const ItemDataScript = preload("res://src/data/schemas/ItemData.gd")
const InventoryComponentScript = preload("res://src/systems/inventory/InventoryComponent.gd")
const WorldResourceNode3DScene = preload("res://src/world3d/WorldResourceNode3D.tscn")
const Player3DScene = preload("res://src/entities3d/player/Player3D.tscn")

func _ready() -> void:
	# Підписуємося на сигнали EventBus для валідації шини
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.day_time_updated.connect(_on_day_time_updated)

	# 1. Валідація доступу до GridManager
	assert(GridManager != null, "GridManager autoload must be available")
	var sample_path_3d: PackedVector3Array = GridManager.get_world_path_3d(Vector3(0, 0, 0), Vector3(20, 0, 20))
	print("[Main] 3D System initialized. Sample path length: ", sample_path_3d.size())

	# 2. Валідація доступу до ItemDatabase (Ітерація 4.1)
	assert(ItemDatabase != null, "ItemDatabase autoload must be available")
	var wood: Resource = ItemDatabase.get_item(&"wood")
	assert(wood != null and wood.get("display_name") == "Деревина", "Item 'wood' must be registered in ItemDatabase")
	print("[Main] ItemDatabase validated: 'wood' => ", wood.get("display_name"))

	# 3. Валідація InventoryComponent (Ітерація 4.2)
	_test_inventory_component(wood)

	# 4. Валідація 3D збору ресурсів та дропу
	_test_harvest_and_drop()

	# 5. Валідація CraftingManager (Ітерація 5.1)
	_test_crafting_manager()

	# 6. Валідація Player3D інструментів та збору ресурсів
	_test_player_3d_tools()


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
	var test_cell = Vector2i(55, 55)
	assert(GridManager.is_cell_walkable(test_cell) == true, "Cell must be initially walkable")

	var node: StaticBody3D = WorldResourceNode3DScene.instantiate()
	node.position = GridManager.map_to_world_3d(test_cell, 0.0)
	node.resource_type = 0 # TREE
	node.max_health = 1.0
	node.current_health = 1.0
	node.drop_item_id = &"wood"
	add_child(node)

	assert(GridManager.is_cell_solid(test_cell) == true, "ResourceNode3D must block cell")
	assert(GridManager.get_occupant(test_cell) == node, "GridManager occupant must be node")

	node.harvest(1.0, 0)
	assert(GridManager.is_cell_walkable(test_cell) == true, "Destroyed node must free cell in GridManager")
	print("[Main] 3D Harvest and drop mechanics unit tests passed successfully!")


func _test_crafting_manager() -> void:
	assert(CraftingManager != null, "CraftingManager autoload must be available")
	var axe_recipe = CraftingManager.get_recipe(&"craft_stone_axe")
	assert(axe_recipe != null, "craft_stone_axe recipe must be loaded")

	var test_inv: Node = InventoryComponentScript.new()
	test_inv.set("slot_count", 6)
	add_child(test_inv)

	# 1. Порожній інвентар — не може скрафтити
	assert(CraftingManager.can_craft(axe_recipe, test_inv) == false, "Cannot craft with empty inventory")

	# 2. Додаємо 2 дерева та 2 кременю
	test_inv.add_item_by_id(&"wood", 2)
	test_inv.add_item_by_id(&"flint", 2)
	assert(CraftingManager.can_craft(axe_recipe, test_inv) == true, "Must be able to craft stone axe with 2 wood + 2 flint")

	# 3. Виконуємо крафт
	var success: bool = CraftingManager.craft_item(axe_recipe, test_inv)
	assert(success == true, "craft_item must return true")

	# 4. Перевіряємо списання інгредієнтів та наявність сокири
	assert(test_inv.get_item_count(&"wood") == 0, "Wood must be consumed")
	assert(test_inv.get_item_count(&"flint") == 0, "Flint must be consumed")
	assert(test_inv.has_item(&"stone_axe", 1) == true, "Inventory must contain 1 stone_axe")

	test_inv.queue_free()
	print("[Main] CraftingManager unit tests passed successfully!")


func _test_player_3d_tools() -> void:
	var test_player = Player3DScene.instantiate()
	add_child(test_player)

	# Перевірка з пустими руками
	test_player.select_hotbar_slot(0)
	assert(test_player._get_active_tool_type() == 0, "Empty hand tool type must be 0 (NONE)")
	assert(test_player._get_active_tool_damage() == 1.0, "Empty hand tool damage must be 1.0")

	# Додаємо кам'яну сокиру в перший слот хотбару
	var axe = ItemDatabase.get_item(&"stone_axe")
	assert(axe != null, "stone_axe must exist in database")
	test_player.inventory.add_item(axe, 1)

	# Перевіряємо зчитування типу інструмента та шкоди
	var tool_type: int = test_player._get_active_tool_type()
	var tool_dmg: float = test_player._get_active_tool_damage()
	assert(tool_type == 1, "Equipped axe must return tool_type 1 (AXE)")
	assert(tool_dmg >= 2.0, "Axe efficiency must be >= 2.0")

	test_player.queue_free()
	print("[Main] Player3D tool calculation unit tests passed successfully!")


func _on_game_state_changed(_new_state: int, _old_state: int) -> void:
	pass


func _on_day_time_updated(_hour: int, _minute: int) -> void:
	pass
