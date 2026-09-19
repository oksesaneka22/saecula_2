class_name WorldResourceNode3D
extends StaticBody3D

## WorldResourceNode3D: 3D природний ресурс на карті (Дерево, Валун, Кущ ягід).
## Блокує тайл у GridManager у площині X-Z, має запас міцності (health),
## реагує на удари/видобуток (harvest), має 3D анімацію тремтіння
## та спавнить DroppedItem3D після знищення.

enum ResourceType {
	TREE,       ## Дерево -> спавнить wood
	ROCK,       ## Кам'яна брила -> спавнить stone
	BUSH,       ## Кущ диких ягід -> спавнить berries
	CLAY,       ## Родовище глини -> спавнить clay (біля водойм)
	FLINT       ## Поклади кремнію -> спавнить flint (біля водойм)
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

	# Прив'язка до центру 3D клітинки сітки (X-Z)
	_cell = GridManager.world_to_map_3d(global_position)
	var snapped_pos: Vector3 = GridManager.map_to_world_3d(_cell, 0.0)
	global_position.x = snapped_pos.x
	global_position.z = snapped_pos.z

	GridManager.register_occupant(_cell, self, true)
	_setup_visual()


func _setup_visual() -> void:
	if visual_root == null:
		return

	for child in visual_root.get_children():
		child.queue_free()

	match resource_type:
		ResourceType.TREE:
			_build_tree_mesh()
		ResourceType.ROCK:
			_build_rock_mesh()
		ResourceType.BUSH:
			_build_bush_mesh()
		ResourceType.CLAY:
			_build_clay_mesh()
		ResourceType.FLINT:
			_build_flint_mesh()


func _build_tree_mesh() -> void:
	# 1. Стовбур
	var trunk: MeshInstance3D = MeshInstance3D.new()
	var trunk_mesh: CylinderMesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.22
	trunk_mesh.bottom_radius = 0.32
	trunk_mesh.height = 1.8
	trunk.mesh = trunk_mesh
	trunk.position.y = 0.9

	var trunk_mat: StandardMaterial3D = TextureHelper.create_material(
		TextureHelper.PATH_RES_WOOD_BARK,
		Color("5C3A21"),
		0.9
	)
	trunk.material_override = trunk_mat
	visual_root.add_child(trunk)

	# 2. Крона (3 конуси різного відтінку для глибини)
	var foliage_data: Array = [
		{"y": 2.0, "radius": 1.25, "height": 1.5, "color": Color("1E5936")},
		{"y": 2.8, "radius": 1.0, "height": 1.3, "color": Color("277748")},
		{"y": 3.5, "radius": 0.7, "height": 1.1, "color": Color("35975D")}
	]

	var fol_mat: StandardMaterial3D = TextureHelper.create_material(
		TextureHelper.PATH_RES_FOLIAGE,
		Color("277748"),
		0.8
	)

	for layer in foliage_data:
		var fol: MeshInstance3D = MeshInstance3D.new()
		var cone: CylinderMesh = CylinderMesh.new()
		cone.top_radius = 0.02
		cone.bottom_radius = layer["radius"]
		cone.height = layer["height"]
		fol.mesh = cone
		fol.position.y = layer["y"]
		fol.material_override = fol_mat
		visual_root.add_child(fol)

	if collision_shape != null:
		var cyl_shape: CylinderShape3D = CylinderShape3D.new()
		cyl_shape.radius = 0.6
		cyl_shape.height = 3.2
		collision_shape.shape = cyl_shape
		collision_shape.position.y = 1.6


func _build_rock_mesh() -> void:
	var boulder: MeshInstance3D = MeshInstance3D.new()
	var b_mesh: BoxMesh = BoxMesh.new()
	b_mesh.size = Vector3(1.4, 0.9, 1.2)
	boulder.mesh = b_mesh
	boulder.position.y = 0.45
	boulder.rotation_degrees = Vector3(5, 25, -8)

	var rock_mat: StandardMaterial3D = TextureHelper.create_material(
		TextureHelper.PATH_RES_ROCK,
		Color("6C7A89"),
		0.7
	)
	boulder.material_override = rock_mat
	visual_root.add_child(boulder)

	var side_rock: MeshInstance3D = MeshInstance3D.new()
	var s_mesh: BoxMesh = BoxMesh.new()
	s_mesh.size = Vector3(0.8, 0.6, 0.7)
	side_rock.mesh = s_mesh
	side_rock.position = Vector3(0.5, 0.3, 0.3)
	side_rock.rotation_degrees = Vector3(-12, 45, 10)

	var side_mat: StandardMaterial3D = TextureHelper.create_material(
		TextureHelper.PATH_RES_ROCK_DARK,
		Color("4D5656"),
		0.75
	)
	side_rock.material_override = side_mat
	visual_root.add_child(side_rock)

	if collision_shape != null:
		var box_shape: BoxShape3D = BoxShape3D.new()
		box_shape.size = Vector3(1.6, 1.0, 1.4)
		collision_shape.shape = box_shape
		collision_shape.position.y = 0.5


func _build_bush_mesh() -> void:
	var bush: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.65
	sphere.height = 0.8
	bush.mesh = sphere
	bush.position.y = 0.4

	var bush_mat: StandardMaterial3D = TextureHelper.create_material(
		TextureHelper.PATH_RES_BUSH,
		Color("27AE60"),
		0.85
	)
	bush.material_override = bush_mat
	visual_root.add_child(bush)

	var berry_offsets: Array[Vector3] = [
		Vector3(0.3, 0.65, 0.2),
		Vector3(-0.35, 0.55, 0.25),
		Vector3(0.1, 0.7, -0.3),
		Vector3(-0.25, 0.6, -0.2),
		Vector3(0.4, 0.45, -0.15)
	]

	var berry_mat: StandardMaterial3D = TextureHelper.create_material(
		TextureHelper.PATH_RES_BERRIES,
		Color("E74C3C"),
		0.3
	)

	for offset in berry_offsets:
		var berry: MeshInstance3D = MeshInstance3D.new()
		var b_mesh: SphereMesh = SphereMesh.new()
		b_mesh.radius = 0.07
		b_mesh.height = 0.14
		berry.mesh = b_mesh
		berry.position = offset
		berry.material_override = berry_mat
		visual_root.add_child(berry)

	if collision_shape != null:
		var cyl_shape: CylinderShape3D = CylinderShape3D.new()
		cyl_shape.radius = 0.65
		cyl_shape.height = 0.9
		collision_shape.shape = cyl_shape
		collision_shape.position.y = 0.45




func _build_clay_mesh() -> void:
	var clay_mat: StandardMaterial3D = TextureHelper.create_material(
		TextureHelper.PATH_RES_CLAY,
		Color("B35427"),
		0.85
	)

	# Основа насипу глини
	var base_mound := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.7
	cyl.height = 0.25
	base_mound.mesh = cyl
	base_mound.position.y = 0.125
	base_mound.material_override = clay_mat
	visual_root.add_child(base_mound)

	# Верхній пласт глини
	var top_mound := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.45
	sph.height = 0.35
	top_mound.mesh = sph
	top_mound.position = Vector3(0.05, 0.25, -0.05)
	top_mound.material_override = clay_mat
	visual_root.add_child(top_mound)

	# Додатковий грудочок глини поруч
	var lump := MeshInstance3D.new()
	var lump_sph := SphereMesh.new()
	lump_sph.radius = 0.22
	lump_sph.height = 0.2
	lump.mesh = lump_sph
	lump.position = Vector3(-0.35, 0.1, 0.3)
	lump.material_override = clay_mat
	visual_root.add_child(lump)

	if collision_shape != null:
		var cyl_shape: CylinderShape3D = CylinderShape3D.new()
		cyl_shape.radius = 0.7
		cyl_shape.height = 0.6
		collision_shape.shape = cyl_shape
		collision_shape.position.y = 0.3


func _build_flint_mesh() -> void:
	var flint_mat: StandardMaterial3D = TextureHelper.create_material(
		TextureHelper.PATH_RES_FLINT,
		Color("2F3640"),
		0.35
	)

	# Центральний кристал / гострий камінь кремнію
	var main_prism := MeshInstance3D.new()
	var prism_mesh := PrismMesh.new()
	prism_mesh.size = Vector3(0.7, 0.8, 0.6)
	main_prism.mesh = prism_mesh
	main_prism.position.y = 0.4
	main_prism.rotation_degrees = Vector3(15, 30, -10)
	main_prism.material_override = flint_mat
	visual_root.add_child(main_prism)

	# Бічний відкол кремнію
	var side_prism := MeshInstance3D.new()
	var side_mesh := PrismMesh.new()
	side_mesh.size = Vector3(0.45, 0.55, 0.4)
	side_prism.mesh = side_mesh
	side_prism.position = Vector3(0.35, 0.25, 0.2)
	side_prism.rotation_degrees = Vector3(-20, 60, 25)
	side_prism.material_override = flint_mat
	visual_root.add_child(side_prism)

	# Менший осколок
	var small_prism := MeshInstance3D.new()
	var small_mesh := BoxMesh.new()
	small_mesh.size = Vector3(0.35, 0.25, 0.35)
	small_prism.mesh = small_mesh
	small_prism.position = Vector3(-0.3, 0.15, -0.2)
	small_prism.rotation_degrees = Vector3(35, -45, 10)
	small_prism.material_override = flint_mat
	visual_root.add_child(small_prism)

	if collision_shape != null:
		var box_shape: BoxShape3D = BoxShape3D.new()
		box_shape.size = Vector3(1.1, 0.8, 1.1)
		collision_shape.shape = box_shape
		collision_shape.position.y = 0.4


func harvest(damage: float = 1.0, tool_type: int = 0) -> void:
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
