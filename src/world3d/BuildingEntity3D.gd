extends StaticBody3D
class_name BuildingEntity3D

## BuildingEntity3D: Фізична завершена споруда у 3D світі гри.
## Замінює ConstructionSite3D після завершення робіт, реєструє свої тайли в GridManager,
## містить опціональний InventoryComponent для складів/скринь, візуальну процедурну модель та 3D Billboard текст.

const TextureHelper = preload("res://src/core3d/TextureHelper.gd")
const InventoryComponentScript = preload("res://src/systems/inventory/InventoryComponent.gd")

var building_data: BuildingData = null
var origin_cell: Vector2i = Vector2i.ZERO
var occupied_cells: Array[Vector2i] = []

var inventory: Node = null
var _visual_root: Node3D = null
var _collision_shape: CollisionShape3D = null
var _label_3d: Label3D = null
var _fire_light: OmniLight3D = null


func _ready() -> void:
	add_to_group("buildings")
	add_to_group("interactable")


## Налаштовує щойно зведену будівлю за схемою та початковою клітинкою
func setup_building(data: BuildingData, cell: Vector2i) -> void:
	building_data = data
	origin_cell = cell

	# 1. Розрахунок зайнятих клітинок
	occupied_cells = BuildingPlacementController.get_occupied_cells(origin_cell, building_data.size_in_tiles)

	# 2. Позиціонування у світових координатах (за центром будівлі)
	var world_center: Vector3 = BuildingPlacementController.get_building_world_center(origin_cell, building_data.size_in_tiles)
	global_position = world_center

	# 3. Реєстрація займаних клітинок у GridManager
	for c in occupied_cells:
		GridManager.register_occupant(c, self, building_data.is_solid)

	# 4. Створення InventoryComponent, якщо передбачено слоти сховища
	if building_data.storage_slots > 0:
		_setup_inventory(building_data.storage_slots)

	# 5. Створення колізії для взаємодії та фізики
	_setup_collision()

	# 6. Побудова процедурної 3D візуалізації будівлі
	_setup_visual()

	# 7. Оновлення тач-скріна
	_update_label()


func _setup_inventory(slots: int) -> void:
	if inventory == null:
		inventory = InventoryComponentScript.new()
		inventory.name = "BuildingInventory"
		inventory.set("slot_count", slots)
		add_child(inventory)
		inventory.inventory_updated.connect(_on_inventory_updated)


func _setup_collision() -> void:
	if _collision_shape == null:
		_collision_shape = CollisionShape3D.new()
		_collision_shape.name = "BuildingCollision"
		add_child(_collision_shape)

	var size_m: Vector2 = Vector2(building_data.size_in_tiles) * GridManager.TILE_SIZE_3D
	var box := BoxShape3D.new()
	var height: float = 3.6 if building_data.is_solid else 0.4
	box.size = Vector3(size_m.x - 0.1, height, size_m.y - 0.1)
	_collision_shape.shape = box
	_collision_shape.position = Vector3(0, height * 0.5, 0)


func _setup_visual() -> void:
	if _visual_root != null:
		_visual_root.queue_free()

	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)

	var size_m: Vector2 = Vector2(building_data.size_in_tiles) * GridManager.TILE_SIZE_3D

	match building_data.id:
		&"campfire":
			_build_campfire_visual(size_m)
		&"stockpile":
			_build_stockpile_visual(size_m)
		&"wooden_hut":
			_build_wooden_hut_visual(size_m)
		_:
			_build_generic_visual(size_m)

	# 3D Billboard текст
	_setup_label(size_m)


func _build_campfire_visual(size_m: Vector2) -> void:
	# 1. Кам'яне кільце вогнища (використовуємо один спільний меш для камінців)
	var stone_mat: StandardMaterial3D = TextureHelper.create_material(
		TextureHelper.PATH_BLD_CAMPFIRE_STONE,
		Color(0.45, 0.45, 0.48),
		0.9
	)

	var ring_radius: float = minf(size_m.x, size_m.y) * 0.35
	var stone_count: int = maxi(8, int(ring_radius * 6.0))
	var stone_w: float = clampf(ring_radius * 0.35, 0.35, 1.0)
	var stone_h: float = clampf(ring_radius * 0.25, 0.25, 0.7)

	var stone_mesh := BoxMesh.new()
	stone_mesh.size = Vector3(stone_w, stone_h, stone_w)

	for i in range(stone_count):
		var angle: float = (float(i) / float(stone_count)) * TAU
		var sx: float = cos(angle) * ring_radius
		var sz: float = sin(angle) * ring_radius
		var stone_inst := MeshInstance3D.new()
		stone_inst.mesh = stone_mesh
		stone_inst.material_override = stone_mat
		stone_inst.position = Vector3(sx, stone_h * 0.5, sz)
		stone_inst.rotation.y = angle + randf_range(-0.3, 0.3)
		_visual_root.add_child(stone_inst)

	# 2. Поперечні колоди у центрі (спільний CylinderMesh)
	var wood_mat: StandardMaterial3D = TextureHelper.create_material(
		TextureHelper.PATH_BLD_LOG_WOOD,
		Color(0.35, 0.22, 0.12),
		0.85
	)

	var log_r: float = clampf(ring_radius * 0.12, 0.12, 0.35)
	var log_mesh := CylinderMesh.new()
	log_mesh.top_radius = log_r * 0.9
	log_mesh.bottom_radius = log_r
	log_mesh.height = ring_radius * 1.5

	for i in range(4):
		var log_inst := MeshInstance3D.new()
		log_inst.mesh = log_mesh
		log_inst.material_override = wood_mat
		log_inst.position = Vector3(0, log_r, 0)
		log_inst.rotation.y = float(i) * (PI / 4.0)
		log_inst.rotation.z = PI / 2.0
		_visual_root.add_child(log_inst)

	# 3. Палаюче вугілля та полум'я
	var flame_mat: StandardMaterial3D = TextureHelper.create_material(
		TextureHelper.PATH_BLD_FIRE,
		Color(1.0, 0.5, 0.05),
		0.5,
		Vector3.ONE,
		true,
		Color(1.0, 0.55, 0.1),
		3.0
	)

	var flame_h: float = clampf(ring_radius * 1.1, 1.2, 2.8)
	var flame_mesh := CylinderMesh.new()
	flame_mesh.top_radius = 0.0
	flame_mesh.bottom_radius = ring_radius * 0.45
	flame_mesh.height = flame_h
	var flame_inst := MeshInstance3D.new()
	flame_inst.mesh = flame_mesh
	flame_inst.material_override = flame_mat
	flame_inst.position = Vector3(0, flame_h * 0.5, 0)
	_visual_root.add_child(flame_inst)

	# 4. Тепле світло вогню (shadow_enabled вимкнено для уникнення важкої компіляції шейдерів тіней на ходу)
	_fire_light = OmniLight3D.new()
	_fire_light.light_color = Color(1.0, 0.65, 0.25)
	_fire_light.light_energy = 2.5
	_fire_light.omni_range = maxf(ring_radius * 4.0, 10.0)
	_fire_light.shadow_enabled = false
	_fire_light.position = Vector3(0, flame_h * 0.7, 0)
	_visual_root.add_child(_fire_light)


func _build_stockpile_visual(size_m: Vector2) -> void:
	# 1. Дерев'яний настил платформи
	var deck_mat: StandardMaterial3D = TextureHelper.create_material(
		TextureHelper.PATH_BLD_WOOD_PLANKS,
		Color(0.48, 0.35, 0.22),
		0.8,
		Vector3(size_m.x * 0.5, size_m.y * 0.5, 1.0)
	)

	var deck_mesh := BoxMesh.new()
	deck_mesh.size = Vector3(size_m.x - 0.2, 0.15, size_m.y - 0.2)
	var deck_inst := MeshInstance3D.new()
	deck_inst.mesh = deck_mesh
	deck_inst.material_override = deck_mat
	deck_inst.position = Vector3(0, 0.08, 0)
	_visual_root.add_child(deck_inst)

	# 2. Чотири кутові стовпи
	var post_mat: StandardMaterial3D = TextureHelper.create_material(
		TextureHelper.PATH_BLD_WOOD_POST,
		Color(0.32, 0.2, 0.1),
		0.85
	)
	var hx: float = size_m.x * 0.5 - 0.5
	var hz: float = size_m.y * 0.5 - 0.5
	var corners := [Vector3(-hx, 1.0, -hz), Vector3(hx, 1.0, -hz), Vector3(-hx, 1.0, hz), Vector3(hx, 1.0, hz)]
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.25
	post_mesh.bottom_radius = 0.25
	post_mesh.height = 2.0
	for c in corners:
		var post_inst := MeshInstance3D.new()
		post_inst.mesh = post_mesh
		post_inst.material_override = post_mat
		post_inst.position = c
		_visual_root.add_child(post_inst)

	# 3. Декоративні ящики та піддони на складі
	var crate_mat: StandardMaterial3D = TextureHelper.create_material(
		TextureHelper.PATH_BLD_CRATE,
		Color(0.6, 0.44, 0.25),
		0.8
	)
	var crate_spacing_x: float = minf(size_m.x * 0.28, 3.5)
	var crate_spacing_z: float = minf(size_m.y * 0.28, 3.5)
	var crate_sz: float = clampf(size_m.x * 0.1, 0.8, 1.4)
	var crate_mesh := BoxMesh.new()
	crate_mesh.size = Vector3(crate_sz, crate_sz * 0.85, crate_sz)

	for i in range(6):
		var crate_inst := MeshInstance3D.new()
		crate_inst.mesh = crate_mesh
		crate_inst.material_override = crate_mat
		var offset_x: float = ((i % 3) - 1.0) * crate_spacing_x
		var offset_z: float = (float(i / 3) - 0.5) * crate_spacing_z
		crate_inst.position = Vector3(offset_x, crate_sz * 0.42, offset_z)
		_visual_root.add_child(crate_inst)


func _build_wooden_hut_visual(size_m: Vector2) -> void:
	var wall_w: float = size_m.x * 0.8
	var wall_h: float = 3.6
	var wall_d: float = size_m.y * 0.8

	var wall_mat: StandardMaterial3D = TextureHelper.create_material(
		TextureHelper.PATH_BLD_HUT_WALL,
		Color(0.42, 0.28, 0.16),
		0.9,
		Vector3(wall_w * 0.25, wall_h * 0.25, 1.0)
	)

	var roof_mat: StandardMaterial3D = TextureHelper.create_material(
		TextureHelper.PATH_BLD_HUT_ROOF,
		Color(0.28, 0.18, 0.1),
		0.85,
		Vector3(wall_w * 0.25, wall_d * 0.25, 1.0)
	)

	# 1. Основні дерев'яні стіни коробки хатини
	var house_mesh := BoxMesh.new()
	house_mesh.size = Vector3(wall_w, wall_h, wall_d)
	var house_inst := MeshInstance3D.new()
	house_inst.mesh = house_mesh
	house_inst.material_override = wall_mat
	house_inst.position = Vector3(0, wall_h * 0.5, 0)
	_visual_root.add_child(house_inst)

	# 2. Двосхилий дах
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(wall_w + 1.2, 2.5, wall_d + 1.2)
	var roof_inst := MeshInstance3D.new()
	roof_inst.mesh = roof_mesh
	roof_inst.material_override = roof_mat
	roof_inst.position = Vector3(0, wall_h + 1.25, 0)
	_visual_root.add_child(roof_inst)

	# 3. Вхідні двері
	var door_mat: StandardMaterial3D = TextureHelper.create_material(
		TextureHelper.PATH_BLD_HUT_DOOR,
		Color(0.2, 0.12, 0.06),
		0.85
	)
	var door_mesh := BoxMesh.new()
	door_mesh.size = Vector3(1.8, 2.4, 0.3)
	var door_inst := MeshInstance3D.new()
	door_inst.mesh = door_mesh
	door_inst.material_override = door_mat
	door_inst.position = Vector3(0, 1.2, wall_d * 0.5 + 0.1)
	_visual_root.add_child(door_inst)

	# 4. Ліхтар біля входу
	var lantern_light := OmniLight3D.new()
	lantern_light.light_color = Color(1.0, 0.8, 0.4)
	lantern_light.light_energy = 2.0
	lantern_light.omni_range = 10.0
	lantern_light.shadow_enabled = false
	lantern_light.position = Vector3(1.4, 2.2, wall_d * 0.5 + 0.6)
	_visual_root.add_child(lantern_light)


func _build_generic_visual(size_m: Vector2) -> void:
	var gen_mat: StandardMaterial3D = TextureHelper.create_material(
		TextureHelper.PATH_BLD_GENERIC,
		Color(0.5, 0.5, 0.5),
		0.8
	)
	var gen_mesh := BoxMesh.new()
	gen_mesh.size = Vector3(size_m.x - 0.2, 2.0, size_m.y - 0.2)
	var gen_inst := MeshInstance3D.new()
	gen_inst.mesh = gen_mesh
	gen_inst.material_override = gen_mat
	gen_inst.position = Vector3(0, 1.0, 0)
	_visual_root.add_child(gen_inst)


func _setup_label(size_m: Vector2) -> void:
	if _label_3d == null:
		_label_3d = Label3D.new()
		_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label_3d.no_depth_test = false
		_label_3d.font_size = 26
		_label_3d.outline_size = 8
		_label_3d.outline_modulate = Color(0, 0, 0, 0.95)
		_label_3d.modulate = Color(1, 0.95, 0.7, 1.0)
		add_child(_label_3d)

	var height: float = 2.2
	if building_data != null:
		if building_data.id == &"campfire":
			height = 2.4
		elif building_data.is_solid:
			height = 4.5
		else:
			height = 2.2
	_label_3d.position = Vector3(0, height + 0.6, 0)


func _update_label() -> void:
	if _label_3d == null or building_data == null:
		return

	var text: String = "🏛 %s (%dx%d)" % [
		building_data.display_name,
		building_data.size_in_tiles.x,
		building_data.size_in_tiles.y
	]

	if inventory != null:
		text += "\n📦 Сховище: %d/%d слотів" % [inventory.get_all_items().size(), inventory.slot_count]

	if not building_data.job_type_provided.is_empty():
		text += "\n🛠 Робоче місце: %s" % [String(building_data.job_type_provided).capitalize()]

	_label_3d.text = text


func _on_inventory_updated() -> void:
	_update_label()


## Демонтує будівлю, звільняє клітинки сітки та надсилає сигнал
func demolish() -> void:
	for c in occupied_cells:
		GridManager.unregister_occupant(c, true)

	EventBus.building_demolished.emit(self, building_data.id, origin_cell)
	queue_free()
