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
	GRASS       ## Дика трава кучками -> спавнить straw (потрібна коса)
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


func _ready() -> void:
	add_to_group("resource_nodes")
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


# ------------------------------------------------------------------------------
# Видобуток (Harvest) та анімація удару
# ------------------------------------------------------------------------------
func harvest(damage: float = 1.0, tool_type: int = 0) -> void:
	if resource_type == ResourceType.GRASS:
		# Траву можна косити ТІЛЬКИ косою (ToolType.SCYTHE = 5)
		if tool_type != 5:
			_play_hit_effect()
			return
		current_health -= damage * 2.0
		_play_hit_effect()
		if current_health <= 0.0:
			_destroy_and_drop()
		return

	var effective_damage: float = damage
	if resource_type == ResourceType.TREE and tool_type == 1: # AXE
		effective_damage *= 2.0
	elif (resource_type == ResourceType.ROCK or resource_type == ResourceType.FLINT) and tool_type == 2: # PICKAXE
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

	_shake_tween = create_tween()
	_shake_tween.tween_property(visual_root, "scale", _original_scale * Vector3(1.1, 0.9, 1.1), 0.05)
	_shake_tween.tween_property(visual_root, "scale", _original_scale * Vector3(0.95, 1.05, 0.95), 0.05)
	_shake_tween.tween_property(visual_root, "scale", _original_scale, 0.06)


func _destroy_and_drop() -> void:
	GridManager.unregister_occupant(get_cell(), true)

	var drop_count: int = randi_range(drop_min_amount, drop_max_amount)
	if get_parent() != null and DroppedItem3DScene != null:
		var drop = DroppedItem3DScene.instantiate()
		drop.position = position + Vector3(0, 0.3, 0)
		drop.set_item(drop_item_id, drop_count)
		get_parent().add_child(drop)

	EventBus.item_dropped.emit(drop_item_id, drop_count, Vector2(position.x, position.z))
	EventBus.resource_harvested.emit(self, drop_item_id, drop_count, Vector2(position.x, position.z))

	queue_free()
