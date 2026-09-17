extends Node2D

## World: Головна сцена світу гри.
## Ініціалізує тайлове поле під екран/гру, з'єднує розміри з GridManager
## та малює відладочну сітку (Debug Grid) при натисканні клавіші F3.

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
