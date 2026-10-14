class_name ColonistRestState3D
extends "res://src/entities3d/colonist/states/ColonistState3D.gd"

## ColonistRestState3D: Стан нічного відпочинку та сну колоніста біля табірного вогнища.
## Колоніст сідає на землю, гріється біля вогню, періодично випускає 'zzz',
## плавно повертається обличчям до вогнища та прокидається на світанку.

var target_campfire: Node3D = null
var _breath_timer: float = 0.0
var _zzz_timer: float = 2.0


func enter(msg: Dictionary = {}) -> void:
	target_campfire = null
	var raw_cf: Variant = msg.get("campfire", null)
	if raw_cf != null and is_instance_valid(raw_cf) and not (raw_cf is Node and raw_cf.is_queued_for_deletion()) and raw_cf is Node3D:
		target_campfire = raw_cf as Node3D
	elif target_campfire == null and get_tree() != null:
		var campfires = get_tree().get_nodes_in_group("campfires")
		for cf in campfires:
			if is_instance_valid(cf) and not cf.is_queued_for_deletion() and cf is Node3D:
				target_campfire = cf as Node3D
				break

	var is_indoors: bool = false
	if ModularManager != null and actor != null and GridManager != null:
		var cell: Vector2i = GridManager.world_to_map_3d(actor.global_position)
		is_indoors = ModularManager.is_cell_indoors(cell)

	if actor != null:
		actor.velocity = Vector3.ZERO
		actor.hide_hand_items()
		var status_str := "🏠 У затишному приміщенні" if is_indoors else ("💤 Спить біля вогнища" if target_campfire != null else "💤 Відпочиває")
		actor.set_status_display(status_str)
		_apply_sit_pose()

	_breath_timer = 0.0
	_zzz_timer = 1.5


func exit() -> void:
	if actor != null:
		_reset_sit_pose()
		actor.set_status_display("☕ Вільний")


func physics_update(delta: float) -> void:
	if actor == null:
		return

	# Гравітація при сидінні
	apply_gravity(delta, true)

	var is_in_room: bool = false
	if ModularManager != null and actor != null and GridManager != null:
		var cell: Vector2i = GridManager.world_to_map_3d(actor.global_position)
		is_in_room = ModularManager.is_cell_indoors(cell)
	var heal_amt: float = 4.0 if is_in_room else 1.5
	actor.heal(heal_amt * delta)

	# Відновлення енергії: у закритому приміщенні удвічі швидше (8.0 vs 4.0)
	var energy_rate: float = 8.0 if is_in_room else 4.0
	if "current_energy" in actor and "max_energy" in actor:
		actor.current_energy = minf(actor.max_energy, actor.current_energy + energy_rate * delta)

	# Якщо гравець дав наказ слідувати або розбудив — виходимо
	if actor.is_following_player:
		state_machine.transition_to(&"idle")
		return

	# Перевірка наступу ранку (сон завершується після 06:00)
	if GameManager != null and not GameManager.is_night():
		state_machine.transition_to(&"idle")
		return

	# Плавний поворот обличчям до вогнища
	if target_campfire != null and is_instance_valid(target_campfire):
		face_target(target_campfire.global_position, delta, 5.0)

	# Легка анімація дихання уві сні
	_breath_timer += delta * 2.5
	if actor.torso_mesh != null:
		actor.torso_mesh.position.y = 0.88 + sin(_breath_timer) * 0.015

	# Періодичне спливання 'zzz'
	_zzz_timer -= delta
	if _zzz_timer <= 0.0:
		_zzz_timer = randf_range(3.5, 6.0)
		if FloatingTextManager != null:
			FloatingTextManager.spawn_text(actor.global_position + Vector3(0, 1.8, 0), "💤", Color("BDC3C7"), 1.3, 0.6)


func _apply_sit_pose() -> void:
	if actor.visual_root != null:
		actor.visual_root.position.y = -0.28

	if actor.left_leg_pivot != null:
		actor.left_leg_pivot.rotation.x = deg_to_rad(-80)
	if actor.right_leg_pivot != null:
		actor.right_leg_pivot.rotation.x = deg_to_rad(-80)

	if actor.left_arm_pivot != null:
		actor.left_arm_pivot.rotation.x = deg_to_rad(-40)
	if actor.right_arm_pivot != null:
		actor.right_arm_pivot.rotation.x = deg_to_rad(-40)

	if actor.head_mesh != null:
		actor.head_mesh.rotation.x = deg_to_rad(12)


func _reset_sit_pose() -> void:
	if actor.visual_root != null:
		actor.visual_root.position.y = 0.0

	if actor.left_leg_pivot != null:
		actor.left_leg_pivot.rotation.x = 0.0
	if actor.right_leg_pivot != null:
		actor.right_leg_pivot.rotation.x = 0.0

	if actor.left_arm_pivot != null:
		actor.left_arm_pivot.rotation.x = 0.0
	if actor.right_arm_pivot != null:
		actor.right_arm_pivot.rotation.x = 0.0

	if actor.head_mesh != null:
		actor.head_mesh.rotation.x = 0.0

	if actor.torso_mesh != null:
		actor.torso_mesh.position.y = 0.88
