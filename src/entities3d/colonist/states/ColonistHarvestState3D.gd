class_name ColonistHarvestState3D
extends "res://src/entities/fsm/State.gd"

## ColonistHarvestState3D: Стан видобутку та рубки природних ресурсів.
## Колоніст підходить до ресурсу, бере у руки сокиру/кайло/косу, завдає ударів
## та завершує завдання після повного збору ресурсу.

var target_node: Node = null
var swing_timer: float = 0.0
var swing_interval: float = 0.6
var _has_scythe: bool = false


func enter(msg: Dictionary = {}) -> void:
	target_node = msg.get("target_node", null)
	if target_node == null and actor != null and actor.current_job != null:
		target_node = actor.current_job.target_node

	if target_node == null or not is_instance_valid(target_node):
		_abort_job("Ресурс не знайдено")
		return

	if actor != null:
		actor.velocity = Vector3.ZERO
		var res_type = target_node.get("resource_type")
		match res_type:
			0: # TREE
				actor.set_status_display("🪓 Рубає дерево")
				actor.show_hand_tool(&"stone_axe")
			1: # ROCK
				actor.set_status_display("⛏️ Довбає камінь")
				actor.show_hand_tool(&"stone_pickaxe")
			2: # BUSH
				actor.set_status_display("🍓 Збирає ягоди")
				actor.hide_hand_items()
			3: # CLAY
				actor.set_status_display("🏺 Видобуває глину")
				actor.show_hand_tool(&"stone_pickaxe")
			4: # FLINT
				actor.set_status_display("🪨 Довбає кремінь")
				actor.show_hand_tool(&"stone_pickaxe")
			5: # GRASS
				_setup_grass_harvest()
			_:
				actor.set_status_display("⛏️ Довбає ресурс")
				actor.show_hand_tool(&"stone_pickaxe")

	swing_timer = 0.2


func exit() -> void:
	if actor != null:
		actor.hide_hand_items()
	_has_scythe = false


func physics_update(delta: float) -> void:
	if actor == null:
		return

	# Гравітація
	if not actor.is_on_floor():
		actor.velocity.y -= 19.6 * delta
		actor.move_and_slide()

	# Перевірка чи ціль досі існує
	if target_node == null or not is_instance_valid(target_node) or target_node.is_queued_for_deletion():
		_abort_job("Ціль зникла або знищена")
		return

	# Поворот обличчям до ресурсу
	var node3d := target_node as Node3D
	if node3d != null:
		var dir := (node3d.global_position - actor.global_position)
		dir.y = 0.0
		if dir.length_squared() > 0.001:
			var target_angle := atan2(dir.x, dir.z)
			actor.rotation.y = lerp_angle(actor.rotation.y, target_angle, 10.0 * delta)

	swing_timer -= delta
	if swing_timer <= 0.0:
		swing_timer = swing_interval
		_perform_swing()


func _perform_swing() -> void:
	if actor == null or target_node == null or not is_instance_valid(target_node):
		_abort_job("Ціль недійсна")
		return

	actor.play_swing_animation()

	var tool_type: int = 1 # Axe default
	var swing_damage: float = 1.0
	var res_type = target_node.get("resource_type")
	if res_type == 1 or res_type == 3 or res_type == 4: # Rock, Clay or Flint
		tool_type = 2 # Pickaxe
	elif res_type == 5: # Grass
		if _has_scythe:
			tool_type = 5 # Scythe
			swing_damage = 1.0
		else:
			tool_type = 0 # Bare hands
			swing_damage = 1.0
	elif res_type == 2: # Bush
		tool_type = 0 # Bare hands

	if target_node.has_method("harvest"):
		target_node.harvest(swing_damage, tool_type)

	# Оновлюємо прогрес у плашці над головою робітника
	if is_instance_valid(target_node) and "current_health" in target_node and "max_health" in target_node:
		var pct: int = int((1.0 - clampf(float(target_node.current_health) / float(target_node.max_health), 0.0, 1.0)) * 100.0)
		var icon: String = "🪓"
		var res_name: String = "дерево"
		match res_type:
			0:
				icon = "🪓"
				res_name = "дерево"
			1:
				icon = "⛏️"
				res_name = "камінь"
			2:
				icon = "🍓"
				res_name = "ягоди"
			3:
				icon = "🏺"
				res_name = "глину"
			4:
				icon = "🪨"
				res_name = "кремінь"
			5:
				icon = "🌾"
				res_name = "траву (коса)" if _has_scythe else "траву вручну"
			_:
				icon = "⛏️"
				res_name = "ресурс"
		actor.set_status_display("%s Здобуває %s (%d%%)" % [icon, res_name, pct])

	# Якщо після удару вузол вичерпано — завершуємо як успіх
	if not is_instance_valid(target_node) or target_node.is_queued_for_deletion():
		_finish_job()


func _finish_job() -> void:
	if actor != null:
		actor.hide_hand_items()
		if actor.current_job != null:
			if JobManager != null:
				JobManager.complete_job(actor.current_job)
			actor.current_job = null

		_collect_nearby_drops()

		if actor.has_method("has_items_to_unload") and actor.has_items_to_unload():
			if actor.start_unloading_to_stockpile():
				return

	state_machine.transition_to(&"idle")


func _abort_job(reason: String = "Ціль недоступна") -> void:
	if actor != null:
		actor.hide_hand_items()
		if actor.current_job != null:
			if JobManager != null:
				JobManager.release_job(actor.current_job, reason)
			actor.current_job = null

		_collect_nearby_drops()

		if actor.has_method("has_items_to_unload") and actor.has_items_to_unload():
			if actor.start_unloading_to_stockpile():
				return

	state_machine.transition_to(&"idle")


func _collect_nearby_drops() -> void:
	if actor == null or actor.inventory == null:
		return
	var tree := get_tree()
	if tree == null:
		return
	var items = tree.get_nodes_in_group("dropped_items")
	for item in items:
		var d := item as Node3D
		if d != null and is_instance_valid(d) and not d.is_queued_for_deletion():
			if actor.global_position.distance_to(d.global_position) <= 4.0:
				var drop_id = d.get("item_id")
				var drop_amount = d.get("amount")
				if drop_id != null and drop_amount != null and drop_amount > 0:
					var rem: int = actor.inventory.add_item_by_id(drop_id, drop_amount)
					if rem <= 0:
						d.queue_free()
					else:
						if d.has_method("set_item"):
							d.set_item(drop_id, rem)
						else:
							d.set("amount", rem)


func _setup_grass_harvest() -> void:
	if actor == null:
		return
	var has_scythe: bool = false
	if actor.inventory != null and actor.inventory.has_item(&"scythe", 1):
		has_scythe = true
	elif LogisticsManager != null and LogisticsManager.has_item(&"scythe"):
		var taken: int = LogisticsManager.withdraw_item(&"scythe", 1)
		if taken > 0:
			if actor.inventory != null:
				actor.inventory.add_item_by_id(&"scythe", 1)
			has_scythe = true
			if FloatingTextManager != null:
				FloatingTextManager.spawn_info(actor.global_position + Vector3(0, 1.8, 0), "🌾 Взяв косу зі складу")

	_has_scythe = has_scythe
	if _has_scythe:
		actor.set_status_display("🌾 Косить траву (коса)")
		actor.show_hand_tool(&"scythe")
		swing_interval = 0.5
	else:
		actor.set_status_display("🌾 Збирає траву вручну")
		actor.hide_hand_items()
		swing_interval = 0.8
