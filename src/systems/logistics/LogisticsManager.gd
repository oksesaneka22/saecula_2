extends Node

## LogisticsManager: Центральний менеджер складів та логістики колонії.
## Відстежує всі зареєстровані склади, скрині та сховища (Stockpiles & Containers),
## веде загальний облік доступних ресурсів у поселенні, координує розподіл предметів,
## пошук сховищ із вільним місцем та запити на вилучення ресурсів робітниками або будівництвом.

signal stockpile_registered(stockpile: Node)
signal stockpile_unregistered(stockpile: Node)
signal colony_storage_updated(item_id: StringName, total_count: int)

var _stockpiles: Array[Node] = []


func _ready() -> void:
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
