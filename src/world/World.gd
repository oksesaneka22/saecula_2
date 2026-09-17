extends Node2D

## World: Головна сцена світу гри.
## Ініціалізує тайлове поле під екран/гру, з'єднує розміри з GridManager,
## спавнить природні ресурси (дерева, каміння, кущі) та малює відладочну сітку (F3).

const ResourceNodeScene = preload("res://src/world/WorldResourceNode.tscn")

# Для 1920x1080 при TILE_SIZE=32 потрібно мінімум 60x34 тайли (1920x1088 px).
# Задаємо комфортне поле 80x50 (2560x1600 px), що повністю покриває і 1080p, і 1440p монітори.
@export var map_width: int = 80
@export var map_height: int = 50

@onready var ground_layer: TileMapLayer = $GroundLayer

var is_debug_grid_visible: bool = false

func _ready() -> void:
	# 1. Ініціалізуємо розміри GridManager під карту світу
	GridManager.initialize_grid(map_width, map_height)

	# 2. Процедурно заповнюємо поле тайлами землі та трави
	if ground_layer != null and ground_layer.has_method("generate_terrain"):
		ground_layer.generate_terrain(map_width, map_height)

	# 3. Спавнимо базові природні ресурси (Ітерація 4.3)
	_spawn_natural_resources()


func _spawn_natural_resources() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1337 # Фіксований сід для стабільності

	# Спавнимо дерева (TREE)
	for i in range(45):
		var cell = Vector2i(rng.randi_range(5, map_width - 6), rng.randi_range(5, map_height - 6))
		if _is_cell_free_from_player(cell) and GridManager.is_cell_walkable(cell):
			_create_resource_node(cell, 0, &"wood", 3.0, 2, 4) # 0 = TREE

	# Спавнимо каміння (ROCK)
	for i in range(25):
		var cell = Vector2i(rng.randi_range(5, map_width - 6), rng.randi_range(5, map_height - 6))
		if _is_cell_free_from_player(cell) and GridManager.is_cell_walkable(cell):
			_create_resource_node(cell, 1, &"stone", 4.0, 2, 3) # 1 = ROCK

	# Спавнимо кущі ягід (BUSH)
	for i in range(20):
		var cell = Vector2i(rng.randi_range(5, map_width - 6), rng.randi_range(5, map_height - 6))
		if _is_cell_free_from_player(cell) and GridManager.is_cell_walkable(cell):
			_create_resource_node(cell, 2, &"berries", 1.0, 3, 5) # 2 = BUSH


func _is_cell_free_from_player(cell: Vector2i) -> bool:
	var player_center_cell = Vector2i(40, 25) # Player спавниться на Vector2(1280, 800) -> (40, 25)
	return Vector2(cell).distance_to(Vector2(player_center_cell)) > 4.0


func _create_resource_node(cell: Vector2i, type: int, drop_id: StringName, hp: float, min_drop: int, max_drop: int) -> void:
	var node = ResourceNodeScene.instantiate()
	node.resource_type = type
	node.drop_item_id = drop_id
	node.max_health = hp
	node.current_health = hp
	node.drop_min_amount = min_drop
	node.drop_max_amount = max_drop
	node.global_position = GridManager.map_to_world(cell)
	add_child(node)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug_grid"):
		toggle_debug_grid()
		get_viewport().set_input_as_handled()


func toggle_debug_grid() -> void:
	is_debug_grid_visible = not is_debug_grid_visible
	queue_redraw()
	EventBus.notification_posted.emit(
		"Debug",
		"Відображення сітки: %s" % ("УВІМКНЕНО" if is_debug_grid_visible else "ВИМКНЕНО"),
		GameManager.NotificationType.INFO
	)


func _draw() -> void:
	if not is_debug_grid_visible:
		return

	var tile_size: float = float(GridManager.TILE_SIZE)
	var world_w: float = float(map_width) * tile_size
	var world_h: float = float(map_height) * tile_size
	var line_color: Color = Color(1.0, 1.0, 1.0, 0.3)
	var border_color: Color = Color(1.0, 0.8, 0.2, 0.7)

	# Вертикальні лінії сітки
	for x in range(map_width + 1):
		var px: float = float(x) * tile_size
		draw_line(Vector2(px, 0.0), Vector2(px, world_h), line_color, 1.0)

	# Горизонтальні лінії сітки
	for y in range(map_height + 1):
		var py: float = float(y) * tile_size
		draw_line(Vector2(0.0, py), Vector2(world_w, py), line_color, 1.0)

	# Зовнішня рамка карти
	draw_rect(Rect2(0.0, 0.0, world_w, world_h), border_color, false, 2.0)
