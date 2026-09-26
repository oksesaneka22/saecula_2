class_name ColonistMoveToState3D
extends "res://src/entities/fsm/State.gd"

## ColonistMoveToState3D: Стан навігації та переміщення колоніста у 3D світі.
## Розраховує маршрут через GridManager.get_world_path_3d, обходить перешкоди,
## плавно повертає тіло та анімує кроки.

var target_position: Vector3 = Vector3.ZERO
var next_state_name: StringName = &"idle"
var next_state_msg: Dictionary = {}
var arrival_distance: float = 1.2

var path_points: PackedVector3Array = PackedVector3Array()
var current_path_index: int = 0
var repath_timer: float = 0.0
var stuck_timer: float = 0.0
var last_pos: Vector3 = Vector3.ZERO


func enter(msg: Dictionary = {}) -> void:
	target_position = msg.get("target_pos", Vector3.ZERO)
	next_state_name = msg.get("next_state", &"idle")
	next_state_msg = msg.get("next_msg", {})
	arrival_distance = msg.get("arrival_distance", 1.2)

	if actor != null:
		var dest_str := "Ціль"
		if next_state_name == &"build":
			dest_str = "Будівництво"
		elif next_state_name == &"harvest":
			dest_str = "Ресурс"
		elif next_state_name == &"haul":
			dest_str = "Вантаж"
		elif next_state_name == &"rest":
			dest_str = "Вогнище"
		actor.set_status_display("🏃 Йде до: %s" % dest_str)

	_calculate_path()
	current_path_index = 0
	repath_timer = 0.0
	stuck_timer = 0.0
	if actor != null:
		last_pos = actor.global_position


func exit() -> void:
	if actor != null:
		actor.stop_walk_animation()


func physics_update(delta: float) -> void:
	if actor == null:
		return

	# Гравітація
	if not actor.is_on_floor():
		actor.velocity.y -= 19.6 * delta

	# Перевірка досягнення кінцевої цілі
	var dist_to_target: float = actor.global_position.distance_to(target_position)
	if dist_to_target <= arrival_distance:
		_reach_destination()
		return

	# Перевірка чи є точки шляху
	if path_points.is_empty() or current_path_index >= path_points.size():
		# Спробуємо прямий рух якщо поруч
		if dist_to_target <= arrival_distance + 1.5:
			_move_towards(target_position, delta)
		else:
			_reach_destination()
		return

	var current_waypoint: Vector3 = path_points[current_path_index]
	var dist_to_waypoint: float = actor.global_position.distance_to(Vector3(current_waypoint.x, actor.global_position.y, current_waypoint.z))

	if dist_to_waypoint <= 0.6:
		current_path_index += 1
		if current_path_index >= path_points.size():
			_reach_destination()
			return
		current_waypoint = path_points[current_path_index]

	_move_towards(current_waypoint, delta)

	# Динамічне оновлення цілі, якщо робітник слідує за рухомим гравцем
	if actor.is_following_player and actor.target_follow_node != null and is_instance_valid(actor.target_follow_node):
		repath_timer += delta
		if repath_timer >= 1.0:
			repath_timer = 0.0
			target_position = actor.target_follow_node.global_position
			_calculate_path()

	# Детектор застрягання
	if actor.global_position.distance_to(last_pos) < 0.05 * delta:
		stuck_timer += delta
		if stuck_timer >= 3.0:
			# Перераховуємо шлях або скасовуємо
			stuck_timer = 0.0
			_calculate_path()
	else:
		stuck_timer = 0.0
	last_pos = actor.global_position


func _move_towards(target_wp: Vector3, delta: float) -> void:
	var move_dir := Vector3(target_wp.x - actor.global_position.x, 0.0, target_wp.z - actor.global_position.z)
	if move_dir.length_squared() > 0.001:
		move_dir = move_dir.normalized()
		var speed: float = actor.walk_speed if "walk_speed" in actor else 3.5
		actor.velocity.x = move_dir.x * speed
		actor.velocity.z = move_dir.z * speed

		# Плавний поворот у напрямку руху
		var target_angle: float = atan2(move_dir.x, move_dir.z)
		actor.rotation.y = lerp_angle(actor.rotation.y, target_angle, 12.0 * delta)
		actor.play_walk_animation(delta)
	else:
		actor.velocity.x = move_toward(actor.velocity.x, 0.0, 10.0 * delta)
		actor.velocity.z = move_toward(actor.velocity.z, 0.0, 10.0 * delta)

	actor.move_and_slide()


func _calculate_path() -> void:
	if actor == null or GridManager == null:
		return

	var from_pos: Vector3 = actor.global_position
	path_points = GridManager.get_world_path_3d(from_pos, target_position, from_pos.y)
	current_path_index = 0


func _reach_destination() -> void:
	if actor != null:
		actor.velocity.x = 0.0
		actor.velocity.z = 0.0
		actor.stop_walk_animation()

	state_machine.transition_to(next_state_name, next_state_msg)

