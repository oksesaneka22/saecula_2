extends Node3D

## World3D: Головна 3D сцена світу Saecula.
## Керує 3D простором, освітленням, процедурною генерацією ресурсів (дерева, каміння, кущі),
## та перемиканням режимів: First-Person (гравець) <-> Top-Down RTS (менеджмент колонії).

const ResourceNode3DScene = preload("res://src/world3d/WorldResourceNode3D.tscn")
const Player3DScene = preload("res://src/entities3d/player/Player3D.tscn")
const RTSCamera3DScene = preload("res://src/core3d/RTSCamera3D.tscn")

@export var map_tiles_width: int = 60
@export var map_tiles_height: int = 60

@export var initial_trees_count: int = 40
@export var initial_rocks_count: int = 25
@export var initial_bushes_count: int = 20

var player: CharacterBody3D = null
var rts_camera: Node3D = null

@onready var resource_container: Node3D = $ResourceContainer
@onready var ground_mesh: MeshInstance3D = $Ground/GroundMesh


func _ready() -> void:
	# Ініціалізація розміру сітки в GridManager
	GridManager.initialize_grid(map_tiles_width, map_tiles_height)

	_setup_ground()
	_setup_player_and_camera()
	_generate_resources()

	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.inventory_window_toggle_requested.connect(_on_inventory_toggle_requested)

	# За замовчуванням стартуємо у First-Person режимі
	_apply_mode(GameManager.current_state)


func _setup_ground() -> void:
	var total_width_meters: float = float(map_tiles_width) * GridManager.TILE_SIZE_3D
	var total_height_meters: float = float(map_tiles_height) * GridManager.TILE_SIZE_3D

	if ground_mesh != null:
		var plane_mesh: PlaneMesh = PlaneMesh.new()
		plane_mesh.size = Vector2(total_width_meters, total_height_meters)
		ground_mesh.mesh = plane_mesh
		ground_mesh.position = Vector3(total_width_meters / 2.0, 0.0, total_height_meters / 2.0)

		var ground_mat: StandardMaterial3D = StandardMaterial3D.new()
		ground_mat.albedo_color = Color("386641") # Приємна зелена галявина
		ground_mat.roughness = 0.95
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


func _generate_resources() -> void:
	var center_cell: Vector2i = Vector2i(map_tiles_width / 2, map_tiles_height / 2)
	var clear_radius: int = 4

	_spawn_resource_batch(ResourceNode3DScene, 0, &"wood", initial_trees_count, center_cell, clear_radius) # TREE
	_spawn_resource_batch(ResourceNode3DScene, 1, &"stone", initial_rocks_count, center_cell, clear_radius) # ROCK
	_spawn_resource_batch(ResourceNode3DScene, 2, &"berries", initial_bushes_count, center_cell, clear_radius) # BUSH


func _spawn_resource_batch(scene: PackedScene, res_type: int, drop_id: StringName, count: int, center_cell: Vector2i, clear_radius: int) -> void:
	var spawned: int = 0
	var attempts: int = 0
	var max_attempts: int = count * 15

	while spawned < count and attempts < max_attempts:
		attempts += 1
		var cx: int = randi_range(2, map_tiles_width - 3)
		var cy: int = randi_range(2, map_tiles_height - 3)
		var cell: Vector2i = Vector2i(cx, cy)

		# Не спавнимо в зоні появи гравця
		if cell.distance_to(center_cell) <= clear_radius:
			continue

		# Перевіряємо вільність клітинки
		if not GridManager.is_cell_walkable(cell):
			continue

		var node = scene.instantiate()
		node.resource_type = res_type
		node.drop_item_id = drop_id
		node.position = GridManager.map_to_world_3d(cell, 0.0)
		resource_container.add_child(node)
		spawned += 1


func _on_game_state_changed(new_state: int, _old_state: int) -> void:
	_apply_mode(new_state)


func _apply_mode(state: int) -> void:
	if player == null or rts_camera == null:
		return

	match state:
		GameManager.GameState.PLAYING:
			# Режим гравця: First-Person
			player.set_active(true)
			rts_camera.set_active(false)

		GameManager.GameState.COLONY_MODE, GameManager.GameState.BUILDING_MODE:
			# Режим огляду та менеджменту: Top-Down RTS
			player.set_active(false)
			rts_camera.focus_on_position(player.global_position)
			rts_camera.set_active(true)

		GameManager.GameState.PAUSED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_inventory_toggle_requested() -> void:
	if GameManager.current_state == GameManager.GameState.PLAYING:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
