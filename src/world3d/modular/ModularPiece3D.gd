class_name ModularPiece3D
extends StaticBody3D

## ModularPiece3D: Модульний будівельний блок у стилі Going Medieval.
## Підтримує типи: modular_floor, modular_pillar, modular_wall, modular_door, modular_roof.
## Стан креслення (blueprint): світиться напівпрозорим синім, пульсує емісією, приймає матеріали на E/клік.
## Стан побудованого (constructed): повноцінний 3D об'єкт зі статичними текстурами та твердою колізією.

signal piece_constructed(piece: ModularPiece3D)
signal piece_removed(piece: ModularPiece3D)

@export var piece_type: StringName = &"modular_floor"
@export var cell_coord: Vector2i = Vector2i.ZERO
@export var is_built: bool = false
@export var is_door_open: bool = false
var construction_progress_hits: int = 0
@export var rotation_index: int = 0

var required_materials: Dictionary = {} # StringName -> int
var _visual_root: Node3D = null
var _collision_shape: CollisionShape3D = null
var _door_pivot: Node3D = null
var _door_collision: CollisionShape3D = null
var _post_l_col: CollisionShape3D = null
var _post_r_col: CollisionShape3D = null
var _label_3d: Label3D = null
var _holo_mat: StandardMaterial3D = null
var _time_passed: float = 0.0

const TextureHelper = preload("res://src/core3d/TextureHelper.gd")


func _ready() -> void:
	add_to_group("modular_pieces")
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 0


func _process(delta: float) -> void:
	if not is_built and _holo_mat != null:
		_time_passed += delta
		_holo_mat.emission_energy_multiplier = 0.75 + 0.35 * sin(_time_passed * 3.5)


func setup_piece(p_type: StringName, p_cell: Vector2i, p_built: bool = false, p_rot_deg: float = 0.0) -> void:
	piece_type = p_type
	cell_coord = p_cell
	is_built = p_built
	rotation_degrees.y = p_rot_deg
	rotation_index = int(round(p_rot_deg / 90.0)) % 4
	name = "%s_%d_%d" % [piece_type, cell_coord.x, cell_coord.y]

	global_position = GridManager.map_to_world_3d(cell_coord, 0.0)

	_init_costs()
	_rebuild_mesh()

	if is_built:
		apply_built_state(false)
	else:
		apply_blueprint_state()


func _init_costs() -> void:
	required_materials.clear()
	match piece_type:
		&"modular_floor":
			required_materials[&"wood"] = 1
		&"modular_pillar":
			required_materials[&"wood"] = 1
		&"modular_wall":
			required_materials[&"wood"] = 2
		&"modular_door":
			required_materials[&"wood"] = 2
		&"modular_roof":
			required_materials[&"wood"] = 1
			required_materials[&"straw"] = 2


func get_cost_text() -> String:
	var parts: Array[String] = []
	for it in required_materials.keys():
		var it_name = "Деревина" if it == &"wood" else ("Сіно" if it == &"straw" else str(it))
		parts.append("%d %s" % [required_materials[it], it_name])
	return ", ".join(parts)


func _create_holo_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.albedo_color = Color(0.12, 0.65, 1.0, 0.45)
	mat.emission_enabled = true
	mat.emission = Color(0.08, 0.55, 1.0)
	mat.emission_energy_multiplier = 0.9
	return mat


func _create_textured_material(tex_path: String, fallback_col: Color) -> StandardMaterial3D:
	return TextureHelper.create_material(tex_path, fallback_col, 0.8)


func _rebuild_mesh() -> void:
	if _visual_root != null:
		_visual_root.queue_free()

	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)

	if _collision_shape != null:
		_collision_shape.queue_free()
		_collision_shape = null
	if _door_collision != null:
		_door_collision.queue_free()
		_door_collision = null
	if _post_l_col != null:
		_post_l_col.queue_free()
		_post_l_col = null
	if _post_r_col != null:
		_post_r_col.queue_free()
		_post_r_col = null

	_holo_mat = _create_holo_material()
	var current_mat: Material = _holo_mat if not is_built else _get_built_material()

	match piece_type:
		&"modular_floor":
			_build_floor_geometry(current_mat)
		&"modular_pillar":
			_build_pillar_geometry(current_mat)
		&"modular_wall":
			_build_wall_geometry(current_mat)
		&"modular_door":
			_build_door_geometry(current_mat)
		&"modular_roof":
			_build_roof_geometry(current_mat)

	_setup_label()


func _get_built_material() -> StandardMaterial3D:
	match piece_type:
		&"modular_floor":
			return _create_textured_material(TextureHelper.PATH_BLD_WOOD_PLANKS, Color("8D6E63"))
		&"modular_pillar":
			return _create_textured_material(TextureHelper.PATH_BLD_WOOD_POST, Color("5D4037"))
		&"modular_wall":
			return _create_textured_material(TextureHelper.PATH_BLD_HUT_WALL, Color("795548"))
		&"modular_door":
			return _create_textured_material(TextureHelper.PATH_BLD_HUT_DOOR, Color("A1887F"))
		&"modular_roof":
			return _create_textured_material(TextureHelper.PATH_BLD_STRAW_THATCH, Color("D7CCC8"))
		_:
			return _create_textured_material(TextureHelper.PATH_BLD_WOOD_PLANKS, Color("8D6E63"))


func _build_floor_geometry(mat: Material) -> void:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 0.08, 1.0)
	mesh_inst.mesh = box
	mesh_inst.material_override = mat
	mesh_inst.position = Vector3(0.0, 0.04, 0.0)
	_visual_root.add_child(mesh_inst)

	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 0.08, 1.0)
	_collision_shape.shape = shape
	_collision_shape.position = Vector3(0.0, 0.04, 0.0)
	add_child(_collision_shape)


func _build_pillar_geometry(mat: Material) -> void:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 2.0, 1.0)
	mesh_inst.mesh = box
	mesh_inst.material_override = mat
	mesh_inst.position = Vector3(0.0, 1.0, 0.0)
	_visual_root.add_child(mesh_inst)

	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 2.0, 1.0)
	_collision_shape.shape = shape
	_collision_shape.position = Vector3(0.0, 1.0, 0.0)
	add_child(_collision_shape)


func _build_wall_geometry(mat: Material) -> void:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 2.0, 0.2)
	mesh_inst.mesh = box
	mesh_inst.material_override = mat
	mesh_inst.position = Vector3(0.0, 1.0, 0.0)
	_visual_root.add_child(mesh_inst)

	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 2.0, 0.2)
	_collision_shape.shape = shape
	_collision_shape.position = Vector3(0.0, 1.0, 0.0)
	add_child(_collision_shape)


func _build_door_geometry(mat: Material) -> void:
	# 1. Ліва стійка рами дверей (тонка стійка 0.06м на самому краю x = -0.47)
	var post_l := MeshInstance3D.new()
	var post_box := BoxMesh.new()
	post_box.size = Vector3(0.06, 2.1, 0.12)
	post_l.mesh = post_box
	post_l.material_override = mat
	post_l.position = Vector3(-0.47, 1.05, 0.0)
	_visual_root.add_child(post_l)

	_post_l_col = CollisionShape3D.new()
	var shape_l := BoxShape3D.new()
	shape_l.size = Vector3(0.06, 2.1, 0.12)
	_post_l_col.shape = shape_l
	_post_l_col.position = Vector3(-0.47, 1.05, 0.0)
	add_child(_post_l_col)

	# 2. Права стійка рами дверей (тонка стійка 0.06м на самому краю x = +0.47)
	var post_r := MeshInstance3D.new()
	post_r.mesh = post_box
	post_r.material_override = mat
	post_r.position = Vector3(0.47, 1.05, 0.0)
	_visual_root.add_child(post_r)

	_post_r_col = CollisionShape3D.new()
	var shape_r := BoxShape3D.new()
	shape_r.size = Vector3(0.06, 2.1, 0.12)
	_post_r_col.shape = shape_r
	_post_r_col.position = Vector3(0.47, 1.05, 0.0)
	add_child(_post_r_col)

	# 3. Перемичка (одвірок) на висоті 2.05м
	var lintel := MeshInstance3D.new()
	var lintel_box := BoxMesh.new()
	lintel_box.size = Vector3(1.0, 0.1, 0.12)
	lintel.mesh = lintel_box
	lintel.material_override = mat
	lintel.position = Vector3(0.0, 2.05, 0.0)
	_visual_root.add_child(lintel)

	# 4. Поворотне полотно дверей (шарнір біля лівої стійки на x = -0.44)
	_door_pivot = Node3D.new()
	_door_pivot.name = "DoorPivot"
	_door_pivot.position = Vector3(-0.44, 0.0, 0.0)
	_visual_root.add_child(_door_pivot)

	var door_leaf := MeshInstance3D.new()
	var leaf_box := BoxMesh.new()
	leaf_box.size = Vector3(0.88, 1.98, 0.05)
	door_leaf.mesh = leaf_box
	door_leaf.material_override = mat
	door_leaf.position = Vector3(0.44, 1.0, 0.0)
	_door_pivot.add_child(door_leaf)

	# 5. Колізія проходу дверей (ширина 0.88м, висота 2.0м, вимикається при відкритті)
	_door_collision = CollisionShape3D.new()
	var shape_c := BoxShape3D.new()
	shape_c.size = Vector3(0.88, 2.0, 0.1)
	_door_collision.shape = shape_c
	_door_collision.position = Vector3(0.0, 1.0, 0.0)
	add_child(_door_collision)


func _build_roof_geometry(mat: Material) -> void:
	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 0.12, 1.0)
	mesh_inst.mesh = box
	mesh_inst.material_override = mat
	mesh_inst.position = Vector3(0.0, 2.06, 0.0)
	_visual_root.add_child(mesh_inst)

	_collision_shape = CollisionShape3D.new()
	_collision_shape.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 0.12, 1.0)
	_collision_shape.shape = shape
	_collision_shape.position = Vector3(0.0, 2.06, 0.0)
	add_child(_collision_shape)


func _setup_label() -> void:
	if _label_3d != null:
		_label_3d.queue_free()

	_label_3d = Label3D.new()
	_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label_3d.no_depth_test = true
	_label_3d.pixel_size = 0.004
	_label_3d.font_size = 20
	_label_3d.outline_size = 4
	_label_3d.outline_modulate = Color(0, 0, 0, 0.85)

	match piece_type:
		&"modular_floor":
			_label_3d.position = Vector3(0, 0.45, 0)
		&"modular_roof":
			_label_3d.position = Vector3(0, 1.85, 0)
		_:
			_label_3d.position = Vector3(0, 1.25, 0)

	add_child(_label_3d)
	_update_label_text()


func _update_label_text() -> void:
	if _label_3d == null:
		return
	if not is_built:
		_label_3d.modulate = Color("56CCF2")
		_label_3d.text = "[E] Збудувати\n(%s)" % get_cost_text()
	else:
		if piece_type == &"modular_door":
			_label_3d.modulate = Color("F4A261")
			_label_3d.text = "[E] Зачинити" if is_door_open else "[E] Відчинити"
		else:
			_label_3d.text = ""


func apply_blueprint_state() -> void:
	is_built = false
	if _visual_root != null:
		_set_material_recursive(_visual_root, _holo_mat)
	_update_label_text()


func apply_built_state(animate: bool = true) -> void:
	is_built = true
	var built_mat = _get_built_material()
	if _visual_root != null:
		_set_material_recursive(_visual_root, built_mat)

	if piece_type == &"modular_wall":
		GridManager.set_cell_solid(cell_coord, true)
	elif piece_type == &"modular_door":
		if _door_collision != null:
			_door_collision.disabled = is_door_open
		GridManager.set_cell_solid(cell_coord, not is_door_open)

	_update_label_text()

	if animate:
		var tween := create_tween()
		scale = Vector3(1.0, 0.2, 1.0)
		tween.tween_property(self, "scale", Vector3(1.08, 1.08, 1.08), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector3.ONE, 0.1)


func _set_material_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_set_material_recursive(child, mat)


func show_temporary_message(text: String, col: Color = Color(1, 0.3, 0.3)) -> void:
	if _label_3d == null:
		return
	_label_3d.text = text
	_label_3d.modulate = col
	var t := create_tween()
	t.tween_interval(1.8)
	t.tween_callback(_update_label_text)


## Взаємодія на [E] або клік миші (зведення частини або відкриття дверей)
func interact_construct(inventory: Node, has_hammer: bool = false) -> bool:
	if is_built:
		if piece_type == &"modular_door":
			interact(null)
		return false

	# 1. Перевірка структурних правил перед будівництвом
	if piece_type in [&"modular_wall", &"modular_pillar", &"modular_door"]:
		if ModularManager != null and not ModularManager.has_built_floor(cell_coord):
			show_temporary_message("Спочатку збудуйте підлогу!", Color(1.0, 0.35, 0.35))
			return false

	if piece_type == &"modular_roof":
		if ModularManager != null and not ModularManager.has_built_support_for_roof(cell_coord):
			show_temporary_message("Спочатку збудуйте стіни або опори!", Color(1.0, 0.35, 0.35))
			return false

	# 2. Перевірка наявності матеріалів в інвентарі
	if inventory != null:
		for item_id in required_materials.keys():
			var needed: int = required_materials[item_id]
			var count: int = inventory.get_item_count(item_id) if inventory.has_method("get_item_count") else 0
			if count < needed:
				show_temporary_message("Потрібно: %s" % get_cost_text(), Color(1.0, 0.35, 0.35))
				return false

	# 3. Механіка ударів/махів: 10 без молотка (+1 бал), 5 з молотком (+2 бали)
	var hit_points := 2 if has_hammer else 1
	construction_progress_hits += hit_points
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.04, 0.96, 1.04), 0.08)
	tw.tween_property(self, "scale", Vector3.ONE, 0.08)

	if construction_progress_hits < 10:
		var current_swings := int(ceil(float(construction_progress_hits) / (2.0 if has_hammer else 1.0)))
		var max_swings := 5 if has_hammer else 10
		var tool_text := "🔨 Молоток" if has_hammer else "🖐️ Без молотка"
		show_temporary_message("Будівництво: %d/%d (%s)" % [current_swings, max_swings, tool_text], Color(0.85, 0.95, 1.0))
		return false

	# 4. Списання матеріалів при завершенні (10/10)
	if inventory != null:
		for item_id in required_materials.keys():
			var needed: int = required_materials[item_id]
			if inventory.has_method("remove_item_by_id"):
				inventory.remove_item_by_id(item_id, needed)
			elif inventory.has_method("remove_item"):
				inventory.remove_item(item_id, needed)

	# 5. Завершення будівництва
	apply_built_state(true)
	piece_constructed.emit(self)
	if ModularManager != null:
		ModularManager.notify_piece_built(self)
	show_temporary_message("Збудовано! ✅", Color(0.4, 1.0, 0.4))
	return true


## Взаємодія гравця з готовим об'єктом (наприклад, відкривання/закривання дверей)
func interact(_player: Node = null) -> void:
	if piece_type == &"modular_door" and is_built:
		is_door_open = not is_door_open
		if _door_pivot != null:
			var tw := create_tween()
			var target_rot = deg_to_rad(90.0) if is_door_open else 0.0
			tw.tween_property(_door_pivot, "rotation:y", target_rot, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		if _door_collision != null:
			_door_collision.disabled = is_door_open

		GridManager.set_cell_solid(cell_coord, not is_door_open)
		_update_label_text()
