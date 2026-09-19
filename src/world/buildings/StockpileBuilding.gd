class_name StockpileBuilding
extends StaticBody2D

## StockpileBuilding: 2D сутність складу ресурсів / скрині поселення (Етап 7.1).
## Містить великий InventoryComponent (за замовчуванням 32 слоти),
## автоматично реєструється в глобальній логістичній системі LogisticsManager,
## надає методи для перевірки, вилучення та внесення матеріалів,
## а також обробляє взаємодію гравця (відкриття інтерфейсу передачі предметів).

const InventoryComponentScript = preload("res://src/systems/inventory/InventoryComponent.gd")

@export var building_id: StringName = &"stockpile"
@export var size_in_tiles: Vector2i = Vector2i(4, 4)
@export var slot_count: int = 32

var map_position: Vector2i = Vector2i.ZERO
var inventory: Node = null


func _ready() -> void:
	# 1. Створення та ініціалізація інвентаря складу
	if inventory == null:
		inventory = InventoryComponentScript.new()
		inventory.name = "BuildingInventory"
		inventory.set("slot_count", slot_count)
		add_child(inventory)

	# 2. Обчислення мапових координат, якщо не задані заздалегідь
	if map_position == Vector2i.ZERO and GridManager != null:
		map_position = GridManager.world_to_map(global_position)

	# 3. Реєстрація у глобальному логістичному менеджері поселення
	if LogisticsManager != null:
		LogisticsManager.register_stockpile(self)

	# 4. Реєстрація зайнятості клітинок у GridManager
	_register_grid_cells()

	# 5. Візуальне відображення
	queue_redraw()


func _exit_tree() -> void:
	if LogisticsManager != null:
		LogisticsManager.unregister_stockpile(self)
	_unregister_grid_cells()


func _register_grid_cells() -> void:
	if GridManager == null:
		return
	for x in range(size_in_tiles.x):
		for y in range(size_in_tiles.y):
			var cell: Vector2i = map_position + Vector2i(x, y)
			# Склад є прохідним для колоністів, але зареєстрований як споруда
			GridManager.register_occupant(cell, self, false)


func _unregister_grid_cells() -> void:
	if GridManager == null:
		return
	for x in range(size_in_tiles.x):
		for y in range(size_in_tiles.y):
			var cell: Vector2i = map_position + Vector2i(x, y)
			if GridManager.get_occupant(cell) == self:
				GridManager.unregister_occupant(cell, true)


## Повертає кількість конкретного предмета на цьому складі
func get_available_item_count(item_id: StringName) -> int:
	if inventory != null and inventory.has_method("get_item_count"):
		return inventory.get_item_count(item_id)
	return 0


## Вилучає count предметів зі складу. Повертає фактично вилучену кількість
func withdraw_item(item_id: StringName, count: int) -> int:
	if inventory == null or count <= 0:
		return 0

	var available: int = inventory.get_item_count(item_id)
	var to_withdraw: int = mini(available, count)
	if to_withdraw > 0:
		inventory.remove_item(item_id, to_withdraw, true)
	return to_withdraw


## Вносить count предметів на склад. Повертає залишок, який не помістився
func deposit_item(item_id: StringName, count: int) -> int:
	if inventory == null or count <= 0:
		return count

	var item_res: Resource = ItemDatabase.get_item(item_id) if ItemDatabase != null else null
	if item_res == null:
		return count

	return inventory.add_item(item_res, count)


## Взаємодія з гравцем: запит на відкриття вікна перенесення ресурсів
func interact(player: Node = null) -> void:
	EventBus.storage_ui_requested.emit(self)


func _draw() -> void:
	# Малювання дерев'яного настилу складу в 2D
	var tile_px: float = float(GridManager.TILE_SIZE if GridManager != null else 32)
	var total_size: Vector2 = Vector2(size_in_tiles.x * tile_px, size_in_tiles.y * tile_px)
	var rect: Rect2 = Rect2(Vector2.ZERO, total_size)

	# Базова дерев'яна площадка
	draw_rect(rect, Color(0.28, 0.2, 0.13, 0.85), true)
	draw_rect(rect, Color(0.48, 0.36, 0.22, 1.0), false, 2.0)

	# Розмітка внутрішніх зон
	for x in range(1, size_in_tiles.x):
		var x_pos: float = x * tile_px
		draw_line(Vector2(x_pos, 0), Vector2(x_pos, total_size.y), Color(0.38, 0.28, 0.18, 0.5), 1.0)
	for y in range(1, size_in_tiles.y):
		var y_pos: float = y * tile_px
		draw_line(Vector2(0, y_pos), Vector2(total_size.x, y_pos), Color(0.38, 0.28, 0.18, 0.5), 1.0)
