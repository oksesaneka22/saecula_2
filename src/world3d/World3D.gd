extends Node3D

## World3D: Головна 3D сцена світу Saecula.
## Керує 3D простором, процедурною генерацією безмежного лісу (1000x1000 тайлів)
## з природними звивистими річками, лісовими озерами, скельними пасмами, галявинами,
## береговими родовищами глини та кремнію, чанковим стрімінгом (Chunk Streaming),
## будівельними майданчиками (ConstructionSite3D), спорудами (BuildingEntity3D)
## та перемиканням режимів: First-Person (гравець) <-> Top-Down RTS (менеджмент/будівництво).

const TextureHelper = preload("res://src/core3d/TextureHelper.gd")
const ResourceNode3DScene = preload("res://src/world3d/WorldResourceNode3D.tscn")
const WorldResourceNode3D = preload("res://src/world3d/WorldResourceNode3D.gd")
const Player3DScene = preload("res://src/entities3d/player/Player3D.tscn")
const RTSCamera3DScene = preload("res://src/core3d/RTSCamera3D.tscn")
const BuildingGhost3DScene = preload("res://src/world3d/BuildingGhost3D.tscn")
const ConstructionSite3DScene = preload("res://src/world3d/ConstructionSite3D.tscn")

# ------------------------------------------------------------------------------
# Параметри карти та процедурної генерації
# ------------------------------------------------------------------------------
@export var map_tiles_width: int = 1000
@export var map_tiles_height: int = 1000
@export var world_seed: int = 1337

const CHUNK_SIZE: int = 25
const ACTIVE_CHUNK_RADIUS: int = 2

# Генератори шуму для процедурного лісового ландшафту
var _forest_noise: FastNoiseLite = null
var _rock_noise: FastNoiseLite = null
var _bush_noise: FastNoiseLite = null
var _shore_noise: FastNoiseLite = null
var _grass_noise: FastNoiseLite = null

# Чанковий менеджмент та персистентність збору ресурсів
var _loaded_chunks: Dictionary = {}    # Vector2i(chunk_x, chunk_y) -> Node3D
var _harvested_cells: Dictionary = {}  # Vector2i(map_x, map_y) -> bool
var _last_focal_chunk: Vector2i = Vector2i(-9999, -9999)
var _water_material: StandardMaterial3D = null

var player: CharacterBody3D = null
var rts_camera: Node3D = null
var building_ghost: Node3D = null
var buildings_container: Node3D = null

@onready var resource_container: Node3D = $ResourceContainer
@onready var ground_mesh: MeshInstance3D = $Ground/GroundMesh


func _ready() -> void:
	# 1. Ініціалізація глобальної навігаційної та просторової сітки
	GridManager.initialize_grid(map_tiles_width, map_tiles_height)

	# 2. Створення контейнера для споруд колонії
	buildings_container = Node3D.new()
	buildings_container.name = "Buildings"
	add_child(buildings_container)

	_setup_ground()

	var blocks_node := Node3D.new()
	blocks_node.name = "Blocks"
	add_child(blocks_node)
	BlockManager.blocks_container = blocks_node

	if ModularManager != null:
		ModularManager.set_container(buildings_container)

	# 3. Ініціалізація процедурних шумів лісу
	_init_noise_generators()

	# 4. Процедурна генерація гідрографії (головна річка, притоки та 8 озер)
	_generate_water_system()

	# 5. Створення гравця та RTS-камери в центрі карти (500, 500)
	_setup_player_and_camera()

	# 6. Матеріал водної поверхні
	_setup_water_material()

	# 7. Стартове завантаження чанків навколо гравця
	var spawn_cell: Vector2i = Vector2i(map_tiles_width / 2, map_tiles_height / 2)
	var initial_chunk := Vector2i(spawn_cell.x / CHUNK_SIZE, spawn_cell.y / CHUNK_SIZE)
	_last_focal_chunk = initial_chunk
	_sync_chunks(initial_chunk)

	# 8. Підписка на події гри
	EventBus.game_state_changed.connect(_on_game_state_changed)
	EventBus.inventory_window_toggle_requested.connect(_on_inventory_toggle_requested)
	EventBus.resource_harvested.connect(_on_resource_harvested)
	BuildingPlacementController.placement_confirmed.connect(_on_building_placement_confirmed)

	# 9. Стартовий режим від 1-ї особи та стартовий майданчик вогнища
	_apply_mode(GameManager.current_state)
	_spawn_starter_construction_site()


var _chunk_check_timer: float = 0.0

func _process(delta: float) -> void:
	_chunk_check_timer += delta
	if _chunk_check_timer >= 0.15:
		_chunk_check_timer = 0.0
		_update_chunk_streaming()


# ------------------------------------------------------------------------------
# Налаштування ландшафту та колізії землі 1000x1000
# ------------------------------------------------------------------------------
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

	var ground_shape = $Ground/CollisionShape3D
	if ground_shape != null:
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(total_width_meters, 0.2, total_height_meters)
		ground_shape.shape = box
		ground_shape.position = Vector3(total_width_meters / 2.0, -0.1, total_height_meters / 2.0)


# ------------------------------------------------------------------------------
# Спавн персонажа, RTS камери та прев'ю споруд
# ------------------------------------------------------------------------------
func _setup_player_and_camera() -> void:
	var spawn_cell: Vector2i = Vector2i(map_tiles_width / 2, map_tiles_height / 2)
	var spawn_pos: Vector3 = GridManager.map_to_world_3d(spawn_cell, 0.1)

	player = Player3DScene.instantiate()
	player.position = spawn_pos
	add_child(player)

	rts_camera = RTSCamera3DScene.instantiate()
	rts_camera.position = spawn_pos
	add_child(rts_camera)

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


# ------------------------------------------------------------------------------
# Ініціалізація шумів FastNoiseLite
# ------------------------------------------------------------------------------
func _init_noise_generators() -> void:
	_forest_noise = FastNoiseLite.new()
	_forest_noise.seed = world_seed
	_forest_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_forest_noise.frequency = 0.022
	_forest_noise.fractal_octaves = 3

	_rock_noise = FastNoiseLite.new()
	_rock_noise.seed = world_seed + 101
	_rock_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_rock_noise.frequency = 0.035
	_rock_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED

	_bush_noise = FastNoiseLite.new()
	_bush_noise.seed = world_seed + 202
	_bush_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_bush_noise.frequency = 0.055

	_shore_noise = FastNoiseLite.new()
	_shore_noise.seed = world_seed + 303
	_shore_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_shore_noise.frequency = 0.08

	_grass_noise = FastNoiseLite.new()
	_grass_noise.seed = 1405
	_grass_noise.frequency = 0.075


func _setup_water_material() -> void:
	_water_material = TextureHelper.create_material(
		TextureHelper.PATH_TERRAIN_WATER,
		Color(0.15, 0.52, 0.82, 0.85),
		0.12,
		Vector3(1.0, 1.0, 1.0)
	)
	_water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_water_material.metallic = 0.15


# ------------------------------------------------------------------------------
# Процедурна генерація водойм (Річки та Озера 1000x1000)
# ------------------------------------------------------------------------------
func _generate_water_system() -> void:
	var spawn_center := Vector2i(map_tiles_width / 2, map_tiles_height / 2)

	# 1. Головна звивиста річка, що перетинає карту з півночі на південь
	for y in range(map_tiles_height):
		var rx: float = 460.0 + sin(float(y) * 0.012) * 55.0 + cos(float(y) * 0.005) * 30.0 + sin(float(y) * 0.03) * 8.0
		var irx: int = int(round(rx))
		var w: int = 3 if y % 4 != 0 else 4
		for dx in range(w):
			var cell := Vector2i(irx + dx, y)
			if cell.x >= 0 and cell.x < map_tiles_width:
				if cell.distance_to(spawn_center) > 18.0:
					GridManager.register_water_cell(cell)

	# 2. Східна притока річки (відгалужується на y ~ 350 і тече на схід)
	for x in range(460, mini(map_tiles_width - 40, 950)):
		var ry: float = 350.0 + sin(float(x) * 0.015) * 35.0 + cos(float(x) * 0.008) * 20.0
		var iry: int = int(round(ry))
		var w: int = 2 if x % 3 != 0 else 3
		for dy in range(w):
			var cell := Vector2i(x, iry + dy)
			if cell.y >= 0 and cell.y < map_tiles_height:
				if cell.distance_to(spawn_center) > 18.0:
					GridManager.register_water_cell(cell)

	# 3. 8 органічних лісових озер, розподілених по карті
	var lakes = [
		{"c": Vector2i(220, 180), "rx": 24.0, "ry": 19.0},
		{"c": Vector2i(780, 200), "rx": 26.0, "ry": 20.0},
		{"c": Vector2i(160, 520), "rx": 16.0, "ry": 13.0},
		{"c": Vector2i(750, 780), "rx": 32.0, "ry": 24.0},
		{"c": Vector2i(240, 820), "rx": 22.0, "ry": 17.0},
		{"c": Vector2i(570, 480), "rx": 15.0, "ry": 12.0},
		{"c": Vector2i(480, 80), "rx": 18.0, "ry": 14.0},
		{"c": Vector2i(460, 920), "rx": 20.0, "ry": 15.0}
	]

	for l in lakes:
		_carve_lake_shape(l["c"], l["rx"], l["ry"], spawn_center)

	# Звільняємо тестову зону (0, 0) - (25, 25) від води для автотестів шляхів
	for tx in range(25):
		for ty in range(25):
			GridManager.unregister_water_cell(Vector2i(tx, ty))

	print("[World3D] Успішно згенеровано гідросистему: %d водних тайлів." % GridManager.get_all_water_cells().size())


func _carve_lake_shape(center: Vector2i, rx: float, ry: float, spawn_center: Vector2i) -> void:
	var min_x: int = maxi(0, int(floor(float(center.x) - rx - 1.0)))
	var max_x: int = mini(map_tiles_width - 1, int(ceil(float(center.x) + rx + 1.0)))
	var min_y: int = maxi(0, int(floor(float(center.y) - ry - 1.0)))
	var max_y: int = mini(map_tiles_height - 1, int(ceil(float(center.y) + ry + 1.0)))

	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			var cell := Vector2i(x, y)
			if cell.distance_to(spawn_center) <= 18.0:
				continue
			var dx: float = float(x - center.x) / rx
			var dy: float = float(y - center.y) / ry
			if (dx * dx + dy * dy) <= 1.0:
				GridManager.register_water_cell(cell)


# ------------------------------------------------------------------------------
# Чанковий стрімінг процедурного лісу (Chunk Streaming)
# ------------------------------------------------------------------------------
func _update_chunk_streaming() -> void:
	var focal_pos: Vector3 = Vector3.ZERO
	if rts_camera != null and rts_camera.is_active:
		focal_pos = rts_camera.global_position
	elif player != null:
		focal_pos = player.global_position
	else:
		focal_pos = Vector3(float(map_tiles_width) * 0.5, 0.0, float(map_tiles_height) * 0.5)

	var focal_cell := GridManager.world_to_map_3d(focal_pos)
	var current_chunk := Vector2i(focal_cell.x / CHUNK_SIZE, focal_cell.y / CHUNK_SIZE)

	if current_chunk != _last_focal_chunk:
		_last_focal_chunk = current_chunk
		_sync_chunks(current_chunk)


func _sync_chunks(center_chunk: Vector2i) -> void:
	var max_cx: int = int(ceil(float(map_tiles_width) / float(CHUNK_SIZE)))
	var max_cy: int = int(ceil(float(map_tiles_height) / float(CHUNK_SIZE)))

	var desired_chunks: Dictionary = {}
	for dx in range(-ACTIVE_CHUNK_RADIUS, ACTIVE_CHUNK_RADIUS + 1):
		for dy in range(-ACTIVE_CHUNK_RADIUS, ACTIVE_CHUNK_RADIUS + 1):
			var ch := center_chunk + Vector2i(dx, dy)
			if ch.x >= 0 and ch.x < max_cx and ch.y >= 0 and ch.y < max_cy:
				desired_chunks[ch] = true
				if not _loaded_chunks.has(ch):
					_load_chunk(ch)

	var to_unload: Array[Vector2i] = []
	for ch in _loaded_chunks.keys():
		if not desired_chunks.has(ch):
			to_unload.append(ch)

	for ch in to_unload:
		_unload_chunk(ch)


func _load_chunk(ch: Vector2i) -> void:
	if _loaded_chunks.has(ch):
		return

	var chunk_node := Node3D.new()
	chunk_node.name = "Chunk_%d_%d" % [ch.x, ch.y]
	resource_container.add_child(chunk_node)
	_loaded_chunks[ch] = chunk_node

	var water_quads: Array[Vector2i] = []
	var spawn_center := Vector2i(map_tiles_width / 2, map_tiles_height / 2)
	var start_x: int = ch.x * CHUNK_SIZE
	var start_y: int = ch.y * CHUNK_SIZE

	for lx in range(CHUNK_SIZE):
		for ly in range(CHUNK_SIZE):
			var gx: int = start_x + lx
			var gy: int = start_y + ly
			var cell := Vector2i(gx, gy)

			if not GridManager.is_within_bounds(cell):
				continue

			if GridManager.is_water_cell(cell):
				water_quads.append(cell)
				continue

			if _harvested_cells.has(cell):
				continue

			# Безпечна відкрита галявина навколо стартового табору
			if cell.distance_to(spawn_center) < 18.0:
				continue

			if not GridManager.is_cell_walkable(cell):
				continue

			# 1. Прибережна смуга (1..3 тайли від води): родовища глини та кремнію
			if GridManager.is_near_water(cell, 3):
				if (gx * 53 + gy * 79) % 6 == 0:
					var sn: float = _shore_noise.get_noise_2d(gx, gy)
					if sn > 0.05:
						_spawn_chunk_node(chunk_node, cell, WorldResourceNode3D.ResourceType.CLAY, &"clay")
					elif sn < -0.05:
						_spawn_chunk_node(chunk_node, cell, WorldResourceNode3D.ResourceType.FLINT, &"flint")
			else:
				# 2. Суходіл: Скелі, дерева, кущі ягід (оптимізована щільність для 60-144+ FPS)
				var rn: float = _rock_noise.get_noise_2d(gx, gy)
				if rn > 0.70 and (gx * 37 + gy * 71) % 6 == 0:
					_spawn_chunk_node(chunk_node, cell, WorldResourceNode3D.ResourceType.ROCK, &"stone")
				else:
					var fn: float = _forest_noise.get_noise_2d(gx, gy)
					if fn > 0.08:
						var cell_hash: int = (gx * 73856093 ^ gy * 19349663) & 0x7fffffff
						var spawn_prob: float = 0.075 if fn > 0.25 else 0.038
						if float(cell_hash % 1000) / 1000.0 < spawn_prob:
							_spawn_chunk_node(chunk_node, cell, WorldResourceNode3D.ResourceType.TREE, &"wood")
					elif _bush_noise.get_noise_2d(gx, gy) > 0.38 and (gx * 31 + gy * 17) % 9 == 0:
						_spawn_chunk_node(chunk_node, cell, WorldResourceNode3D.ResourceType.BUSH, &"berries")
					elif fn <= 0.10:
						var gn: float = _grass_noise.get_noise_2d(gx, gy)
						if gn > 0.40 and (gx * 41 + gy * 67) % 2 == 0:
							_spawn_chunk_node(chunk_node, cell, WorldResourceNode3D.ResourceType.GRASS, &"straw")

	if not water_quads.is_empty():
		_build_chunk_water_mesh(chunk_node, water_quads)


func _unload_chunk(ch: Vector2i) -> void:
	if not _loaded_chunks.has(ch):
		return
	var chunk_node: Node3D = _loaded_chunks[ch]
	for child in chunk_node.get_children():
		if child is WorldResourceNode3D:
			GridManager.unregister_occupant(child.get_cell(), true)
	chunk_node.queue_free()
	_loaded_chunks.erase(ch)


func _spawn_chunk_node(
	chunk_node: Node3D,
	cell: Vector2i,
	type: WorldResourceNode3D.ResourceType,
	item_id: StringName
) -> void:
	var node: WorldResourceNode3D = ResourceNode3DScene.instantiate()
	node.resource_type = type
	node.drop_item_id = item_id
	if type == WorldResourceNode3D.ResourceType.GRASS:
		node.max_health = 1.0
		node.drop_min_amount = 1
		node.drop_max_amount = 3
	node.position = GridManager.map_to_world_3d(cell, 0.0)
	node.set_cell(cell)
	chunk_node.add_child(node)


func _build_chunk_water_mesh(chunk_node: Node3D, cells: Array[Vector2i]) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tile_size: float = GridManager.TILE_SIZE_3D
	var water_y: float = 0.03

	for cell in cells:
		var x0: float = float(cell.x) * tile_size
		var x1: float = x0 + tile_size
		var z0: float = float(cell.y) * tile_size
		var z1: float = z0 + tile_size

		st.set_normal(Vector3.UP)
		var v0 := Vector3(x0, water_y, z0)
		var v1 := Vector3(x1, water_y, z0)
		var v2 := Vector3(x1, water_y, z1)
		var v3 := Vector3(x0, water_y, z1)

		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(v0)
		st.set_uv(Vector2(1.0, 0.0))
		st.add_vertex(v1)
		st.set_uv(Vector2(1.0, 1.0))
		st.add_vertex(v2)

		st.set_uv(Vector2(0.0, 0.0))
		st.add_vertex(v0)
		st.set_uv(Vector2(1.0, 1.0))
		st.add_vertex(v2)
		st.set_uv(Vector2(0.0, 1.0))
		st.add_vertex(v3)

	var mesh = st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "ChunkWaterMesh"
	mi.mesh = mesh
	mi.material_override = _water_material
	chunk_node.add_child(mi)


# ------------------------------------------------------------------------------
# Обробники подій та будівельної системи
# ------------------------------------------------------------------------------
func _on_resource_harvested(
	_node: Node,
	_item_id: StringName,
	_count: int,
	world_pos2d: Vector2
) -> void:
	var cell := GridManager.world_to_map(world_pos2d)
	_harvested_cells[cell] = true


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
				if player != null and state == GameManager.GameState.BUILDING_MODE:
					rts_camera.focus_on_position(player.global_position)
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
	if building.id.begins_with("modular_") or building.id == &"wooden_hut":
		return
	spawn_construction_site(building, cell)


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
