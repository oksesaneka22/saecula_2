class_name BlockGhost3D
extends Node3D

## BlockGhost3D: Напівпрозорий попередній перегляд розміщення воксельного блоку (Minecraft-style).
## Відображає 1x1x1м куб у світі: смарагдово-зелений при валідній позиції, червоний — якщо перешкода.

var mesh_instance: MeshInstance3D = null
var ghost_mat: StandardMaterial3D = null


func _ready() -> void:
	mesh_instance = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.02, 1.02, 1.02) # Легке розширення для чіткої видимості граней
	mesh_instance.mesh = box

	ghost_mat = StandardMaterial3D.new()
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_mat.albedo_color = Color(0.2, 0.95, 0.4, 0.45)

	mesh_instance.material_override = ghost_mat
	add_child(mesh_instance)
	visible = false


func show_at(coord: Vector3i, can_place: bool) -> void:
	global_position = Vector3(float(coord.x) + 0.5, float(coord.y) + 0.5, float(coord.z) + 0.5)
	if ghost_mat != null:
		if can_place:
			ghost_mat.albedo_color = Color(0.2, 0.95, 0.4, 0.45)
		else:
			ghost_mat.albedo_color = Color(0.95, 0.2, 0.2, 0.45)
	visible = true


func hide_ghost() -> void:
	visible = false
