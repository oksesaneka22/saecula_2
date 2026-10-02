class_name ColonistIdleState3D
extends "res://src/entities/fsm/State.gd"
const Job = preload("res://src/systems/jobs/Job.gd")

## ColonistIdleState3D: Стан очікування та відпочинку колоніста.
## Колоніст оглядається, гріється біля вогнища за холоду/вночі
## та регулярно запитує нові завдання у JobManager.

var _job_search_timer: float = 0.0
var _wander_timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	if actor != null:
		actor.velocity = Vector3.ZERO
		actor.set_status_display("💤 Очікує")
		actor.hide_hand_items()
		if not actor.is_following_player and actor.has_method("has_items_to_unload") and actor.has_items_to_unload():
			if actor.start_unloading_to_stockpile():
				return
	_job_search_timer = 0.2
	_wander_timer = randf_range(4.0, 8.0)


func physics_update(delta: float) -> void:
	if actor == null:
		return

	# Гравітація
	if not actor.is_on_floor():
		actor.velocity.y -= 19.6 * delta
	else:
		actor.velocity.x = move_toward(actor.velocity.x, 0.0, 10.0 * delta)
		actor.velocity.z = move_toward(actor.velocity.z, 0.0, 10.0 * delta)

	actor.move_and_slide()

	# Якщо колоніст слідує за гравцем — тримаємо дистанцію до гравця
	if actor.is_following_player and actor.target_follow_node != null and is_instance_valid(actor.target_follow_node):
		var dist_to_player: float = actor.global_position.distance_to(actor.target_follow_node.global_position)
		if dist_to_player > 4.0:
			actor.set_status_display("🚶 Наздоганяє гравця")
			state_machine.transition_to(&"moveto", {
				"target_pos": actor.target_follow_node.global_position,
				"next_state": &"idle",
				"arrival_distance": 2.5
			})
			return
		else:
			actor.set_status_display("👀 Слідує за гравцем")
		return

	# Нічний відпочинок біля табірного вогнища
	if GameManager != null and GameManager.is_night() and not actor.is_following_player and actor.current_job == null:
		var campfires = get_tree().get_nodes_in_group("campfires")
		if not campfires.is_empty():
			var campfire: Node3D = campfires[0] as Node3D
			var angle: float = float(actor.get_instance_id() % 360) * (PI / 180.0)
			var rest_spot: Vector3 = campfire.global_position + Vector3(cos(angle), 0, sin(angle)) * 2.4
			if actor.global_position.distance_to(rest_spot) > 1.2:
				state_machine.transition_to(&"moveto", {
					"target_pos": rest_spot,
					"next_state": &"rest",
					"arrival_distance": 1.2,
					"next_msg": { "campfire": campfire }
				})
				return
			else:
				state_machine.transition_to(&"rest", { "campfire": campfire })
				return
		else:
			state_machine.transition_to(&"rest", { "campfire": null })
			return

	# Періодичний пошук роботи (якщо не слідує за гравцем)
	_job_search_timer -= delta
	if _job_search_timer <= 0.0:
		_job_search_timer = 0.6
		if actor.has_method("has_items_to_unload") and actor.has_items_to_unload():
			if actor.start_unloading_to_stockpile():
				return
		if JobManager != null and actor.current_job == null:
			var job: Job = JobManager.request_job(actor)
			if job != null:
				actor.assign_job(job)
				return

	# Випадковий блукаючий рух неподалік (якщо немає роботи)
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = randf_range(6.0, 12.0)
		_try_idle_wander()


func _try_idle_wander() -> void:
	if actor == null:
		return
	var offset := Vector3(randf_range(-3.0, 3.0), 0.0, randf_range(-3.0, 3.0))
	var target := actor.global_position + offset
	state_machine.transition_to(&"moveto", {
		"target_pos": target,
		"next_state": &"idle",
		"arrival_distance": 0.8
	})

