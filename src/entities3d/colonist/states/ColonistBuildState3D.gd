class_name ColonistBuildState3D
extends "res://src/entities/fsm/State.gd"
const Job = preload("res://src/systems/jobs/Job.gd")
const ConstructionSite3D = preload("res://src/world3d/ConstructionSite3D.gd")

## ColonistBuildState3D: Стан зведення 3D споруд (ConstructionSite3D) та модульних блоків (ModularPiece3D).
## Перевіряє та доставляє необхідні ресурси з інвентаря чи складів,
## після чого працює будівельним молотком до повного завершення будівництва.

var target_site: Node = null
var build_timer: float = 0.0
var build_interval: float = 0.5
var missing_material_retries: int = 0
const MAX_MATERIAL_RETRIES: int = 3


func enter(msg: Dictionary = {}) -> void:
	target_site = msg.get("target_node", null)
	if target_site == null and actor != null and actor.current_job != null:
		target_site = actor.current_job.target_node

	if target_site == null or not is_instance_valid(target_site) or target_site.is_queued_for_deletion():
		_abort_job("Ціль недоступна")
		return

	if target_site.get("is_completed") == true or target_site.get("is_built") == true:
		_finish_job()
		return

	missing_material_retries = 0

	if actor != null:
		actor.velocity = Vector3.ZERO
		var b_name := _get_site_display_name()
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

	if target_site == null or not is_instance_valid(target_site) or target_site.is_queued_for_deletion():
		_abort_job("Ціль видалено")
		return

	if target_site.get("is_completed") == true or target_site.get("is_built") == true:
		_finish_job()
		return

	# Поворот обличчям до будівельного майданчика
	var site_3d := target_site as Node3D
	if site_3d != null:
		var dir := (site_3d.global_position - actor.global_position)
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
		_abort_job("Ціль недоступна")
		return

	if target_site.has_method("interact_construct"):
		_perform_modular_build_step()
	elif target_site is ConstructionSite3D:
		_perform_site_build_step()
	else:
		_abort_job("Невідомий тип споруди")


func _perform_modular_build_step() -> void:
	# 1. Перевірка вимог конструкції (підлога під стіною, стіни/опори під дахом)
	if ModularManager != null and "cell_coord" in target_site:
		var p_type = target_site.get("piece_type")
		var cell = target_site.cell_coord
		if p_type in [&"modular_wall", &"modular_pillar", &"modular_door"]:
			if not ModularManager.has_built_floor(cell):
				_abort_job("Очікує побудови підлоги")
				return
		elif p_type == &"modular_roof":
			if not ModularManager.has_built_support_for_roof(cell):
				_abort_job("Очікує стін або опор")
				return

	# 2. Перевірка та доставка матеріалів у інвентар робітника
	var req_mats: Dictionary = target_site.get("required_materials") if "required_materials" in target_site else {}
	var missing: Dictionary = {}
	for item_id in req_mats.keys():
		var needed: int = req_mats[item_id]
		var have: int = actor.inventory.get_item_count(item_id) if actor.inventory != null and actor.inventory.has_method("get_item_count") else 0
		if have < needed:
			missing[item_id] = needed - have

	if not missing.is_empty():
		var supplied := _try_fetch_materials_to_inventory(missing)
		if not supplied:
			missing_material_retries += 1
			if missing_material_retries >= MAX_MATERIAL_RETRIES:
				_abort_job("Бракує матеріалів на складі")
			return
		else:
			missing_material_retries = 0

	# 3. Виконання маху молотком
	actor.play_swing_animation()
	if AudioManager != null and target_site is Node3D:
		AudioManager.play_sound_3d(&"build", (target_site as Node3D).global_position, -2.0, randf_range(0.9, 1.1))

	var has_hammer: bool = actor.profession == &"builder" or (actor.has_method("has_hammer_equipped") and actor.has_hammer_equipped())
	var is_done: bool = target_site.interact_construct(actor.inventory, has_hammer)

	var hits: int = int(target_site.get("construction_progress_hits")) if "construction_progress_hits" in target_site else 10
	var pct: int = int(clampf(float(hits) / 10.0, 0.0, 1.0) * 100.0)
	var piece_label := _get_site_display_name()
	actor.set_status_display("🔨 Будує %s (%d%%)" % [piece_label, pct])

	if is_done or target_site.get("is_built") == true:
		_finish_job()


func _perform_site_build_step() -> void:
	var cs := target_site as ConstructionSite3D
	# 1. Якщо матеріали ще не внесені — вносимо з інвентаря або беремо зі складу
	if not cs.is_materials_ready():
		var missing := cs.get_missing_materials()
		var supplied_any := false
		for item_id in missing.keys():
			var needed: int = missing[item_id]
			if actor.inventory != null and actor.inventory.has_item(item_id, 1):
				var available: int = actor.inventory.get_item_count(item_id)
				var to_give: int = mini(available, needed)
				var accepted: int = cs.deliver_material(item_id, to_give)
				if accepted > 0:
					actor.inventory.remove_item(item_id, accepted)
					supplied_any = true

		if not cs.is_materials_ready() and not supplied_any:
			var fetched := _try_fetch_materials_from_stockpile(missing)
			if not fetched:
				missing_material_retries += 1
				if missing_material_retries >= MAX_MATERIAL_RETRIES:
					_abort_job("Бракує матеріалів на складі")
				return
			else:
				missing_material_retries = 0

	# 2. Якщо всі матеріали на майданчику — будуємо молотком
	if cs.is_materials_ready():
		missing_material_retries = 0
		actor.play_swing_animation()
		if AudioManager != null:
			AudioManager.play_sound_3d(&"build", cs.global_position, -2.0, randf_range(0.9, 1.1))

		var work_power: float = 1.0 if actor.profession == &"builder" else 0.6
		cs.build_work(work_power)

		var max_work: float = cs.building_data.build_time if cs.building_data != null else 10.0
		var pct: int = int(clampf(cs.build_progress / maxf(max_work, 0.01), 0.0, 1.0) * 100.0)
		var piece_label := _get_site_display_name()
		actor.set_status_display("🔨 Будує %s (%d%%)" % [piece_label, pct])

		if cs.is_completed or not is_instance_valid(cs):
			_finish_job()


func _try_fetch_materials_from_stockpile(missing: Dictionary) -> bool:
	if LogisticsManager == null:
		return false

	for item_id in missing.keys():
		var needed: int = missing[item_id]
		var sp = LogisticsManager.find_stockpile_with_item(item_id, 1)
		if sp != null and is_instance_valid(sp):
			var withdrawn: int = LogisticsManager.withdraw_item(item_id, needed)
			if withdrawn > 0 and actor.inventory != null:
				actor.inventory.add_item_by_id(item_id, withdrawn)
				if target_site is ConstructionSite3D:
					(target_site as ConstructionSite3D).deliver_material(item_id, withdrawn)
					actor.inventory.remove_item(item_id, withdrawn)
				return true
	return false


func _try_fetch_materials_to_inventory(missing: Dictionary) -> bool:
	if LogisticsManager == null or actor.inventory == null:
		return false

	var any_withdrawn := false
	for item_id in missing.keys():
		var needed: int = missing[item_id]
		var sp = LogisticsManager.find_stockpile_with_item(item_id, 1)
		if sp != null and is_instance_valid(sp):
			var withdrawn: int = LogisticsManager.withdraw_item(item_id, needed)
			if withdrawn > 0:
				actor.inventory.add_item_by_id(item_id, withdrawn)
				any_withdrawn = true
	return any_withdrawn


func _get_site_display_name() -> String:
	if target_site == null or not is_instance_valid(target_site):
		return "споруду"
	if target_site is ConstructionSite3D and (target_site as ConstructionSite3D).building_data != null:
		return (target_site as ConstructionSite3D).building_data.display_name
	if target_site.get("piece_type") != null:
		match target_site.piece_type:
			&"modular_floor": return "підлогу"
			&"modular_wall": return "стіну"
			&"modular_pillar": return "опору"
			&"modular_door": return "двері"
			&"modular_roof": return "дах"
	return "модуль"


func _finish_job() -> void:
	if actor != null:
		actor.hide_hand_items()
		if actor.current_job != null and JobManager != null:
			JobManager.complete_job(actor.current_job)
		actor.current_job = null
	state_machine.transition_to(&"idle")


func _abort_job(reason: String = "Перервано") -> void:
	if actor != null:
		actor.hide_hand_items()
		if actor.current_job != null and JobManager != null:
			JobManager.release_job(actor.current_job, reason)
		actor.current_job = null
	state_machine.transition_to(&"idle")
