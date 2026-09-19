extends Node3D

const BlueprintVisualHelperScript = preload("res://src/world3d/BlueprintVisualHelper.gd")

## BuildingGhost3D: 3D візуалізація креслення-привида (Blueprint Preview) перед розміщенням.
## Слідує за координатами сітки під мишкою, масштабується під розмір будівлі,
## обертається на клавішу R та змінює колір на зелений (вільно) або червоний (зайнято/непрохідно).

@onready var footprint_mesh: MeshInstance3D = $FootprintMesh
@onready var info_label: Label3D = $InfoLabel

var _material: StandardMaterial3D = null
var _current_building: BuildingData = null
var _holo_instance: Node3D = null


func _ready() -> void:
	visible = false
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.emission_enabled = true

	if footprint_mesh != null:
		footprint_mesh.material_override = _material

	BuildingPlacementController.placement_started.connect(_on_placement_started)
	BuildingPlacementController.placement_canceled.connect(_on_placement_canceled)
	BuildingPlacementController.placement_hover_updated.connect(_on_placement_hover_updated)
	BuildingPlacementController.placement_rotation_changed.connect(_on_placement_rotation_changed)


func _on_placement_started(building: BuildingData) -> void:
	_current_building = building
	rotation_degrees.y = 0.0
	visible = true
	_update_ghost_mesh_size()


func _on_placement_canceled() -> void:
	_current_building = null
	rotation_degrees.y = 0.0
	visible = false
	if _holo_instance != null:
		_holo_instance.queue_free()
		_holo_instance = null


func _on_placement_rotation_changed(_rot_index: int, rot_degrees: float) -> void:
	rotation_degrees.y = rot_degrees
	_update_ghost_mesh_size()
	if _current_building != null and BuildingPlacementController._current_cell != Vector2i(-9999, -9999):
		_on_placement_hover_updated(BuildingPlacementController._current_cell, BuildingPlacementController._is_valid)


func _on_placement_hover_updated(cell: Vector2i, is_valid: bool) -> void:
	if _current_building == null:
		return

	# Розраховуємо центр споруди у 3D світі з урахуванням обертання
	var eff_size: Vector2i = BuildingPlacementController.get_effective_size(_current_building)
	var size_x: float = float(eff_size.x)
	var size_y: float = float(eff_size.y)
	var tile_size: float = GridManager.TILE_SIZE_3D

	var center_x: float = (float(cell.x) + size_x * 0.5) * tile_size
	var center_z: float = (float(cell.y) + size_y * 0.5) * tile_size

	global_position = Vector3(center_x, 0.05, center_z)

	_apply_visual_status(is_valid)


func _update_ghost_mesh_size() -> void:
	if _current_building == null or footprint_mesh == null:
		return

	var size_x: float = float(maxi(_current_building.size_in_tiles.x, 1)) * GridManager.TILE_SIZE_3D
	var size_y: float = float(maxi(_current_building.size_in_tiles.y, 1)) * GridManager.TILE_SIZE_3D

	# 1. Плоска рамка відбитку на землі
	var box_height: float = 0.12
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(size_x - 0.1, box_height, size_y - 0.1)
	footprint_mesh.mesh = box
	footprint_mesh.position = Vector3(0, box_height * 0.5, 0)

	# 2. Голографічний каркас будівлі
	if _holo_instance != null:
		_holo_instance.queue_free()
		_holo_instance = null
	_holo_instance = BlueprintVisualHelperScript.build_blueprint_hologram(_current_building.id, Vector2(size_x, size_y), _material)
	add_child(_holo_instance)

	if info_label != null:
		var label_h: float = maxf(2.6, (size_y * 0.35) + 1.2)
		info_label.position = Vector3(0, label_h, 0)
		info_label.font_size = 28
		info_label.outline_size = 8


func _apply_visual_status(is_valid: bool) -> void:
	if _material == null or _current_building == null:
		return

	var bld_name: String = _current_building.display_name
	var eff_size: Vector2i = BuildingPlacementController.get_effective_size(_current_building)
	var sx: int = eff_size.x
	var sy: int = eff_size.y

	if is_valid:
		# Напівпрозорий смарагдово-зелений
		_material.albedo_color = Color(0.2, 0.9, 0.3, 0.45)
		_material.emission = Color(0.1, 0.55, 0.2)
		if info_label != null:
			info_label.text = "%s (%dx%d)\n[ВІЛЬНО ДЛЯ БУДІВНИЦТВА]\n[ЛКМ] Встановити  [R] Обертати  [Shift] Серія  [ПКМ/Esc] Скасувати" % [bld_name, sx, sy]
			info_label.modulate = Color(0.4, 1.0, 0.4)
	else:
		# Напівпрозорий яскраво-червоний
		_material.albedo_color = Color(0.95, 0.2, 0.2, 0.45)
		_material.emission = Color(0.65, 0.1, 0.1)
		if info_label != null:
			info_label.text = "%s (%dx%d)\n[ПЕРЕШКОДА АБО ЗАЙНЯТО]\n[R] Обертати  [ПКМ/Esc] Скасувати" % [bld_name, sx, sy]
			info_label.modulate = Color(1.0, 0.4, 0.4)
