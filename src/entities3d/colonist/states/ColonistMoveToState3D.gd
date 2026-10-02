class_name ColonistMoveToState3D
extends "res://src/entities/fsm/State.gd"

## ColonistMoveToState3D: Стан навігації та інтелектуального переміщення колоніста у 3D світі.
## Розраховує глобальний маршрут через покращений GridManager (AStarGrid2D з діагоналями без зрізання),
## активно обходить фізичні перешкоди (променеві сенсори-вусики 3D whisker raycasts),
## плавно ковзає вздовж перешкод (slide collision normal deflection),
## використовує зрізання прямої видимості (string-pulling line-of-sight shortcutting)
## та надійний детектор застрягання з багаторівневим відновленням руху.

var target_position: Vector3 = Vector3.ZERO
var next_state_name: StringName = &"idle"
var next_state_msg: Dictionary = {}
var arrival_distance: float = 1.2

var path_points: PackedVector3Array = PackedVector3Array()
var current_path_index: int = 0
var repath_timer: float = 0.0

# Детектор застрягання
var stuck_timer: float = 0.0
var _last_progress_pos: Vector3 = Vector3.ZERO
var _time_since_progress_check: float = 0.0


func enter(msg: Dictionary = {}) -> void:
	target_position = msg.get("target_pos", Vector3.ZERO)
	next_state_name = msg.get("next_state", &"idle")
	next_state_msg = msg.get("next_msg", {})
	arrival_distance = msg.get("arrival_distance", 1.2)

	if actor != null:
		if msg.has("custom_status"):
			actor.set_status_display(msg["custom_status"])
		else:
			var dest_str := "Ціль"
			if next_state_name == &"build":
				dest_str = "Будівництво"
			elif next_state_name == &"harvest":
				dest_str = "Ресурс"
			elif next_state_name == &"haul":
				var stage = next_state_msg.get("stage", 1)
				dest_str = "Склад" if stage == 2 else "Вантаж"
			elif next_state_name == &"rest":
				dest_str = "Вогнище"
			actor.set_status_display("🏃 Йде до: %s" % dest_str)

	# Якщо колоніст вже знаходиться в радіусі взаємодії — миттєве прибуття
	if actor != null:
		var init_h: float = Vector2(actor.global_position.x - target_position.x, actor.global_position.z - target_position.z).length()
		var init_v: float = absf(actor.global_position.y - target_position.y)
		var max_v_init: float = 3.5 if next_state_name == &"build" else 2.2
		if init_h <= arrival_distance and init_v <= max_v_init:
			_reach_destination()
			return

	_calculate_path()
	current_path_index = 0
	repath_timer = 0.0
	stuck_timer = 0.0
	_time_since_progress_check = 0.0
	if actor != null:
		_last_progress_pos = actor.global_position


func exit() -> void:
	if actor != null:
		actor.stop_walk_animation()


func physics_update(delta: float) -> void:
	if actor == null:
		return

	# Гравітація
	if not actor.is_on_floor():
		actor.velocity.y -= 19.6 * delta

	# 1. Перевірка досягнення кінцевої цілі (горизонтальна XZ-дистанція з вертикальним допуском)
	var horiz_dist_to_target: float = Vector2(actor.global_position.x - target_position.x, actor.global_position.z - target_position.z).length()
	var vert_dist_to_target: float = absf(actor.global_position.y - target_position.y)
	var max_vert: float = 3.5 if next_state_name == &"build" else 2.2
	if horiz_dist_to_target <= arrival_distance and vert_dist_to_target <= max_vert:
		_reach_destination()
		return

	# 2. Якщо шляху немає або дійшли кінця списку точок
	if path_points.is_empty() or current_path_index >= path_points.size():
		if horiz_dist_to_target <= arrival_distance + 1.5 and vert_dist_to_target <= 2.5:
			_move_towards(target_position, delta)
		else:
			# Спробуємо перерахувати шлях
			repath_timer += delta
			if repath_timer >= 0.5:
				repath_timer = 0.0
				_calculate_path()
				if path_points.is_empty():
					# Шляху немає! Не біжимо в стіну, а вивільняємо завдання і обираємо інше
					_abort_unreachable_job("Немає шляху до цілі (заблоковано)")
					return
		return

	# 3. Вибір поточної та оптимізація прямої видимості (String Pulling)
	var current_waypoint: Vector3 = path_points[current_path_index]

	# Перевірка зрізання кутів через пряму видимість наступної точки шляху
	if current_path_index + 1 < path_points.size():
		var next_wp: Vector3 = path_points[current_path_index + 1]
		if _has_clear_line_of_sight(actor.global_position, next_wp):
			current_path_index += 1
			current_waypoint = next_wp

	var dist_to_waypoint: float = actor.global_position.distance_to(
		Vector3(current_waypoint.x, actor.global_position.y, current_waypoint.z)
	)

	if dist_to_waypoint <= 0.6:
		current_path_index += 1
		if current_path_index >= path_points.size():
			if horiz_dist_to_target <= arrival_distance + 1.2 and vert_dist_to_target <= 2.5:
				_reach_destination()
			else:
				_calculate_path()
				if path_points.is_empty():
					_abort_unreachable_job("Немає шляху до цілі (заблоковано)")
					return
			return
		current_waypoint = path_points[current_path_index]

	# Рух з інтелектуальним обходом перешкод
	_move_towards(current_waypoint, delta)

	# 4. Динамічне оновлення цілі, якщо робітник слідує за рухомим гравцем
	if actor.is_following_player and actor.target_follow_node != null and is_instance_valid(actor.target_follow_node):
		repath_timer += delta
		if repath_timer >= 1.0:
			repath_timer = 0.0
			target_position = actor.target_follow_node.global_position
			_calculate_path()

	# 5. Надійний детектор застрягання на основі реального переміщення
	_time_since_progress_check += delta
	if _time_since_progress_check >= 0.35:
		var moved_dist: float = actor.global_position.distance_to(_last_progress_pos)
		_last_progress_pos = actor.global_position
		_time_since_progress_check = 0.0

		if moved_dist < 0.12 and not (horiz_dist_to_target <= arrival_distance and vert_dist_to_target <= 2.2):
			stuck_timer += 0.35
			if stuck_timer >= 1.05:
				stuck_timer = 0.0
				# Стратегія 1: Якщо ціль поряд (наприклад, дерево чи споруда заблокували підхід до центру),
				# вважаємо ціль успішно досягнутою
				if horiz_dist_to_target <= arrival_distance + 1.4 and vert_dist_to_target <= 2.5:
					_reach_destination()
					return

				# Стратегія 2: Пропуск застряглої точки на користь наступної
				if current_path_index + 1 < path_points.size():
					current_path_index += 1
				else:
					# Стратегія 3: Повний перерахунок маршруту або вивільнення заблокованого завдання
					_calculate_path()
					if path_points.is_empty():
						_abort_unreachable_job("Немає шляху до цілі (застряг)")
						return
		else:
			stuck_timer = 0.0


func _move_towards(target_wp: Vector3, delta: float) -> void:
	var desired_dir := Vector3(target_wp.x - actor.global_position.x, 0.0, target_wp.z - actor.global_position.z)
	if desired_dir.length_squared() > 0.001:
		desired_dir = desired_dir.normalized()

		# Променевий сенсор перешкод (Active Whisker Sensing)
		var move_dir: Vector3 = _detect_obstacle_avoidance(desired_dir)

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

	# Ковзання вздовж фізичних перешкод при контакті (Slide Deflection)
	if actor.get_slide_collision_count() > 0:
		for i in range(actor.get_slide_collision_count()):
			var col = actor.get_slide_collision(i)
			var n: Vector3 = col.get_normal()
			if abs(n.y) < 0.7: # Вертикальна стіна, камінь чи дерево
				var slide_vel: Vector3 = actor.velocity.slide(n)
				actor.velocity.x = slide_vel.x
				actor.velocity.z = slide_vel.z


## Променевий сенсор перешкод попереду колоніста (Whisker Raycasts)
func _detect_obstacle_avoidance(desired_dir: Vector3) -> Vector3:
	if actor == null:
		return desired_dir
	var world_3d = actor.get_world_3d()
	if world_3d == null or world_3d.direct_space_state == null:
		return desired_dir

	var space_state = world_3d.direct_space_state
	var origin: Vector3 = actor.global_position + Vector3(0.0, 0.6, 0.0) # Висота поясу
	var exclude: Array[RID] = [actor.get_rid()]

	# Центральний промінь: довжина 1.35м прямо по курсу
	var fwd_query := PhysicsRayQueryParameters3D.create(origin, origin + (desired_dir * 1.35))
	fwd_query.exclude = exclude
	fwd_query.collide_with_bodies = true
	fwd_query.collide_with_areas = false
	var fwd_hit: Dictionary = space_state.intersect_ray(fwd_query)

	# Якщо прямо перед колоністом вільно — йдемо без корекції
	if fwd_hit.is_empty():
		return desired_dir

	# Перешкода попереду! Перевіряємо бічні промені-вусики (кут 30 градусів)
	var left_dir := desired_dir.rotated(Vector3.UP, deg_to_rad(30.0)).normalized()
	var right_dir := desired_dir.rotated(Vector3.UP, deg_to_rad(-30.0)).normalized()

	var left_query := PhysicsRayQueryParameters3D.create(origin, origin + (left_dir * 1.15))
	left_query.exclude = exclude
	left_query.collide_with_bodies = true
	left_query.collide_with_areas = false
	var left_hit: Dictionary = space_state.intersect_ray(left_query)

	var right_query := PhysicsRayQueryParameters3D.create(origin, origin + (right_dir * 1.15))
	right_query.exclude = exclude
	right_query.collide_with_bodies = true
	right_query.collide_with_areas = false
	var right_hit: Dictionary = space_state.intersect_ray(right_query)

	# Ухиляємося в бік вільнішого простору
	if right_hit.is_empty() and not left_hit.is_empty():
		return (desired_dir + (right_dir * 1.3)).normalized()
	elif left_hit.is_empty() and not right_hit.is_empty():
		return (desired_dir + (left_dir * 1.3)).normalized()
	else:
		# Якщо обидва боки зайняті або обидва вільні — відхиляємося вздовж дотичної до нормалі перешкоди
		var hit_norm: Vector3 = fwd_hit.get("normal", Vector3.ZERO)
		var tangent := Vector3(-hit_norm.z, 0.0, hit_norm.x).normalized()
		if tangent.dot(desired_dir) < 0.0:
			tangent = -tangent
		return (desired_dir * 0.4 + tangent * 1.2).normalized()


## Перевірка прямої видимості до точки без перешкод (String Pulling)
func _has_clear_line_of_sight(from_pos: Vector3, to_pos: Vector3) -> bool:
	if actor == null:
		return false
	var world_3d = actor.get_world_3d()
	if world_3d == null or world_3d.direct_space_state == null:
		return false

	var space_state = world_3d.direct_space_state
	var origin: Vector3 = from_pos + Vector3(0.0, 0.6, 0.0)
	var dest: Vector3 = to_pos + Vector3(0.0, 0.6, 0.0)
	var query := PhysicsRayQueryParameters3D.create(origin, dest)
	query.exclude = [actor.get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit: Dictionary = space_state.intersect_ray(query)
	return hit.is_empty()


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


func _abort_unreachable_job(reason: String) -> void:
	if actor != null:
		actor.velocity.x = 0.0
		actor.velocity.z = 0.0
		actor.stop_walk_animation()
		if actor.current_job != null and JobManager != null:
			JobManager.release_job(actor.current_job, reason)
			actor.current_job = null
		if actor.has_method("has_items_to_unload") and actor.has_items_to_unload():
			if actor.start_unloading_to_stockpile():
				return
	state_machine.transition_to(&"idle")
