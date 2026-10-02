extends Node

## FloatingTextManager: Централізований менеджер спливаючих 3D написів (Floating Combat/Resource Text).
## Автоматично відображає написи при підборі предметів (+1 Деревина), здобутті ресурсів,
## завершенні споруд чи попередженнях про виснаження енергії.

const FloatingText3DScript = preload("res://src/ui/hud/FloatingText3D.gd")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_event_bus()
	print("[FloatingTextManager] 💬 Менеджер спливаючого тексту успішно ініціалізовано.")


## Створює плаваючий 3D напис у заданих глобальних координатах
func spawn_text(world_pos: Vector3, text: String, color: Color = Color.WHITE, duration: float = 0.9, upward_speed: float = 1.4) -> Node3D:
	var ft := FloatingText3DScript.new()
	ft.setup(text, color, duration, upward_speed)
	call_deferred("_deferred_add_text", ft, world_pos)
	return ft


func _deferred_add_text(ft: Node3D, world_pos: Vector3) -> void:
	if not is_instance_valid(ft):
		return
	var target_parent: Node = _get_world_container()
	if target_parent == null or not is_instance_valid(target_parent) or not target_parent.is_inside_tree():
		ft.queue_free()
		return

	target_parent.add_child(ft)
	if ft.is_inside_tree():
		ft.global_position = world_pos


## Спливаючий напис про успішне зведення споруди
func spawn_construction_success(world_pos: Vector3, title: String) -> void:
	spawn_text(world_pos, "✅ Збудовано: %s!" % title, Color(0.2, 1.0, 0.4), 1.6, 1.2)


## Спливаючий напис при підборі предмета гравцем
func spawn_item_pickup(world_pos: Vector3, item_id: StringName, amount: int) -> void:
	var item_name: String = String(item_id)
	if ItemDatabase != null:
		var item_res = ItemDatabase.get_item(item_id)
		if item_res != null:
			item_name = item_res.display_name

	var text: String = "+%d %s" % [amount, item_name]
	spawn_text(world_pos, text, Color("2ECC71"), 1.0, 1.5)


## Спливаючий напис при зрубуванні чи видобутку ресурсу у світі
func spawn_resource_harvest(world_pos: Vector3, item_id: StringName, amount: int) -> void:
	var item_name: String = String(item_id)
	if ItemDatabase != null:
		var item_res = ItemDatabase.get_item(item_id)
		if item_res != null:
			item_name = item_res.display_name

	var text: String = "+%d %s" % [amount, item_name]
	spawn_text(world_pos, text, Color("F1C40F"), 1.1, 1.6)


## Попередження про брак сил/енергії
func spawn_warning(world_pos: Vector3, text: String) -> void:
	spawn_text(world_pos, text, Color("E74C3C"), 1.2, 1.2)


## Інформаційне повідомлення або прогрес
func spawn_info(world_pos: Vector3, text: String, color: Color = Color("3498DB")) -> void:
	spawn_text(world_pos, text, color, 1.0, 1.3)


func _get_world_container() -> Node:
	var tree := get_tree()
	if tree == null:
		return null

	var current := tree.current_scene
	if current is Node3D and current.is_inside_tree():
		return current

	var worlds := tree.get_nodes_in_group("world3d")
	if not worlds.is_empty() and worlds[0] is Node3D and (worlds[0] as Node3D).is_inside_tree():
		return worlds[0]

	if tree.root != null:
		for child in tree.root.get_children():
			if child is Node3D and child.is_inside_tree() and child.visible:
				return child

	return null


func _connect_event_bus() -> void:
	if EventBus == null:
		return

	if EventBus.has_signal("resource_harvested"):
		EventBus.resource_harvested.connect(func(_source, item_id, amount, pos):
			var spawn_pos := Vector3(pos.x, 1.2, pos.y)
			spawn_resource_harvest(spawn_pos, item_id, amount)
		)

	if EventBus.has_signal("item_picked_up"):
		EventBus.item_picked_up.connect(func(collector, item_id, amount):
			var pos := Vector3.ZERO
			if collector is Node3D:
				pos = (collector as Node3D).global_position + Vector3(0, 1.4, 0)
			spawn_item_pickup(pos, item_id, amount)
		)

	if EventBus.has_signal("energy_depleted_action_attempted"):
		EventBus.energy_depleted_action_attempted.connect(func():
			var players := get_tree().get_nodes_in_group("player")
			if not players.is_empty() and players[0] is Node3D:
				var p_pos: Vector3 = (players[0] as Node3D).global_position + Vector3(0, 1.8, 0)
				spawn_warning(p_pos, "⚡ Недостатньо енергії!")
		)

	if EventBus.has_signal("building_completed"):
		EventBus.building_completed.connect(func(building_node, b_id, coords):
			var pos := Vector3(coords.x, 1.5, coords.y)
			if building_node is Node3D:
				pos = (building_node as Node3D).global_position + Vector3(0, 1.8, 0)
			elif GridManager != null:
				pos = GridManager.map_to_world_3d(coords, 1.8)

			var bld_name: String = str(b_id)
			if BuildingPlacementController != null:
				var b_data = BuildingPlacementController.get_building(b_id)
				if b_data != null and not b_data.display_name.is_empty():
					bld_name = b_data.display_name
			spawn_text(pos, "✅ Збудовано: %s!" % bld_name, Color(0.2, 1.0, 0.4), 1.6, 1.2)
		)
