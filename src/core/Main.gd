extends Node

const ItemDataScript = preload("res://src/data/schemas/ItemData.gd")
const InventoryComponentScript = preload("res://src/systems/inventory/InventoryComponent.gd")
const WorldResourceNode3DScene = preload("res://src/world3d/WorldResourceNode3D.tscn")
const Player3DScene = preload("res://src/entities3d/player/Player3D.tscn")
const ConstructionSite3DScript = preload("res://src/world3d/ConstructionSite3D.gd")
const BuildingEntity3DScript = preload("res://src/world3d/BuildingEntity3D.gd")

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

	# 8. Валідація ConstructionSite3D та повного циклу будівництва (Ітерація 6.2)
	_test_construction_site()


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

	# Симулюємо видобуток (використовуємо масив для коректного захоплення посиланням у замиканні)
	var drop_spawned: Array[bool] = [false]
	EventBus.item_dropped.connect(func(_id, _amount, _pos): drop_spawned[0] = true, CONNECT_ONE_SHOT)
	node.harvest(1.0, 1) # AXE damage

	assert(GridManager.is_cell_walkable(test_cell) == true, "Cell must become walkable after harvest")
	assert(GridManager.get_occupant(test_cell) == null, "Occupant must be cleared")
	assert(drop_spawned[0] == true, "Dropped item signal must be emitted")

	print("[Main] 3D Harvest and drop mechanics unit tests passed successfully!")


func _test_crafting_manager() -> void:
	assert(CraftingManager != null, "CraftingManager autoload must be available")
	var recipes: Array = CraftingManager.get_all_recipes()
	assert(recipes.size() >= 3, "At least 3 recipes must be loaded")

	var test_inv: Node = InventoryComponentScript.new()
	test_inv.set("slot_count", 5)
	add_child(test_inv)

	# Тест невдалого крафту через брак ресурсів
	var axe_recipe = CraftingManager.get_recipe(&"craft_stone_axe")
	assert(axe_recipe != null, "Stone axe recipe must exist")
	assert(CraftingManager.can_craft(axe_recipe, test_inv) == false, "Cannot craft axe without materials")

	# Додаємо потрібні матеріали
	test_inv.add_item_by_id(&"wood", 2)
	test_inv.add_item_by_id(&"flint", 2)
	assert(CraftingManager.can_craft(axe_recipe, test_inv) == true, "Should be able to craft axe with 2 wood and 2 flint")

	# Виконуємо крафт
	var success = CraftingManager.craft_item(axe_recipe, test_inv)
	assert(success == true, "Crafting must succeed")
	assert(test_inv.get_item_count(&"wood") == 0, "Wood must be consumed")
	assert(test_inv.get_item_count(&"flint") == 0, "Flint must be consumed")
	assert(test_inv.has_item(&"stone_axe", 1) == true, "Stone axe must be in inventory")

	test_inv.queue_free()
	print("[Main] CraftingManager unit tests passed successfully!")


func _test_player_3d_tools() -> void:
	var p3d: CharacterBody3D = Player3DScene.instantiate()
	add_child(p3d)

	# Слот 4 за замовчуванням порожній (starter items займають слоти 0, 1, 2, 3)
	p3d.select_hotbar_slot(4)
	assert(p3d._get_active_tool_type() == 0, "Empty slot tool type must be NONE (0)")
	assert(is_equal_approx(p3d._get_active_tool_damage(), 1.0), "Default damage must be 1.0")

	# Тестуємо слот 0 з сокирою
	p3d.select_hotbar_slot(0)
	assert(p3d._get_active_tool_type() == 1, "Slot 0 with stone_axe must return tool_type AXE (1)")
	assert(p3d._get_active_tool_damage() >= 2.0, "Tool damage must be >= 2.0")

	p3d.queue_free()
	print("[Main] Player3D tool calculation unit tests passed successfully!")


func _test_building_placement_controller() -> void:
	assert(BuildingPlacementController != null, "BuildingPlacementController autoload must be available")
	var buildings = BuildingPlacementController.get_all_buildings()
	assert(buildings.size() >= 3, "Must load at least 3 buildings")

	var campfire = BuildingPlacementController.get_building(&"campfire")
	assert(campfire != null, "Campfire building must exist")
	assert(campfire.size_in_tiles == Vector2i(2, 2), "Campfire size must be 2x2")

	var stockpile = BuildingPlacementController.get_building(&"stockpile")
	assert(stockpile != null, "Stockpile building must exist")
	assert(stockpile.size_in_tiles == Vector2i(6, 6), "Stockpile size must be 6x6")

	var wooden_hut = BuildingPlacementController.get_building(&"wooden_hut")
	assert(wooden_hut != null, "Wooden hut building must exist")
	assert(wooden_hut.size_in_tiles == Vector2i(8, 8), "Wooden hut size must be 8x8")

	# Перевірка get_occupied_cells
	var occupied = BuildingPlacementController.get_occupied_cells(Vector2i(10, 10), Vector2i(2, 2))
	assert(occupied.size() == 4, "2x2 building must occupy 4 cells")
	assert(occupied.has(Vector2i(10, 10)) and occupied.has(Vector2i(11, 11)), "Must cover all rectangle tiles")

	var hut_occupied = BuildingPlacementController.get_occupied_cells(Vector2i(20, 20), Vector2i(8, 8))
	assert(hut_occupied.size() == 64, "8x8 building must occupy 64 cells")

	# Перевірка can_place_at: виділена тестова зона (34..44) з тимчасовим збереженням клітинок
	var test_origin = Vector2i(34, 34)
	var test_cells = BuildingPlacementController.get_occupied_cells(test_origin, campfire.size_in_tiles)
	var saved_occupants: Dictionary = {}
	var saved_solids: Dictionary = {}
	for c in test_cells:
		saved_occupants[c] = GridManager.get_occupant(c)
		saved_solids[c] = GridManager.is_cell_solid(c)
		GridManager.unregister_occupant(c, true)

	assert(BuildingPlacementController.can_place_at(campfire, test_origin) == true, "Empty lawn must be valid for campfire placement")

	# Штучно блокуємо одну клітинку
	GridManager.set_cell_solid(test_origin, true)
	assert(BuildingPlacementController.can_place_at(campfire, test_origin) == false, "Solid cell must block placement")

	# Відновлюємо початковий стан клітинок
	for c in test_cells:
		if saved_occupants[c] != null:
			GridManager.register_occupant(c, saved_occupants[c], saved_solids[c])
		else:
			GridManager.set_cell_solid(c, saved_solids[c])

	# Перевірка за межами карти
	assert(BuildingPlacementController.can_place_at(campfire, Vector2i(-5, -5)) == false, "Negative coords must be invalid")
	assert(BuildingPlacementController.can_place_at(campfire, Vector2i(79, 79)) == false, "Out of bounds must be invalid")

	# Перевірка розрахунку 3D центру будівлі
	var center: Vector3 = BuildingPlacementController.get_building_world_center(Vector2i(0, 0), Vector2i(2, 2))
	assert(is_equal_approx(center.x, 2.0) and is_equal_approx(center.z, 2.0), "2x2 origin 0,0 center must be (2.0, 0, 2.0)")

	# Перевірка перемикання станів FSM
	BuildingPlacementController.start_placement(campfire)
	assert(GameManager.current_state == GameManager.GameState.BUILDING_MODE, "Must switch to BUILDING_MODE")
	BuildingPlacementController.cancel_placement()
	assert(GameManager.current_state == GameManager.GameState.PLAYING, "Must restore previous state")

	print("[Main] BuildingPlacementController unit tests passed successfully!")


func _test_construction_site() -> void:
	var campfire = BuildingPlacementController.get_building(&"campfire")
	assert(campfire != null, "Campfire must exist")

	var test_origin = Vector2i(34, 34)
	var test_cells = BuildingPlacementController.get_occupied_cells(test_origin, campfire.size_in_tiles)
	var saved_occupants: Dictionary = {}
	var saved_solids: Dictionary = {}
	for c in test_cells:
		saved_occupants[c] = GridManager.get_occupant(c)
		saved_solids[c] = GridManager.is_cell_solid(c)
		GridManager.unregister_occupant(c, true)

	# 1. Створюємо будмайданчик
	var site: StaticBody3D = ConstructionSite3DScript.new()
	add_child(site)
	site.setup_site(campfire, test_origin)

	# 2. Перевіряємо блокування сітки (2x2 = 4 клітинки)
	assert(site.occupied_cells.size() == 4, "Campfire site must occupy 4 cells")
	for c in site.occupied_cells:
		assert(GridManager.is_cell_solid(c) == true, "Site cells must be solid")
		assert(GridManager.get_occupant(c) == site, "Site cells must have site as occupant")

	# 3. Перевіряємо потреби в матеріалах (4 дерева + 4 каменю)
	assert(site.can_accept_material(&"wood") == true, "Site must accept needed wood")
	assert(site.can_accept_material(&"stone") == true, "Site must accept needed stone")
	assert(site.can_accept_material(&"non_existent") == false, "Site must reject non-needed items")

	# Спроба будувати без матеріалів має блокуватись
	var premature_work: bool = site.build_work(1.0)
	assert(premature_work == false, "build_work must fail before all materials are delivered")
	assert(site.build_progress == 0.0, "build_progress must remain 0 when materials not ready")

	# 4. Доставляємо матеріали
	var wood_needed: int = site.get_remaining_needed(&"wood")
	var delivered_wood: int = site.deliver_material(&"wood", wood_needed)
	assert(delivered_wood == wood_needed, "All needed wood must be accepted")
	assert(site.can_accept_material(&"wood") == false, "Wood must now be complete")

	var stone_needed: int = site.get_remaining_needed(&"stone")
	var delivered_stone: int = site.deliver_material(&"stone", stone_needed)
	assert(delivered_stone == stone_needed, "All needed stone must be accepted")
	assert(site.is_materials_ready() == true, "is_materials_ready must be true once all materials are delivered")

	# 5. Перевіряємо будівельні роботи
	var partial_work: bool = site.build_work(campfire.build_time * 0.5)
	assert(partial_work == false, "Partial work must not finish construction")
	assert(is_equal_approx(site.build_progress, campfire.build_time * 0.5), "Build progress must be 50%")

	# Завершуємо роботу
	var finished_building = site.complete_construction()
	assert(finished_building != null, "complete_construction must return BuildingEntity3D instance")
	assert(is_instance_of(finished_building, BuildingEntity3DScript), "finished_building must be BuildingEntity3D")
	assert(finished_building.building_data == campfire, "Building data must match campfire")

	# Перевіряємо, що клітинки тепер зайняті BuildingEntity3D
	for c in finished_building.occupied_cells:
		assert(GridManager.get_occupant(c) == finished_building, "Grid occupant must be replaced by BuildingEntity3D")

	# 6. Тестуємо демонтаж споруди (demolish)
	finished_building.demolish()
	for c in test_cells:
		assert(GridManager.get_occupant(c) == null, "Demolished building must clear occupants")

	# 7. Відновлюємо початковий стан клітинок
	for c in test_cells:
		if saved_occupants[c] != null:
			GridManager.register_occupant(c, saved_occupants[c], saved_solids[c])
		else:
			GridManager.set_cell_solid(c, saved_solids[c])

	print("[Main] ConstructionSite3D & BuildingEntity3D unit tests passed successfully!")


func _on_game_state_changed(new_state: int, old_state: int) -> void:
	print("[Main] Стан гри змінився: %s -> %s" % [old_state, new_state])


func _on_day_time_updated(hour: int, minute: int) -> void:
	# Тільки для логування важливих переходів
	if hour % 6 == 0 and minute == 0:
		print("[Main] День %d, час: %02d:%02d" % [GameManager.current_day, hour, minute])
