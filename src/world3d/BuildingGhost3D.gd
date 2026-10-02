extends Node3D

const BlueprintVisualHelperScript = preload("res://src/world3d/BlueprintVisualHelper.gd")

## BuildingGhost3D: 3D візуалізація креслення-привида (Blueprint Preview) перед розміщенням.
## Слідує за координатами сітки під мишкою, масштабується під розмір будівлі,
## обертається на клавішу R/Shift+R та змінює колір на зелений (вільно) або червоний (зайнято/непрохідно).

@onready var footprint_mesh: MeshInstance3D = $FootprintMesh
@onready var info_label: Label3D = $InfoLabel

var _material: StandardMaterial3D = null
var _current_building: BuildingData = null
var _holo_instance: Node3D = null
var _facade_root: Node3D = null
var _arrow_mat: StandardMaterial3D = null


func _ready() -> void:
	visible = false
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.emission_enabled = true

	if footprint_mesh != null:
		footprint_mesh.material_override = _material
	if info_label != null:
		info_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED

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
	if _facade_root != null:
		_facade_root.queue_free()
		_facade_root = null


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

	# 3. Стрілка орієнтації фасаду та вхідної зони
	_update_facade_indicator(size_x, size_y)

	if info_label != null:
		var label_h: float = maxf(2.6, (size_y * 0.35) + 1.2)
		info_label.position = Vector3(0, label_h, 0)
		info_label.font_size = 28
		info_label.outline_size = 8


func _update_facade_indicator(size_x: float, size_y: float) -> void:
	if _facade_root != null:
		_facade_root.queue_free()
		_facade_root = null

	_facade_root = Node3D.new()
	_facade_root.name = "FacadeIndicator"
	add_child(_facade_root)

	if _arrow_mat == null:
		_arrow_mat = StandardMaterial3D.new()
		_arrow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_arrow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_arrow_mat.albedo_color = Color(1.0, 0.88, 0.22, 0.95)

	var half_d: float = size_y * 0.5

	# 1. Стрижень стрілки (прямує вперед по +Z від передньої кромки будівлі)
	var shaft_len: float = clampf(size_y * 0.22, 0.6, 1.4)
	var shaft_w: float = 0.2
	var shaft := MeshInstance3D.new()
	var shaft_mesh := BoxMesh.new()
	shaft_mesh.size = Vector3(shaft_w, 0.08, shaft_len)
	shaft.mesh = shaft_mesh
	shaft.material_override = _arrow_mat
	shaft.position = Vector3(0, 0.08, half_d + shaft_len * 0.5)
	_facade_root.add_child(shaft)

	# 2. Наконечник стрілки (вістря вперед по +Z)
	var tip_size: float = clampf(shaft_w * 3.2, 0.6, 1.0)
	var tip := MeshInstance3D.new()
	var tip_mesh := PrismMesh.new()
	tip_mesh.size = Vector3(tip_size, 0.08, tip_size * 0.8)
	tip.mesh = tip_mesh
	tip.material_override = _arrow_mat
	tip.rotation_degrees = Vector3(-90.0, 180.0, 0.0)
	tip.position = Vector3(0, 0.08, half_d + shaft_len + tip_size * 0.35)
	_facade_root.add_child(tip)

	# 3. Текстова мітка фасаду
	var facade_label := Label3D.new()
	facade_label.text = "▲ ВХІД / ФАСАД ▲"
	facade_label.font_size = 18
	facade_label.outline_size = 6
	facade_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	facade_label.modulate = Color(1.0, 0.9, 0.25)
	facade_label.position = Vector3(0, 0.45, half_d + shaft_len + tip_size * 0.7)
	_facade_root.add_child(facade_label)


func _apply_visual_status(is_valid: bool) -> void:
	if _material == null or _current_building == null:
		return

	var bld_name: String = _current_building.display_name
	var eff_size: Vector2i = BuildingPlacementController.get_effective_size(_current_building)
	var sx: int = eff_size.x
	var sy: int = eff_size.y
	var rot_deg_int: int = int(round(rotation_degrees.y)) % 360
	var rot_str: String = " • %d°" % rot_deg_int if rot_deg_int != 0 else ""

	if is_valid:
		# Напівпрозорий смарагдово-зелений
		_material.albedo_color = Color(0.2, 0.9, 0.3, 0.45)
		_material.emission = Color(0.1, 0.55, 0.2)
		if _arrow_mat != null:
			_arrow_mat.albedo_color = Color(1.0, 0.88, 0.22, 0.95)
		if info_label != null:
			info_label.text = "%s (%dx%d%s)
[ВІЛЬНО ДЛЯ БУДІВНИЦТВА]
[ЛКМ] Встановити  [R/Shift+R] Обертання  [Shift] Серія  [ПКМ/Esc] Скасувати" % [bld_name, sx, sy, rot_str]
			info_label.modulate = Color(0.4, 1.0, 0.4)
	else:
		# Напівпрозорий яскраво-червоний
		_material.albedo_color = Color(0.95, 0.2, 0.2, 0.45)
		_material.emission = Color(0.65, 0.1, 0.1)
		if _arrow_mat != null:
			_arrow_mat.albedo_color = Color(1.0, 0.35, 0.35, 0.95)
		if info_label != null:
			info_label.text = "%s (%dx%d%s)
[ПЕРЕШКОДА АБО ЗАЙНЯТО]
[R/Shift+R] Обертання  [ПКМ/Esc] Скасувати" % [bld_name, sx, sy, rot_str]
			info_label.modulate = Color(1.0, 0.4, 0.4)
