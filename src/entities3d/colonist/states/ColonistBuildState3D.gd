class_name ColonistBuildState3D
extends "res://src/entities/fsm/State.gd"
const Job = preload("res://src/systems/jobs/Job.gd")
const ConstructionSite3D = preload("res://src/world3d/ConstructionSite3D.gd")

## ColonistBuildState3D: Стан зведення 3D споруд за кресленнями (ConstructionSite3D).
## Перевіряє та доставляє необхідні ресурси з інвентаря чи складів,
## після чого працює будівельним молотком до повного завершення будівництва.

var target_site: ConstructionSite3D = null
var build_timer: float = 0.0
var build_interval: float = 0.5


func enter(msg: Dictionary = {}) -> void:
	target_site = msg.get("target_node", null) as ConstructionSite3D
	if target_site == null and actor != null and actor.current_job != null:
		target_site = actor.current_job.target_node as ConstructionSite3D

	if target_site == null or not is_instance_valid(target_site) or target_site.is_completed:
		_finish_or_abort()
		return

	if actor != null:
		actor.velocity = Vector3.ZERO
		var b_name: String = "споруду"
		if target_site != null and target_site.building_data != null:
			b_name = target_site.building_data.display_name
		actor.set_status_display("🔨 Будує %s" % b_name)
		actor.show_hand_tool(&"hammer")

	build_timer = 0.2


func exit() -> void:
	if actor != null:
		actor.hide_hand_items()


func physics_update(delta: float) -> void:
	if actor == null:
		return

	# Гравітація
	if not actor.is_on_floor():
		actor.velocity.y -= 19.6 * delta
		actor.move_and_slide()

	if target_site == null or not is_instance_valid(target_site) or target_site.is_completed:
		_finish_or_abort()
		return

	# Поворот обличчям до будівельного майданчика
	var dir := (target_site.global_position - actor.global_position)
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		var target_angle := atan2(dir.x, dir.z)
		actor.rotation.y = lerp_angle(actor.rotation.y, target_angle, 10.0 * delta)

	build_timer -= delta
	if build_timer <= 0.0:
		build_timer = build_interval
		_perform_build_step()


func _perform_build_step() -> void:
	if actor == null or target_site == null or not is_instance_valid(target_site):
		_finish_or_abort()
		return

	# 1. Якщо матеріали ще не внесені — вносимо з інвентаря колоніста
	if not target_site.is_materials_ready():
		var missing := target_site.get_missing_materials()
		var supplied_any := false
		for item_id in missing.keys():
			var needed: int = missing[item_id]
			if actor.inventory != null and actor.inventory.has_item(item_id, 1):
				var available: int = actor.inventory.get_item_count(item_id)
				var to_give: int = mini(available, needed)
				var accepted: int = target_site.deliver_material(item_id, to_give)
				if accepted > 0:
					actor.inventory.remove_item(item_id, accepted)
					supplied_any = true

		if not target_site.is_materials_ready() and not supplied_any:
			# Матеріалів у колоніста немає — спробуємо перевірити склади
			_try_fetch_materials_from_stockpile(missing)
			return

	# 2. Якщо всі матеріали на майданчику — б'ємо молотком і зводимо будівлю
	if target_site.is_materials_ready():
		actor.play_swing_animation()
		if AudioManager != null and target_site != null:
			AudioManager.play_sound_3d(&"build", target_site.global_position, -2.0, randf_range(0.9, 1.1))
		# Якщо є молоток у руках/професія будівельника — подвійна швидкість
		var work_power: float = 0.6
		target_site.build_work(work_power)

		var pct: int = int(clampf(target_site.current_progress / maxf(target_site.required_work, 0.01), 0.0, 1.0) * 100.0)
		actor.set_status_display("🔨 Будує споруду (%d%%)" % pct)

		if target_site.is_completed or not is_instance_valid(target_site):
			_finish_or_abort()


func _try_fetch_materials_from_stockpile(missing: Dictionary) -> void:
	if LogisticsManager == null:
		return

	for item_id in missing.keys():
		var needed: int = missing[item_id]
		var sp = LogisticsManager.find_stockpile_with_item(item_id, 1)
		if sp != null and is_instance_valid(sp):
			var sp_pos: Vector3 = (sp as Node3D).global_position if sp is Node3D else Vector3.ZERO
			# Вилучаємо зі складу необхідну кількість
			var withdrawn: int = LogisticsManager.withdraw_item(item_id, needed)
			if withdrawn > 0 and actor.inventory != null:
				actor.inventory.add_item_by_id(item_id, withdrawn)
				# Доставляємо негайно на будмайданчик
				target_site.deliver_material(item_id, withdrawn)
				actor.inventory.remove_item(item_id, withdrawn)
				return


func _finish_or_abort() -> void:
	if actor != null:
		actor.hide_hand_items()
		if actor.current_job != null and JobManager != null:
			JobManager.complete_job(actor.current_job)
		actor.current_job = null

	state_machine.transition_to(&"idle")

