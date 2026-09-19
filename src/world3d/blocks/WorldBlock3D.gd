class_name WorldBlock3D
extends StaticBody3D

## WorldBlock3D: 3D воксельний блок у стилі Minecraft (1x1x1м).
## Підтримує дерево (wood) та камінь (stone), має тверду колізію, текстуру, запас міцності
## та реагує на удари/видобуток з відповідними бонусами інструментів (сокира для дерева, кирка для каменю).

signal destroyed(coord: Vector3i)

const TextureHelper = preload("res://src/core3d/TextureHelper.gd")
const DroppedItem3DScene = preload("res://src/entities3d/items/DroppedItem3D.tscn")

@export var block_type: StringName = &"wood"
@export var grid_coord: Vector3i = Vector3i.ZERO
@export var max_health: float = 2.0
@export var current_health: float = 2.0
@export var drop_item_id: StringName = &"wood"
@export var drop_amount: int = 1

var mesh_instance: MeshInstance3D = null
var collision_shape: CollisionShape3D = null
var _shake_tween: Tween = null


func _ready() -> void:
	add_to_group(&"blocks")
	add_to_group(&"interactable")
	add_to_group(&"resource_nodes")

	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3.ONE
		collision_shape.shape = box_shape
		add_child(collision_shape)

	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MeshInstance3D"
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3.ONE
		mesh_instance.mesh = box_mesh
		add_child(mesh_instance)

	_apply_visual()


func setup_block(type: StringName, coord: Vector3i) -> void:
	block_type = type
	grid_coord = coord
	position = Vector3(float(coord.x) + 0.5, float(coord.y) + 0.5, float(coord.z) + 0.5)

	if block_type == &"wood":
		max_health = 2.0
		drop_item_id = &"wood"
	elif block_type == &"stone":
		max_health = 3.5
		drop_item_id = &"stone"
	else:
		max_health = 2.0
		drop_item_id = type

	current_health = max_health
	if is_inside_tree():
		_apply_visual()


func _apply_visual() -> void:
	if mesh_instance == null:
		return

	var mat: StandardMaterial3D = null
	if block_type == &"wood":
		mat = TextureHelper.create_material(
			TextureHelper.PATH_BLOCK_WOOD,
			Color(0.72, 0.52, 0.32),
			0.85
		)
	elif block_type == &"stone":
		mat = TextureHelper.create_material(
			TextureHelper.PATH_BLOCK_STONE,
			Color(0.65, 0.65, 0.68),
			0.9
		)
	else:
		mat = TextureHelper.create_material(
			TextureHelper.PATH_BLD_GENERIC,
			Color(0.55, 0.55, 0.55),
			0.8
		)

	mesh_instance.material_override = mat


## Видобуток або руйнування блоку гравцем/колоністом
func harvest(damage: float, tool_type: int = 0) -> void:
	var effective_damage: float = damage

	# Бонуси інструментів (сокира для дерева, кирка для каменю)
	# ToolType: 1 = AXE, 2 = PICKAXE
	if block_type == &"wood" and tool_type == 1:
		effective_damage *= 2.5
	elif block_type == &"stone" and tool_type == 2:
		effective_damage *= 2.5

	current_health -= effective_damage

	# Візуальний ефект удару (струшування)
	if mesh_instance != null:
		if _shake_tween != null and _shake_tween.is_valid():
			_shake_tween.kill()
		_shake_tween = create_tween()
		_shake_tween.tween_property(mesh_instance, "scale", Vector3(1.08, 0.92, 1.08), 0.04)
		_shake_tween.tween_property(mesh_instance, "scale", Vector3.ONE, 0.08)

	if current_health <= 0.0:
		destroy_block()


## Повне руйнування блоку з випаданням предмета
func destroy_block() -> void:
	if drop_item_id != &"":
		var parent_node = get_parent()
		if parent_node != null and DroppedItem3DScene != null:
			var drop = DroppedItem3DScene.instantiate()
			drop.set_item(drop_item_id, drop_amount)
			drop.position = global_position
			parent_node.add_child(drop)

	destroyed.emit(grid_coord)
	EventBus.block_destroyed.emit(block_type, grid_coord)
	queue_free()
