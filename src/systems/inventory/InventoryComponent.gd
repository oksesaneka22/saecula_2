class_name InventoryComponent
extends Node

## InventoryComponent: Універсальний модульний компонент інвентаря.
## Підходить для гравця, жителів колонії, скринь та будівельних складів.
## Підтримує обмежену кількість слотів, стакування за item.max_stack,
## додавання/видалення предметів та сигнал inventory_updated.

const SlotScript = preload("res://src/systems/inventory/InventorySlot.gd")

signal inventory_updated()
signal slot_changed(slot_index: int)
signal item_added(item: Resource, amount: int)
signal item_removed(item_id: StringName, amount: int)

@export var slot_count: int = 24:
	set(value):
		slot_count = maxi(1, value)
		_adjust_slots_size()

var slots: Array = [] # Array[InventorySlot]


func _ready() -> void:
	_init_slots()


func _init_slots() -> void:
	slots.clear()
	for i in range(slot_count):
		slots.append(SlotScript.new())


func _adjust_slots_size() -> void:
	if slots.size() == slot_count:
		return
	while slots.size() < slot_count:
		slots.append(SlotScript.new())
	while slots.size() > slot_count:
		slots.pop_back()
	inventory_updated.emit()


## Додає вказану кількість предмета до інвентаря.
## Повертає залишок, який не вдалося вмістити (0 якщо все додано успішно).
func add_item(item: Resource, amount: int) -> int:
	if item == null or amount <= 0:
		return amount

	var remaining: int = amount
	var item_id: StringName = _extract_item_id(item)
	var max_stack: int = _extract_max_stack(item)
	var modified: bool = false

	# 1. Фаза стакування в існуючі непорожні слоти з цим же предметом
	for i in range(slots.size()):
		var slot = slots[i]
		if not slot.is_empty() and slot.get_item_id() == item_id:
			var space: int = max_stack - slot.count
			if space > 0:
				var to_add: int = mini(remaining, space)
				slot.count += to_add
				remaining -= to_add
				modified = true
				slot_changed.emit(i)
				if remaining <= 0:
					break

	# 2. Фаза розміщення залишку у вільні порожні слоти
	if remaining > 0:
		for i in range(slots.size()):
			var slot = slots[i]
			if slot.is_empty():
				var to_add: int = mini(remaining, max_stack)
				slot.item = item
				slot.count = to_add
				remaining -= to_add
				modified = true
				slot_changed.emit(i)
				if remaining <= 0:
					break

	if modified:
		item_added.emit(item, amount - remaining)
		inventory_updated.emit()

	return remaining


## Додає предмет за його ID (автоматично отримує Resource з ItemDatabase).
## Повертає залишок, який не вдалося вмістити.
func add_item_by_id(item_id: StringName, amount: int) -> int:
	var item_res: Resource = ItemDatabase.get_item(item_id)
	if item_res == null:
		push_warning("[InventoryComponent] Предмет не знайдено в ItemDatabase: %s" % str(item_id))
		return amount
	return add_item(item_res, amount)


## Перевіряє, чи є в інвентарі вказана кількість предмета
func has_item(item_id: StringName, amount: int = 1) -> bool:
	return get_item_count(item_id) >= amount


## Підраховує сумарну кількість вказаного предмета у всіх слотах
func get_item_count(item_id: StringName) -> int:
	var total: int = 0
	for slot in slots:
		if not slot.is_empty() and slot.get_item_id() == item_id:
			total += slot.count
	return total


## Видаляє вказану кількість предмета з інвентаря.
## Повертає true, якщо вся кількість була успішно видалена.
## Якщо предметів менше ніж потрібно і allow_partial == false, інвентар не змінюється.
func remove_item(item_id: StringName, amount: int, allow_partial: bool = false) -> bool:
	if amount <= 0:
		return true

	var total_available: int = get_item_count(item_id)
	if total_available < amount and not allow_partial:
		return false

	var remaining_to_remove: int = amount
	var actual_removed: int = 0

	# Видаляємо починаючи з кінця або з перших знайдених слотів
	for i in range(slots.size()):
		var slot = slots[i]
		if not slot.is_empty() and slot.get_item_id() == item_id:
			var to_remove: int = mini(remaining_to_remove, slot.count)
			slot.count -= to_remove
			remaining_to_remove -= to_remove
			actual_removed += to_remove
			if slot.count <= 0:
				slot.clear()
			slot_changed.emit(i)
			if remaining_to_remove <= 0:
				break

	if actual_removed > 0:
		item_removed.emit(item_id, actual_removed)
		inventory_updated.emit()

	return remaining_to_remove <= 0


## Очищує весь інвентар
func clear_inventory() -> void:
	var modified: bool = false
	for i in range(slots.size()):
		if not slots[i].is_empty():
			slots[i].clear()
			modified = true
			slot_changed.emit(i)
	if modified:
		inventory_updated.emit()


## Повертає слот за індексом
func get_slot(index: int):
	if index >= 0 and index < slots.size():
		return slots[index]
	return null


## Повертає масив усіх зайнятих слотів у вигляді словників [{ "item": Resource, "count": int, "slot_index": int }]
func get_all_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(slots.size()):
		var slot = slots[i]
		if not slot.is_empty():
			result.append({
				"item": slot.item,
				"count": slot.count,
				"slot_index": i
			})
	return result


## Допоміжні методи вилучення властивостей
func _extract_item_id(item: Resource) -> StringName:
	var raw_id: Variant = item.get("id")
	if raw_id is StringName:
		return raw_id
	elif raw_id is String:
		return StringName(raw_id)
	return &""


func _extract_max_stack(item: Resource) -> int:
	var max_s: Variant = item.get("max_stack")
	if max_s is int and max_s > 0:
		return max_s
	return 64
