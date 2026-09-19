class_name BlueprintVisualHelper
extends RefCounted

## BlueprintVisualHelper: Генератор голографічних 3D моделей креслень (Factorio Blueprint Style).
## Створює напівпрозорі моделі споруд (вогнище, склад, хатина) для прев'ю розміщення та будівельних майданчиків.


## Створює голографічний матеріал для креслень
static func create_hologram_material(
	base_color: Color = Color(0.18, 0.68, 1.0, 0.42),
	emission_color: Color = Color(0.12, 0.52, 0.98),
	emission_energy: float = 0.7
) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.albedo_color = base_color
	mat.emission_enabled = true
	mat.emission = emission_color
	mat.emission_energy_multiplier = emission_energy
	return mat


## Будує голографічну геометрію споруди за її ідентифікатором
static func build_blueprint_hologram(building_id: StringName, size_m: Vector2, material: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "BlueprintHologram"

	match building_id:
		&"campfire":
			_build_campfire_holo(root, size_m, material)
		&"stockpile":
			_build_stockpile_holo(root, size_m, material)
		&"wooden_hut":
			_build_wooden_hut_holo(root, size_m, material)
		&"modular_floor":
			_build_modular_floor_holo(root, material)
		&"modular_pillar":
			_build_modular_pillar_holo(root, material)
		&"modular_wall":
			_build_modular_wall_holo(root, material)
		&"modular_door":
			_build_modular_door_holo(root, material)
		&"modular_roof":
			_build_modular_roof_holo(root, material)
		_:
			_build_generic_holo(root, size_m, material)

	return root


static func _build_campfire_holo(parent: Node3D, size_m: Vector2, mat: Material) -> void:
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
		var inst := MeshInstance3D.new()
		inst.mesh = stone_mesh
		inst.material_override = mat
		inst.position = Vector3(sx, stone_h * 0.5, sz)
		inst.rotation.y = angle
		parent.add_child(inst)

	# Перехресні колоди
	var log_r: float = clampf(ring_radius * 0.12, 0.12, 0.35)
	var log_mesh := CylinderMesh.new()
	log_mesh.top_radius = log_r * 0.9
	log_mesh.bottom_radius = log_r
	log_mesh.height = ring_radius * 1.5

	for i in range(4):
		var log_inst := MeshInstance3D.new()
		log_inst.mesh = log_mesh
		log_inst.material_override = mat
		log_inst.position = Vector3(0, log_r, 0)
		log_inst.rotation.y = float(i) * (PI / 4.0)
		log_inst.rotation.z = PI / 2.0
		parent.add_child(log_inst)

	# Голографічне ядро вогню
	var fire_mesh := SphereMesh.new()
	fire_mesh.radius = ring_radius * 0.3
	fire_mesh.height = ring_radius * 0.6
	var fire_inst := MeshInstance3D.new()
	fire_inst.mesh = fire_mesh
	fire_inst.material_override = mat
	fire_inst.position = Vector3(0, ring_radius * 0.35, 0)
	parent.add_child(fire_inst)


static func _build_stockpile_holo(parent: Node3D, size_m: Vector2, mat: Material) -> void:
	# 1. Голографічний настил
	var plat_mesh := BoxMesh.new()
	plat_mesh.size = Vector3(size_m.x - 0.2, 0.12, size_m.y - 0.2)
	var plat_inst := MeshInstance3D.new()
	plat_inst.mesh = plat_mesh
	plat_inst.material_override = mat
	plat_inst.position = Vector3(0, 0.06, 0)
	parent.add_child(plat_inst)

	# 2. Кутові стовпи
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.4, 1.4, 0.4)
	var hx: float = size_m.x * 0.5 - 0.35
	var hz: float = size_m.y * 0.5 - 0.35
	var post_pos := [Vector3(-hx, 0.7, -hz), Vector3(hx, 0.7, -hz), Vector3(-hx, 0.7, hz), Vector3(hx, 0.7, hz)]
	for p in post_pos:
		var post_inst := MeshInstance3D.new()
		post_inst.mesh = post_mesh
		post_inst.material_override = mat
		post_inst.position = p
		parent.add_child(post_inst)

	# 3. Голографічні ящики
	var crate_size: float = clampf(minf(size_m.x, size_m.y) * 0.15, 0.8, 1.5)
	var crate_mesh := BoxMesh.new()
	crate_mesh.size = Vector3(crate_size, crate_size, crate_size)
	var crate_offsets := [
		Vector3(-hx * 0.5, crate_size * 0.5 + 0.12, -hz * 0.5),
		Vector3(hx * 0.4, crate_size * 0.5 + 0.12, -hz * 0.3),
		Vector3(-hx * 0.3, crate_size * 0.5 + 0.12, hz * 0.5),
		Vector3(hx * 0.5, crate_size * 0.5 + 0.12, hz * 0.4),
		Vector3(0.0, crate_size * 0.5 + 0.12, 0.0)
	]
	for cr_pos in crate_offsets:
		var cr_inst := MeshInstance3D.new()
		cr_inst.mesh = crate_mesh
		cr_inst.material_override = mat
		cr_inst.position = cr_pos
		parent.add_child(cr_inst)


static func _build_wooden_hut_holo(parent: Node3D, size_m: Vector2, mat: Material) -> void:
	var wall_h: float = 3.2
	var hx: float = size_m.x * 0.5
	var hz: float = size_m.y * 0.5

	# Задня стіна
	var back_mesh := BoxMesh.new()
	back_mesh.size = Vector3(size_m.x - 0.2, wall_h, 0.3)
	var back_inst := MeshInstance3D.new()
	back_inst.mesh = back_mesh
	back_inst.material_override = mat
	back_inst.position = Vector3(0, wall_h * 0.5, -hz + 0.2)
	parent.add_child(back_inst)

	# Бічні стіни
	var side_mesh := BoxMesh.new()
	side_mesh.size = Vector3(0.3, wall_h, size_m.y - 0.4)
	var left_inst := MeshInstance3D.new()
	left_inst.mesh = side_mesh
	left_inst.material_override = mat
	left_inst.position = Vector3(-hx + 0.2, wall_h * 0.5, 0)
	parent.add_child(left_inst)

	var right_inst := MeshInstance3D.new()
	right_inst.mesh = side_mesh
	right_inst.material_override = mat
	right_inst.position = Vector3(hx - 0.2, wall_h * 0.5, 0)
	parent.add_child(right_inst)

	# Передня стіна з дверним отвором
	var door_w: float = 2.4
	var wall_seg_w: float = (size_m.x - door_w - 0.4) * 0.5
	var f_mesh := BoxMesh.new()
	f_mesh.size = Vector3(wall_seg_w, wall_h, 0.3)

	var f_left := MeshInstance3D.new()
	f_left.mesh = f_mesh
	f_left.material_override = mat
	f_left.position = Vector3(-hx + wall_seg_w * 0.5 + 0.2, wall_h * 0.5, hz - 0.2)
	parent.add_child(f_left)

	var f_right := MeshInstance3D.new()
	f_right.mesh = f_mesh
	f_right.material_override = mat
	f_right.position = Vector3(hx - wall_seg_w * 0.5 - 0.2, wall_h * 0.5, hz - 0.2)
	parent.add_child(f_right)

	# Двосхилий каркас даху
	var roof_h: float = 2.4
	var roof_angle: float = deg_to_rad(30.0)
	var slab_w: float = (size_m.x * 0.5) / cos(roof_angle) + 0.6
	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(slab_w, 0.15, size_m.y + 0.6)

	var r_left := MeshInstance3D.new()
	r_left.mesh = slab_mesh
	r_left.material_override = mat
	r_left.position = Vector3(-hx * 0.5, wall_h + roof_h * 0.5, 0)
	r_left.rotation.z = roof_angle
	parent.add_child(r_left)

	var r_right := MeshInstance3D.new()
	r_right.mesh = slab_mesh
	r_right.material_override = mat
	r_right.position = Vector3(hx * 0.5, wall_h + roof_h * 0.5, 0)
	r_right.rotation.z = -roof_angle
	parent.add_child(r_right)


static func _build_generic_holo(parent: Node3D, size_m: Vector2, mat: Material) -> void:
	var h: float = 2.2
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(size_m.x - 0.2, h, size_m.y - 0.2)
	var box_inst := MeshInstance3D.new()
	box_inst.mesh = box_mesh
	box_inst.material_override = mat
	box_inst.position = Vector3(0, h * 0.5, 0)
	parent.add_child(box_inst)

static func _build_modular_floor_holo(parent: Node3D, mat: Material) -> void:
	var inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 0.08, 1.0)
	inst.mesh = box
	inst.material_override = mat
	inst.position = Vector3(0.0, 0.04, 0.0)
	parent.add_child(inst)


static func _build_modular_pillar_holo(parent: Node3D, mat: Material) -> void:
	var inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.24, 2.0, 0.24)
	inst.mesh = box
	inst.material_override = mat
	inst.position = Vector3(0.0, 1.0, 0.0)
	parent.add_child(inst)


static func _build_modular_wall_holo(parent: Node3D, mat: Material) -> void:
	var inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 2.0, 0.2)
	inst.mesh = box
	inst.material_override = mat
	inst.position = Vector3(0.0, 1.0, 0.0)
	parent.add_child(inst)


static func _build_modular_door_holo(parent: Node3D, mat: Material) -> void:
	var post_l := MeshInstance3D.new()
	var post_box := BoxMesh.new()
	post_box.size = Vector3(0.12, 2.0, 0.2)
	post_l.mesh = post_box
	post_l.material_override = mat
	post_l.position = Vector3(-0.44, 1.0, 0.0)
	parent.add_child(post_l)

	var post_r := MeshInstance3D.new()
	post_r.mesh = post_box
	post_r.material_override = mat
	post_r.position = Vector3(0.44, 1.0, 0.0)
	parent.add_child(post_r)

	var lintel := MeshInstance3D.new()
	var lintel_box := BoxMesh.new()
	lintel_box.size = Vector3(1.0, 0.15, 0.2)
	lintel.mesh = lintel_box
	lintel.material_override = mat
	lintel.position = Vector3(0.0, 1.925, 0.0)
	parent.add_child(lintel)

	var door := MeshInstance3D.new()
	var door_box := BoxMesh.new()
	door_box.size = Vector3(0.76, 1.85, 0.06)
	door.mesh = door_box
	door.material_override = mat
	door.position = Vector3(0.0, 0.925, 0.0)
	parent.add_child(door)


static func _build_modular_roof_holo(parent: Node3D, mat: Material) -> void:
	var inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 0.12, 1.0)
	inst.mesh = box
	inst.material_override = mat
	inst.position = Vector3(0.0, 2.06, 0.0)
	parent.add_child(inst)
