class_name ColonistRestState3D
extends "res://src/entities/fsm/State.gd"

## ColonistRestState3D: Стан нічного відпочинку та сну колоніста біля табірного вогнища.
## Колоніст сідає на землю, гріється біля вогню, періодично випускає 'zzz',
## плавно повертається обличчям до вогнища та прокидається на світанку.

var target_campfire: Node3D = null
var _breath_timer: float = 0.0
var _zzz_timer: float = 2.0


func enter(msg: Dictionary = {}) -> void:
	target_campfire = msg.get("campfire", null) as Node3D
	if target_campfire == null:
		var campfires = get_tree().get_nodes_in_group("campfires")
		if not campfires.is_empty() and campfires[0] is Node3D:
			target_campfire = campfires[0] as Node3D

	if actor != null:
		actor.velocity = Vector3.ZERO
		actor.hide_hand_items()
		var status_str := "💤 Спить біля вогнища" if target_campfire != null else "💤 Відпочиває"
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
	if not actor.is_on_floor():
		actor.velocity.y -= 19.6 * delta
		actor.move_and_slide()

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
		var dir: Vector3 = target_campfire.global_position - actor.global_position
		dir.y = 0.0
		if dir.length_squared() > 0.01:
			var target_angle := atan2(dir.x, dir.z)
			actor.rotation.y = lerp_angle(actor.rotation.y, target_angle, 5.0 * delta)

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
