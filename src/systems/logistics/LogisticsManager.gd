extends Node

## LogisticsManager: Центральний менеджер складів та логістики колонії.
## Відстежує всі зареєстровані склади, скрині та сховища (Stockpiles & Containers),
## веде загальний облік доступних ресурсів у поселенні, координує розподіл предметів,
## пошук сховищ із вільним місцем та запити на вилучення ресурсів робітниками або будівництвом.
## Забезпечує інтелектуальний розподіл точок підходу до складів (Anti-crowding) для запобігання скупченню.

signal stockpile_registered(stockpile: Node)
signal stockpile_unregistered(stockpile: Node)
signal colony_storage_updated(item_id: StringName, total_count: int)

var _stockpiles: Array[Node] = []
var _claimed_arrival_slots: Dictionary = {} # colonist_instance_id (int) -> Vector3


func _ready() -> void:
	_claimed_arrival_slots.clear()
	print("[LogisticsManager] Логістичний менеджер колонії успішно ініціалізовано.")


## Реєструє нове сховище або майданчик складу в логістичній мережі колонії
func register_stockpile(stockpile: Node) -> void:
	if stockpile == null or _stockpiles.has(stockpile):
		return

	_stockpiles.append(stockpile)

	# Автоматичне відписування при видаленні вузла з дерева
	if not stockpile.tree_exited.is_connected(_on_stockpile_tree_exited.bind(stockpile)):
		stockpile.tree_exited.connect(_on_stockpile_tree_exited.bind(stockpile))

	# Підключення до сигналу оновлення інвентаря
	var inv: Node = _get_stockpile_inventory(stockpile)
	if inv != null and inv.has_signal("inventory_updated"):
		if not inv.inventory_updated.is_connected(_on_stockpile_inventory_updated):
			inv.inventory_updated.connect(_on_stockpile_inventory_updated)

	stockpile_registered.emit(stockpile)
	EventBus.stockpile_registered.emit(stockpile)

	print("[LogisticsManager] Зареєстровано сховище '%s'. Усього активних складів: %d" % [
		stockpile.name,
		_stockpiles.size()
	])


## Видаляє сховище з логістичної мережі
func unregister_stockpile(stockpile: Node) -> void:
	if stockpile == null or not _stockpiles.has(stockpile):
		return

	var inv: Node = _get_stockpile_inventory(stockpile)
	if inv != null and inv.has_signal("inventory_updated"):
		if inv.inventory_updated.is_connected(_on_stockpile_inventory_updated):
			inv.inventory_updated.disconnect(_on_stockpile_inventory_updated)

	_stockpiles.erase(stockpile)
	_clean_stale_reservations()

	stockpile_unregistered.emit(stockpile)
	EventBus.stockpile_unregistered.emit(stockpile)

	print("[LogisticsManager] Сховище '%s' знято з обліку. Залишилось складів: %d" % [
		stockpile.name,
		_stockpiles.size()
	])


func _on_stockpile_tree_exited(stockpile: Node) -> void:
	unregister_stockpile(stockpile)


func _on_stockpile_inventory_updated() -> void:
	EventBus.inventory_changed.emit(self)


## Повертає масив усіх активних зареєстрованих складів
func get_all_stockpiles() -> Array[Node]:
	var active: Array[Node] = []
	for s in _stockpiles:
		if is_instance_valid(s):
			active.append(s)
	return active


## Повертає кількість зареєстрованих складів
func get_stockpiles_count() -> int:
	return get_all_stockpiles().size()


## Повертає загальну кількість вказаного предмета на всіх складах колонії
func get_available_item_count(item_id: StringName) -> int:
	var total: int = 0
	for s in get_all_stockpiles():
		var inv = _get_stockpile_inventory(s)
		if inv != null and inv.has_method("get_item_count"):
			total += inv.get_item_count(item_id)
		elif s.has_method("get_available_item_count"):
			total += s.get_available_item_count(item_id)
	return total


## Перевіряє, чи є щонайменше min_amount заданого предмета на складах колонії
func has_item(item_id: StringName, min_amount: int = 1) -> bool:
	return get_available_item_count(item_id) >= min_amount


## Повертає словник усіх наявних на складах предметів { item_id: total_amount }
func get_total_stored_items() -> Dictionary:
	var summary: Dictionary = {}
	for s in get_all_stockpiles():
		var inv = _get_stockpile_inventory(s)
		if inv != null and inv.has_method("get_all_items"):
			var items: Array = inv.get_all_items()
			for slot in items:
				if slot != null and slot.item != null and slot.count > 0:
					var id: StringName = slot.item.id
					summary[id] = summary.get(id, 0) + slot.count
	return summary


## Знаходить перше сховище, в якому є щонайменше min_amount заданого ресурсу
func find_stockpile_with_item(item_id: StringName, min_amount: int = 1) -> Node:
	for s in get_all_stockpiles():
		var inv = _get_stockpile_inventory(s)
		if inv != null and inv.has_method("has_item"):
			if inv.has_item(item_id, min_amount):
				return s
		elif s.has_method("get_available_item_count"):
			if s.get_available_item_count(item_id) >= min_amount:
				return s
	return null


## Знаходить перше сховище, здатне прийняти заданий ресурс
func find_stockpile_with_space(item_id: StringName, amount: int = 1) -> Node:
	var item_res: Resource = ItemDatabase.get_item(item_id) if ItemDatabase != null else null
	for s in get_all_stockpiles():
		var inv = _get_stockpile_inventory(s)
		if inv != null:
			# Перевіряємо наявність вільних слотів або слотів для стакування
			if inv.has_method("has_free_slot") and inv.has_free_slot():
				return s
			if item_res != null and inv.has_method("can_accept_item"):
				if inv.can_accept_item(item_res, amount):
					return s
	return null


## Вносить предмет на склади колонії. Повертає залишок, який не помістився (0 = успіх)
func deposit_item(item_id: StringName, amount: int) -> int:
	if amount <= 0:
		return 0

	var item_res: Resource = ItemDatabase.get_item(item_id) if ItemDatabase != null else null
	if item_res == null:
		return amount

	var remaining: int = amount
	for s in get_all_stockpiles():
		if remaining <= 0:
			break
		var inv = _get_stockpile_inventory(s)
		if inv != null and inv.has_method("add_item"):
			remaining = inv.add_item(item_res, remaining)
		elif s.has_method("deposit_item"):
			remaining = s.deposit_item(item_id, remaining)

	var deposited: int = amount - remaining
	if deposited > 0:
		var new_total: int = get_available_item_count(item_id)
		colony_storage_updated.emit(item_id, new_total)
		EventBus.colony_storage_updated.emit(item_id, new_total)

	return remaining


## Вилучає до amount одиниць предмета зі складів колонії. Повертає фактично вилучену кількість.
func withdraw_item(item_id: StringName, amount: int) -> int:
	if amount <= 0:
		return 0

	var needed: int = amount
	var withdrawn: int = 0

	for s in get_all_stockpiles():
		if needed <= 0:
			break

		var inv = _get_stockpile_inventory(s)
		if inv != null and inv.has_method("get_item_count") and inv.has_method("remove_item"):
			var cur: int = inv.get_item_count(item_id)
			if cur > 0:
				var to_take: int = mini(needed, cur)
				if inv.remove_item(item_id, to_take, true):
					withdrawn += to_take
					needed -= to_take
		elif s.has_method("withdraw_item"):
			var taken: int = s.withdraw_item(item_id, needed)
			withdrawn += taken
			needed -= taken

	if withdrawn > 0:
		var new_total: int = get_available_item_count(item_id)
		colony_storage_updated.emit(item_id, new_total)
		EventBus.colony_storage_updated.emit(item_id, new_total)

	return withdrawn


## Допоміжний метод вилучення компонента InventoryComponent з об'єкта
func _get_stockpile_inventory(stockpile: Node) -> Node:
	if stockpile == null:
		return null
	if stockpile.has_method("get_all_items") and stockpile.has_method("add_item"):
		return stockpile # Сам об'єкт є компонентом інвентаря
	if "inventory" in stockpile and stockpile.inventory != null:
		return stockpile.inventory
	if stockpile.has_node("BuildingInventory"):
		return stockpile.get_node("BuildingInventory")
	if stockpile.has_node("InventoryComponent"):
		return stockpile.get_node("InventoryComponent")
	return null


# ==============================================================================
# Розумний розподіл точок підходу до складу (Anti-crowding)
# ==============================================================================

## Повертає масив прохідних клітинок периметра навколо складу
func get_stockpile_perimeter_cells(stockpile: Node) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if stockpile == null:
		return cells

	if "occupied_cells" in stockpile and not stockpile.occupied_cells.is_empty():
		var occ_set: Dictionary = {}
		for c in stockpile.occupied_cells:
			occ_set[c] = true
		var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		var perim_dict: Dictionary = {}
		for c in stockpile.occupied_cells:
			for d in dirs:
				var neighbor: Vector2i = c + d
				if not occ_set.has(neighbor):
					perim_dict[neighbor] = true
		for p in perim_dict.keys():
			if GridManager == null or (GridManager.is_within_bounds(p) and GridManager.is_cell_walkable(p)):
				cells.append(p)
		if not cells.is_empty():
			return cells

	var origin: Vector2i = Vector2i.ZERO
	var eff_size: Vector2i = Vector2i(1, 1)

	if "origin_cell" in stockpile and "building_data" in stockpile and stockpile.building_data != null:
		origin = stockpile.origin_cell
		eff_size = stockpile.building_data.size_in_tiles
		if "rotation_index" in stockpile and stockpile.rotation_index % 2 == 1:
			eff_size = Vector2i(eff_size.y, eff_size.x)
	elif "origin_cell" in stockpile and "size_in_tiles" in stockpile:
		origin = stockpile.origin_cell
		eff_size = stockpile.size_in_tiles
	elif "map_position" in stockpile and "size_in_tiles" in stockpile:
		origin = stockpile.map_position
		eff_size = stockpile.size_in_tiles
	elif stockpile is Node3D and GridManager != null:
		origin = GridManager.world_to_map_3d((stockpile as Node3D).global_position)
		eff_size = Vector2i(1, 1)

	# Зовнішній периметр прямокутника
	for x in range(origin.x - 1, origin.x + eff_size.x + 1):
		cells.append(Vector2i(x, origin.y - 1))
		cells.append(Vector2i(x, origin.y + eff_size.y))
	for y in range(origin.y, origin.y + eff_size.y):
		cells.append(Vector2i(origin.x - 1, y))
		cells.append(Vector2i(origin.x + eff_size.x, y))

	var valid_cells: Array[Vector2i] = []
	for c in cells:
		if GridManager == null or (GridManager.is_within_bounds(c) and GridManager.is_cell_walkable(c)):
			valid_cells.append(c)

	return valid_cells


## Очищає застарілі резервації точок підходу
func _clean_stale_reservations() -> void:
	var to_remove: Array[int] = []
	for id in _claimed_arrival_slots.keys():
		var inst = instance_from_id(id)
		if inst == null or not is_instance_valid(inst) or not inst.is_inside_tree():
			to_remove.append(id)
		elif "current_state" in inst:
			var cur_st = inst.current_state
			if cur_st != &"haul" and cur_st != &"moveto":
				to_remove.append(id)
	for id in to_remove:
		_claimed_arrival_slots.erase(id)


## Звільняє зарезервовану точку підходу для конкретного колоніста
func release_arrival_position(actor: Node) -> void:
	if actor != null:
		_claimed_arrival_slots.erase(actor.get_instance_id())


## Обчислює найоптимальнішу точку прибуття до складу з урахуванням напрямку підходу та запобігання скупченню (Anti-Crowding)
func get_stockpile_arrival_position(stockpile: Node, actor: Node3D = null) -> Vector3:
	if stockpile == null:
		return Vector3.ZERO

	var default_pos: Vector3 = (stockpile as Node3D).global_position if stockpile is Node3D else Vector3.ZERO
	var perim_cells := get_stockpile_perimeter_cells(stockpile)

	var actor_pos: Vector3 = actor.global_position if actor != null else default_pos
	var actor_id: int = actor.get_instance_id() if actor != null else 0

	_clean_stale_reservations()

	var candidate_positions: Array[Vector3] = []
	if not perim_cells.is_empty():
		for c in perim_cells:
			if GridManager != null:
				candidate_positions.append(GridManager.map_to_world_3d(c, default_pos.y))
			else:
				candidate_positions.append(Vector3(float(c.x) + 0.5, default_pos.y, float(c.y) + 0.5))
	else:
		for i in range(8):
			var ang: float = float(i) * TAU / 8.0
			candidate_positions.append(default_pos + Vector3(cos(ang) * 1.8, 0.0, sin(ang) * 1.8))

	if candidate_positions.is_empty():
		return default_pos

	var best_pos: Vector3 = candidate_positions[0]
	var best_score: float = INF

	var other_colonist_positions: Array[Vector3] = []
	if actor != null and actor.is_inside_tree():
		var tree = actor.get_tree()
		if tree != null:
			for node in tree.get_nodes_in_group("colonists"):
				if node != actor and node is Node3D and is_instance_valid(node):
					other_colonist_positions.append((node as Node3D).global_position)

	for cand in candidate_positions:
		var score: float = actor_pos.distance_to(cand)

		# Штраф за резервацію іншим колоністом
		for res_id in _claimed_arrival_slots.keys():
			if res_id != actor_id:
				var res_pos: Vector3 = _claimed_arrival_slots[res_id]
				if cand.distance_to(res_pos) < 1.0:
					score += 50.0

		# Штраф за фізичну присутність іншого колоніста поруч
		for other_pos in other_colonist_positions:
			var dist_other = cand.distance_to(other_pos)
			if dist_other < 1.0:
				score += 30.0
			elif dist_other < 2.0:
				score += 10.0

		if score < best_score:
			best_score = score
			best_pos = cand

	if actor_id != 0:
		_claimed_arrival_slots[actor_id] = best_pos

	return best_pos
