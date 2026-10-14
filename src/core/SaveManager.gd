extends Node

## SaveManager: Головний менеджер збереження та завантаження 3D світу гри Saecula.
## Відповідає за повну JSON-серіалізацію епохи, технологій, гравця, модульних частин,
## воксельних блоків, споруд та жителів відповідно до специфікації skill-save-system.md.

signal game_saved(slot: int, success: bool)
signal game_loaded(slot: int, success: bool)

const SAVES_DIR: String = "user://saves/"
const SAVE_VERSION: int = 2

const BuildingEntity3DScript = preload("res://src/world3d/BuildingEntity3D.gd")
const Colonist3DScene = preload("res://src/entities3d/colonist/Colonist3D.tscn")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_saves_dir()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			save_game(1)
		elif event.keycode == KEY_F9:
			load_game(1)
	elif event.is_action_pressed("quick_save"):
		save_game(1)
	elif event.is_action_pressed("quick_load"):
		load_game(1)


func _ensure_saves_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		DirAccess.make_dir_recursive_absolute(SAVES_DIR)


func get_save_path(slot: int = 1) -> String:
	return "%sslot_%d.json" % [SAVES_DIR, slot]


func has_save(slot: int = 1) -> bool:
	return FileAccess.file_exists(get_save_path(slot))


func delete_save(slot: int = 1) -> bool:
	var path := get_save_path(slot)
	if FileAccess.file_exists(path):
		return DirAccess.remove_absolute(path) == OK
	return false


## Зберігає повний стан гри у вибраний слот (JSON)
func save_game(slot: int = 1) -> bool:
	_ensure_saves_dir()
	var save_path := get_save_path(slot)

	var save_dict: Dictionary = {
		"save_version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"era": _serialize_era(),
		"game_time": _serialize_game_time(),
		"player": _serialize_player(),
		"voxel_blocks": _serialize_blocks(),
		"modular_pieces": _serialize_modular(),
		"buildings": _serialize_buildings(),
		"colonists": _serialize_colonists()
	}

	var json_string := JSON.stringify(save_dict, "\t")
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] Не вдалося відкрити файл для запису: %s (Помилка: %d)" % [save_path, FileAccess.get_open_error()])
		game_saved.emit(slot, false)
		return false

	file.store_string(json_string)
	file.close()

	print("[SaveManager] 💾 Гру успішно збережено у слот %d: %s" % [slot, save_path])
	game_saved.emit(slot, true)

	if EventBus != null and EventBus.has_signal("notification_posted"):
		EventBus.notification_posted.emit("ГРУ ЗБЕРЕЖЕНО", "Слот %d успішно збережено!" % slot, 0)
	return true


## Завантажує стан гри із вибраного слота
func load_game(slot: int = 1) -> bool:
	var save_path := get_save_path(slot)
	if not FileAccess.file_exists(save_path):
		push_warning("[SaveManager] Файл збереження не знайдено: %s" % save_path)
		game_loaded.emit(slot, false)
		return false

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_error("[SaveManager] Не вдалося відкрити файл збереження: %s" % save_path)
		game_loaded.emit(slot, false)
		return false

	var json_string := file.get_as_text()
	file.close()

	var parse_result: Variant = JSON.parse_string(json_string)
	if not (parse_result is Dictionary):
		push_error("[SaveManager] Помилка парсингу JSON збереження: %s" % save_path)
		game_loaded.emit(slot, false)
		return false

	var save_dict: Dictionary = parse_result

	# 1. Відновлення епохи та технологій
	if save_dict.has("era"):
		_deserialize_era(save_dict["era"])

	# 2. Відновлення ігрового часу
	if save_dict.has("game_time"):
		_deserialize_game_time(save_dict["game_time"])

	# 3. Відновлення воксельних блоків
	if save_dict.has("voxel_blocks"):
		_deserialize_blocks(save_dict["voxel_blocks"])

	# 4. Відновлення модульних конструкцій
	if save_dict.has("modular_pieces"):
		_deserialize_modular(save_dict["modular_pieces"])

	# 5. Відновлення будівель та складів
	if save_dict.has("buildings"):
		_deserialize_buildings(save_dict["buildings"])

	# 6. Відновлення колоністів
	if save_dict.has("colonists"):
		_deserialize_colonists(save_dict["colonists"])

	# 7. Відновлення гравця
	if save_dict.has("player"):
		_deserialize_player(save_dict["player"])

	print("[SaveManager] 📂 Гру успішно завантажено зі слота %d!" % slot)
	game_loaded.emit(slot, true)

	if EventBus != null and EventBus.has_signal("notification_posted"):
		EventBus.notification_posted.emit("ГРУ ЗАВАНТАЖЕНО", "Слот %d успішно завантажено!" % slot, 0)
	return true


# ------------------------------------------------------------------------------
# Серіалізація підсистем
# ------------------------------------------------------------------------------
func _serialize_era() -> Dictionary:
	var era_val: int = 0
	var era_name: String = "stone_age"
	var techs: Array = []
	if EraManager != null:
		era_val = EraManager.get_current_era()
		era_name = EraManager.get_current_era_name()
		if EraManager.has_method("get_unlocked_tech_ids"):
			techs = EraManager.get_unlocked_tech_ids()
	return {
		"current_era": era_val,
		"current_era_id": era_name,
		"unlocked_techs": techs
	}


func _serialize_game_time() -> Dictionary:
	var day: int = 1
	var sec: float = 8.0 * 3600.0
	if GameManager != null:
		day = GameManager.current_day
		sec = GameManager.in_game_time_seconds
	return {
		"day": day,
		"time_seconds": sec
	}


func _serialize_player() -> Dictionary:
	var p = _find_player()
	if p == null:
		return {}

	var inv_items: Array = []
	if p.inventory != null and "slots" in p.inventory:
		for slot in p.inventory.slots:
			if slot != null and not slot.is_empty() and slot.item != null and slot.count > 0:
				inv_items.append({
					"item_id": String(slot.item.id),
					"count": slot.count
				})

	return {
		"position": {"x": p.global_position.x, "y": p.global_position.y, "z": p.global_position.z},
		"rotation_y": p.rotation.y,
		"energy": p.current_energy if "current_energy" in p else 100.0,
		"health": p.current_health if "current_health" in p else 100.0,
		"active_slot": p.active_hotbar_slot if "active_hotbar_slot" in p else 0,
		"inventory": inv_items
	}


func _serialize_blocks() -> Array:
	if BlockManager != null and BlockManager.has_method("get_all_blocks_data"):
		return BlockManager.get_all_blocks_data()
	return []


func _serialize_modular() -> Array:
	if ModularManager != null and ModularManager.has_method("get_all_modular_data"):
		return ModularManager.get_all_modular_data()
	return []


func _serialize_buildings() -> Array:
	var result: Array = []
	var b_nodes = get_tree().get_nodes_in_group("buildings")
	for b in b_nodes:
		if is_instance_valid(b) and b is BuildingEntity3DScript and b.has_method("serialize"):
			result.append(b.serialize())
	return result


func _serialize_colonists() -> Array:
	var result: Array = []
	var c_nodes = get_tree().get_nodes_in_group("colonists")
	for c in c_nodes:
		if is_instance_valid(c) and not c.is_queued_for_deletion():
			var inv_data: Array = []
			if c.inventory != null and "slots" in c.inventory:
				for slot in c.inventory.slots:
					if slot != null and not slot.is_empty() and slot.item != null and slot.count > 0:
						inv_data.append({
							"item_id": String(slot.item.id),
							"count": slot.count
						})
			result.append({
				"name": c.colonist_name if "colonist_name" in c else "Житель",
				"profession": String(c.profession) if "profession" in c else "settler",
				"health": c.current_health if "current_health" in c else 100.0,
				"position": {"x": c.global_position.x, "y": c.global_position.y, "z": c.global_position.z},
				"inventory": inv_data
			})
	return result


# ------------------------------------------------------------------------------
# Десеріалізація підсистем
# ------------------------------------------------------------------------------
func _deserialize_era(data: Dictionary) -> void:
	if EraManager == null:
		return
	var era_val: int = int(data.get("current_era", 0))
	var techs: Array = data.get("unlocked_techs", [])
	if EraManager.has_method("restore_era_data"):
		EraManager.restore_era_data(era_val, techs)
	else:
		EraManager.set_era(era_val)


func _deserialize_game_time(data: Dictionary) -> void:
	if GameManager == null:
		return
	GameManager.current_day = int(data.get("day", 1))
	GameManager.in_game_time_seconds = float(data.get("time_seconds", 8.0 * 3600.0))
	if EventBus != null:
		EventBus.day_passed.emit(GameManager.current_day)
		EventBus.day_time_updated.emit(GameManager.get_current_hour(), GameManager.get_current_minute())


func _deserialize_player(data: Dictionary) -> void:
	var p = _find_player()
	if p == null:
		return

	if data.has("position"):
		var pos = data["position"]
		p.global_position = Vector3(float(pos["x"]), float(pos["y"]), float(pos["z"]))
	if data.has("rotation_y"):
		p.rotation.y = float(data["rotation_y"])
	if data.has("energy") and "current_energy" in p:
		p.current_energy = float(data["energy"])
	if data.has("health") and "current_health" in p:
		p.current_health = float(data["health"])
	if data.has("active_slot") and p.has_method("select_hotbar_slot"):
		p.select_hotbar_slot(int(data["active_slot"]))

	if data.has("inventory") and p.inventory != null:
		if p.inventory.has_method("clear"):
			p.inventory.clear()
		for itm in data["inventory"]:
			var itm_id = StringName(itm.get("item_id", ""))
			var itm_count = int(itm.get("count", 1))
			if itm_id != &"" and ItemDatabase != null:
				var res = ItemDatabase.get_item(itm_id)
				if res != null:
					p.inventory.add_item(res, itm_count)


func _deserialize_blocks(data: Array) -> void:
	if BlockManager != null and BlockManager.has_method("restore_blocks_data"):
		BlockManager.restore_blocks_data(data)


func _deserialize_modular(data: Array) -> void:
	if ModularManager != null and ModularManager.has_method("restore_modular_data"):
		ModularManager.restore_modular_data(data)


func _deserialize_buildings(data: Array) -> void:
	# 1. Зносимо існуючі споруди
	var b_nodes = get_tree().get_nodes_in_group("buildings")
	for b in b_nodes:
		if is_instance_valid(b) and b is BuildingEntity3DScript:
			if "occupied_cells" in b:
				for c in b.occupied_cells:
					GridManager.unregister_occupant(c, true)
			b.queue_free()

	# 2. Відновлюємо будівлі зі збережених даних
	var container := _get_default_spawn_container()
	for b_dict in data:
		if not (b_dict is Dictionary):
			continue
		var b_id = StringName(b_dict.get("building_id", &""))
		var b_data = BuildingPlacementController.get_building(b_id) if BuildingPlacementController != null else null
		if b_data == null:
			continue

		var bld := BuildingEntity3DScript.new()
		container.add_child(bld)
		var origin_coords = b_dict.get("origin_cell", [0, 0])
		var origin := Vector2i(int(origin_coords[0]), int(origin_coords[1]))
		var rot_idx := int(b_dict.get("rotation_index", 0))
		bld.setup_building(b_data, origin, rot_idx)

		if bld.inventory != null and b_dict.has("inventory"):
			for itm in b_dict["inventory"]:
				var itm_id = StringName(itm.get("item_id", ""))
				var count = int(itm.get("count", 1))
				if itm_id != &"" and ItemDatabase != null:
					var item_res = ItemDatabase.get_item(itm_id)
					if item_res != null:
						bld.inventory.add_item(item_res, count)


func _deserialize_colonists(data: Array) -> void:
	var existing = get_tree().get_nodes_in_group("colonists")
	for c in existing:
		if is_instance_valid(c):
			c.queue_free()

	var container := _get_default_spawn_container()
	for c_dict in data:
		if not (c_dict is Dictionary):
			continue
		var col = Colonist3DScene.instantiate()
		container.add_child(col)
		if c_dict.has("position"):
			var p = c_dict["position"]
			col.global_position = Vector3(float(p["x"]), float(p["y"]), float(p["z"]))
		var col_name: String = c_dict.get("name", "Житель")
		var col_prof: StringName = StringName(c_dict.get("profession", "settler"))
		col.setup_colonist(col_name, col_prof)
		if c_dict.has("health") and "current_health" in col:
			col.current_health = float(c_dict["health"])

		if c_dict.has("inventory") and col.inventory != null:
			for itm in c_dict["inventory"]:
				var itm_id = StringName(itm.get("item_id", ""))
				var count = int(itm.get("count", 1))
				if itm_id != &"" and ItemDatabase != null:
					var item_res = ItemDatabase.get_item(itm_id)
					if item_res != null:
						col.inventory.add_item(item_res, count)


# ------------------------------------------------------------------------------
# Допоміжні функції пошуку сутностей
# ------------------------------------------------------------------------------
func _find_player() -> Node:
	var players = get_tree().get_nodes_in_group("player")
	if not players.is_empty() and is_instance_valid(players[0]):
		return players[0]
	return get_tree().root.find_child("Player3D", true, false)


func _get_default_spawn_container() -> Node:
	var main = get_tree().root.get_node_or_null("Main")
	if main != null:
		var world_3d = main.get_node_or_null("World3D")
		if world_3d != null:
			return world_3d
		return main
	return get_tree().current_scene if get_tree().current_scene != null else get_tree().root
