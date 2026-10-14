class_name ColonistCraftState3D
extends "res://src/entities3d/colonist/states/ColonistState3D.gd"

## ColonistCraftState3D: Стан виготовлення предметів на верстаку (JobType.CRAFT).
## Колоніст бере інгредієнти зі складу (LogisticsManager), підходить до верстака,
## працює протягом craft_time і відносить готовий предмет на склад.

var current_job: Job = null
var target_workbench: Node3D = null

var _craft_time: float = 2.5
var _craft_timer: float = 0.0
var _work_sound_timer: float = 0.0
var _recipe_id: StringName = &""
var _craft_amount: int = 1
var _is_crafting: bool = false


func enter(msg: Dictionary = {}) -> void:
	current_job = msg.get("job") as Job
	target_workbench = msg.get("target_node") as Node3D

	if current_job != null:
		_recipe_id = current_job.data.get("recipe_id", &"")
		_craft_amount = current_job.data.get("amount", 1)
		_craft_time = current_job.data.get("craft_time", 2.5)

	if target_workbench == null and current_job != null and current_job.target_node is Node3D:
		target_workbench = current_job.target_node as Node3D

	_craft_timer = 0.0
	_work_sound_timer = 0.0
	_is_crafting = true

	# 1. Забір інгредієнтів зі складу (LogisticsManager)
	var recipe_res: Resource = null
	if CraftingManager != null and _recipe_id != &"":
		recipe_res = CraftingManager.get_recipe(_recipe_id)

	if recipe_res != null and LogisticsManager != null and actor != null and actor.inventory != null:
		var ings = recipe_res.get("ingredients")
		if ings is Array:
			for cost in ings:
				if cost != null and "item" in cost and "amount" in cost and cost.item != null:
					var ing_id: StringName = cost.item.id
					var needed: int = cost.amount * _craft_amount
					var in_inv: int = actor.inventory.get_item_count(ing_id)
					if in_inv < needed:
						var to_take: int = needed - in_inv
						var taken: int = LogisticsManager.withdraw_item(ing_id, to_take)
						if taken > 0:
							actor.inventory.add_item(cost.item, taken)

	if actor != null:
		actor.velocity = Vector3.ZERO
		actor.show_hand_tool(&"hammer")
		var display_name := String(_recipe_id)
		if recipe_res != null and "result_item" in recipe_res and recipe_res.result_item != null:
			display_name = recipe_res.result_item.display_name
		actor.set_status_display("🔨 Майструє: %s" % display_name)


func exit() -> void:
	if actor != null:
		actor.hide_hand_items()
	_is_crafting = false


func physics_update(delta: float) -> void:
	if actor == null:
		return

	apply_gravity(delta, true)

	if not _is_crafting:
		return

	# Поворот обличчям до верстака
	if target_workbench != null and is_instance_valid(target_workbench):
		face_target(target_workbench.global_position, delta)

	# Періодична анімація удару молотком
	_work_sound_timer -= delta
	if _work_sound_timer <= 0.0:
		_work_sound_timer = 0.55
		actor.play_swing_animation()
		if AudioManager != null:
			AudioManager.play_sound_3d(&"build", actor.global_position, -2.0, randf_range(0.9, 1.1))

	_craft_timer += delta
	if _craft_timer >= _craft_time:
		_finish_crafting()


func _finish_crafting() -> void:
	_is_crafting = false
	if actor == null:
		return

	var recipe_res: Resource = null
	if CraftingManager != null and _recipe_id != &"":
		recipe_res = CraftingManager.get_recipe(_recipe_id)

	var result_item: ItemData = null
	var result_count: int = _craft_amount
	var item_name: String = "Виріб"

	if recipe_res != null:
		# Списання інгредієнтів
		var ings = recipe_res.get("ingredients")
		if ings is Array:
			for cost in ings:
				if cost != null and cost.item != null:
					actor.inventory.remove_item(cost.item.id, cost.amount * _craft_amount, true)

		if "result_item" in recipe_res and recipe_res.result_item is ItemData:
			result_item = recipe_res.result_item
			item_name = result_item.display_name
		if "result_amount" in recipe_res:
			result_count = recipe_res.result_amount * _craft_amount
	elif _recipe_id != &"":
		result_item = ItemDatabase.get_item(_recipe_id)
		if result_item != null:
			item_name = result_item.display_name

	# Додавання готового предмета в інвентар робітника
	if result_item != null and actor.inventory != null:
		actor.inventory.add_item(result_item, result_count)

	if FloatingTextManager != null:
		FloatingTextManager.spawn_info(actor.global_position + Vector3(0, 1.8, 0), "✅ Виготовлено: %s" % item_name, Color(0.3, 1.0, 0.4))

	if AudioManager != null:
		AudioManager.play_sound_3d(&"pickup", actor.global_position, 0.0, 1.2)

	# Завершення завдання в JobManager
	if current_job != null and JobManager != null:
		JobManager.complete_job(current_job)
		current_job = null

	# Віднесення готового виробу на склад
	try_unload_or_idle()
