class_name DroppedItem3D
extends Area3D

## DroppedItem3D: 3D сутність підбирального предмета на карті.
## Плаває та обертається над землею, магнітиться до гравця у 3D просторі
## та автоматично поміщається в його InventoryComponent.

const TextureHelper = preload("res://src/core3d/TextureHelper.gd")

@export var item_id: StringName = &"wood"
@export var amount: int = 1
@export var magnet_radius: float = 3.5
@export var pickup_radius: float = 0.8
@export var magnet_speed: float = 8.0

var _base_y: float = 0.4
var _bob_time: float = 0.0
var _is_being_picked_up: bool = false
var _target_player: Node3D = null

@onready var visual_root: Node3D = $VisualRoot


func _ready() -> void:
	add_to_group("dropped_items")
	_base_y = global_position.y
	_setup_visual()


func set_item(new_item_id: StringName, new_amount: int) -> void:
	item_id = new_item_id
	amount = new_amount
	_setup_visual()


func _setup_visual() -> void:
	if not is_inside_tree() or visual_root == null:
		return

	# Очищаємо старі меші якщо були
	for child in visual_root.get_children():
		child.queue_free()

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	var tex_path: String = TextureHelper.get_item_texture_path(item_id)
	var fallback_color: Color = Color("F1C40F")

	match item_id:
		&"wood":
			var cyl: CylinderMesh = CylinderMesh.new()
			cyl.top_radius = 0.12
			cyl.bottom_radius = 0.12
			cyl.height = 0.45
			mesh_instance.mesh = cyl
			mesh_instance.rotation_degrees = Vector3(0, 0, 90)
			fallback_color = Color("8B5A2B")

		&"stone":
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = 0.18
			sphere.height = 0.28
			mesh_instance.mesh = sphere
			fallback_color = Color("7F8C8D")

		&"flint":
			var prism: PrismMesh = PrismMesh.new()
			prism.size = Vector3(0.22, 0.3, 0.18)
			mesh_instance.mesh = prism
			fallback_color = Color("2C3E50")

		&"clay":
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = 0.16
			sphere.height = 0.22
			mesh_instance.mesh = sphere
			fallback_color = Color("B35427")

		&"berries":
			var sphere: SphereMesh = SphereMesh.new()
			sphere.radius = 0.16
			sphere.height = 0.26
			mesh_instance.mesh = sphere
			fallback_color = Color("E74C3C")

		&"stone_axe":
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(0.2, 0.45, 0.1)
			mesh_instance.mesh = box
			fallback_color = Color("95A5A6")

		&"stone_pickaxe":
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(0.35, 0.35, 0.1)
			mesh_instance.mesh = box
			fallback_color = Color("BDC3C7")

		&"campfire":
			var cyl: CylinderMesh = CylinderMesh.new()
			cyl.top_radius = 0.25
			cyl.bottom_radius = 0.3
			cyl.height = 0.2
			mesh_instance.mesh = cyl
			fallback_color = Color("E67E22")

		&"scythe":
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(0.4, 0.45, 0.08)
			mesh_instance.mesh = box
			fallback_color = Color("BDC3C7")

		_:
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3(0.25, 0.25, 0.25)
			mesh_instance.mesh = box
			fallback_color = Color("F1C40F")

	var mat: StandardMaterial3D = TextureHelper.create_material(
		tex_path,
		fallback_color,
		0.6
	)
	mesh_instance.material_override = mat
	visual_root.add_child(mesh_instance)


func _physics_process(delta: float) -> void:
	# Анімація обертання та погойдування
	_bob_time += delta * 3.0
	if visual_root != null:
		visual_root.rotate_y(delta * 2.0)
		visual_root.position.y = sin(_bob_time) * 0.1

	if _target_player == null:
		_search_for_player()
	else:
		_process_magnet(delta)


func _search_for_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return

	var player: Node3D = players[0] as Node3D
	if player != null and global_position.distance_to(player.global_position) <= magnet_radius:
		_target_player = player


func _process_magnet(delta: float) -> void:
	if not is_instance_valid(_target_player):
		_target_player = null
		return

	var target_pos: Vector3 = _target_player.global_position + Vector3(0, 0.8, 0)
	var dist: float = global_position.distance_to(target_pos)

	if dist <= pickup_radius:
		_pickup()
		return

	# Магнітимося до гравця
	var dir: Vector3 = (target_pos - global_position).normalized()
	global_position += dir * magnet_speed * delta


func _pickup() -> void:
	if _is_being_picked_up:
		return
	_is_being_picked_up = true

	if _target_player != null and _target_player.has_node("InventoryComponent"):
		var inv = _target_player.get_node("InventoryComponent")
		if inv.has_method("add_item_by_id"):
			inv.add_item_by_id(item_id, amount)

	queue_free()
