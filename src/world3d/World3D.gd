extends Node3D

## World3D: Головна 3D сцена світу Saecula.
## Керує 3D простором, освітленням, процедурною генерацією ресурсів (дерева, каміння, кущі),
## будівельними майданчиками (ConstructionSite3D), спорудами (BuildingEntity3D)
## та перемиканням режимів: First-Person (гравець) <-> Top-Down RTS (менеджмент колонії/будівництво).

const TextureHelper = preload("res://src/core3d/TextureHelper.gd")
const ResourceNode3DScene = preload("res://src/world3d/WorldResourceNode3D.tscn")
const Player3DScene = preload("res://src/entities3d/player/Player3D.tscn")
const RTSCamera3DScene = preload("res://src/core3d/RTSCamera3D.tscn")
const BuildingGhost3DScene = preload("res://src/world3d/BuildingGhost3D.tscn")
const ConstructionSite3DScene = preload("res://src/world3d/ConstructionSite3D.tscn")

@export var map_tiles_width: int = 80
@export var map_tiles_height: int = 80

@export var initial_trees_count: int = 50
@export var initial_rocks_count: int = 30
@export var initial_bushes_count: int = 25

var player: CharacterBody3D = null
var rts_camera: Node3D = null
var building_ghost: Node3D = null
var buildings_container: Node3D = null

@onready var resource_container: Node3D = $ResourceContainer
@onready var ground_mesh: MeshInstance3D = $Ground/GroundMesh


func _ready() -> void:
	# Ініціалізація розміру сітки в GridManager
	GridManager.initialize_grid(map_tiles_width, map_tiles_height)

	# Створюємо контейнер для споруд та будівельних майданчиків
	buildings_container = Node3D.new()
	buildings_container.name = "Buildings"
	add_child(buildings_container)

	_setup_ground()
	_setup_player_and_camera()
	_generate_resources()

	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.inventory_window_toggle_requested.connect(_on_inventory_toggle_requested)
	BuildingPlacementController.placement_confirmed.connect(_on_building_placement_confirmed)

	# За замовчуванням стартуємо у First-Person режимі
	_apply_mode(GameManager.current_state)

	# Розміщуємо стартовий будівельний майданчик перед гравцем на спавні
	_spawn_starter_construction_site()


func _setup_ground() -> void:
	var total_width_meters: float = float(map_tiles_width) * GridManager.TILE_SIZE_3D
	var total_height_meters: float = float(map_tiles_height) * GridManager.TILE_SIZE_3D

	if ground_mesh != null:
		var plane_mesh: PlaneMesh = PlaneMesh.new()
		plane_mesh.size = Vector2(total_width_meters, total_height_meters)
		ground_mesh.mesh = plane_mesh
		ground_mesh.position = Vector3(total_width_meters / 2.0, 0.0, total_height_meters / 2.0)

		var ground_mat: StandardMaterial3D = TextureHelper.create_material(
			TextureHelper.PATH_TERRAIN_GRASS,
			Color("386641"),
			0.95,
			Vector3(float(map_tiles_width), float(map_tiles_height), 1.0)
		)
		ground_mesh.material_override = ground_mat

	# Налаштовуємо форму колізії землі
	var ground_shape = $Ground/CollisionShape3D
	if ground_shape != null:
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(total_width_meters, 0.2, total_height_meters)
		ground_shape.shape = box
		ground_shape.position = Vector3(total_width_meters / 2.0, -0.1, total_height_meters / 2.0)


func _setup_player_and_camera() -> void:
	# Центр карти
	var spawn_cell: Vector2i = Vector2i(map_tiles_width / 2, map_tiles_height / 2)
	var spawn_pos: Vector3 = GridManager.map_to_world_3d(spawn_cell, 0.1)

	# Спавнимо 3D персонажа
	player = Player3DScene.instantiate()
	player.position = spawn_pos
	add_child(player)

	# Спавнимо 3D RTS камеру
	rts_camera = RTSCamera3DScene.instantiate()
	rts_camera.position = spawn_pos
	add_child(rts_camera)

	# Спавнимо 3D привид будівлі (Blueprint Preview)
	building_ghost = BuildingGhost3DScene.instantiate()
	building_ghost.name = "BuildingGhost3D"
	add_child(building_ghost)


func _spawn_starter_construction_site() -> void:
	var spawn_cell: Vector2i = Vector2i(map_tiles_width / 2, map_tiles_height / 2)
	var campfire_data = BuildingPlacementController.get_building(&"campfire")
	if campfire_data == null:
		return

	var starter_cell: Vector2i = spawn_cell + Vector2i(-1, -4)
	if starter_cell.x < 0 or starter_cell.y < 0:
		return
	if starter_cell.x + campfire_data.size_in_tiles.x >= map_tiles_width or starter_cell.y + campfire_data.size_in_tiles.y >= map_tiles_height:
		return

	spawn_construction_site(campfire_data, starter_cell)


func _generate_resources() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()

	var spawn_center: Vector2i = Vector2i(map_tiles_width / 2, map_tiles_height / 2)
	var safe_radius_tiles: int = 16 # Вільний простір для розбудови початкового поселення

	var tree_item = ItemDatabase.get_item(&"wood")
	var rock_item = ItemDatabase.get_item(&"stone")
	var berry_item = ItemDatabase.get_item(&"berries")

	_spawn_nodes_of_type(0, initial_trees_count, tree_item, rng, spawn_center, safe_radius_tiles) # 0 = TREE
	_spawn_nodes_of_type(1, initial_rocks_count, rock_item, rng, spawn_center, safe_radius_tiles) # 1 = ROCK
	_spawn_nodes_of_type(2, initial_bushes_count, berry_item, rng, spawn_center, safe_radius_tiles) # 2 = BUSH


func _spawn_nodes_of_type(
	type_int: int,
	count: int,
	drop_item: ItemData,
	rng: RandomNumberGenerator,
	center: Vector2i,
	safe_radius: int
) -> void:
	var spawned: int = 0
	var attempts: int = 0
	var max_attempts: int = count * 20

	while spawned < count and attempts < max_attempts:
		attempts += 1
		var cx: int = rng.randi_range(2, map_tiles_width - 3)
		var cy: int = rng.randi_range(2, map_tiles_height - 3)
		var cell: Vector2i = Vector2i(cx, cy)

		# Не спавнимо в зоні безпеки навколо спавну гравця
		if cell.distance_to(center) <= float(safe_radius):
			continue

		if not GridManager.is_cell_walkable(cell):
			continue

		var node_inst = ResourceNode3DScene.instantiate()
		node_inst.position = GridManager.map_to_world_3d(cell, 0.0)
		node_inst.resource_type = type_int
		if drop_item != null:
			node_inst.drop_item_id = drop_item.id

		resource_container.add_child(node_inst)
		spawned += 1


func _on_game_state_changed(new_state: GameManager.GameState, _prev: GameManager.GameState) -> void:
	_apply_mode(new_state)


func _apply_mode(state: GameManager.GameState) -> void:
	match state:
		GameManager.GameState.PLAYING:
			if player != null:
				player.set_active(true)
			if rts_camera != null:
				rts_camera.set_active(false)
			if building_ghost != null:
				building_ghost.visible = false
		GameManager.GameState.COLONY_MODE, GameManager.GameState.BUILDING_MODE:
			if player != null:
				player.set_active(false)
			if rts_camera != null:
				rts_camera.set_active(true)
		GameManager.GameState.PAUSED:
			if player != null:
				player.set_active(false)


func _on_inventory_toggle_requested() -> void:
	if GameManager.current_state == GameManager.GameState.PLAYING and player != null:
		if player.is_active:
			player.set_active(false)
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			player.set_active(true)


func _on_building_placement_confirmed(building: BuildingData, cell: Vector2i) -> void:
	spawn_construction_site(building, cell)


## Створює фізичний будівельний майданчик споруди у 3D світі
func spawn_construction_site(building: BuildingData, cell: Vector2i) -> Node3D:
	if buildings_container == null:
		buildings_container = Node3D.new()
		buildings_container.name = "Buildings"
		add_child(buildings_container)

	var site = ConstructionSite3DScene.instantiate()
	site.name = "Site_%s_%d_%d" % [building.id, cell.x, cell.y]
	buildings_container.add_child(site)
	if site.has_method("setup_site"):
		site.setup_site(building, cell)
	return site
