class_name InventorySlot
extends RefCounted

## InventorySlot: Окремий слот контейнера інвентаря.
## Зберігає посилання на ItemData (або Resource) та поточну кількість предметів.

var item: Resource = null
var count: int = 0

func _init(p_item: Resource = null, p_count: int = 0) -> void:
	item = p_item
	count = p_count


func is_empty() -> bool:
	return item == null or count <= 0


func clear() -> void:
	item = null
	count = 0


func get_item_id() -> StringName:
	if item != null:
		var raw_id: Variant = item.get("id")
		if raw_id is StringName:
			return raw_id
		elif raw_id is String:
			return StringName(raw_id)
	return &""


func get_max_stack() -> int:
	if item != null:
		var max_s: Variant = item.get("max_stack")
		if max_s is int and max_s > 0:
			return max_s
	return 64


func get_remaining_space() -> int:
	if is_empty():
		return 64
	return maxi(0, get_max_stack() - count)
