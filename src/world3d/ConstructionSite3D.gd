class_name ConstructionSite3D
extends StaticBody3D

## ConstructionSite3D: Фізичний будівельний майданчик споруди у 3D просторі.
## Спавниться після підтвердження розміщення креслення (Blueprint).
## Блокує свої тайли у GridManager, приймає необхідні матеріали
## (ItemCost), відображає прогрес-бар та після завершення будівництва
## автоматично замінюється на фінальну споруду BuildingEntity3D.

signal material_delivered(item_id: StringName, amount_delivered: int, total_delivered: int, total_needed: int)
signal materials_completed
signal construction_progress_updated(progress_ratio: float, current_progress: float, total_time: float)
signal construction_completed(building_data: BuildingData, origin_cell: Vector2i, building_instance: Node3D)
signal construction_canceled

const TextureHelper = preload("res://src/core3d/TextureHelper.gd")
const DroppedItem3DScene = preload("res://src/entities3d/items/DroppedItem3D.tscn")
const BuildingEntity3DScript = preload("res://src/world3d/BuildingEntity3D.gd")
const BlueprintVisualHelperScript = preload("res://src/world3d/BlueprintVisualHelper.gd")

@export var building_data: BuildingData = null
@export var origin_cell: Vector2i = Vector2i.ZERO

var occupied_cells: Array[Vector2i] = []
var required_materials: Dictionary = {}   ## StringName -> int (необхідно)
var delivered_materials: Dictionary = {}  ## StringName -> int (доставлено)

var build_progress: float = 0.0
var is_completed: bool = false

var _collision_shape: CollisionShape3D = null
var _visual_root: Node3D = null
var _label_3d: Label3D = null
var _progress_bar_mesh: MeshInstance3D = null
var _wobble_tween: Tween = null
var _blueprint_hologram: Node3D = null
var _holo_material: StandardMaterial3D = null
var _holo_time: float = 0.0



func _process(delta: float) -> void:
	if _holo_material != null:
		_holo_time += delta
		_holo_material.emission_energy_multiplier = 0.55 + 0.25 * sin(_holo_time * 3.0)

func _ready() -> void:
	add_to_group("construction_sites")
	add_to_group("interactable")


func setup_site(p_building_data: BuildingData, p_origin_cell: Vector2i) -> void:
	building_data = p_building_data
	origin_cell = p_origin_cell

	# 1. Розрахунок зайнятих клітинок
	occupied_cells = BuildingPlacementController.get_occupied_cells(origin_cell, building_data.size_in_tiles)

	# 2. Позиціонування у світових координатах за центром будівлі
	var center_m: Vector3 = BuildingPlacementController.get_building_world_center(origin_cell, building_data.size_in_tiles)
	global_position = center_m

	# 3. Блокування клітинок у GridManager на час будівництва
	for c in occupied_cells:
		GridManager.register_occupant(c, self, true)

	# 4. Ініціалізація вимог до матеріалів
	required_materials.clear()
	delivered_materials.clear()
	for cost in building_data.construction_cost:
		if cost != null and cost.item != null:
			var item_id: StringName = cost.item.id
			required_materials[item_id] = cost.amount
			delivered_materials[item_id] = 0

	# 5. Створення колізії майданчика
	_setup_collision()

	# 6. Створення візуального риштування та огорожі
	_setup_visual()

	# 7. Оновлення текстового тач-скріна
	_update_display()

	# 8. Сповіщення в EventBus
	EventBus.construction_site_placed.emit(self, building_data.id, origin_cell)


func _setup_collision() -> void:
	if _collision_shape == null:
		_collision_shape = CollisionShape3D.new()
		_collision_shape.name = "SiteCollision"
		add_child(_collision_shape)

	var size_m: Vector2 = Vector2(building_data.size_in_tiles) * GridManager.TILE_SIZE_3D
	var box := BoxShape3D.new()
	box.size = Vector3(size_m.x - 0.1, 1.8, size_m.y - 0.1)
	_collision_shape.shape = box
	_collision_shape.position = Vector3(0, 0.9, 0)


func _setup_visual() -> void:
	if _visual_root != null:
		_visual_root.queue_free()

	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)

	var size_m: Vector2 = Vector2(building_data.size_in_tiles) * GridManager.TILE_SIZE_3D

	# 1. Земляна/піщана основа майданчика
	var base_mat: StandardMaterial3D = TextureHelper.create_material(
		TextureHelper.PATH_BLD_SITE_GROUND,
		Color(0.38, 0.3, 0.2),
		0.95,
		Vector3(size_m.x * 0.5, size_m.y * 0.5, 1.0)
	)

	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(size_m.x - 0.1, 0.08, size_m.y - 0.1)
	var base_inst := MeshInstance3D.new()
	base_inst.mesh = base_mesh
	base_inst.material_override = base_mat
	base_inst.position = Vector3(0, 0.04, 0)
	_visual_root.add_child(base_inst)

	# 2. Кутові дерев'яні палі та сигнальні позначки
	var stake_mat: StandardMaterial3D = TextureHelper.create_material(
		TextureHelper.PATH_BLD_WOOD_POST,
		Color(0.55, 0.4, 0.25),
		0.85
	)

	var hx: float = size_m.x * 0.5 - 0.4
	var hz: float = size_m.y * 0.5 - 0.4
	var corners := [Vector3(-hx, 1.0, -hz), Vector3(hx, 1.0, -hz), Vector3(-hx, 1.0, hz), Vector3(hx, 1.0, hz)]
	for c in corners:
		var stake_mesh := CylinderMesh.new()
		stake_mesh.top_radius = 0.2
		stake_mesh.bottom_radius = 0.25
		stake_mesh.height = 2.0
		var stake_inst := MeshInstance3D.new()
		stake_inst.mesh = stake_mesh
		stake_inst.material_override = stake_mat
		stake_inst.position = c
		_visual_root.add_child(stake_inst)

	# 3. Периметральна мотузка / балки огорожі
	var rope_mat: StandardMaterial3D = TextureHelper.create_material(
		TextureHelper.PATH_BLD_ROPE,
		Color(0.8, 0.7, 0.4),
		0.8
	)

	var rope_x_mesh := BoxMesh.new()
	rope_x_mesh.size = Vector3(size_m.x - 0.8, 0.08, 0.08)
	var rope_top := MeshInstance3D.new()
	rope_top.mesh = rope_x_mesh
	rope_top.material_override = rope_mat
	rope_top.position = Vector3(0, 1.2, -hz)
	_visual_root.add_child(rope_top)

	var rope_bottom := MeshInstance3D.new()
	rope_bottom.mesh = rope_x_mesh
	rope_bottom.material_override = rope_mat
	rope_bottom.position = Vector3(0, 1.2, hz)
	_visual_root.add_child(rope_bottom)

	var rope_z_mesh := BoxMesh.new()
	rope_z_mesh.size = Vector3(0.08, 0.08, size_m.y - 0.8)
	var rope_left := MeshInstance3D.new()
	rope_left.mesh = rope_z_mesh
	rope_left.material_override = rope_mat
	rope_left.position = Vector3(-hx, 1.2, 0)
	_visual_root.add_child(rope_left)

	var rope_right := MeshInstance3D.new()
	rope_right.mesh = rope_z_mesh
	rope_right.material_override = rope_mat
	rope_right.position = Vector3(hx, 1.2, 0)
	_visual_root.add_child(rope_right)

	# 4. Голографічний блупрінт споруди (Factorio Blueprint Hologram)
	_setup_blueprint_hologram(size_m)

	# 5. 3D Billboard текст
	_setup_label(size_m)



func _setup_blueprint_hologram(size_m: Vector2) -> void:
	if building_data == null:
		return
	_holo_material = BlueprintVisualHelperScript.create_hologram_material(
		Color(0.18, 0.68, 1.0, 0.42),
		Color(0.12, 0.52, 0.98),
		0.7
	)
	_blueprint_hologram = BlueprintVisualHelperScript.build_blueprint_hologram(
		building_data.id,
		size_m,
		_holo_material
	)
	_visual_root.add_child(_blueprint_hologram)

func _setup_label(size_m: Vector2) -> void:
	if _label_3d == null:
		_label_3d = Label3D.new()
		_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label_3d.no_depth_test = false
		_label_3d.font_size = 28
		_label_3d.outline_size = 8
		_label_3d.outline_modulate = Color(0, 0, 0, 0.95)
		_label_3d.modulate = Color(1, 0.9, 0.4, 1.0)
		add_child(_label_3d)

	var height: float = 2.4
	_label_3d.position = Vector3(0, height + 0.5, 0)


func _update_display() -> void:
	if _label_3d == null or building_data == null:
		return

	var text: String = "📐 КРЕСЛЕННЯ: %s [%dx%d]\n" % [
		building_data.display_name,
		building_data.size_in_tiles.x,
		building_data.size_in_tiles.y
	]

	if not is_materials_ready():
		text += "Ресурси:\n"
		for id in required_materials.keys():
			var item_name: String = String(id)
			var item_res = ItemDatabase.get_item(id)
			if item_res != null and not item_res.display_name.is_empty():
				item_name = item_res.display_name
			var cur: int = delivered_materials.get(id, 0)
			var req: int = required_materials[id]
			var check: String = "✓" if cur >= req else "⏳"
			text += "%s %s: %d/%d\n" % [check, item_name, cur, req]
		text += "(Підійдіть і натисніть [E], щоб внести)"
	else:
		var pct: int = int((build_progress / maxf(0.001, building_data.build_time)) * 100.0)
		text += "Прогрес робіт: %d%%\n" % pct
		text += "🔨 Затисніть [E] для будівництва"

	_label_3d.text = text.strip_edges()


## Перевірка чи може майданчик прийняти даний предмет
func can_accept_material(item_id: StringName) -> bool:
	if not required_materials.has(item_id):
		return false
	return delivered_materials.get(item_id, 0) < required_materials[item_id]


## Скільки ще одиниць матеріалу не вистачає
func get_remaining_needed(item_id: StringName) -> int:
	if not required_materials.has(item_id):
		return 0
	return maxi(0, required_materials[item_id] - delivered_materials.get(item_id, 0))


## Доставляє ресурси на майданчик. Повертає фактично прийняту кількість.
func deliver_material(item_id: StringName, amount: int) -> int:
	if amount <= 0 or not can_accept_material(item_id):
		return 0

	var needed: int = get_remaining_needed(item_id)
	var accepted: int = mini(amount, needed)
	delivered_materials[item_id] = delivered_materials.get(item_id, 0) + accepted

	material_delivered.emit(item_id, accepted, delivered_materials[item_id], required_materials[item_id])

	if is_materials_ready():
		materials_completed.emit()

	_play_wobble_animation()
	_update_display()
	return accepted


## Чи доставлені всі необхідні матеріали
func is_materials_ready() -> bool:
	if required_materials.is_empty():
		return true
	for id in required_materials.keys():
		if delivered_materials.get(id, 0) < required_materials[id]:
			return false
	return true


## Словник ресурсів, яких ще не вистачає
func get_missing_materials() -> Dictionary:
	var missing: Dictionary = {}
	for id in required_materials.keys():
		var rem: int = get_remaining_needed(id)
		if rem > 0:
			missing[id] = rem
	return missing


## Виконати будівельну роботу над майданчиком
func build_work(delta_work: float) -> bool:
	if is_completed:
		return false

	if not is_materials_ready():
		_play_wobble_animation(Color(1.0, 0.3, 0.3))
		return false

	build_progress = minf(build_progress + delta_work, building_data.build_time)
	var ratio: float = clampf(build_progress / maxf(0.001, building_data.build_time), 0.0, 1.0)

	construction_progress_updated.emit(ratio, build_progress, building_data.build_time)
	_play_wobble_animation(Color(0.5, 1.0, 0.5))
	_update_display()

	if build_progress >= building_data.build_time:
		complete_construction()
		return true

	return false


## Завершує будівництво та створює фінальну будівлю BuildingEntity3D
func complete_construction() -> Node3D:
	if is_completed:
		return null
	is_completed = true

	# Звільняємо майданчик з клітинок GridManager перед реєстрацією нової будівлі
	for c in occupied_cells:
		GridManager.unregister_occupant(c, false)

	# Створюємо завершену будівлю
	var building_inst: Node3D = null
	if building_data.custom_scene != null:
		building_inst = building_data.custom_scene.instantiate()
	if building_inst == null:
		building_inst = BuildingEntity3DScript.new()

	building_inst.name = "%s_%d_%d" % [building_data.id, origin_cell.x, origin_cell.y]
	get_parent().add_child(building_inst)
	if building_inst.has_method("setup_building"):
		building_inst.setup_building(building_data, origin_cell)

	EventBus.building_completed.emit(building_inst, building_data.id, origin_cell)
	construction_completed.emit(building_data, origin_cell, building_inst)

	queue_free()
	return building_inst


## Скасовує будівництво, повертає внесені матеріали дропом і очищає сітку
func cancel_construction() -> void:
	for c in occupied_cells:
		GridManager.unregister_occupant(c, true)

	# Дропаємо внесені матеріали
	for item_id in delivered_materials.keys():
		var count: int = delivered_materials[item_id]
		if count > 0 and DroppedItem3DScene != null:
			var drop = DroppedItem3DScene.instantiate()
			drop.position = global_position + Vector3(randf_range(-1.5, 1.5), 0.4, randf_range(-1.5, 1.5))
			drop.set_item(item_id, count)
			get_parent().add_child(drop)

	construction_canceled.emit()
	queue_free()


## Універсальна точка входу взаємодії гравця або робітника
func interact_construct(player_inventory: InventoryComponent = null) -> bool:
	if is_completed:
		return false

	# 1. Якщо майданчик потребує матеріалів — перевіряємо інвентар гравця
	if not is_materials_ready() and player_inventory != null:
		var any_delivered: bool = false
		for item_id in required_materials.keys():
			var rem: int = get_remaining_needed(item_id)
			if rem > 0 and player_inventory.has_item(item_id, 1):
				var available: int = player_inventory.get_item_count(item_id)
				var to_give: int = mini(rem, available)
				if player_inventory.remove_item(item_id, to_give, true):
					deliver_material(item_id, to_give)
					any_delivered = true

		if any_delivered:
			return true

	# 2. Якщо матеріали зібрані — виконуємо будівельну роботу
	if is_materials_ready():
		return build_work(1.5)

	return false


func _play_wobble_animation(_flash_color: Color = Color.WHITE) -> void:
	if _visual_root == null:
		return
	if _wobble_tween != null and _wobble_tween.is_valid():
		_wobble_tween.kill()

	_wobble_tween = create_tween()
	_visual_root.scale = Vector3(1.02, 0.95, 1.02)
	_wobble_tween.tween_property(_visual_root, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
