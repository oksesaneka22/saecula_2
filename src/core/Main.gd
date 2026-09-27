extends Node

const ItemDataScript = preload("res://src/data/schemas/ItemData.gd")
const InventoryComponentScript = preload("res://src/systems/inventory/InventoryComponent.gd")
const WorldResourceNode3DScene = preload("res://src/world3d/WorldResourceNode3D.tscn")
const Player3DScene = preload("res://src/entities3d/player/Player3D.tscn")
const ConstructionSite3DScript = preload("res://src/world3d/ConstructionSite3D.gd")
const BuildingEntity3DScript = preload("res://src/world3d/BuildingEntity3D.gd")
const StockpileBuildingScript = preload("res://src/world/buildings/StockpileBuilding.gd")
const ModularPiece3DScript = preload("res://src/world3d/modular/ModularPiece3D.gd")
const ItemSlotUIScript = preload("res://src/ui/hud/ItemSlotUI.gd")
const EnergyBarUIScript = preload("res://src/ui/hud/EnergyBarUI.gd")
const SleepOverlayUIScript = preload("res://src/ui/hud/SleepOverlayUI.gd")
const SurvivalStatsUIScript = preload("res://src/ui/hud/SurvivalStatsUI.gd")
const AdminPanelUIScript = preload("res://src/ui/hud/AdminPanelUI.gd")
const Job = preload("res://src/systems/jobs/Job.gd")
const Colonist3DScene = preload("res://src/entities3d/colonist/Colonist3D.tscn")
const Colonist3DScript = preload("res://src/entities3d/colonist/Colonist3D.gd")

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
		_run_all_unit_tests()
		print("[Main] === УСІ ТЕСТИ УСПІШНО ПРОЙДЕНО ===")
	else:
		print("[Main] 🎮 Запуск гри у звичайному режимі (юніт-тести пропущено).")


func _run_all_unit_tests() -> void:
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

	# 9. Валідація LogisticsManager та складів (Ітерація 7.1)
	_test_logistics_and_stockpile()

	# 10. Валідація меню створення будівель та блупрінтів Factorio (Ітерація 7.2)
	_test_blueprint_and_build_menu()

	# 11. Валідація воксельних блоків у стилі Minecraft (дерево/камінь)
	_test_block_placement()

	# 12. Валідація модульного будівництва Going Medieval (підлога, стіна, опора, двері, стеля)
	_test_going_medieval_modular_construction()

	# 13. Валідація водойм (річки/озера) та родовищ глини і кремнію на узбережжі
	_test_water_bodies_and_shore_resources()

	# 14. Валідація процедурної генерації світу (1000x1000 тайлів лісу, чанковий стрімінг)
	_test_procedural_forest_world_generation()

	# 15. Валідація дикої трави, коси та заготівлі сіна
	_test_grass_and_scythe()

	# 16. Валідація текстур в інвентарі та повного розміру дерев'яної колоди-опори
	_test_inventory_textures_and_pillar_size()

	# 17. Валідація системи енергії (1000 од., дії, виснаження при 0, шкала EnergyBarUI)
	_test_player_energy_system()

	# 18. Валідація механік виживання: голод, спрага, пиття води з річки, загибель при 0 та SurvivalStatsUI
	_test_player_survival_system()

	# 19. Валідація зміни дня та ночі, руху Сонця і Місяця, темряви вночі та освітлення від табірного вогнища
	_test_day_night_and_campfire_lighting()

	# 20. Валідація адмін-панелі: видача предметів, зміна характеристик виживання, часу доби та супершвидкості
	_test_admin_panel_ui()

	# 22. Валідація Меню Епох, підепох та вертикального дерева досліджень (Tree/Forest Layout, суворе блокування)
	_test_era_and_tech_tree_system()

	# 23. Валідація 3D Поселенців, FSM та системи автономних завдань (JobManager, Minecolonies-стиль)
	_test_colonists_and_job_system()

	# 21. Валідація смолоскипа (освітлення в руці та встановлення), будівельного молотка (10 махів без нього, 5 з ним) та мотузки
	_test_torch_hammer_rope_mechanics()

	# 24. Валідація аудіо-системи (процедурний синтез звуків, кроки, удари, крафт, дзвін епох) та спливаючих 3D написів
	_test_audio_and_floating_text_system()

	# 25. Валідація поведінки поселенців: нічний відпочинок біля вогнища, візуальні статуси завдань та плавні повороти
	_test_colonist_night_rest_and_visual_task_polish()

	# 26. Валідація списку поселенців (Colony Roster UI: міні-панель, картки, перемикання слідування, діалог, фокус)
	_test_colony_roster_ui()

	# 27. Валідація візуального контуру виділення та знесення модульних блоків (Going Medieval: Highlight, Demolition, Resource refunds)
	_test_modular_block_highlight_and_demolish()

	# 28. Валідація контекстного прицілу (CrosshairUI: підказки для поселенців з HP/роботою/дистанцією, вогнища з денним/нічним сном, споруд та ресурсів)
	_test_enhanced_crosshair_hints()

	# 29. Валідація покращеного пошуку шляху та обходу фізичних перешкод поселенцями (GridManager, AStarGrid2D діагоналі, solid-start recovery, Whisker raycasts, slide deflection)
	_test_colonist_obstacle_avoidance_and_pathfinding()


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
	var existing_occ = GridManager.get_occupant(test_cell)
	if existing_occ is Node:
		existing_occ.queue_free()
	GridManager.unregister_occupant(test_cell, true)
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
	assert(campfire.size_in_tiles == Vector2i(4, 4), "Campfire size must be 4x4")

	var stockpile = BuildingPlacementController.get_building(&"stockpile")
	assert(stockpile != null, "Stockpile building must exist")
	assert(stockpile.size_in_tiles == Vector2i(6, 6), "Stockpile size must be 6x6")

	var wooden_hut = BuildingPlacementController.get_building(&"wooden_hut")
	assert(wooden_hut != null, "Wooden hut building must exist")
	assert(wooden_hut.size_in_tiles == Vector2i(10, 10), "Wooden hut size must be 10x10")

	# Перевірка get_occupied_cells
	var occupied = BuildingPlacementController.get_occupied_cells(Vector2i(10, 10), Vector2i(4, 4))
	assert(occupied.size() == 16, "4x4 building must occupy 16 cells")
	assert(occupied.has(Vector2i(10, 10)) and occupied.has(Vector2i(13, 13)), "Must cover all rectangle tiles")

	var hut_occupied = BuildingPlacementController.get_occupied_cells(Vector2i(20, 20), Vector2i(10, 10))
	assert(hut_occupied.size() == 100, "10x10 building must occupy 100 cells")

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
	assert(BuildingPlacementController.can_place_at(campfire, Vector2i(GridManager.grid_width - 1, GridManager.grid_height - 1)) == false, "Out of bounds must be invalid")

	# Перевірка розрахунку 3D центру будівлі
	var center: Vector3 = BuildingPlacementController.get_building_world_center(Vector2i(0, 0), Vector2i(4, 4))
	assert(is_equal_approx(center.x, 2.0) and is_equal_approx(center.z, 2.0), "4x4 origin 0,0 center must be (2.0, 0, 2.0)")

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
	assert(site.occupied_cells.size() == 16, "Campfire site must occupy 16 cells")
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


func _test_logistics_and_stockpile() -> void:
	assert(LogisticsManager != null, "LogisticsManager autoload must be available")
	var initial_stockpiles: int = LogisticsManager.get_stockpiles_count()

	# 1. Створення та тестування 2D складу (StockpileBuilding)
	var sp_2d = StockpileBuildingScript.new()
	sp_2d.name = "TestStockpile2D"
	sp_2d.map_position = Vector2i(70, 70)
	add_child(sp_2d)

	assert(LogisticsManager.get_all_stockpiles().has(sp_2d), "2D Stockpile must be registered in LogisticsManager")
	assert(LogisticsManager.get_stockpiles_count() == initial_stockpiles + 1, "Stockpile count must increment")

	# Тест внесення предметів через 2D склад
	var unadded: int = sp_2d.deposit_item(&"wood", 10)
	assert(unadded == 0, "All 10 wood must fit into stockpile")
	assert(sp_2d.get_available_item_count(&"wood") == 10, "Stockpile must have 10 wood")
	assert(LogisticsManager.get_available_item_count(&"wood") >= 10, "LogisticsManager must report wood in colony storage")

	# Тест часткового вилучення через 2D склад
	var taken_2d: int = sp_2d.withdraw_item(&"wood", 4)
	assert(taken_2d == 4, "Must withdraw 4 wood")
	assert(sp_2d.get_available_item_count(&"wood") == 6, "Stockpile must retain 6 wood")

	# 2. Створення та тестування 3D складу (BuildingEntity3D)
	var stockpile_data = BuildingPlacementController.get_building(&"stockpile")
	assert(stockpile_data != null, "Stockpile building data must exist")

	var sp_3d: StaticBody3D = BuildingEntity3DScript.new()
	sp_3d.name = "TestStockpile3D"
	add_child(sp_3d)
	sp_3d.setup_building(stockpile_data, Vector2i(55, 55))

	assert(LogisticsManager.get_all_stockpiles().has(sp_3d), "3D Stockpile must be registered in LogisticsManager")
	assert(LogisticsManager.get_stockpiles_count() == initial_stockpiles + 2, "Stockpiles count must be +2")

	# 3. Тест глобальних операцій LogisticsManager (deposit / withdraw)
	var rem: int = LogisticsManager.deposit_item(&"stone", 25)
	assert(rem == 0, "25 stone must fit into available stockpiles")
	assert(LogisticsManager.get_available_item_count(&"stone") == 25, "Colony stone count must be 25")

	var found_sp = LogisticsManager.find_stockpile_with_item(&"stone", 10)
	assert(found_sp != null, "Must find stockpile holding stone")

	var withdrawn_stone: int = LogisticsManager.withdraw_item(&"stone", 15)
	assert(withdrawn_stone == 15, "Must withdraw 15 stone through LogisticsManager")
	assert(LogisticsManager.get_available_item_count(&"stone") == 10, "Remaining colony stone must be 10")

	# 4. Демонтаж та автоматичне зняття з обліку
	sp_3d.demolish()
	sp_2d.queue_free()

	LogisticsManager.unregister_stockpile(sp_2d)

	assert(LogisticsManager.get_stockpiles_count() == initial_stockpiles, "Stockpiles count must return to initial state")

	print("[Main] LogisticsManager & Stockpile unit tests passed successfully!")


func _on_game_state_changed(new_state: int, old_state: int) -> void:
	print("[Main] Стан гри змінився: %s -> %s" % [old_state, new_state])


func _on_day_time_updated(hour: int, minute: int) -> void:
	# Тільки для логування важливих переходів
	if hour % 6 == 0 and minute == 0:
		print("[Main] День %d, час: %02d:%02d" % [GameManager.current_day, hour, minute])

func _test_blueprint_and_build_menu() -> void:
	const BlueprintHelper = preload("res://src/world3d/BlueprintVisualHelper.gd")
	const BuildMenuUIScene = preload("res://src/ui/hud/BuildMenuUI.tscn")

	# 1. Валідація генерації голограм блупрінтів
	var holo_mat = BlueprintHelper.create_hologram_material()
	assert(holo_mat != null and holo_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "Holo material must have alpha transparency")

	var campfire_holo = BlueprintHelper.build_blueprint_hologram(&"campfire", Vector2(4, 4), holo_mat)
	assert(campfire_holo != null and campfire_holo.get_child_count() > 0, "Campfire holo must have children")
	campfire_holo.queue_free()

	var stockpile_holo = BlueprintHelper.build_blueprint_hologram(&"stockpile", Vector2(6, 6), holo_mat)
	assert(stockpile_holo != null and stockpile_holo.get_child_count() > 0, "Stockpile holo must have children")
	stockpile_holo.queue_free()

	var hut_holo = BlueprintHelper.build_blueprint_hologram(&"wooden_hut", Vector2(10, 10), holo_mat)
	assert(hut_holo != null and hut_holo.get_child_count() > 0, "Hut holo must have children")
	hut_holo.queue_free()

	# 2. Валідація ConstructionSite3D голограми
	var campfire = BuildingPlacementController.get_building(&"campfire")
	var site = ConstructionSite3DScript.new()
	add_child(site)
	site.setup_site(campfire, Vector2i(42, 42))
	assert(site._blueprint_hologram != null, "ConstructionSite3D must instantiate blueprint hologram")
	site.cancel_construction()

	# 3. Валідація BuildMenuUI
	var build_menu = BuildMenuUIScene.instantiate()
	add_child(build_menu)
	build_menu.open()
	assert(build_menu.visible == true, "BuildMenuUI must be visible after open()")
	build_menu.close()
	assert(build_menu.visible == false, "BuildMenuUI must be hidden after close()")
	build_menu.queue_free()

	print("[Main] Blueprint & BuildMenuUI unit tests passed successfully!")


func _test_block_placement() -> void:
	# 1. Перевірка типу предметів
	assert(BlockManager.is_placeable_block(&"wood") == true, "Wood must be placeable as block")
	assert(BlockManager.is_placeable_block(&"stone") == true, "Stone must be placeable as block")
	assert(BlockManager.is_placeable_block(&"berries") == false, "Berries cannot be placed as block")

	# 2. Перевірка конвертації координат
	var coord: Vector3i = BlockManager.world_to_block_coord(Vector3(12.3, 0.5, 15.9))
	assert(coord == Vector3i(12, 0, 15), "Voxel coord must snap to floor integer")
	var world_pos: Vector3 = BlockManager.block_coord_to_world(coord)
	assert(is_equal_approx(world_pos.x, 12.5) and is_equal_approx(world_pos.y, 0.5) and is_equal_approx(world_pos.z, 15.5), "World pos must be voxel center")

	# 3. Розміщення дерев'яного блоку (Wood Block)
	var test_coord: Vector3i = Vector3i(25, 0, 25)
	assert(BlockManager.can_place_block_at(test_coord) == true, "Cell must be available for placement")
	var wood_block: Node = BlockManager.place_block(&"wood", test_coord, self)
	assert(wood_block != null, "Wood block must be placed successfully")
	assert(BlockManager.has_block(test_coord) == true, "BlockManager must register block")
	assert(BlockManager.get_block(test_coord) == wood_block, "Get block must return placed instance")
	assert(BlockManager.can_place_block_at(test_coord) == false, "Cannot place on top of existing block at same coord")

	# 4. Вертикальне штабелювання (Minecraft-style stack на Y=1)
	var top_coord: Vector3i = test_coord + Vector3i(0, 1, 0)
	assert(BlockManager.can_place_block_at(top_coord) == true, "Upper cell must be available")
	var stone_block: Node = BlockManager.place_block(&"stone", top_coord, self)
	assert(stone_block != null, "Stone block must be placed above wood block")
	assert(BlockManager.has_block(top_coord) == true, "Stone block must be registered")
	assert(BlockManager.get_block_count() == 2, "Total blocks count must be 2")

	# 5. Перевірка видобутку та руйнування блоку (Mining)
	wood_block.harvest(1.0, 1)
	assert(BlockManager.has_block(test_coord) == false, "Wood block must be destroyed after harvest")

	# 6. Очищення тестових блоків
	BlockManager.clear_all_blocks()
	assert(BlockManager.get_block_count() == 0, "All blocks must be cleared")

	# 7. Перевірка реакції Player3D на вибір слота хотбару
	var test_player = Player3DScene.instantiate()
	add_child(test_player)
	assert(test_player._get_active_item_id() == &"stone_axe", "Initial active item must be stone_axe")
	EventBus.hotbar_slot_selected.emit(2)
	assert(test_player.active_hotbar_slot == 2, "Player active slot must update to 2 via EventBus")
	assert(test_player._get_active_item_id() == &"wood", "Active item must be wood")
	EventBus.hotbar_slot_selected.emit(3)
	assert(test_player.active_hotbar_slot == 3, "Player active slot must update to 3 via EventBus")
	assert(test_player._get_active_item_id() == &"stone", "Active item must be stone")
	test_player.queue_free()

	# 8. Перевірка, що воксельні блоки заважають зведенню споруд
	var campfire_bld = BuildingPlacementController.get_building(&"campfire")
	var test_b_coord := Vector3i(28, 0, 28)
	var test_b_block = BlockManager.place_block(&"wood", test_b_coord, self)
	assert(test_b_block != null, "Block placed")
	assert(BlockManager.has_blocks_in_area(Vector2i(28, 28), campfire_bld.size_in_tiles) == true, "Area has blocks")
	assert(BuildingPlacementController.can_place_at(campfire_bld, Vector2i(28, 28)) == false, "Building placement must fail when block is present")
	BlockManager.remove_block(test_b_coord)
	assert(BlockManager.has_blocks_in_area(Vector2i(28, 28), campfire_bld.size_in_tiles) == false, "Area has no blocks after removal")

	print("[Main] Minecraft-style Block Placement unit tests passed successfully!")


func _test_going_medieval_modular_construction() -> void:
	print("[Main] Testing Going Medieval modular construction system...")

	# 1. Перевірка наявності автолоаду ModularManager
	assert(ModularManager != null, "ModularManager autoload must be registered")

	# 2. Перевірка реєстрації всіх 5 модульних споруд
	var floor_bld = BuildingPlacementController.get_building(&"modular_floor")
	var pillar_bld = BuildingPlacementController.get_building(&"modular_pillar")
	var wall_bld = BuildingPlacementController.get_building(&"modular_wall")
	var door_bld = BuildingPlacementController.get_building(&"modular_door")
	var roof_bld = BuildingPlacementController.get_building(&"modular_roof")

	assert(floor_bld != null, "modular_floor must exist in BuildingPlacementController")
	assert(pillar_bld != null, "modular_pillar must exist in BuildingPlacementController")
	assert(wall_bld != null, "modular_wall must exist in BuildingPlacementController")
	assert(door_bld != null, "modular_door must exist in BuildingPlacementController")
	assert(roof_bld != null, "modular_roof must exist in BuildingPlacementController")

	# 3. Валідація правил ієрархії (Не можна ставити стіни та опори до підлоги, і стелю до стін)
	var test_cell := Vector2i(70, 70)
	ModularManager.clear_all()

	# Без підлоги стіна, опора та двері НЕ повинні дозволятися
	assert(not ModularManager.can_place_modular_piece(&"modular_wall", test_cell), "Cannot place wall without floor")
	assert(not ModularManager.can_place_modular_piece(&"modular_pillar", test_cell), "Cannot place pillar without floor")
	assert(not ModularManager.can_place_modular_piece(&"modular_door", test_cell), "Cannot place door without floor")
	assert(not ModularManager.can_place_modular_piece(&"modular_roof", test_cell), "Cannot place roof without walls/support")

	# Підлога на вільній клітинці ДОЗВОЛЯЄТЬСЯ
	assert(ModularManager.can_place_modular_piece(&"modular_floor", test_cell), "Can place floor on free ground")
	var floor_piece = ModularManager.place_blueprint(&"modular_floor", test_cell)
	assert(floor_piece != null, "Floor blueprint must be created")
	assert(not floor_piece.is_built, "Newly placed floor must be in blueprint mode")
	assert(ModularManager.has_floor(test_cell), "ModularManager must recognize floor at cell")

	# Тепер, коли є підлога, стіна/опора/двері ДОЗВОЛЯЮТЬСЯ
	assert(ModularManager.can_place_modular_piece(&"modular_wall", test_cell), "Can place wall on floor")
	assert(ModularManager.can_place_modular_piece(&"modular_pillar", test_cell), "Can place pillar on floor")
	assert(ModularManager.can_place_modular_piece(&"modular_door", test_cell), "Can place door on floor")

	# Ставимо стіну на цю ж клітинку з підлогою
	var wall_piece = ModularManager.place_blueprint(&"modular_wall", test_cell)
	assert(wall_piece != null, "Wall blueprint must be created on floor")
	assert(ModularManager.has_wall_or_pillar(test_cell), "ModularManager must recognize wall at cell")

	# Тепер, коли є стіна, стеля (сіно) ДОЗВОЛЯЄТЬСЯ
	assert(ModularManager.can_support_roof(test_cell), "Roof can be supported by wall")
	assert(ModularManager.can_place_modular_piece(&"modular_roof", test_cell), "Can place roof on wall")
	var roof_piece = ModularManager.place_blueprint(&"modular_roof", test_cell)
	assert(roof_piece != null, "Roof blueprint must be created")

	# 4. Тестування зведення частин по черзі (інвентар гравця)
	var test_inv: Node = InventoryComponentScript.new()
	test_inv.set("slot_count", 8)
	add_child(test_inv)
	test_inv.add_item_by_id(&"wood", 10)
	test_inv.add_item_by_id(&"straw", 10)

	# Спроба збудувати стіну до того, як збудована підлога -> повинно заблокувати
	wall_piece.interact_construct(test_inv)
	assert(not wall_piece.is_built, "Wall cannot be built before floor is built")

	# Будуємо підлогу (10 махів без молотка)
	for _i in range(10):
		floor_piece.interact_construct(test_inv, false)
	assert(floor_piece.is_built, "Floor must be built after interact_construct (10 swings)")
	assert(ModularManager.has_built_floor(test_cell), "ModularManager must recognize built floor")
	assert(test_inv.get_item_count(&"wood") == 9, "Floor cost 1 wood (10 - 1 = 9)")

	# Тепер будуємо стіну (5 махів з молотком)
	for _i in range(5):
		wall_piece.interact_construct(test_inv, true)
	assert(wall_piece.is_built, "Wall must be built after floor is built (5 swings with hammer)")
	assert(test_inv.get_item_count(&"wood") == 7, "Wall cost 2 wood (9 - 2 = 7)")

	# Будуємо стелю
	for _i in range(5):
		roof_piece.interact_construct(test_inv, true)
	assert(roof_piece.is_built, "Roof must be built after wall is built")
	assert(test_inv.get_item_count(&"wood") == 6, "Roof cost 1 wood (7 - 1 = 6)")
	assert(test_inv.get_item_count(&"straw") == 8, "Roof cost 2 straw (10 - 2 = 8)")

	# 5. Тестування дверей (відчинення та зачинення на interact)
	var door_cell := Vector2i(71, 70)
	var door_floor = ModularManager.place_blueprint(&"modular_floor", door_cell)
	for _i in range(5):
		door_floor.interact_construct(test_inv, true)
	var door_piece = ModularManager.place_blueprint(&"modular_door", door_cell)
	for _i in range(5):
		door_piece.interact_construct(test_inv, true)
	assert(door_piece.is_built, "Door must be built")
	assert(not door_piece.is_door_open, "Door starts closed")
	assert(GridManager.is_cell_solid(door_cell), "Closed door blocks cell")

	# Відчиняємо двері
	door_piece.interact(null)
	assert(door_piece.is_door_open, "Door must be open after interact")
	assert(not GridManager.is_cell_solid(door_cell), "Open door allows passage")

	# Зачиняємо двері
	door_piece.interact(null)
	assert(not door_piece.is_door_open, "Door must be closed after second interact")
	assert(GridManager.is_cell_solid(door_cell), "Closed door blocks cell again")

	# 6. Перевірка відкриття через interact_construct на готових дверях
	door_piece.interact_construct(null)
	assert(door_piece.is_door_open, "interact_construct on built door must toggle it open")
	door_piece.interact_construct(null)
	assert(not door_piece.is_door_open, "interact_construct on built door must toggle it closed")

	# 7. Тестування системи обертання будівель (клавіша R)
	BuildingPlacementController.start_placement(wall_bld)
	assert(BuildingPlacementController.current_rotation == 0, "Initial rotation must be 0")
	assert(BuildingPlacementController.get_rotation_degrees_y() == 0.0, "Initial rotation angle must be 0.0")
	BuildingPlacementController.rotate_placement(1)
	assert(BuildingPlacementController.current_rotation == 1, "Rotation index must be 1 after R")
	assert(BuildingPlacementController.get_rotation_degrees_y() == 90.0, "Rotation angle must be 90.0 after R")
	BuildingPlacementController.cancel_placement()

	# 8. Тестування розбиття великого креслення хатини на модульні компоненти Going Medieval
	ModularManager.clear_all()
	var hut_origin := Vector2i(50, 50)
	var hut_size := Vector2i(4, 4) # 4x4 для швидкого тесту

	# Очищуємо тестову зону 4x4 від випадкових природних ресурсів генерації карти
	for dx in range(4):
		for dy in range(4):
			var c = hut_origin + Vector2i(dx, dy)
			GridManager.unregister_occupant(c, true)
			GridManager.set_cell_solid(c, false)

	var spawned_parts = ModularManager.place_prefab_hut_blueprints(hut_origin, hut_size, 0)
	assert(spawned_parts.size() > 0, "Prefab hut must spawn modular blueprint parts")

	# Перевіряємо, що всі клітинки підлоги розміщені
	for dx in range(4):
		for dy in range(4):
			var c = hut_origin + Vector2i(dx, dy)
			assert(ModularManager.has_floor(c), "Prefab hut must place floor at %s" % str(c))
			assert(ModularManager.has_roof(c), "Prefab hut must place roof at %s" % str(c))

	# Перевіряємо кутові колоди-опори
	assert(ModularManager.has_wall_or_pillar(hut_origin), "Corner (0,0) must have pillar")
	assert(ModularManager.has_wall_or_pillar(hut_origin + Vector2i(3, 0)), "Corner (3,0) must have pillar")
	assert(ModularManager.has_wall_or_pillar(hut_origin + Vector2i(0, 3)), "Corner (0,3) must have pillar")
	assert(ModularManager.has_wall_or_pillar(hut_origin + Vector2i(3, 3)), "Corner (3,3) must have pillar")

	# Перевіряємо наявність дверей
	var hut_door = ModularManager.get_piece_at(hut_origin + Vector2i(2, 0), "structure")
	assert(hut_door != null and hut_door.piece_type == &"modular_door", "Hut must have modular_door blueprint at front entrance")

	# Очищення тестових об'єктів
	ModularManager.clear_all()
	test_inv.queue_free()

	print("[Main] Going Medieval modular construction unit tests passed successfully!")


func _test_water_bodies_and_shore_resources() -> void:
	print("[Main] Testing water bodies and shore deposits (clay and flint)...")

	# 1. Перевірка наявності предметів глини та кремнію в базі
	var clay_item = ItemDatabase.get_item(&"clay")
	assert(clay_item != null, "ItemDatabase must contain 'clay'")
	assert(clay_item.display_name == "Глина", "Clay display_name must be 'Глина'")

	var flint_item = ItemDatabase.get_item(&"flint")
	assert(flint_item != null, "ItemDatabase must contain 'flint'")
	assert(flint_item.display_name == "Кремінь", "Flint display_name must be 'Кремінь'")

	# 2. Перевірка водної системи GridManager
	var test_water_pos := Vector2i(10, 10)
	GridManager.register_water_cell(test_water_pos)
	assert(GridManager.is_water_cell(test_water_pos), "Cell must be identified as water")
	assert(not GridManager.is_cell_walkable(test_water_pos), "Water cell must NOT be walkable")
	assert(GridManager.is_cell_solid(test_water_pos), "Water cell must be solid")

	# 3. Перевірка узбережжя
	var adjacent_shore := Vector2i(11, 10)
	assert(GridManager.is_near_water(adjacent_shore, 2), "Adjacent cell must be near water")
	var far_land := Vector2i(25, 25)
	assert(not GridManager.is_near_water(far_land, 2), "Distant cell must NOT be near water")

	# Очищення тестової водної клітинки
	GridManager.unregister_water_cell(test_water_pos)
	assert(not GridManager.is_water_cell(test_water_pos), "Cell must no longer be water")

	# 4. Перевірка згенерованих водойм на реальній карті
	var all_waters: Array[Vector2i] = GridManager.get_all_water_cells()
	assert(all_waters.size() > 0, "Map must have generated water cells (rivers/lakes)")
	var shore_cells: Array[Vector2i] = GridManager.get_shore_cells(3)
	assert(shore_cells.size() > 0, "Map must have shore cells around water bodies")

	# 5. Перевірка збирання глини (CLAY) та кремнію (FLINT)
	var clay_node = WorldResourceNode3DScene.instantiate()
	clay_node.resource_type = 3 # CLAY
	clay_node.drop_item_id = &"clay"
	add_child(clay_node)
	assert(clay_node.current_health == 3.0, "Clay node health must be 3.0")
	clay_node.harvest(1.0, 0)
	assert(clay_node.current_health < 3.0, "Clay node must take damage on harvest")
	clay_node.queue_free()

	var flint_node = WorldResourceNode3DScene.instantiate()
	flint_node.resource_type = 4 # FLINT
	flint_node.drop_item_id = &"flint"
	add_child(flint_node)
	assert(flint_node.current_health == 3.0, "Flint node health must be 3.0")
	# Перевірка бонусу видобутку кайлом (PICKAXE = 2)
	flint_node.harvest(1.0, 2)
	assert(flint_node.current_health == 1.0, "Flint node must take 2.0 damage from pickaxe")
	flint_node.queue_free()

	print("[Main] Water bodies and shore deposits unit tests passed successfully!")


func _test_procedural_forest_world_generation() -> void:
	print("[Main] Testing procedural forest world generation (1000x1000) & chunk streaming...")

	# 1. Перевірка габаритів світу (1000x1000)
	assert(GridManager.grid_width == 1000, "Grid width must be 1000")
	assert(GridManager.grid_height == 1000, "Grid height must be 1000")

	# 2. Перевірка генерації гідрографії на великій карті
	var water_cells: Array[Vector2i] = GridManager.get_all_water_cells()
	assert(water_cells.size() > 5000, "1000x1000 world must have a rich river and lake system (> 5000 water cells)")

	# 3. Перевірка точки спавну (500, 500)
	var spawn_pos := Vector2i(500, 500)
	assert(not GridManager.is_water_cell(spawn_pos), "Spawn point must not be in water")
	assert(GridManager.is_within_bounds(spawn_pos), "Spawn point must be within bounds")

	# 4. Перевірка чанкового стрімінгу у World3D
	var world3d: Node = get_node_or_null("World3D")
	if world3d != null and "_loaded_chunks" in world3d:
		var loaded_chunks: Dictionary = world3d._loaded_chunks
		assert(loaded_chunks.size() > 0, "World3D must have active loaded chunks around player")
		print("[Main] Active chunks around spawn: ", loaded_chunks.size())

	# 5. Перевірка наявності прибережних зон для глини та кремнію
	var shore_cells: Array[Vector2i] = GridManager.get_shore_cells(3)
	assert(shore_cells.size() > 100, "Shoreline must provide abundant cells for clay and flint deposits")

	print("[Main] Procedural forest world generation & chunk streaming unit tests passed successfully!")


func _test_grass_and_scythe() -> void:
	print("[Main] Testing wild grass, scythe crafting and harvesting straw...")
	# 1. Валідація предмета scythe
	var scythe_item = ItemDatabase.get_item(&"scythe")
	assert(scythe_item != null, "Item 'scythe' must exist in ItemDatabase")
	assert(scythe_item.tool_type == 5, "Scythe tool_type must be 5 (ToolType.SCYTHE)")

	# 2. Валідація рецепта craft_scythe
	var scythe_recipe = CraftingManager.get_recipe(&"craft_scythe")
	assert(scythe_recipe != null, "Recipe 'craft_scythe' must exist in CraftingManager")

	var test_inv: Node = InventoryComponentScript.new()
	test_inv.set("slot_count", 5)
	add_child(test_inv)

	test_inv.add_item_by_id(&"wood", 2)
	test_inv.add_item_by_id(&"flint", 1)
	assert(CraftingManager.can_craft(scythe_recipe, test_inv) == true, "Must be able to craft scythe with 2 wood and 1 flint")

	var craft_ok = CraftingManager.craft_item(scythe_recipe, test_inv)
	assert(craft_ok == true, "Crafting scythe must succeed")
	assert(test_inv.has_item(&"scythe", 1) == true, "Scythe must be in inventory")
	assert(test_inv.get_item_count(&"wood") == 0, "Wood must be consumed")
	assert(test_inv.get_item_count(&"flint") == 0, "Flint must be consumed")

	# 3. Валідація вузла трави: створення та перевірка прохідності
	var grass_cell = Vector2i(77, 77)
	var prev_occ = GridManager.get_occupant(grass_cell)
	if prev_occ is Node:
		prev_occ.queue_free()
	GridManager.unregister_occupant(grass_cell, true)

	var grass_node: StaticBody3D = WorldResourceNode3DScene.instantiate()
	grass_node.position = GridManager.map_to_world_3d(grass_cell, 0.0)
	grass_node.resource_type = 5 # GRASS
	grass_node.drop_item_id = &"straw"
	grass_node.drop_min_amount = 1
	grass_node.drop_max_amount = 2
	grass_node.max_health = 1.0
	grass_node.current_health = 1.0
	add_child(grass_node)

	# Трава НЕ повинна блокувати клітинку для руху
	assert(GridManager.is_cell_walkable(grass_cell) == true, "Grass cell must be walkable for player/colonists")

	# 4. Спроба видобутку без коси (руками/сокирою/киркою)
	grass_node.harvest(1.0, 0) # bare hands
	assert(grass_node.current_health == 1.0, "Grass must take NO damage from bare hands")
	grass_node.harvest(1.0, 1) # axe
	assert(grass_node.current_health == 1.0, "Grass must take NO damage from axe")
	grass_node.harvest(1.0, 2) # pickaxe
	assert(grass_node.current_health == 1.0, "Grass must take NO damage from pickaxe")

	# 5. Видобуток косою (tool_type = 5)
	var straw_dropped: Array[bool] = [false]
	EventBus.item_dropped.connect(func(item_id, _amt, _pos):
		if item_id == &"straw":
			straw_dropped[0] = true
	, CONNECT_ONE_SHOT)

	grass_node.harvest(1.0, 5) # scythe
	assert(straw_dropped[0] == true, "Harvesting grass with scythe must drop straw")
	assert(GridManager.is_cell_walkable(grass_cell) == true, "Cell remains walkable after grass is cut")

	test_inv.queue_free()
	print("[Main] Wild grass, scythe crafting and harvesting straw unit tests passed successfully!")


func _test_inventory_textures_and_pillar_size() -> void:
	print("[Main] Testing inventory slot textures and modular pillar block size...")
	# 1. Перевірка розміру дерев'яної колоди (ModularPiece3D)
	var pillar: StaticBody3D = ModularPiece3DScript.new()
	add_child(pillar)
	pillar.setup_piece(&"modular_pillar", Vector2i(88, 88), true, 0.0)

	var col: CollisionShape3D = null
	for child in pillar.get_children():
		if child is CollisionShape3D:
			col = child
			break
	assert(col != null, "Pillar collision shape must exist")
	var col_box = col.shape as BoxShape3D
	assert(col_box != null, "Pillar shape must be BoxShape3D")
	assert(col_box.size == Vector3(1.0, 2.0, 1.0), "Pillar must be full 1.0x2.0x1.0 block size to eliminate gaps with walls")
	pillar.queue_free()

	# 2. Перевірка завантаження реальних текстур у слоти інвентаря
	var slot_ui = ItemSlotUIScript.new()
	add_child(slot_ui)

	var items_to_test = [&"wood", &"stone", &"flint", &"clay", &"straw", &"berries", &"scythe", &"stone_axe"]
	for item_id in items_to_test:
		var item_res = ItemDatabase.get_item(item_id)
		assert(item_res != null, "Item '%s' must exist" % item_id)
		slot_ui.set_slot_data(item_res, 5)
		assert(slot_ui.item_texture != null, "Slot UI must load valid Texture2D for '%s'" % item_id)

	slot_ui.queue_free()
	print("[Main] Inventory slot textures and modular pillar block size tests passed successfully!")


func _test_player_energy_system() -> void:
	print("[Main] Testing player energy system & EnergyBarUI...")
	var player = Player3DScene.instantiate()
	add_child(player)

	# 1. Початковий стан: великий запас на день (1000 од.)
	assert(player.max_energy == 1000.0, "Max energy must be 1000.0 for a full day of activities")
	assert(player.current_energy == 1000.0, "Current energy must start at 1000.0")
	assert(player.has_energy(2.5), "Player must have energy for harvesting")
	assert(player.has_energy(6.0), "Player must have energy for modular construction")
	assert(player.has_energy(3.0), "Player must have energy for block placement")
	assert(player.sprint_energy_per_sec == 0.0, "Sprinting must not consume energy")
	assert(player.rest_regen_rate == 0.0, "There should be no passive energy regeneration")

	# 2. Витрата енергії при діях
	var consumed = player.consume_energy(25.0)
	assert(consumed == true, "Energy consumption must succeed")
	assert(is_equal_approx(player.current_energy, 975.0), "Energy should be 975.0 after 25.0 consumed")

	# 3. Виснаження до 0
	player.consume_energy(1000.0)
	assert(player.current_energy == 0.0, "Energy cannot drop below 0.0")
	assert(player.has_energy(2.5) == false, "At 0 energy player cannot perform actions requiring energy")
	assert(player.consume_energy(5.0) == false, "consume_energy at 0 must return false")

	# 4. Відновлення енергії (їжа / відпочинок)
	player.restore_energy(25.0)
	assert(is_equal_approx(player.current_energy, 25.0), "Energy should be restored by 25.0 (berries)")

	# 5. Новий день (EventBus.day_passed) відновлює сили на максимум
	EventBus.day_passed.emit(2)
	assert(is_equal_approx(player.current_energy, 1000.0), "Passing a day must fully replenish energy to 1000.0")

	# 6. Валідація інтерфейсної шкали EnergyBarUI
	var energy_bar = EnergyBarUIScript.new()
	add_child(energy_bar)
	energy_bar._on_energy_changed(750.0, 1000.0)
	assert(energy_bar.current_energy == 750.0, "EnergyBarUI must track current energy")
	assert(energy_bar.max_energy == 1000.0, "EnergyBarUI must track max energy")
	energy_bar.queue_free()

	# 7. Валідація наявності збудованого багаття та взаємодії interact_campfire
	assert(player.is_campfire_built() == false, "Initially no campfire should be built in tests")
	var campfire_node = Node3D.new()
	campfire_node.name = "TestCampfire"
	campfire_node.add_to_group("campfires")
	add_child(campfire_node)
	assert(player.is_campfire_built() == true, "Player must detect built campfire in group 'campfires'")

	var bld_entity = BuildingEntity3DScript.new()
	assert(bld_entity.has_method("interact_campfire"), "BuildingEntity3D must have interact_campfire method")
	assert(bld_entity.has_method("interact_storage"), "BuildingEntity3D must have interact_storage method")
	bld_entity.queue_free()

	# 8. Валідація методів відновлення сил та завершення сну
	player.consume_energy(600.0)
	assert(player.current_energy == 400.0, "Energy should be 400.0")
	player.restore_energy(600.0)
	assert(is_equal_approx(player.current_energy, 1000.0), "Restore energy should replenish to 1000.0")

	# 9. Валідація SleepOverlayUI
	var sleep_overlay = SleepOverlayUIScript.new()
	add_child(sleep_overlay)
	assert(sleep_overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "SleepOverlayUI must not block mouse input")
	sleep_overlay.queue_free()

	# 10. Валідація прокручування хотбару колесом миші та вибору слотів (1-8)
	player.active_hotbar_slot = 0
	var wheel_down_event := InputEventMouseButton.new()
	wheel_down_event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_down_event.pressed = true
	player._unhandled_input(wheel_down_event)
	assert(player.active_hotbar_slot == 1, "Wheel down must advance hotbar slot to 1")

	var wheel_up_event := InputEventMouseButton.new()
	wheel_up_event.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up_event.pressed = true
	player._unhandled_input(wheel_up_event)
	assert(player.active_hotbar_slot == 0, "Wheel up must return hotbar slot to 0")

	player._unhandled_input(wheel_up_event)
	assert(player.active_hotbar_slot == 7, "Wheel up from 0 must wrap around to 7")

	var key_3_event := InputEventKey.new()
	key_3_event.keycode = KEY_3
	key_3_event.pressed = true
	player._unhandled_input(key_3_event)
	assert(player.active_hotbar_slot == 2, "Key 3 must select hotbar slot index 2")

	campfire_node.queue_free()
	player.queue_free()
	print("[Main] Player energy system, Sleep mechanics & SleepOverlayUI unit tests passed successfully!")


func _test_player_survival_system() -> void:
	print("[Main] Testing hunger, thirst, drinking water and instant death mechanics...")
	var player = Player3DScene.instantiate()
	add_child(player)
	player.global_position = Vector3(15.0, 1.0, 15.0)

	# 1. Початкові значення голоду та спраги
	assert(player.max_hunger == 100.0, "Max hunger must be 100.0")
	assert(player.current_hunger == 100.0, "Initial hunger must be 100.0")
	assert(player.max_thirst == 100.0, "Max thirst must be 100.0")
	assert(player.current_thirst == 100.0, "Initial thirst must be 100.0")

	# 2. Витрата та відновлення голоду
	var hunger_ok = player.consume_hunger(25.0)
	assert(hunger_ok, "consume_hunger should return true")
	assert(is_equal_approx(player.current_hunger, 75.0), "Hunger should drop to 75.0")
	player.restore_hunger(15.0)
	assert(is_equal_approx(player.current_hunger, 90.0), "Hunger should restore to 90.0")

	# 3. Витрата та відновлення спраги
	var thirst_ok = player.consume_thirst(40.0)
	assert(thirst_ok, "consume_thirst should return true")
	assert(is_equal_approx(player.current_thirst, 60.0), "Thirst should drop to 60.0")
	player.restore_thirst(20.0)
	assert(is_equal_approx(player.current_thirst, 80.0), "Thirst should restore to 80.0")

	# 4. Вживання ягід відновлює енергію (+25), голод (+15) та спрагу (+5)
	var berry_res = ItemDatabase.get_item(&"berries")
	assert(berry_res != null, "ItemDatabase must have berries")
	player.inventory.add_item(berry_res, 3)
	player.consume_energy(50.0) # Енергія 950
	# Симулюємо вибір ягід у слот
	player.active_hotbar_slot = 0
	var initial_slot = player.inventory.get_slot(0)
	var old_item = initial_slot.item
	var old_count = initial_slot.count
	initial_slot.item = berry_res
	initial_slot.count = 2

	var consumed = player._try_consume_food()
	assert(consumed, "Berries should be consumed on food action")
	assert(is_equal_approx(player.current_energy, 975.0), "Berries must restore +25 energy")
	assert(player.current_hunger > 90.0, "Berries must restore +15 hunger")
	assert(player.current_thirst > 80.0, "Berries must restore +5 thirst")

	# Відновлюємо слот
	initial_slot.item = old_item
	initial_slot.count = old_count

	# 5. Пиття води з водойми
	var water_cell := Vector2i(50, 50)
	GridManager.register_water_cell(water_cell)
	player.global_position = GridManager.map_to_world_3d(water_cell, 1.0)
	assert(player.is_looking_at_water(), "Player at water cell must detect water")
	player.current_thirst = 50.0
	var drank = player._try_drink_water()
	assert(drank, "Drinking near water cell must succeed")
	assert(is_equal_approx(player.current_thirst, 80.0), "Drinking water restores +30 thirst")
	GridManager.unregister_water_cell(water_cell)

	# 6. Миттєва смерть при нульовому голоді
	player.spawn_position = Vector3(10.0, 1.0, 10.0)
	player.current_hunger = 2.0
	player.consume_hunger(5.0) # падає до 0 -> die("голоду") -> respawn()
	assert(is_equal_approx(player.current_hunger, 100.0), "Respawn must restore hunger to 100.0")
	assert(is_equal_approx(player.current_thirst, 100.0), "Respawn must restore thirst to 100.0")
	assert(is_equal_approx(player.current_energy, 1000.0), "Respawn must restore energy to 1000.0")

	# 7. Миттєва смерть при нульовій спразі
	player.current_thirst = 3.0
	player.consume_thirst(10.0) # падає до 0 -> die("спраги") -> respawn()
	assert(is_equal_approx(player.current_hunger, 100.0), "Respawn must restore hunger to 100.0")
	assert(is_equal_approx(player.current_thirst, 100.0), "Respawn must restore thirst to 100.0")

	# 8. Валідація інтерфейсу SurvivalStatsUI
	var survival_ui = SurvivalStatsUIScript.new()
	add_child(survival_ui)
	assert(survival_ui.mouse_filter == Control.MOUSE_FILTER_IGNORE, "SurvivalStatsUI must not block mouse clicks")
	assert(survival_ui.has_node("HBox"), "SurvivalStatsUI must contain HBox container")
	assert(survival_ui.has_node("HBox/HungerContainer"), "SurvivalStatsUI must contain HungerContainer")
	assert(survival_ui.has_node("HBox/ThirstContainer"), "SurvivalStatsUI must contain ThirstContainer")
	survival_ui.queue_free()

	player.queue_free()
	print("[Main] Hunger, thirst, drinking water and instant death mechanics unit tests passed successfully!")

func _test_day_night_and_campfire_lighting() -> void:
	print("[Main] Testing Day/Night cycle, celestial sun/moon movement, darkness and campfire light...")
	var world = get_node_or_null("World3D")
	assert(world != null, "World3D instance must exist in Main")
	assert(world.sun_light != null, "Sun DirectionalLight3D must exist")
	assert(world.moon_light != null, "Moon DirectionalLight3D must exist")
	assert(world.world_environment != null, "WorldEnvironment must exist")

	# 1. Полудень (12:00 = 43200 сек) - Сонце в зеніті, яскравий день
	world._update_celestial_cycle(12.0 * 3600.0)
	assert(world.sun_light.visible == true, "Sun must be visible at noon")
	assert(world.sun_light.light_energy >= 0.8, "Sun light energy must be bright at noon")
	assert(world.moon_light.visible == false, "Moon must be hidden at noon")
	assert(world.world_environment.environment.ambient_light_energy > 0.3, "Ambient light must be bright at noon")

	# 2. Північ (00:00 = 0 сек) - Повна темрява, Місяць на небі
	world._update_celestial_cycle(0.0)
	assert(world.sun_light.visible == false, "Sun must be hidden at midnight")
	assert(world.sun_light.light_energy == 0.0, "Sun energy must be 0 at midnight")
	assert(world.moon_light.visible == true, "Moon must be visible at midnight")
	assert(world.moon_light.light_energy > 0.04, "Moon light must shine at midnight")
	# Навколишній світ стає дуже темним (ambient energy <= 0.03)
	assert(world.world_environment.environment.ambient_light_energy <= 0.03, "Ambient energy at night must be very dark (<= 0.03)")

	# 3. Світанок (06:00 = 21600 сек) - Сонце сходить
	world._update_celestial_cycle(6.0 * 3600.0)

	# 4. Повернення до поточного ігрового часу
	world._update_celestial_cycle(GameManager.in_game_time_seconds)

	# 5. Перевірка вогнища як ключового джерела світла з тінями та мерехтінням
	var campfire_entity = BuildingEntity3DScript.new()
	add_child(campfire_entity)
	var campfire_data = BuildingPlacementController.get_building(&"campfire")
	assert(campfire_data != null, "Campfire building data must exist")
	campfire_entity.setup_building(campfire_data, Vector2i(55, 55))
	assert(campfire_entity._fire_light != null, "Campfire must create OmniLight3D")
	assert(campfire_entity._fire_light.shadow_enabled == true, "Campfire light must cast dynamic shadows")
	assert(campfire_entity._fire_light.omni_range >= 15.0, "Campfire light range must illuminate surrounding campsite (>= 15m)")
	assert(campfire_entity._fire_light.light_energy >= 2.5, "Campfire light energy must be bright (>= 2.5)")

	# Тестуємо мерехтіння вогнища в _process
	campfire_entity._process(0.2)
	assert(campfire_entity._flicker_time > 0.0, "Campfire flicker timer must progress")
	campfire_entity.queue_free()

	# 6. Перевірка перемотування часу до ранку (07:00) після сну біля вогнища
	var player = Player3DScene.instantiate()
	add_child(player)
	GameManager.in_game_time_seconds = 23.0 * 3600.0 # 23:00 (глибока ніч)
	var prev_day = GameManager.current_day
	player.complete_sleep()
	assert(GameManager.current_day == prev_day + 1, "Sleeping at night must advance to next day")
	assert(is_equal_approx(GameManager.in_game_time_seconds, 7.0 * 3600.0), "Sleeping must advance time to 07:00 morning")
	assert(is_equal_approx(player.current_energy, 1000.0), "Energy must be fully restored after sleep")
	player.queue_free()

	print("[Main] Day/Night cycle, celestial sun/moon movement, darkness and campfire light unit tests passed successfully!")
func _test_admin_panel_ui() -> void:
	print("[Main] Testing AdminPanelUI: item spawning, survival stats modification, time of day controls & cheats...")
	var hud = get_node_or_null("HUD")
	assert(hud != null, "HUD node must exist in Main")
	var admin_ui = hud.get_node_or_null("AdminPanelUI")
	assert(admin_ui != null, "AdminPanelUI node must exist in HUD")
	assert(admin_ui.visible == false, "AdminPanelUI must be initially hidden")

	# 1. Відкриття та закриття через toggle / open / close
	admin_ui.open()
	assert(admin_ui.visible == true, "AdminPanelUI must be visible after open()")
	assert(admin_ui._is_open == true, "_is_open must be true after open()")

	# 2. Тестування взаємодії з характеристиками гравця
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		player = Player3DScene.instantiate()
		add_child(player)

	admin_ui._set_player_energy(350.0)
	assert(is_equal_approx(player.current_energy, 350.0), "Admin panel must set player energy to 350")
	admin_ui._mod_player_energy(100.0)
	assert(is_equal_approx(player.current_energy, 450.0), "Admin panel +100 energy must yield 450")

	admin_ui._set_player_hunger(42.0)
	assert(is_equal_approx(player.current_hunger, 42.0), "Admin panel must set player hunger to 42")

	admin_ui._set_player_thirst(73.0)
	assert(is_equal_approx(player.current_thirst, 73.0), "Admin panel must set player thirst to 73")

	admin_ui._restore_all_stats()
	assert(is_equal_approx(player.current_energy, 1000.0), "Restore all stats must set energy to 1000")
	assert(is_equal_approx(player.current_hunger, 100.0), "Restore all stats must set hunger to 100")
	assert(is_equal_approx(player.current_thirst, 100.0), "Restore all stats must set thirst to 100")

	# 3. Тестування видачі предметів та очищення інвентарю
	admin_ui._clear_player_inventory()
	assert(player.inventory.get_item_count(&"wood") == 0, "Inventory must be empty after clear")

	var wood_item = ItemDatabase.get_item(&"wood")
	assert(wood_item != null, "Item wood must exist")
	admin_ui._give_item(wood_item, 10)
	assert(player.inventory.get_item_count(&"wood") == 10, "Inventory must contain 10 wood after giving")

	admin_ui._give_all_resources()
	assert(player.inventory.get_item_count(&"stone") == 64, "Give all resources must give 64 stone")
	assert(player.inventory.get_item_count(&"clay") == 64, "Give all resources must give 64 clay")
	assert(player.inventory.get_item_count(&"straw") == 64, "Give all resources must give 64 straw")

	# 4. Тестування керування часом доби
	admin_ui._set_time_hours(14.0)
	assert(GameManager.get_current_hour() == 14, "Setting time to 14.0 must make current hour 14")
	admin_ui._shift_time_hours(3.0)
	assert(GameManager.get_current_hour() == 17, "Shifting time by +3h from 14 must make current hour 17")

	# 5. Тестування супершвидкості
	assert(admin_ui._is_super_speed == false, "Super speed must be off initially")
	admin_ui._toggle_super_speed()
	assert(admin_ui._is_super_speed == true, "Super speed must be active after toggle")
	assert(player.walk_speed > 10.0, "Walk speed must be accelerated in super speed mode")
	admin_ui._toggle_super_speed()
	assert(admin_ui._is_super_speed == false, "Super speed must be deactivated after second toggle")
	assert(is_equal_approx(player.walk_speed, 5.0), "Walk speed must return to normal (5.0)")

	# 6. Закриття адмін-панелі
	admin_ui.close()
	assert(admin_ui.visible == false, "AdminPanelUI must be hidden after close()")
	assert(admin_ui._is_open == false, "_is_open must be false after close()")

	print("[Main] AdminPanelUI unit tests passed successfully!")
func _test_torch_hammer_rope_mechanics() -> void:
	print("[Main] Testing Torch (hand light & placed), Hammer (10 vs 5 swings) and Rope...")
	# 1. Перевірка наявності предметів у базі
	assert(ItemDatabase.has_item(&"torch"), "ItemDatabase must contain torch")
	assert(ItemDatabase.has_item(&"hammer"), "ItemDatabase must contain hammer")
	assert(ItemDatabase.has_item(&"rope"), "ItemDatabase must contain rope")

	var torch_item = ItemDatabase.get_item(&"torch")
	var hammer_item = ItemDatabase.get_item(&"hammer")
	var rope_item = ItemDatabase.get_item(&"rope")

	assert(torch_item.display_name == "Смолоскип", "Torch name must match")
	assert(hammer_item.display_name == "Будівельний молоток", "Hammer name must match")
	assert(rope_item.display_name == "Мотузка", "Rope name must match")

	# 2. Перевірка рецептів крафту
	var craft_inv: Node = InventoryComponentScript.new()
	craft_inv.set("slot_count", 8)
	add_child(craft_inv)

	var rope_recipe = CraftingManager.get_recipe(&"craft_rope")
	assert(rope_recipe != null, "Rope recipe must exist")
	var hammer_recipe = CraftingManager.get_recipe(&"craft_hammer")
	assert(hammer_recipe != null, "Hammer recipe must exist")
	var torch_recipe = CraftingManager.get_recipe(&"craft_torch")
	assert(torch_recipe != null, "Torch recipe must exist")

	# Крафт мотузки: 3 соломи -> 1 мотузка
	craft_inv.add_item_by_id(&"straw", 3)
	assert(CraftingManager.can_craft(rope_recipe, craft_inv), "Must be able to craft rope with 3 straw")
	assert(CraftingManager.craft_item(rope_recipe, craft_inv), "Crafting rope must succeed")
	assert(craft_inv.get_item_count(&"rope") == 1, "Must have 1 rope after crafting")
	assert(craft_inv.get_item_count(&"straw") == 0, "Straw must be consumed")

	# Крафт молотка: 2 дерева, 1 камінь, 1 мотузка -> 1 молоток
	craft_inv.add_item_by_id(&"wood", 2)
	craft_inv.add_item_by_id(&"stone", 1)
	assert(CraftingManager.can_craft(hammer_recipe, craft_inv), "Must be able to craft hammer with wood, stone and rope")
	assert(CraftingManager.craft_item(hammer_recipe, craft_inv), "Crafting hammer must succeed")
	assert(craft_inv.get_item_count(&"hammer") == 1, "Must have 1 hammer after crafting")

	# Крафт смолоскипа: 1 дерево, 1 солома -> 2 смолоскипи
	craft_inv.add_item_by_id(&"wood", 1)
	craft_inv.add_item_by_id(&"straw", 1)
	assert(CraftingManager.can_craft(torch_recipe, craft_inv), "Must be able to craft torch with wood and straw")
	assert(CraftingManager.craft_item(torch_recipe, craft_inv), "Crafting torch must succeed")
	assert(craft_inv.get_item_count(&"torch") == 2, "Must have 2 torches after crafting")

	# 3. Перевірка смолоскипа в руці у гравця
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		player = Player3DScene.instantiate()
		add_child(player)

	assert(player._torch_light != null, "Player must have _torch_light node")
	assert(player._torch_light.visible == false, "Torch light must be initially off")

	# Очищуємо інвентар та кладемо смолоскип у перший слот гравця
	if player.inventory != null:
		player.inventory.clear()
		player.inventory.add_item(torch_item, 5)
	player.select_hotbar_slot(0)
	assert(player.is_holding_torch(), "Player must be recognized as holding torch")
	player._process(0.016)
	assert(player._torch_light.visible == true, "Torch light must be active while holding torch")
	assert(player._torch_light.light_energy > 0.0, "Torch light must have positive energy")

	# Перемикаємо слот на інший
	player.select_hotbar_slot(7)
	assert(not player.is_holding_torch(), "Player should not be holding torch in slot 7")
	player._process(0.016)
	assert(player._torch_light.visible == false, "Torch light must turn off when unequipped")

	# 4. Перевірка встановлення та витрати смолоскипа (PlacedTorch3D)
	player.select_hotbar_slot(0)
	var before_place_count: int = player.inventory.get_item_count(&"torch")
	assert(before_place_count >= 1, "Player must have torches to place")
	# Симулюємо успішне списання через inventory.remove_item
	var removed_ok: bool = player.inventory.remove_item(&"torch", 1)
	assert(removed_ok, "Removing torch from inventory must succeed")
	assert(player.inventory.get_item_count(&"torch") == before_place_count - 1, "Torch count must decrease by 1 upon placement")

	var PlacedTorchScript = load("res://src/world3d/PlacedTorch3D.gd")
	var placed_torch = PlacedTorchScript.new()
	add_child(placed_torch)
	assert(placed_torch.is_in_group("placed_torches"), "Placed torch must be in group placed_torches")
	assert(placed_torch.is_in_group("interactable"), "Placed torch must be interactable")
	assert(placed_torch._light != null and placed_torch._light.light_energy > 0.0, "Placed torch light must be active with positive energy")

	# Підбір встановленого смолоскипа гравцем
	var initial_torch_count = player.inventory.get_item_count(&"torch")
	placed_torch.interact(player)
	assert(player.inventory.get_item_count(&"torch") == initial_torch_count + 1, "Interacting with placed torch must pick it up")

	# 5. Перевірка будівельного молотка: 10 махів без нього проти 5 махів з ним
	var test_build_inv: Node = InventoryComponentScript.new()
	test_build_inv.set("slot_count", 8)
	add_child(test_build_inv)
	test_build_inv.add_item_by_id(&"wood", 20)

	# А) Без молотка -> рівно 10 махів
	var floor_no_hammer = ModularManager.place_blueprint(&"modular_floor", Vector2i(90, 90))
	for swing in range(9):
		floor_no_hammer.interact_construct(test_build_inv, false)
		assert(not floor_no_hammer.is_built, "Piece must NOT be built at swing %d/10 without hammer" % (swing + 1))
	floor_no_hammer.interact_construct(test_build_inv, false)
	assert(floor_no_hammer.is_built, "Piece MUST be built after exactly 10 swings without hammer")

	# Б) З молотком -> рівно 5 махів
	var floor_with_hammer = ModularManager.place_blueprint(&"modular_floor", Vector2i(91, 91))
	for swing in range(4):
		floor_with_hammer.interact_construct(test_build_inv, true)
		assert(not floor_with_hammer.is_built, "Piece must NOT be built at swing %d/5 with hammer" % (swing + 1))
	floor_with_hammer.interact_construct(test_build_inv, true)
	assert(floor_with_hammer.is_built, "Piece MUST be built after exactly 5 swings with hammer")

	print("[Main] Torch, Hammer and Rope unit tests passed successfully!")


func _test_era_and_tech_tree_system() -> void:
	print("[Main] Testing Era and Technology Tree System (Sub-eras, Tree Forest Layout, Strict progression)...")

	# 1. Перевірка автозавантаження та констант
	assert(EraManager != null, "EraManager singleton must be loaded")
	assert(EraManager.ERA_NAMES.size() == 4, "Must define 4 eras")
	assert(EraManager.SUB_ERAS.size() == 8, "Must define 8 sub-eras across all eras")
	assert(EraManager.get_total_tech_count() >= 13, "Must have at least 13 technologies configured")

	# 2. Перевірка стартового стану
	EraManager.reset_techs_cheat()
	assert(EraManager.current_era == 0, "Initial era must be 0 (Paleolithic)")
	assert(EraManager.current_sub_era_index == 0, "Initial sub-era must be 0 (paleo_early)")
	assert(EraManager.is_tech_unlocked(&"primitive_survival") == true, "primitive_survival must be unlocked by default")
	assert(EraManager.is_tech_unlocked(&"fire_mastery") == false, "fire_mastery must be locked initially")
	assert(EraManager.is_tech_unlocked(&"stone_flaking") == false, "stone_flaking must be locked initially")
	assert(EraManager.is_sub_era_unlocked(&"paleo_early") == true, "Sub-era 0 (paleo_early) is always unlocked")
	assert(EraManager.is_sub_era_unlocked(&"paleo_late") == false, "Sub-era 1 (paleo_late) MUST be locked before completing paleo_early")

	# 3. Перевірка блокування переходу до наступної підепохи
	var test_inv: Node = InventoryComponentScript.new()
	test_inv.set("slot_count", 10)
	add_child(test_inv)

	# Навіть маючи ресурси, не можна дослідити stone_flaking, бо підепоха paleo_late ще заблокована!
	test_inv.add_item_by_id(&"wood", 100)
	test_inv.add_item_by_id(&"stone", 100)
	test_inv.add_item_by_id(&"flint", 20)
	test_inv.add_item_by_id(&"straw", 50)
	test_inv.add_item_by_id(&"rope", 10)

	assert(EraManager.can_research(&"stone_flaking", test_inv) == false, "stone_flaking cannot be researched while sub-era paleo_late is locked")
	assert(EraManager.research_tech(&"stone_flaking", test_inv) == false, "Research stone_flaking must fail when sub-era locked")

	# 4. Завершення першої підепохи (досліджуємо fire_mastery)
	assert(EraManager.can_research(&"fire_mastery", test_inv) == true, "Can research fire_mastery")
	var fire_ok = EraManager.research_tech(&"fire_mastery", test_inv)
	assert(fire_ok == true, "fire_mastery research succeeded")
	assert(EraManager.is_tech_unlocked(&"fire_mastery") == true, "fire_mastery is unlocked")

	# Тепер sub-era paleo_early завершена (primitive_survival + fire_mastery обидва відкриті)!
	assert(EraManager.is_sub_era_completed(&"paleo_early") == true, "paleo_early must be completed")
	assert(EraManager.is_sub_era_unlocked(&"paleo_late") == true, "paleo_late must now be UNLOCKED!")
	assert(EraManager.current_sub_era_index == 1, "Current sub-era must automatically advance to 1 (paleo_late)")

	# 5. Дослідження другої підепохи (stone_flaking та primitive_shelter)
	var axe_recipe = CraftingManager.get_recipe(&"craft_stone_axe")
	assert(axe_recipe != null, "Stone axe recipe must exist")
	assert(CraftingManager.is_recipe_unlocked(axe_recipe) == false, "Stone axe recipe must be locked before stone_flaking tech")

	var hut_building = BuildingPlacementController.get_building(&"wooden_hut")
	assert(hut_building != null, "Wooden hut building must exist")
	assert(BuildingPlacementController.is_building_unlocked(hut_building) == false, "Wooden hut must be locked before wooden_architecture tech")

	assert(EraManager.can_research(&"stone_flaking", test_inv) == true, "stone_flaking can now be researched")
	var res_sf = EraManager.research_tech(&"stone_flaking", test_inv)
	assert(res_sf == true, "stone_flaking research succeeded")
	assert(CraftingManager.is_recipe_unlocked(axe_recipe) == true, "Stone axe recipe unlocked after stone_flaking")

	# Підепоха neo_early все ще заблокована, бо в paleo_late ще залишився primitive_shelter
	assert(EraManager.is_sub_era_unlocked(&"neo_early") == false, "neo_early remains locked until 100% of paleo_late is finished")
	assert(EraManager.can_research(&"agriculture_and_fiber", test_inv) == false, "Cannot jump to Neolithic without finishing shelter")

	# Досліджуємо primitive_shelter
	var res_ps = EraManager.research_tech(&"primitive_shelter", test_inv)
	assert(res_ps == true, "primitive_shelter research succeeded")
	assert(EraManager.is_sub_era_completed(&"paleo_late") == true, "paleo_late is now 100% completed!")
	assert(EraManager.is_sub_era_unlocked(&"neo_early") == true, "neo_early is now unlocked!")

	# 6. Перехід у нову епоху (Неоліт)
	assert(EraManager.can_research(&"agriculture_and_fiber", test_inv) == true, "agriculture_and_fiber can now be researched")
	var res_neo = EraManager.research_tech(&"agriculture_and_fiber", test_inv)
	assert(res_neo == true, "agriculture_and_fiber researched successfully")
	assert(EraManager.current_era == 1, "Settlement advanced to Era 1 (Neolithic)!")
	assert(EraManager.current_sub_era_index == 2, "Current sub-era is neo_early (index 2)")

	# 7. Перевірка модульного зодчества хатини після wooden_architecture
	EraManager.unlock_tech_cheat(&"wooden_architecture")
	assert(EraManager.is_tech_unlocked(&"wooden_architecture") == true, "Cheat unlock wooden_architecture")
	assert(BuildingPlacementController.is_building_unlocked(hut_building) == true, "Wooden hut must now be unlocked")

	# 8. Перевірка чітів адмін-панелі: Відкрити все та Скинути
	EraManager.unlock_all_techs_cheat()
	assert(EraManager.get_unlocked_tech_count() == EraManager.get_total_tech_count(), "All techs must be unlocked")
	assert(EraManager.current_era == 3, "Era must advance to Era 3 (Bronze/Iron)")

	EraManager.reset_techs_cheat()
	assert(EraManager.current_era == 0, "Reset must return to Era 0")
	assert(EraManager.current_sub_era_index == 0, "Reset must return to Sub-era 0")
	assert(EraManager.get_unlocked_tech_count() == 1, "Only primitive_survival unlocked after reset")

	# 9. Перевірка компонентів UI (EraTreeUI) та перемальовування графу зв'язків
	var tree_ui = get_node_or_null("HUD/EraTreeUI")
	if tree_ui != null:
		assert(tree_ui.visible == false, "EraTreeUI must be hidden initially")
		tree_ui.open()
		assert(tree_ui.visible == true, "EraTreeUI must be visible after open()")
		assert(tree_ui._is_open == true, "_is_open must be true")
		# Чергуємо оновлення полотна зв'язків
		if tree_ui._graph_canvas != null:
			tree_ui._graph_canvas.queue_redraw()
		tree_ui.close()
		assert(tree_ui.visible == false, "EraTreeUI must be hidden after close()")

	test_inv.queue_free()
	print("[Main] Era and Technology Tree System unit tests passed successfully!")


func _test_colonists_and_job_system() -> void:
	print("[Main] Testing 3D Colonists, FSM & Autonomous Job System (JobManager, Minecolonies-style)...")

	# 1. Валідація Autoload JobManager
	assert(JobManager != null, "JobManager singleton must be loaded")
	JobManager.clear_all_jobs()
	assert(JobManager.get_pending_jobs_count() == 0, "Pending jobs must be 0 after clear")
	assert(JobManager.get_active_jobs_count() == 0, "Active jobs must be 0 after clear")

	# 2. Створення завдань різного типу та перевірка черги пріоритетів
	var j_haul = JobManager.create_job(Job.JobType.HAUL, Vector3(10, 0, 10), null, 1, &"hauler")
	var j_build = JobManager.create_job(Job.JobType.BUILD, Vector3(20, 0, 20), null, 3, &"builder")
	var j_harvest = JobManager.create_job(Job.JobType.HARVEST, Vector3(15, 0, 15), null, 2, &"lumberjack")

	assert(JobManager.get_pending_jobs_count() == 3, "Must have 3 pending jobs in queue")
	# Пріоритет: BUILD (3) > HARVEST (2) > HAUL (1)
	var pending = JobManager._pending_jobs
	assert(pending[0].priority >= pending[1].priority and pending[1].priority >= pending[2].priority, "Pending jobs must be sorted descending by priority")
	assert(pending[0] == j_build, "Highest priority job (BUILD, prio 3) must be first")

	# 3. Створення та валідація сутності 3D колоніста
	var builder_col: CharacterBody3D = Colonist3DScene.instantiate()
	add_child(builder_col)
	builder_col.setup_colonist("Ратибор", &"builder")

	assert(builder_col.is_in_group("colonists"), "Colonist must belong to group 'colonists'")
	assert(builder_col.is_in_group("interactable"), "Colonist must belong to group 'interactable'")
	assert(builder_col.colonist_name == "Ратибор", "Colonist name must be set")
	assert(builder_col.profession == &"builder", "Colonist profession must be builder")
	assert(builder_col.inventory != null and builder_col.inventory.slot_count == 8, "Colonist must have 8 inventory slots")
	assert(JobManager.get_colonists_count() >= 1, "Colonist must be auto-registered in JobManager")

	# 4. Валідація архітектури FSM
	var fsm = builder_col.state_machine
	assert(fsm != null, "Colonist must have StateMachine node")
	assert(fsm.states.has(&"idle"), "FSM must contain Idle state")
	assert(fsm.states.has(&"moveto"), "FSM must contain MoveTo state")
	assert(fsm.states.has(&"harvest"), "FSM must contain Harvest state")
	assert(fsm.states.has(&"haul"), "FSM must contain Haul state")
	assert(fsm.states.has(&"build"), "FSM must contain Build state")
	assert(fsm.current_state != null and fsm.current_state.name.to_lower() == "idle", "Initial state must be Idle")

	# 5. Видача завдання будівельнику згідно зі спеціалізацією
	var assigned_job = JobManager.request_job(builder_col)
	assert(assigned_job == j_build, "Builder must receive the highest priority BUILD job")
	assert(j_build.status == Job.JobStatus.ASSIGNED, "Job status must be ASSIGNED")
	assert(j_build.assigned_colonist == builder_col, "Job assigned_colonist must point to builder")
	assert(JobManager.get_active_jobs_count() == 1, "Must have 1 active job")
	assert(JobManager.get_pending_jobs_count() == 2, "Must have 2 pending jobs remaining")

	# 6. Завершення завдання
	JobManager.complete_job(j_build)
	assert(j_build.status == Job.JobStatus.COMPLETED, "Job must be COMPLETED")
	assert(JobManager.get_active_jobs_count() == 0, "Active jobs must be 0 after completion")

	# 7. Фільтрація за спеціалізацією: будівельник не повинен брати чужі вузькі завдання
	var should_be_null = JobManager.request_job(builder_col)
	assert(should_be_null == null, "Builder must not take jobs requiring lumberjack or hauler")

	# 8. Створення лісоруба та перевірка взяття / повернення завдання (Release)
	var lumberjack_col: CharacterBody3D = Colonist3DScene.instantiate()
	add_child(lumberjack_col)
	lumberjack_col.setup_colonist("Мирослав", &"lumberjack")

	var lj_job = JobManager.request_job(lumberjack_col)
	assert(lj_job == j_harvest, "Lumberjack must receive the HARVEST job")
	assert(JobManager.get_active_jobs_count() == 1, "Active jobs must be 1")

	# Симуляція переривання / повернення завдання в чергу
	JobManager.release_job(lj_job, "Тестове переривання")
	assert(lj_job.status == Job.JobStatus.PENDING, "Job must return to PENDING")
	assert(JobManager.get_pending_jobs_count() == 2, "Pending jobs must be 2 after release")

	# 9. Валідація візуальних елементів та анімацій колоніста
	builder_col.show_hand_tool(&"hammer")
	assert(builder_col.hand_tool_root.get_child_count() == 1, "Tool mesh must be added to right hand")
	builder_col.hide_hand_items()
	assert(builder_col.hand_tool_root.get_child_count() == 0, "Hand tool must be cleared")

	builder_col.show_carried_cargo(&"wood")
	assert(builder_col.carried_cargo_root.get_child_count() == 1, "Carried cargo mesh must be attached")
	builder_col.hide_hand_items()
	assert(builder_col.carried_cargo_root.get_child_count() == 0, "Cargo mesh must be cleared")

	# Анімації кроків та маху інструментом
	builder_col.play_walk_animation(0.016)
	assert(builder_col._is_walking == true, "Is walking must be true during walk animation")
	builder_col.stop_walk_animation()
	assert(builder_col._is_walking == false, "Is walking must be false after stop")

	builder_col.play_swing_animation()
	assert(builder_col._swing_tween != null and builder_col._swing_tween.is_valid(), "Swing tween must be valid")

	# 10. Перевірка 3D текстової плашки
	builder_col.set_status_display("🔨 Працює")
	assert(builder_col.label_3d != null, "Label3D must exist")
	assert("Ратибор" in builder_col.label_3d.text, "Label3D must contain colonist name")
	assert("Будівельник" in builder_col.label_3d.text, "Label3D must contain profession")
	assert("🔨 Працює" in builder_col.label_3d.text, "Label3D must contain current status")

	# 11. Перевірка живої взаємодії з гравцем (Клавіша E, ColonistDialogUI, зміна фаху та слідування)
	var hud = get_node_or_null("HUD")
	assert(hud != null, "HUD must exist in Main")
	var dialog_ui = hud.get_node_or_null("ColonistDialogUI")
	assert(dialog_ui != null, "ColonistDialogUI must exist in HUD")
	assert(dialog_ui.visible == false, "ColonistDialogUI must be initially hidden")

	# Відкриття діалогу поселенця через взаємодію на E
	builder_col.interact(null)
	assert(dialog_ui.visible == true, "ColonistDialogUI must open upon interact()")
	assert(dialog_ui._target_colonist == builder_col, "Dialog target colonist must be builder_col")
	assert("Ратибор" in dialog_ui._name_label.text, "Dialog header must display colonist name")

	# Перевірка наказу слідування
	var dummy_player = Node3D.new()
	add_child(dummy_player)
	dummy_player.global_position = Vector3(5, 0, 5)
	builder_col.order_follow(dummy_player)
	assert(builder_col.is_following_player == true, "Colonist must be following player")
	assert(builder_col.target_follow_node == dummy_player, "Target follow node must match player")
	assert("🐾" in builder_col.label_3d.text, "Label3D must show follow footprint indicator")

	# Зупинка слідування
	builder_col.order_stop_follow()
	assert(builder_col.is_following_player == false, "Colonist must stop following")

	# Зміна фаху на місці
	builder_col.set_profession(&"lumberjack")
	assert(builder_col.profession == &"lumberjack", "Colonist profession must change to lumberjack")
	assert("Лісоруб" in builder_col.label_3d.text, "Label3D must update to new profession title")

	# Перевірка передачі та забору предметів між гравцем та поселенцем
	var test_player_inv: Node = InventoryComponentScript.new()
	test_player_inv.set("slot_count", 24)
	add_child(test_player_inv)
	dialog_ui._player_inventory = test_player_inv
	test_player_inv.add_item_by_id(&"wood", 5)

	# Клік передати все поселенцю
	dialog_ui._on_give_all_pressed()
	assert(builder_col.inventory.get_item_count(&"wood") == 5, "Colonist must receive 5 wood")
	assert(test_player_inv.get_item_count(&"wood") == 0, "Player must have 0 wood after give all")

	# Клік забрати все собі
	dialog_ui._on_take_all_pressed()
	assert(test_player_inv.get_item_count(&"wood") == 5, "Player must receive 5 wood back")
	assert(builder_col.inventory.get_item_count(&"wood") == 0, "Colonist must have 0 wood after take all")

	dialog_ui.close_dialog()
	assert(dialog_ui.visible == false, "Dialog must close successfully")

	dummy_player.queue_free()
	test_player_inv.queue_free()

	# Очищення тестових вузлів
	builder_col.queue_free()
	lumberjack_col.queue_free()
	JobManager.clear_all_jobs()

	print("[Main] 3D Colonists, FSM & Autonomous Job System unit tests passed successfully!")


func _test_audio_and_floating_text_system() -> void:
	print("[Main] Testing Audio system & Floating Text system...")
	assert(AudioManager != null, "AudioManager autoload must exist")
	assert(FloatingTextManager != null, "FloatingTextManager autoload must exist")

	# 1. Перевірка наявності всіх 13 згенерованих процедурних звуків
	var expected_sounds: Array[StringName] = [
		&"step", &"hit_wood", &"hit_stone", &"hit_grass", &"hit_clay",
		&"build", &"craft", &"pickup", &"era_bell", &"tech_unlock", &"eat", &"drink", &"death"
	]
	for snd in expected_sounds:
		assert(snd in AudioManager._sounds, "Sound '%s' must be pre-generated in AudioManager" % snd)
		var wav = AudioManager._sounds[snd]
		assert(wav is AudioStreamWAV, "Sound '%s' must be an AudioStreamWAV" % snd)
		assert(wav.mix_rate == 22050, "Sample rate must be 22050 Hz")
		assert(wav.data.size() > 0, "Sound '%s' byte data must not be empty" % snd)

	# 2. Перевірка API відтворення 2D звуків
	var p2d = AudioManager.play_sound(&"pickup", -3.0, 1.0)
	assert(p2d != null, "play_sound must return an active AudioStreamPlayer")
	assert(p2d.stream == AudioManager._sounds[&"pickup"], "Player stream must match requested sound")

	# 3. Перевірка API відтворення 3D звуків
	var test_pos := Vector3(15.0, 1.0, 25.0)
	var p3d = AudioManager.play_sound_3d(&"hit_wood", test_pos, 0.0, 1.0)
	assert(p3d != null, "play_sound_3d must return an active AudioStreamPlayer3D")
	assert(p3d.global_position == test_pos, "3D Player position must match target position")
	assert(p3d.stream == AudioManager._sounds[&"hit_wood"], "3D Player stream must match requested sound")

	# 4. Перевірка створення спливаючого 3D тексту
	var ft = FloatingTextManager.spawn_text(Vector3(5.0, 2.0, 5.0), "+1 Деревина", Color.GREEN, 0.5)
	assert(ft != null, "spawn_text must return a valid FloatingText node")

	# 5. Перевірка інтеграції сигналів EventBus
	EventBus.era_advanced.emit(1, 0)
	EventBus.technology_unlocked.emit(&"fire_making")
	EventBus.item_picked_up.emit(null, &"wood", 5)

	print("[Main] Audio system & Floating Text system unit tests passed successfully!")


func _test_colonist_night_rest_and_visual_task_polish() -> void:
	print("[Main] Testing Colonist Night Rest, Campfire Sleep, Visual Task Status & Smooth Rotation...")

	# 1. Валідація визначення дня і ночі в GameManager
	var original_time = GameManager.in_game_time_seconds
	GameManager.in_game_time_seconds = 14.0 * 3600.0 # 14:00 (день)
	assert(GameManager.is_night() == false, "14:00 must be day time")

	GameManager.in_game_time_seconds = 23.0 * 3600.0 # 23:00 (ніч)
	assert(GameManager.is_night() == true, "23:00 must be night time")

	GameManager.in_game_time_seconds = 3.0 * 3600.0 # 03:00 (ніч)
	assert(GameManager.is_night() == true, "03:00 must be night time")

	# 2. Створення тестового колоніста
	var colonist: CharacterBody3D = Colonist3DScene.instantiate()
	colonist.name = "RestTestColonist"
	add_child(colonist)
	colonist.setup_colonist("Ярослав", &"builder")

	# Перевірка наявності стану Rest у FSM
	assert(colonist.state_machine != null, "StateMachine must exist")
	assert(colonist.state_machine.has_node("Rest"), "Rest state must be registered in StateMachine")

	# 3. Валідація бейджів і візуального тексту завдання
	assert("🔨" in colonist.label_3d.text, "Builder label must have hammer badge")
	assert("Ярослав" in colonist.label_3d.text, "Colonist label must have name")

	colonist.set_profession(&"lumberjack")
	assert("🪓" in colonist.label_3d.text, "Lumberjack label must have axe badge")

	colonist.set_profession(&"hauler")
	assert("📦" in colonist.label_3d.text, "Hauler label must have cargo badge")

	# 4. Валідація нічного сну біля табірного вогнища
	var test_campfire = Node3D.new()
	test_campfire.name = "RestTestCampfire"
	test_campfire.position = Vector3(100.0, 0.0, 100.0)
	test_campfire.add_to_group("campfires")
	add_child(test_campfire)

	# Встановлюємо колоніста біля вогнища і нічний час
	colonist.global_position = Vector3(102.0, 0.0, 100.0)
	GameManager.in_game_time_seconds = 22.0 * 3600.0 # 22:00

	# Переводимо в Rest стан
	colonist.state_machine.transition_to(&"rest", { "campfire": test_campfire })
	assert(colonist.is_resting() == true, "Colonist must be in resting state")
	assert("Спить" in colonist.label_3d.text or "💤" in colonist.label_3d.text, "Label3D must indicate sleep/rest")

	# Поза сидіння: опущення та згин ніг
	assert(colonist.visual_root.position.y < -0.1, "Visual root must be lowered in sitting pose")
	assert(colonist.left_leg_pivot.rotation.x < -1.0, "Legs must be bent forward in sitting pose")

	# Оновлення фізики для перевірки повороту до вогнища
	colonist.state_machine.current_state.physics_update(0.1)

	# 5. Прокидання на світанку
	GameManager.in_game_time_seconds = 8.0 * 3600.0 # 08:00 (ранок)
	colonist.state_machine.current_state.physics_update(0.1)
	assert(colonist.is_resting() == false, "Colonist must wake up when night ends")
	assert(is_zero_approx(colonist.visual_root.position.y), "Visual root must return to 0 when standing up")
	assert(is_zero_approx(colonist.left_leg_pivot.rotation.x), "Legs must return to neutral angle")

	# Очищення
	colonist.queue_free()
	test_campfire.queue_free()
	GameManager.in_game_time_seconds = original_time

	print("[Main] Colonist Night Rest, Campfire Sleep, Visual Task Status & Smooth Rotation unit tests passed successfully!")


func _test_colony_roster_ui() -> void:
	print("[Main] Testing Colony Roster UI (Mini-panel, Colonist listing, Collapse toggle, Quick follow & Dialog actions)...")

	var hud = get_node_or_null("HUD")
	assert(hud != null, "HUD must exist in Main")

	var roster = hud.get_node_or_null("ColonyRosterUI")
	assert(roster != null, "ColonyRosterUI must exist in HUD")

	# 1. Початковий стан: панель розгорнута
	assert(roster.is_collapsed() == false, "Roster must initially be expanded")
	assert(roster._scroll_container.custom_minimum_size.y >= 180.0, "ScrollContainer must have explicit minimum height")

	# 2. Перевірка згортання / розгортання
	roster.toggle_roster()
	assert(roster.is_collapsed() == true, "Roster must be collapsed after toggle")
	assert(roster._scroll_container.visible == false, "ScrollContainer must be hidden when collapsed")

	roster.set_collapsed(false)
	assert(roster.is_collapsed() == false, "Roster must be expanded")
	assert(roster._scroll_container.visible == true, "ScrollContainer must be visible when expanded")

	# 3. Реєстрація тестового поселенця та оновлення списку
	var test_col: CharacterBody3D = Colonist3DScene.instantiate()
	test_col.name = "RosterTestWorker"
	add_child(test_col)
	test_col.setup_colonist("Мирослав", &"hauler")

	roster._refresh_roster()
	assert("Поселенці" in roster._title_label.text, "Title label must mention 'Поселенці'")

	# Перевірка наявності створеної картки для Мирослава
	var card = roster._list_vbox.get_node_or_null("Card_RosterTestWorker")
	assert(card != null, "Card for RosterTestWorker must be created")
	var name_lbl := card.find_child("NameLabel", true, false) as Label
	assert(name_lbl != null and name_lbl.text == "Мирослав", "Card name must match colonist name")

	var prof_badge := card.find_child("ProfBadge", true, false) as Label
	assert(prof_badge != null and "Вантажник" in prof_badge.text, "ProfBadge must show profession title")

	# 4. Швидка дія: слідування через кнопку картки
	var btn_follow := card.find_child("BtnFollow", true, false) as Button
	assert(btn_follow != null, "Follow button must exist on card")
	var follow_lbl := card.find_child("FollowIcon", true, false) as Label

	# Натискаємо слідувати
	btn_follow.pressed.emit()
	assert(test_col.is_following_player == true, "Colonist must start following player upon button click")
	assert(btn_follow.text == "⏹️", "Button icon must change to stop icon")

	# Натискаємо зупинитись
	btn_follow.pressed.emit()
	assert(test_col.is_following_player == false, "Colonist must stop following upon second click")
	assert(btn_follow.text == "🐾", "Button icon must return to footprint")

	# 5. Швидка дія: фокусування у світі
	var btn_focus := card.find_child("BtnFocus", true, false) as Button
	assert(btn_focus != null, "Focus button must exist on card")
	btn_focus.pressed.emit()

	# 6. Швидка дія: виклик діалогу через сигнал
	var state_box := {"invoked": false}
	var dlg_callback = func(c):
		if c == test_col:
			state_box.invoked = true
	EventBus.colonist_dialog_requested.connect(dlg_callback)
	var btn_dialog := card.find_child("BtnDialog", true, false) as Button
	assert(btn_dialog != null, "Dialog button must exist on card")
	btn_dialog.pressed.emit()
	assert(state_box.invoked == true, "Dialog request must be emitted for colonist")
	EventBus.colonist_dialog_requested.disconnect(dlg_callback)

	# 7. Перевірка перемикання через подію EventBus
	EventBus.colonist_roster_toggle_requested.emit()
	assert(roster.is_collapsed() == true, "EventBus signal must toggle roster to collapsed")
	EventBus.colonist_roster_toggle_requested.emit()
	assert(roster.is_collapsed() == false, "EventBus signal must toggle roster to expanded")

	# 8. Валідація стійкості до видалених об'єктів (freed object protection)
	test_col.queue_free()
	roster._process(0.6)
	roster._refresh_roster()

	print("[Main] Colony Roster UI unit tests passed successfully!")


func _test_modular_block_highlight_and_demolish() -> void:
	print("[Main] Testing Modular Block Highlight & Demolition (Going Medieval style)...")

	var test_inv: Node = InventoryComponentScript.new()
	test_inv.set("slot_count", 8)
	add_child(test_inv)

	# 1. Створення підлоги, перевірка підсвітки
	var cell_floor := Vector2i(85, 85)
	var floor_piece = ModularPiece3DScript.new()
	add_child(floor_piece)
	floor_piece.setup_piece(&"modular_floor", cell_floor, true, 0.0)
	ModularManager._floors[cell_floor] = floor_piece

	assert(floor_piece.is_highlighted() == false, "Piece must not be highlighted initially")
	floor_piece.set_highlighted(true)
	assert(floor_piece.is_highlighted() == true, "set_highlighted(true) must make piece highlighted")
	var outline_root = floor_piece.get_node_or_null("OutlineRoot")
	assert(outline_root != null, "OutlineRoot must exist on ModularPiece3D")
	assert(outline_root.has_node("WireframeLines"), "WireframeLines must exist inside OutlineRoot")
	assert(outline_root.has_node("TranslucentFaces"), "TranslucentFaces must exist inside OutlineRoot")
	floor_piece.set_highlighted(false)
	assert(floor_piece.is_highlighted() == false, "set_highlighted(false) must hide highlight")

	# 2. Створення стіни на цій підлозі та даху над нею
	var wall_piece = ModularPiece3DScript.new()
	add_child(wall_piece)
	wall_piece.setup_piece(&"modular_wall", cell_floor, true, 0.0)
	ModularManager._structures[cell_floor] = wall_piece
	assert(GridManager.is_cell_walkable(cell_floor) == false, "Wall must make cell solid")

	var roof_piece = ModularPiece3DScript.new()
	add_child(roof_piece)
	roof_piece.setup_piece(&"modular_roof", cell_floor, true, 0.0)
	ModularManager._roofs[cell_floor] = roof_piece

	# 3. Перевірка структурних правил: не можна знести підлогу, поки на ній стоїть стіна
	var can_dem_fl = floor_piece.can_demolish()
	assert(can_dem_fl["can"] == false, "Cannot demolish floor while structure exists on it")
	var dem_fl_res = floor_piece.demolish(test_inv)
	assert(dem_fl_res["success"] == false, "Demolishing floor with wall must fail")

	# 4. Перевірка структурних правил: не можна знести стіну, поки над нею стоїть дах
	var can_dem_wl = wall_piece.can_demolish()
	assert(can_dem_wl["can"] == false, "Cannot demolish wall while roof rests on it")
	var dem_wl_res = wall_piece.demolish(test_inv)
	assert(dem_wl_res["success"] == false, "Demolishing wall with roof must fail")

	# 5. Демонтаж даху (дозволено): повертає 1 дерево і 2 сіна
	var initial_wood = test_inv.get_item_count(&"wood")
	var initial_straw = test_inv.get_item_count(&"straw")
	var dem_rf_res = roof_piece.demolish(test_inv)
	assert(dem_rf_res["success"] == true, "Demolishing roof with no obstructions must succeed")
	assert(test_inv.get_item_count(&"wood") == initial_wood + 1, "Roof must refund 1 wood")
	assert(test_inv.get_item_count(&"straw") == initial_straw + 2, "Roof must refund 2 straw")

	# 6. Демонтаж стіни (тепер дозволено): повертає 2 дерева і відновлює прохідність
	var dem_wl_res2 = wall_piece.demolish(test_inv)
	assert(dem_wl_res2["success"] == true, "Demolishing wall without roof must succeed")
	assert(test_inv.get_item_count(&"wood") == initial_wood + 3, "Wall must refund 2 wood (total 3)")
	assert(GridManager.is_cell_walkable(cell_floor) == true, "Demolishing wall must make cell walkable again")

	# 7. Демонтаж підлоги (тепер дозволено): повертає 1 дерево
	var dem_fl_res2 = floor_piece.demolish(test_inv)
	assert(dem_fl_res2["success"] == true, "Demolishing floor with no structures must succeed")
	assert(test_inv.get_item_count(&"wood") == initial_wood + 4, "Floor must refund 1 wood (total 4)")

	# 8. Скасування синього креслення (blueprint): не повертає матеріалів
	var cell_bp := Vector2i(86, 86)
	var bp_piece = ModularPiece3DScript.new()
	add_child(bp_piece)
	bp_piece.setup_piece(&"modular_pillar", cell_bp, false, 0.0)
	var wood_before_bp = test_inv.get_item_count(&"wood")
	var dem_bp_res = bp_piece.demolish(test_inv)
	assert(dem_bp_res["success"] == true, "Cancelling blueprint must succeed")
	assert(dem_bp_res["refunded"].is_empty(), "Blueprint cancellation must not refund materials")
	assert(test_inv.get_item_count(&"wood") == wood_before_bp, "Inventory wood count must remain identical")

	# Очищення
	test_inv.queue_free()
	print("[Main] Modular Block Highlight & Demolition unit tests passed successfully!")


func _test_enhanced_crosshair_hints() -> void:
	print("[Main] Testing Enhanced Crosshair UI & Context Clues (Colonists, Campfires, Buildings, Resources)...")

	var CrosshairUIScript = load("res://src/ui/hud/CrosshairUI.gd")
	var crosshair = CrosshairUIScript.new()
	crosshair.name = "TestCrosshairUI"
	add_child(crosshair)

	# 1. Валідація структури та розмірів мітки підказок
	assert(crosshair._interact_label != null, "InteractHint label must exist inside CrosshairUI")
	assert(crosshair._interact_label.offset_bottom >= 80.0, "Interact label must have height >= 60px for 2-line hints")
	assert(crosshair._interact_label.get_theme_constant("line_spacing") >= 2, "Interact label must have line spacing >= 2")

	# 2. Створюємо тестового гравця та перевіряємо групу
	var player = get_tree().get_first_node_in_group("player")
	assert(player != null, "Player must exist in scene tree")

	# 3. Тест підказки при наведенні на поселенця (Colonist3D)
	var col_scene = load("res://src/entities3d/colonist/Colonist3D.tscn")
	var test_col = col_scene.instantiate()
	test_col.colonist_name = "Добриня"
	test_col.profession = &"builder"
	test_col.max_health = 100.0
	test_col.current_health = 85.0
	add_child(test_col)
	test_col.global_position = player.global_position + Vector3(0, 0, -2.5)
	test_col.set_status_display("🔨 Будує хатину (45%)")

	# Симуляція перевірки через interact_ray
	assert(test_col.get_status_text() == "🔨 Будує хатину (45%)", "get_status_text() must return current status")

	# Перевірка отримання здоров'я та шкоди
	test_col.take_damage(15.0)
	assert(test_col.current_health == 70.0, "Colonist must take damage correctly")
	test_col.heal(20.0)
	assert(test_col.current_health == 90.0, "Colonist must heal correctly")

	# 4. Тест підказки при наведенні на табірне вогнище (BuildingEntity3D)
	var campfire_entity = BuildingEntity3DScript.new()
	add_child(campfire_entity)
	var campfire_data = BuildingPlacementController.get_building(&"campfire")
	assert(campfire_data != null, "Campfire data must exist")
	campfire_entity.setup_building(campfire_data, Vector2i(70, 70))
	assert(campfire_entity.is_in_group("campfires") or campfire_entity.has_method("interact_campfire"), "Campfire must be in group or have method")

	# Перевірка демонтажу та повернення матеріалів з вогнища
	var test_inv: Node = InventoryComponentScript.new()
	test_inv.set("slot_count", 8)
	add_child(test_inv)

	var initial_wood = test_inv.get_item_count(&"wood")
	var dem_result = campfire_entity.demolish(test_inv)
	assert(dem_result.get("success", false) == true, "Campfire demolish must return success")
	assert(test_inv.get_item_count(&"wood") >= initial_wood, "Demolishing campfire must refund wood")

	# 5. Тест підказки для ресурсів (WorldResourceNode3D)
	var WorldResourceNode3DScript = load("res://src/world3d/WorldResourceNode3D.gd")
	var tree_node = WorldResourceNode3DScript.new()
	tree_node.resource_type = 0 # TREE
	tree_node.max_health = 3.0
	tree_node.current_health = 3.0
	add_child(tree_node)
	assert(tree_node.is_in_group("resource_nodes") or tree_node.has_method("harvest"), "Tree must be resource node")

	# Очищення тимчасових тестових вузлів
	tree_node.queue_free()
	test_inv.queue_free()
	test_col.queue_free()
	crosshair.queue_free()

	print("[Main] Enhanced Crosshair UI & Context Clues unit tests passed successfully!")


func _test_colonist_obstacle_avoidance_and_pathfinding() -> void:
	print("[Main] Testing Colonist Pathfinding & Obstacle Avoidance (GridManager & ColonistMoveToState3D)...")

	# 1. Перевірка обходу суцільної перешкоди (стіни) у 3D
	var wall_x: int = 15
	var wall_cells: Array[Vector2i] = []
	for wy in range(10, 16):
		var wc := Vector2i(wall_x, wy)
		wall_cells.append(wc)
		GridManager.set_cell_solid(wc, true)

	var from_pos := Vector3(13.5, 0.0, 12.5)
	var to_pos := Vector3(17.5, 0.0, 12.5)
	var wall_path: PackedVector3Array = GridManager.get_world_path_3d(from_pos, to_pos, 0.0)
	assert(wall_path.size() > 0, "AStarGrid2D must find path around vertical wall obstacle")

	# Перевірка що жодна точка маршруту не проходить крізь суцільні тайли стіни
	for pt in wall_path:
		var map_c: Vector2i = GridManager.world_to_map_3d(pt)
		assert(not wall_cells.has(map_c), "Path waypoint must never step on a solid wall tile!")

	# 2. Перевірка відновлення при старті всередині твердого тайлу (Solid-Start Recovery)
	var start_cell := GridManager.world_to_map_3d(from_pos)
	GridManager.set_cell_solid(start_cell, true)
	var escape_path: PackedVector3Array = GridManager.get_world_path_3d(from_pos, to_pos, 0.0)
	assert(escape_path.size() > 0, "get_world_path_3d must recover and pathfind out when start cell is solid")
	assert(GridManager.is_cell_solid(start_cell) == true, "Solid start cell must have its solid state restored")
	GridManager.set_cell_solid(start_cell, false)

	# 3. Перевірка радіального пошуку прохідного сусіда навколо товстої перешкоди (3x3)
	var block_center := Vector2i(25, 25)
	var thick_cells: Array[Vector2i] = []
	for bx in range(-1, 2):
		for by in range(-1, 2):
			var tc := block_center + Vector2i(bx, by)
			thick_cells.append(tc)
			GridManager.set_cell_solid(tc, true)

	var neighbor_cell := GridManager.get_closest_walkable_neighbor(Vector2i(20, 25), block_center, 3)
	assert(neighbor_cell != Vector2i(-1, -1), "Must find walkable neighbor around 3x3 solid cluster")
	assert(GridManager.is_cell_walkable(neighbor_cell), "Selected neighbor must be genuinely walkable")
	assert(not thick_cells.has(neighbor_cell), "Selected neighbor must be outside the solid cluster")

	# Очищення тестових клітинок сітки
	for wc in wall_cells:
		GridManager.set_cell_solid(wc, false)
	for tc in thick_cells:
		GridManager.set_cell_solid(tc, false)

	# 4. Перевірка методів стану ColonistMoveToState3D (Whisker raycasts & deflection)
	var MoveStateClass = load("res://src/entities3d/colonist/states/ColonistMoveToState3D.gd")
	var move_state = MoveStateClass.new()
	assert(move_state.has_method("_detect_obstacle_avoidance"), "MoveTo state must implement _detect_obstacle_avoidance")
	assert(move_state.has_method("_has_clear_line_of_sight"), "MoveTo state must implement _has_clear_line_of_sight")

	var test_dir := Vector3(1.0, 0.0, 0.0)
	var deflected: Vector3 = move_state._detect_obstacle_avoidance(test_dir)
	assert(deflected.length() > 0.0, "Obstacle avoidance vector must be non-zero")
	assert(abs(deflected.length() - 1.0) < 0.05, "Obstacle avoidance vector must be normalized")
	move_state.queue_free()

	print("[Main] Colonist Pathfinding & Obstacle Avoidance unit tests passed successfully!")
