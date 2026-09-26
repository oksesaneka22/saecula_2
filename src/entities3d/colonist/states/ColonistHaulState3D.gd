class_name ColonistHaulState3D
extends "res://src/entities/fsm/State.gd"
const Job = preload("res://src/systems/jobs/Job.gd")
const DroppedItem3D = preload("res://src/entities3d/items/DroppedItem3D.gd")

## ColonistHaulState3D: Стан доставки та перенесення предметів на склад колонії.
## Крок 1: Підбирання предметів з землі у вантаж.
## Крок 2: Перенесення вантажу в руках до найближчого складу Stockpile та вивантаження.

var current_stage: int = 1 ## 1 = підбір, 2 = доставка на склад
var carried_item_id: StringName = &""
var carried_amount: int = 0
var target_stockpile: Node = null


func enter(msg: Dictionary = {}) -> void:
	current_stage = msg.get("stage", 1)
	carried_item_id = msg.get("item_id", &"")
	carried_amount = msg.get("amount", 0)
	target_stockpile = msg.get("stockpile", null)

	if current_stage == 1:
		_process_pickup_stage()
	else:
		_process_deposit_stage()


func _process_pickup_stage() -> void:
	if actor == null:
		state_machine.transition_to(&"idle")
		return

	# Шукаємо DroppedItem3D поруч (в радіусі 3.0м)
	var found_item: DroppedItem3D = null
	var tree := get_tree()
	if tree != null:
		var items = tree.get_nodes_in_group("dropped_items")
		for item in items:
			var d_item := item as DroppedItem3D
			if d_item != null and is_instance_valid(d_item) and not d_item.is_queued_for_deletion():
				if actor.global_position.distance_to(d_item.global_position) <= 3.5:
					found_item = d_item
					break

	if found_item != null:
		carried_item_id = found_item.item_id
		carried_amount = found_item.amount
		if actor.inventory != null:
			actor.inventory.add_item_by_id(carried_item_id, carried_amount)
		found_item.queue_free()
	elif actor.current_job != null and not actor.current_job.data.is_empty():
		# Якщо передано в даних завдання
		carried_item_id = actor.current_job.data.get("item_id", &"wood")
		carried_amount = actor.current_job.data.get("amount", 1)
		if actor.inventory != null and actor.inventory.get_item_count(carried_item_id) == 0:
			actor.inventory.add_item_by_id(carried_item_id, carried_amount)

	if carried_amount <= 0 or carried_item_id.is_empty():
		# Немає що підбирати
		_abort_job()
		return

	# Показуємо вантаж у руках
	actor.show_carried_cargo(carried_item_id)
	var item_display: String = str(carried_item_id)
	if ItemDatabase != null:
		var item_res = ItemDatabase.get_item(carried_item_id)
		if item_res != null:
			item_display = item_res.display_name
	actor.set_status_display("📦 Несе %d %s ➔ Склад" % [carried_amount, item_display])

	# Шукаємо склад для вивантаження
	var stockpile: Node = null
	if LogisticsManager != null:
		stockpile = LogisticsManager.find_stockpile_with_space(carried_item_id, carried_amount)
		if stockpile == null:
			var all_s = LogisticsManager.get_all_stockpiles()
			if not all_s.is_empty():
				stockpile = all_s[0]

	if stockpile == null:
		# Якщо складів немає — завершуємо
		_complete_job()
		return

	var dest_pos: Vector3 = Vector3.ZERO
	if stockpile is Node3D:
		dest_pos = (stockpile as Node3D).global_position

	# Переходимо в MoveTo до складу
	state_machine.transition_to(&"moveto", {
		"target_pos": dest_pos,
		"next_state": &"haul",
		"arrival_distance": 2.0,
		"next_msg": {
			"stage": 2,
			"item_id": carried_item_id,
			"amount": carried_amount,
			"stockpile": stockpile
		}
	})


func _process_deposit_stage() -> void:
	if actor == null:
		return

	actor.velocity = Vector3.ZERO
	actor.hide_hand_items()

	if carried_item_id != &"" and carried_amount > 0:
		if LogisticsManager != null:
			LogisticsManager.deposit_item(carried_item_id, carried_amount)
		elif target_stockpile != null and target_stockpile.has_method("deposit_item"):
			target_stockpile.deposit_item(carried_item_id, carried_amount)

		if actor.inventory != null:
			actor.inventory.remove_item(carried_item_id, carried_amount)

	_complete_job()


func _complete_job() -> void:
	if actor != null:
		actor.hide_hand_items()
		if actor.current_job != null and JobManager != null:
			JobManager.complete_job(actor.current_job)
		actor.current_job = null

	state_machine.transition_to(&"idle")


func _abort_job() -> void:
	if actor != null:
		actor.hide_hand_items()
		if actor.current_job != null and JobManager != null:
			JobManager.release_job(actor.current_job, "Предмет не знайдено")
		actor.current_job = null

	state_machine.transition_to(&"idle")

