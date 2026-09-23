class_name PlacedTorch3D
extends StaticBody3D

## PlacedTorch3D: Встановлений у світі смолоскип.
## Освітлює темну ніч навколо яскравим вогняним сяйвом (OmniLight3D з мерехтінням).
## Може бути зібраний гравцем назад до інвентаря на [E].

const TextureHelper = preload("res://src/core3d/TextureHelper.gd")

var _light: OmniLight3D = null
var _flame_mesh: MeshInstance3D = null
var _flicker_time: float = 0.0
var _base_energy: float = 2.8
var _base_range: float = 14.0


func _ready() -> void:
	add_to_group("placed_torches")
	add_to_group("interactable")
	_setup_visuals_and_light()


func _setup_visuals_and_light() -> void:
	# 1. Колізія для взаємодії (райкаст гравця)
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.height = 0.9
	cyl.radius = 0.15
	col.shape = cyl
	col.position.y = 0.45
	add_child(col)

	# 2. Дерев'яний стрижень смолоскипа
	var stick := MeshInstance3D.new()
	var stick_mesh := CylinderMesh.new()
	stick_mesh.top_radius = 0.04
	stick_mesh.bottom_radius = 0.03
	stick_mesh.height = 0.8
	stick.mesh = stick_mesh
	stick.position.y = 0.4
	stick.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var stick_mat := StandardMaterial3D.new()
	stick_mat.albedo_color = Color(0.4, 0.25, 0.12)
	stick_mat.roughness = 0.9
	stick.material_override = stick_mat
	add_child(stick)

	# 3. Вогняний набалдашник / полум'я (самосвітне, не блокує світло)
	_flame_mesh = MeshInstance3D.new()
	var flame_sphere := SphereMesh.new()
	flame_sphere.radius = 0.09
	flame_sphere.height = 0.18
	_flame_mesh.mesh = flame_sphere
	_flame_mesh.position.y = 0.85
	_flame_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.75, 0.25)
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.6, 0.15)
	flame_mat.emission_energy_multiplier = 4.0
	_flame_mesh.material_override = flame_mat
	add_child(_flame_mesh)

	# 4. Джерело освітлення OmniLight3D (висока продуктивність, без важких тіней для десятків смолоскипів)
	_light = OmniLight3D.new()
	_light.name = "TorchLight"
	_light.position.y = 1.05
	_light.light_color = Color(1.0, 0.72, 0.28)
	_light.light_energy = _base_energy
	_light.omni_range = _base_range
	_light.omni_attenuation = 1.0
	_light.shadow_enabled = false
	add_child(_light)


func _process(delta: float) -> void:
	_flicker_time += delta * 10.0
	if _light != null:
		# Органічне мерехтіння вогню смолоскипа
		var flicker := sin(_flicker_time * 1.7) * 0.18 + cos(_flicker_time * 3.1) * 0.12
		_light.light_energy = _base_energy + flicker
		_light.omni_range = _base_range + flicker * 1.5


## Взаємодія з гравцем на [E] — повертає смолоскип в інвентар
func interact(player: Node = null) -> void:
	if player != null and "inventory" in player and player.inventory != null:
		var item = ItemDatabase.get_item(&"torch")
		if item != null:
			player.inventory.add_item(item, 1)
			print("[PlacedTorch3D] 🕯️ Смолоскип піднято гравцем назад в інвентар.")
	queue_free()


## Harvest інтерфейс (якщо гравець вдарить по ньому інструментом або рукою)
func harvest(damage: int, _tool_type: int = 0) -> Array:
	var item = ItemDatabase.get_item(&"torch")
	var dropped: Array = []
	if item != null:
		dropped.append({"item": item, "count": 1})
	queue_free()
	return dropped
