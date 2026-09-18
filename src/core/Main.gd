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

	# 7. Валідація BuildingPlacementController та креслень (Ітерація 6.1)
	_test_building_placement_controller()


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
	var test_cell = Vector2i(75, 75)
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


func _test_building_placement_controller() -> void:
	assert(BuildingPlacementController != null, "BuildingPlacementController autoload must be available")

	var campfire = BuildingPlacementController.get_building(&"campfire")
	assert(campfire != null, "campfire building resource must be loaded")
	assert(campfire.size_in_tiles == Vector2i(8, 8), "campfire size must be 8x8")
	assert(campfire.size_in_tiles.x >= 8 and campfire.size_in_tiles.y >= 8, "campfire must be at least 8x8")

	var stockpile = BuildingPlacementController.get_building(&"stockpile")
	assert(stockpile != null, "stockpile building resource must be loaded")
	assert(stockpile.size_in_tiles == Vector2i(10, 10), "stockpile size must be 10x10")
	assert(stockpile.size_in_tiles.x >= 8 and stockpile.size_in_tiles.y >= 8, "stockpile must be at least 8x8")

	var hut = BuildingPlacementController.get_building(&"wooden_hut")
	assert(hut != null, "wooden_hut building resource must be loaded")
	assert(hut.size_in_tiles == Vector2i(12, 12), "wooden_hut size must be 12x12")
	assert(hut.size_in_tiles.x >= 8 and hut.size_in_tiles.y >= 8, "wooden_hut must be at least 8x8")

	# Тест розрахунку площі зайнятих клітинок (footprint)
	var cells_8x8 = BuildingPlacementController.get_occupied_cells(Vector2i(10, 10), campfire.size_in_tiles)
	assert(cells_8x8.size() == 64, "8x8 footprint must contain exactly 64 cells")
	assert(cells_8x8.has(Vector2i(10, 10)) and cells_8x8.has(Vector2i(17, 17)), "8x8 footprint must span (10..17, 10..17)")

	var cells_10x10 = BuildingPlacementController.get_occupied_cells(Vector2i(10, 10), stockpile.size_in_tiles)
	assert(cells_10x10.size() == 100, "10x10 footprint must contain exactly 100 cells")
	assert(cells_10x10.has(Vector2i(10, 10)) and cells_10x10.has(Vector2i(19, 19)), "10x10 cells must span (10..19, 10..19)")

	var cells_12x12 = BuildingPlacementController.get_occupied_cells(Vector2i(10, 10), hut.size_in_tiles)
	assert(cells_12x12.size() == 144, "12x12 footprint must contain exactly 144 cells")
	assert(cells_12x12.has(Vector2i(10, 10)) and cells_12x12.has(Vector2i(21, 21)), "12x12 cells must span (10..21, 10..21)")

	# Тест валідації розміщення: вільне поле vs зайнята перешкода
	# Ізолюємо тестову зону для повної детермінованості від випадкових спавнів ресурсів
	var test_origin = Vector2i(34, 34)
	var test_cells = BuildingPlacementController.get_occupied_cells(test_origin, Vector2i(14, 14))
	var saved_solids: Dictionary = {}
	var saved_occupants: Dictionary = {}
	for c in test_cells:
		saved_solids[c] = GridManager.is_cell_solid(c)
		saved_occupants[c] = GridManager.get_occupant(c)
		GridManager.unregister_occupant(c, true)

	assert(BuildingPlacementController.can_place_at(campfire, test_origin) == true, "Empty lawn must be valid for campfire placement")
	assert(BuildingPlacementController.can_place_at(stockpile, test_origin) == true, "Empty lawn must be valid for stockpile placement")
	assert(BuildingPlacementController.can_place_at(hut, test_origin) == true, "Empty lawn must be valid for hut placement")

	# Блокуємо одну клітинку під спорудою (наприклад, test_origin + Vector2i(4, 4))
	var blocked_cell = test_origin + Vector2i(4, 4)
	GridManager.set_cell_solid(blocked_cell, true)
	assert(BuildingPlacementController.can_place_at(campfire, test_origin) == false, "Campfire (8x8) cannot be placed if any cell inside footprint is obstructed")
	assert(BuildingPlacementController.can_place_at(stockpile, test_origin) == false, "Stockpile (10x10) cannot be placed if cell is obstructed")
	assert(BuildingPlacementController.can_place_at(hut, test_origin) == false, "Hut (12x12) cannot be placed if cell is obstructed")

	GridManager.set_cell_solid(blocked_cell, false)
	assert(BuildingPlacementController.can_place_at(campfire, test_origin) == true, "Campfire becomes valid once cell is free")

	# Відновлюємо початковий стан клітинок після завершення тесту
	for c in test_cells:
		if saved_occupants[c] != null:
			GridManager.register_occupant(c, saved_occupants[c], saved_solids[c])
		else:
			GridManager.set_cell_solid(c, saved_solids[c])

	# Тест циклу розміщення (Start, Hover, Confirm, Cancel)
	BuildingPlacementController.start_placement(campfire)
	assert(BuildingPlacementController.is_placing() == true, "is_placing() must be true after start_placement")
	assert(BuildingPlacementController.get_active_building() == campfire, "active_building must match campfire")
	assert(GameManager.current_state == GameManager.GameState.BUILDING_MODE, "GameManager state must be BUILDING_MODE")

	BuildingPlacementController.update_hover(test_origin)
	assert(BuildingPlacementController.get_current_hover_cell() == test_origin, "Current hover cell must match")

	# Скасовуємо розміщення для завершення тесту
	BuildingPlacementController.cancel_placement()
	assert(BuildingPlacementController.is_placing() == false, "is_placing must be false after cancellation")

	print("[Main] BuildingPlacementController unit tests passed successfully!")


func _on_game_state_changed(_new_state: int, _old_state: int) -> void:
	pass


func _on_day_time_updated(_hour: int, _minute: int) -> void:
	pass
