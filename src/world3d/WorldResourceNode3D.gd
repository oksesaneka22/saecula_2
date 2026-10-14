class_name WorldResourceNode3D
extends StaticBody3D

## WorldResourceNode3D: Високопродуктивний 3D природний ресурс на карті (Дерево, Валун, Кущ ягід, Глина, Кремінь, Дика трава).
## Оптимізовано для високого FPS: використовує спільні статичні ArrayMesh з запеченими матеріалами (1 MeshInstance3D на вузол),
## статичні Shape3D колізії, вимкнені тіні для дрібних приземних об'єктів та кешування геометрії.

enum ResourceType {
	TREE,       ## Дерево -> спавнить wood
	ROCK,       ## Кам'яна брила -> спавнить stone
	BUSH,       ## Кущ диких ягід -> спавнить berries
	CLAY,       ## Родовище глини -> спавнить clay (біля водойм)
	FLINT,      ## Поклади кремнію -> спавнить flint (біля водойм)
	GRASS,      ## Дика трава кучками -> спавнить straw (потрібна коса)
	COPPER_ORE = 6,
}

const TextureHelper = preload("res://src/core3d/TextureHelper.gd")
const DroppedItem3DScene = preload("res://src/entities3d/items/DroppedItem3D.tscn")

@export var resource_type: ResourceType = ResourceType.TREE
@export var max_health: float = 3.0
@export var current_health: float = 3.0
@export var drop_item_id: StringName = &"wood"
@export var drop_min_amount: int = 2
@export var drop_max_amount: int = 4

var _cell: Vector2i = Vector2i.ZERO
var _shake_tween: Tween = null
var _original_scale: Vector3 = Vector3.ONE
var _sway_phase: float = 0.0
var _sway_timer: float = 0.0

func get_cell() -> Vector2i:
	if _cell == Vector2i.ZERO and GridManager != null:
		return GridManager.world_to_map_3d(global_position)
	return _cell

func set_cell(c: Vector2i) -> void:
	_cell = c

var visual_root: Node3D = null
var collision_shape: CollisionShape3D = null
var _mesh_inst: MeshInstance3D = null

# ------------------------------------------------------------------------------
# Статичне кешування сіток (ArrayMesh) та колізій (Shape3D)
# ------------------------------------------------------------------------------
static var _static_tree_mesh: ArrayMesh = null
static var _static_tree_shape: CylinderShape3D = null

static var _static_rock_mesh: ArrayMesh = null
static var _static_rock_shape: BoxShape3D = null

static var _static_bush_mesh: ArrayMesh = null
static var _static_bush_shape: SphereShape3D = null

static var _static_clay_mesh: ArrayMesh = null
static var _static_clay_shape: CylinderShape3D = null

static var _static_flint_mesh: ArrayMesh = null
static var _static_flint_shape: BoxShape3D = null

static var _static_grass_mesh: ArrayMesh = null
static var _static_grass_shape: BoxShape3D = null

static var _static_copper_ore_mesh: ArrayMesh = null
static var _static_copper_ore_shape: BoxShape3D = null


func _ready() -> void:
	add_to_group("resource_nodes")
	if resource_type == ResourceType.COPPER_ORE:
		max_health = 4.0
		drop_item_id = &"copper_ore"
		drop_min_amount = 2
		drop_max_amount = 4
	current_health = max_health

	if has_node("VisualRoot"):
		visual_root = $VisualRoot
	else:
		visual_root = Node3D.new()
		visual_root.name = "VisualRoot"
		add_child(visual_root)

	if has_node("CollisionShape3D"):
		collision_shape = $CollisionShape3D
	else:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		add_child(collision_shape)

	_original_scale = visual_root.scale

	if _cell == Vector2i.ZERO and GridManager != null:
		_cell = GridManager.world_to_map_3d(global_position)

	if GridManager != null:
		var snapped_pos: Vector3 = GridManager.map_to_world_3d(_cell, 0.0)
		global_position.x = snapped_pos.x
		global_position.z = snapped_pos.z

		if GridManager.get_occupant(_cell) != self:
			var is_solid: bool = (resource_type != ResourceType.GRASS)
			GridManager.register_occupant(_cell, self, is_solid)

	_setup_visual()
	_sway_phase = randf_range(0.0, TAU)
	set_process(resource_type in [ResourceType.TREE, ResourceType.BUSH, ResourceType.GRASS])


func _process(delta: float) -> void:
	if visual_root == null:
		return
	if resource_type in [ResourceType.TREE, ResourceType.BUSH, ResourceType.GRASS]:
		_sway_timer += delta * (2.2 if resource_type == ResourceType.GRASS else 1.2)
		var sway_amount: float = 0.035 if resource_type == ResourceType.GRASS else (0.02 if resource_type == ResourceType.BUSH else 0.015)
		var sway_z: float = sin(_sway_timer + _sway_phase) * sway_amount
		var sway_x: float = cos(_sway_timer * 0.7 + _sway_phase) * (sway_amount * 0.6)
		if _shake_tween == null or not _shake_tween.is_valid():
			visual_root.rotation.z = sway_z
			visual_root.rotation.x = sway_x


func _setup_visual() -> void:
	if visual_root == null:
		return

	_ensure_static_assets()

	if _mesh_inst == null:
		if visual_root.has_node("ResourceMesh"):
			_mesh_inst = visual_root.get_node("ResourceMesh")
		else:
			_mesh_inst = MeshInstance3D.new()
			_mesh_inst.name = "ResourceMesh"
			visual_root.add_child(_mesh_inst)

	match resource_type:
		ResourceType.TREE:
			_mesh_inst.mesh = _static_tree_mesh
			_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if collision_shape != null:
				collision_shape.shape = _static_tree_shape
				collision_shape.position.y = 1.6
		ResourceType.ROCK:
			_mesh_inst.mesh = _static_rock_mesh
			_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if collision_shape != null:
				collision_shape.shape = _static_rock_shape
				collision_shape.position.y = 0.5
		ResourceType.BUSH:
			_mesh_inst.mesh = _static_bush_mesh
			_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if collision_shape != null:
				collision_shape.shape = _static_bush_shape
				collision_shape.position.y = 0.4
		ResourceType.CLAY:
			_mesh_inst.mesh = _static_clay_mesh
			_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if collision_shape != null:
				collision_shape.shape = _static_clay_shape
				collision_shape.position.y = 0.3
		ResourceType.FLINT:
			_mesh_inst.mesh = _static_flint_mesh
			_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if collision_shape != null:
				collision_shape.shape = _static_flint_shape
				collision_shape.position.y = 0.4
		ResourceType.GRASS:
			_mesh_inst.mesh = _static_grass_mesh
			_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if collision_shape != null:
				collision_shape.shape = _static_grass_shape
				collision_shape.position.y = 0.22
		ResourceType.COPPER_ORE:
			_mesh_inst.mesh = _static_copper_ore_mesh
			_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if collision_shape != null:
				collision_shape.shape = _static_copper_ore_shape
				collision_shape.position.y = 0.48


# ------------------------------------------------------------------------------
# Побудова спільних геометрій один раз (Static Initialization)
# ------------------------------------------------------------------------------
static func _ensure_static_assets() -> void:
	if _static_tree_mesh != null:
		return

	# 1. Дерево (ArrayMesh: Поверхня 0 = Стовбур, Поверхня 1 = Крона)
	var trunk = CylinderMesh.new()
	trunk.top_radius = 0.22
	trunk.bottom_radius = 0.32
	trunk.height = 1.8
	var st_trunk = SurfaceTool.new()
	st_trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_trunk.append_from(trunk, 0, Transform3D(Basis(), Vector3(0, 0.9, 0)))

	var fol1 = CylinderMesh.new()
	fol1.top_radius = 0.02
	fol1.bottom_radius = 1.25
	fol1.height = 1.5
	var fol2 = CylinderMesh.new()
	fol2.top_radius = 0.02
	fol2.bottom_radius = 1.0
	fol2.height = 1.3
	var fol3 = CylinderMesh.new()
	fol3.top_radius = 0.02
	fol3.bottom_radius = 0.7
	fol3.height = 1.1

	var st_fol = SurfaceTool.new()
	st_fol.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_fol.append_from(fol1, 0, Transform3D(Basis(), Vector3(0, 2.0, 0)))
	st_fol.append_from(fol2, 0, Transform3D(Basis(), Vector3(0, 2.8, 0)))
	st_fol.append_from(fol3, 0, Transform3D(Basis(), Vector3(0, 3.5, 0)))

	_static_tree_mesh = ArrayMesh.new()
	st_trunk.commit(_static_tree_mesh)
	st_fol.commit(_static_tree_mesh)
	var trunk_mat = TextureHelper.create_material(TextureHelper.PATH_RES_WOOD_BARK, Color("5C3A21"), 0.9)
	var fol_mat = TextureHelper.create_material(TextureHelper.PATH_RES_FOLIAGE, Color("277748"), 0.8)
	_static_tree_mesh.surface_set_material(0, trunk_mat)
	_static_tree_mesh.surface_set_material(1, fol_mat)

	_static_tree_shape = CylinderShape3D.new()
	_static_tree_shape.radius = 0.6
	_static_tree_shape.height = 3.2

	# 2. Кам'яна брила (ArrayMesh: Поверхня 0 = Валун, Поверхня 1 = Бічний камінь)
	var b_mesh = BoxMesh.new()
	b_mesh.size = Vector3(1.4, 0.9, 1.2)
	var rot1 = Basis.from_euler(Vector3(deg_to_rad(5), deg_to_rad(25), deg_to_rad(-8)))
	var st_rock = SurfaceTool.new()
	st_rock.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_rock.append_from(b_mesh, 0, Transform3D(rot1, Vector3(0, 0.45, 0)))

	var s_mesh = BoxMesh.new()
	s_mesh.size = Vector3(0.8, 0.6, 0.7)
	var rot2 = Basis.from_euler(Vector3(deg_to_rad(-12), deg_to_rad(45), deg_to_rad(10)))
	var st_side = SurfaceTool.new()
	st_side.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_side.append_from(s_mesh, 0, Transform3D(rot2, Vector3(0.5, 0.3, 0.3)))

	_static_rock_mesh = ArrayMesh.new()
	st_rock.commit(_static_rock_mesh)
	st_side.commit(_static_rock_mesh)
	var rock_mat = TextureHelper.create_material(TextureHelper.PATH_RES_ROCK, Color("6C7A89"), 0.7)
	var side_mat = TextureHelper.create_material(TextureHelper.PATH_RES_ROCK_DARK, Color("4D5656"), 0.75)
	_static_rock_mesh.surface_set_material(0, rock_mat)
	_static_rock_mesh.surface_set_material(1, side_mat)

	_static_rock_shape = BoxShape3D.new()
	_static_rock_shape.size = Vector3(1.6, 1.0, 1.4)

	# 3. Кущ ягід (ArrayMesh: Поверхня 0 = Кущ, Поверхня 1 = Ягоди)
	var sphere = SphereMesh.new()
	sphere.radius = 0.65
	sphere.height = 0.8
	var st_bush = SurfaceTool.new()
	st_bush.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_bush.append_from(sphere, 0, Transform3D(Basis(), Vector3(0, 0.4, 0)))

	var b_sphere = SphereMesh.new()
	b_sphere.radius = 0.09
	b_sphere.height = 0.18
	var st_berries = SurfaceTool.new()
	st_berries.begin(Mesh.PRIMITIVE_TRIANGLES)
	var b_offsets = [
		Vector3(0.3, 0.65, 0.2),
		Vector3(-0.35, 0.55, 0.25),
		Vector3(0.1, 0.7, -0.3),
		Vector3(-0.25, 0.6, -0.2),
		Vector3(0.35, 0.5, -0.15)
	]
	for bo in b_offsets:
		st_berries.append_from(b_sphere, 0, Transform3D(Basis(), bo))

	_static_bush_mesh = ArrayMesh.new()
	st_bush.commit(_static_bush_mesh)
	st_berries.commit(_static_bush_mesh)
	var bush_mat = TextureHelper.create_material(TextureHelper.PATH_RES_BUSH, Color("27AE60"), 0.85)
	var berry_mat = TextureHelper.create_material(TextureHelper.PATH_RES_BUSH, Color("C0392B"), 0.3)
	_static_bush_mesh.surface_set_material(0, bush_mat)
	_static_bush_mesh.surface_set_material(1, berry_mat)

	_static_bush_shape = SphereShape3D.new()
	_static_bush_shape.radius = 0.7

	# 4. Глина (ArrayMesh: Шаруватий насип теракотової вологої глини)
	var clay_mat = TextureHelper.create_material(TextureHelper.PATH_RES_CLAY, Color("B85333"), 0.88)
	var st_clay = SurfaceTool.new()
	st_clay.begin(Mesh.PRIMITIVE_TRIANGLES)

	var base_cyl = CylinderMesh.new()
	base_cyl.top_radius = 0.8
	base_cyl.bottom_radius = 0.95
	base_cyl.height = 0.25
	st_clay.append_from(base_cyl, 0, Transform3D(Basis(), Vector3(0, 0.12, 0)))

	var sph = SphereMesh.new()
	sph.radius = 0.45
	sph.height = 0.35
	st_clay.append_from(sph, 0, Transform3D(Basis(), Vector3(0.05, 0.25, -0.05)))

	var lump = SphereMesh.new()
	lump.radius = 0.22
	lump.height = 0.2
	st_clay.append_from(lump, 0, Transform3D(Basis(), Vector3(-0.35, 0.1, 0.3)))

	_static_clay_mesh = ArrayMesh.new()
	st_clay.commit(_static_clay_mesh)
	_static_clay_mesh.surface_set_material(0, clay_mat)

	_static_clay_shape = CylinderShape3D.new()
	_static_clay_shape.radius = 0.7
	_static_clay_shape.height = 0.6

	# 5. Кремінь (ArrayMesh: Гострі кристалічні призми)
	var flint_mat = TextureHelper.create_material(TextureHelper.PATH_RES_FLINT, Color("2F3640"), 0.35)
	var st_flint = SurfaceTool.new()
	st_flint.begin(Mesh.PRIMITIVE_TRIANGLES)

	var p1 = PrismMesh.new()
	p1.size = Vector3(0.7, 0.8, 0.6)
	var r1 = Basis.from_euler(Vector3(deg_to_rad(15), deg_to_rad(30), deg_to_rad(-10)))
	st_flint.append_from(p1, 0, Transform3D(r1, Vector3(0, 0.4, 0)))

	var p2 = PrismMesh.new()
	p2.size = Vector3(0.45, 0.55, 0.4)
	var r2 = Basis.from_euler(Vector3(deg_to_rad(-20), deg_to_rad(60), deg_to_rad(25)))
	st_flint.append_from(p2, 0, Transform3D(r2, Vector3(0.35, 0.25, 0.2)))

	var p3 = BoxMesh.new()
	p3.size = Vector3(0.35, 0.25, 0.35)
	var r3 = Basis.from_euler(Vector3(deg_to_rad(35), deg_to_rad(-45), deg_to_rad(10)))
	st_flint.append_from(p3, 0, Transform3D(r3, Vector3(-0.3, 0.15, -0.2)))

	_static_flint_mesh = ArrayMesh.new()
	st_flint.commit(_static_flint_mesh)
	_static_flint_mesh.surface_set_material(0, flint_mat)

	_static_flint_shape = BoxShape3D.new()
	_static_flint_shape.size = Vector3(1.1, 0.8, 1.1)

	# 6. Дика трава (ArrayMesh: перехресні стебла трави для заготівлі сіна)
	var grass_mat = TextureHelper.create_material(TextureHelper.PATH_RES_GRASS, Color("4CAF50"), 0.8)
	var st_grass = SurfaceTool.new()
	st_grass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blade_angles = [0.0, 45.0, 90.0, 135.0]
	for deg in blade_angles:
		var bm = BoxMesh.new()
		bm.size = Vector3(0.55, 0.42, 0.03)
		var brot = Basis.from_euler(Vector3(0, deg_to_rad(deg), 0))
		st_grass.append_from(bm, 0, Transform3D(brot, Vector3(0, 0.21, 0)))

	_static_grass_mesh = ArrayMesh.new()
	st_grass.commit(_static_grass_mesh)
	_static_grass_mesh.surface_set_material(0, grass_mat)

	_static_grass_shape = BoxShape3D.new()
	_static_grass_shape.size = Vector3(0.7, 0.45, 0.7)

	# 7. Copper ore mesh
	var copper_rock = BoxMesh.new()
	copper_rock.size = Vector3(1.3, 0.85, 1.1)
	var rot_cr = Basis.from_euler(Vector3(deg_to_rad(8), deg_to_rad(30), deg_to_rad(-6)))
	var st_crock = SurfaceTool.new()
	st_crock.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_crock.append_from(copper_rock, 0, Transform3D(rot_cr, Vector3(0, 0.42, 0)))

	var c_nodule = BoxMesh.new()
	c_nodule.size = Vector3(0.5, 0.4, 0.5)
	var rot_cn = Basis.from_euler(Vector3(deg_to_rad(-15), deg_to_rad(50), deg_to_rad(12)))
	var st_copper = SurfaceTool.new()
	st_copper.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_copper.append_from(c_nodule, 0, Transform3D(rot_cn, Vector3(0.4, 0.35, 0.2)))

	var m_speckle = PrismMesh.new()
	m_speckle.size = Vector3(0.35, 0.4, 0.3)
	var rot_ms = Basis.from_euler(Vector3(deg_to_rad(25), deg_to_rad(-40), deg_to_rad(15)))
	var st_malachite = SurfaceTool.new()
	st_malachite.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_malachite.append_from(m_speckle, 0, Transform3D(rot_ms, Vector3(-0.35, 0.3, -0.2)))

	_static_copper_ore_mesh = ArrayMesh.new()
	st_crock.commit(_static_copper_ore_mesh)
	st_copper.commit(_static_copper_ore_mesh)
	st_malachite.commit(_static_copper_ore_mesh)

	var crock_mat = TextureHelper.create_material(TextureHelper.PATH_RES_ROCK, Color("5A4D41"), 0.75)
	var copper_mat = TextureHelper.create_material(TextureHelper.PATH_RES_ROCK, Color("B87333"), 0.4)
	var malachite_mat = TextureHelper.create_material(TextureHelper.PATH_RES_ROCK, Color("48A999"), 0.5)

	_static_copper_ore_mesh.surface_set_material(0, crock_mat)
	_static_copper_ore_mesh.surface_set_material(1, copper_mat)
	_static_copper_ore_mesh.surface_set_material(2, malachite_mat)

	_static_copper_ore_shape = BoxShape3D.new()
	_static_copper_ore_shape.size = Vector3(1.5, 0.95, 1.3)



# ------------------------------------------------------------------------------
# Видобуток (Harvest) та анімація удару
# ------------------------------------------------------------------------------
func harvest(damage: float = 1.0, tool_type: int = 0) -> void:
	if resource_type == ResourceType.GRASS:
		# Траву можна косити косою (ToolType.SCYTHE = 5) з подвійною ефективністю,
		# або збирати руками (ToolType.NONE = 0) з половинною швидкістю.
		if tool_type == 5:
			current_health -= damage * 2.0
		elif tool_type == 0:
			current_health -= damage * 0.5
		else:
			# Сокира, кирка тощо не підходять для м'якої трави
			_play_hit_effect()
			return

		_play_hit_effect()
		if current_health <= 0.0:
			_destroy_and_drop()
		return

	var effective_damage: float = damage
	if resource_type == ResourceType.TREE and tool_type == 1: # AXE
		effective_damage *= 2.0
	elif (resource_type == ResourceType.ROCK or resource_type == ResourceType.FLINT or resource_type == ResourceType.COPPER_ORE) and tool_type == 2: # PICKAXE
		effective_damage *= 2.0
	elif resource_type == ResourceType.CLAY and (tool_type == 2 or tool_type == 1):
		effective_damage *= 1.5

	current_health -= effective_damage
	_play_hit_effect()

	if current_health <= 0.0:
		_destroy_and_drop()


func _play_hit_effect() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()

	var punch_rot := Vector3(randf_range(-0.12, 0.12), randf_range(-0.08, 0.08), randf_range(-0.12, 0.12))
	_shake_tween = create_tween()
	_shake_tween.tween_property(visual_root, "scale", _original_scale * Vector3(1.22, 0.78, 1.22), 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_shake_tween.parallel().tween_property(visual_root, "rotation", punch_rot, 0.06)
	_shake_tween.tween_property(visual_root, "scale", _original_scale * Vector3(0.92, 1.12, 0.92), 0.07).set_trans(Tween.TRANS_QUAD)
	_shake_tween.parallel().tween_property(visual_root, "rotation", -punch_rot * 0.4, 0.07)
	_shake_tween.tween_property(visual_root, "scale", _original_scale, 0.08).set_trans(Tween.TRANS_QUAD)
	_shake_tween.parallel().tween_property(visual_root, "rotation", Vector3.ZERO, 0.08)

	_spawn_debris_particles()

	if AudioManager != null:
		var snd: StringName = &"hit_wood"
		match resource_type:
			ResourceType.TREE: snd = &"hit_wood"
			ResourceType.ROCK, ResourceType.FLINT, ResourceType.COPPER_ORE: snd = &"hit_stone"
			ResourceType.GRASS: snd = &"hit_grass"
			ResourceType.CLAY: snd = &"hit_clay"
			ResourceType.BUSH: snd = &"hit_grass"
		AudioManager.play_sound_3d(snd, global_position, 0.0, randf_range(0.92, 1.08))


func _spawn_debris_particles() -> void:
	var parts := CPUParticles3D.new()
	parts.name = "HitDebris"
	parts.emitting = true
	parts.one_shot = true
	parts.explosiveness = 0.95
	parts.amount = 14
	parts.lifetime = 0.55

	var p_mesh := BoxMesh.new()
	var p_mat := StandardMaterial3D.new()
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var emit_h: float = 0.8
	match resource_type:
		ResourceType.TREE:
			p_mesh.size = Vector3(0.08, 0.16, 0.04)
			p_mat.albedo_color = Color(0.72, 0.55, 0.32)
			emit_h = 1.2
		ResourceType.ROCK:
			p_mesh.size = Vector3(0.10, 0.10, 0.10)
			p_mat.albedo_color = Color(0.65, 0.68, 0.70)
			emit_h = 0.6
		ResourceType.FLINT:
			p_mesh.size = Vector3(0.07, 0.07, 0.07)
			p_mat.albedo_color = Color(0.28, 0.30, 0.32)
			emit_h = 0.5
		ResourceType.COPPER_ORE:
			p_mesh.size = Vector3(0.09, 0.09, 0.09)
			p_mat.albedo_color = Color("B87333")
			emit_h = 0.5
		ResourceType.CLAY:
			p_mesh.size = Vector3(0.12, 0.10, 0.12)
			p_mat.albedo_color = Color(0.78, 0.45, 0.28, 0.85)
			emit_h = 0.4
		ResourceType.BUSH, ResourceType.GRASS:
			p_mesh.size = Vector3(0.09, 0.04, 0.12)
			p_mat.albedo_color = Color(0.25, 0.72, 0.32)
			emit_h = 0.4

	p_mesh.material = p_mat
	parts.mesh = p_mesh
	parts.direction = Vector3(0, 1, 0)
	parts.spread = 75.0
	parts.initial_velocity_min = 2.0
	parts.initial_velocity_max = 4.2
	parts.gravity = Vector3(0, -9.8, 0)
	parts.scale_amount_min = 0.6
	parts.scale_amount_max = 1.3

	add_child(parts)
	parts.position = Vector3(0, emit_h, 0)

	var timer := get_tree().create_timer(0.9)
	timer.timeout.connect(func():
		if is_instance_valid(parts):
			parts.queue_free()
	)


func _destroy_and_drop() -> void:
	GridManager.unregister_occupant(get_cell(), true)

	var drop_count: int = randi_range(drop_min_amount, drop_max_amount)
	var spawn_pos: Vector3 = global_position + Vector3(0, 0.3, 0)
	if get_parent() != null and DroppedItem3DScene != null:
		var drop = DroppedItem3DScene.instantiate()
		get_parent().add_child(drop)
		drop.global_position = spawn_pos
		drop.set_item(drop_item_id, drop_count)

	var world_pos_2d := Vector2(global_position.x, global_position.z)
	EventBus.item_dropped.emit(drop_item_id, drop_count, spawn_pos)
	EventBus.resource_harvested.emit(self, drop_item_id, drop_count, global_position)

	queue_free()
