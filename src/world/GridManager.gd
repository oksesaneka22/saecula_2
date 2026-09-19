extends Node

## GridManager: Центральний менеджер тайлової сітки та пошуку шляхів (AStarGrid2D).
## Забезпечує роботу з координатами як 2D, так і 3D (X-Z площина), реєстрацію твердих перешкод,
## пошук шляхів для юнітів/колоністів та запити прохідності.

# ------------------------------------------------------------------------------
# Сигнали (Signals)
# ------------------------------------------------------------------------------
signal cell_solid_changed(cell: Vector2i, is_solid: bool)
signal cell_weight_changed(cell: Vector2i, weight: float)
signal cell_occupant_changed(cell: Vector2i, occupant: Node)
signal grid_initialized(width: int, height: int)

# ------------------------------------------------------------------------------
# Константи та параметри
# ------------------------------------------------------------------------------
const TILE_SIZE: int = 32
const TILE_SIZE_3D: float = 1.0 ## Розмір клітинки в метрах у 3D просторі (1 клітинка = 1x1м, ідентично воксельним блокам)

@export var grid_width: int = 128
@export var grid_height: int = 128

var astar_grid: AStarGrid2D = AStarGrid2D.new()

## Словник зайнятості клітинок сутностями або об'єктами: Vector2i -> Node
var _occupants: Dictionary = {}

# ------------------------------------------------------------------------------
# Життєвий цикл
# ------------------------------------------------------------------------------
func _ready() -> void:
	initialize_grid(grid_width, grid_height)


# ------------------------------------------------------------------------------
# Ініціалізація та конфігурація сітки
# ------------------------------------------------------------------------------
func initialize_grid(width: int, height: int) -> void:
	grid_width = width
	grid_height = height
	_occupants.clear()

	astar_grid.region = Rect2i(0, 0, grid_width, grid_height)
	astar_grid.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	astar_grid.offset = Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)

	# Для тайлової пісочниці 4-напрямний або евклідовий рух.
	# DIAGONAL_MODE_NEVER запобігає зрізанню кутів крізь тверді стіни.
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar_grid.update()

	grid_initialized.emit(grid_width, grid_height)


# ------------------------------------------------------------------------------
# Трансформації координат 2D (Vector2 <-> Vector2i)
# ------------------------------------------------------------------------------
## Перетворює 2D світові координати в пікселях на індекс клітинки сітки (Vector2i)
func world_to_map(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / float(TILE_SIZE))), int(floor(world_pos.y / float(TILE_SIZE))))


## Перетворює індекс клітинки сітки на координати центра клітинки у 2D світі (Vector2)
func map_to_world(map_pos: Vector2i) -> Vector2:
	return (Vector2(map_pos) * float(TILE_SIZE)) + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)


# ------------------------------------------------------------------------------
# Трансформації координат 3D (Vector3 <-> Vector2i на площині X-Z)
# ------------------------------------------------------------------------------
## Перетворює 3D світові координати (де Y - висота) на індекс клітинки сітки (Vector2i: x, z)
func world_to_map_3d(world_pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / TILE_SIZE_3D)), int(floor(world_pos.z / TILE_SIZE_3D)))


## Перетворює індекс клітинки сітки на координати центра клітинки у 3D світі (Vector3: X, Y, Z)
func map_to_world_3d(map_pos: Vector2i, y: float = 0.0) -> Vector3:
	return Vector3(
		(float(map_pos.x) * TILE_SIZE_3D) + (TILE_SIZE_3D / 2.0),
		y,
		(float(map_pos.y) * TILE_SIZE_3D) + (TILE_SIZE_3D / 2.0)
	)


## Перевіряє, чи знаходяться координати клітинки в межах розміру сітки
func is_within_bounds(map_pos: Vector2i) -> bool:
	return map_pos.x >= 0 and map_pos.x < grid_width and map_pos.y >= 0 and map_pos.y < grid_height


# ------------------------------------------------------------------------------
# Керування прохідністю та перешкодами
# ------------------------------------------------------------------------------
## Перевіряє, чи вільна клітинка для проходу персонажа або колоніста
func is_cell_walkable(map_pos: Vector2i) -> bool:
	if not is_within_bounds(map_pos):
		return false
	return not astar_grid.is_point_solid(map_pos)


## Перевіряє, чи є клітинка твердою непрохідною перешкодою
func is_cell_solid(map_pos: Vector2i) -> bool:
	if not is_within_bounds(map_pos):
		return true
	return astar_grid.is_point_solid(map_pos)


## Встановлює клітинку як тверду перешкоду (стіна, дерево, будівля) або вільну
func set_cell_solid(map_pos: Vector2i, solid: bool) -> void:
	if not is_within_bounds(map_pos):
		return
	if astar_grid.is_point_solid(map_pos) == solid:
		return

	astar_grid.set_point_solid(map_pos, solid)
	cell_solid_changed.emit(map_pos, solid)


## Задає коефіцієнт складності проходження клітинки (наприклад, дороги = 0.5, болото = 2.0)
func set_cell_weight(map_pos: Vector2i, weight: float) -> void:
	if not is_within_bounds(map_pos):
		return

	astar_grid.set_point_weight_scale(map_pos, maxf(weight, 0.1))
	cell_weight_changed.emit(map_pos, weight)


# ------------------------------------------------------------------------------
# Реєстрація об'єктів та сутностей на сітці
# ------------------------------------------------------------------------------
## Реєструє об'єкт на клітинці сітки (дерево, будівля, скриня тощо)
func register_occupant(map_pos: Vector2i, occupant: Node, is_solid: bool = true) -> bool:
	if not is_within_bounds(map_pos):
		return false
	if _occupants.has(map_pos):
		return false

	_occupants[map_pos] = occupant
	if is_solid:
		set_cell_solid(map_pos, true)

	cell_occupant_changed.emit(map_pos, occupant)
	return true


## Видаляє об'єкт із клітинки сітки та звільняє прохідність (якщо потрібно)
func unregister_occupant(map_pos: Vector2i, set_walkable: bool = true) -> void:
	if _occupants.has(map_pos):
		_occupants.erase(map_pos)
		if set_walkable:
			set_cell_solid(map_pos, false)
		cell_occupant_changed.emit(map_pos, null)


## Отримує об'єкт, закріплений за клітинкою (або null)
func get_occupant(map_pos: Vector2i) -> Node:
	return _occupants.get(map_pos, null)


# ------------------------------------------------------------------------------
# Пошук шляхів (Pathfinding) 2D та 3D
# ------------------------------------------------------------------------------
## Повертає масив 2D світових точок (Vector2) від початкової до кінцевої позиції.
func get_world_path(from_world: Vector2, to_world: Vector2) -> PackedVector2Array:
	var from_cell: Vector2i = world_to_map(from_world)
	var to_cell: Vector2i = world_to_map(to_world)

	if not is_within_bounds(from_cell) or not is_within_bounds(to_cell):
		return PackedVector2Array()

	if astar_grid.is_point_solid(to_cell):
		to_cell = get_closest_walkable_neighbor(from_cell, to_cell)
		if to_cell == Vector2i(-1, -1):
			return PackedVector2Array()

	var id_path: Array[Vector2i] = astar_grid.get_id_path(from_cell, to_cell)
	var world_path: PackedVector2Array = PackedVector2Array()

	for cell in id_path:
		world_path.append(map_to_world(cell))

	return world_path


## Повертає масив 3D світових точок (Vector3) на площині X-Z для навігації колоністів
func get_world_path_3d(from_world: Vector3, to_world: Vector3, y: float = 0.0) -> PackedVector3Array:
	var from_cell: Vector2i = world_to_map_3d(from_world)
	var to_cell: Vector2i = world_to_map_3d(to_world)

	if not is_within_bounds(from_cell) or not is_within_bounds(to_cell):
		return PackedVector3Array()

	if astar_grid.is_point_solid(to_cell):
		to_cell = get_closest_walkable_neighbor(from_cell, to_cell)
		if to_cell == Vector2i(-1, -1):
			return PackedVector3Array()

	var id_path: Array[Vector2i] = astar_grid.get_id_path(from_cell, to_cell)
	var world_path: PackedVector3Array = PackedVector3Array()

	for cell in id_path:
		world_path.append(map_to_world_3d(cell, y))

	return world_path


## Знаходить найближчу вільну клітинку з 4 кардинальних сусідів (Up, Down, Left, Right)
func get_closest_walkable_neighbor(from_cell: Vector2i, target_cell: Vector2i) -> Vector2i:
	var neighbors: Array[Vector2i] = [
		target_cell + Vector2i.UP,
		target_cell + Vector2i.DOWN,
		target_cell + Vector2i.LEFT,
		target_cell + Vector2i.RIGHT
	]

	var best_neighbor: Vector2i = Vector2i(-1, -1)
	var min_dist: float = INF

	for neighbor in neighbors:
		if is_cell_walkable(neighbor):
			var dist: float = Vector2(from_cell).distance_to(Vector2(neighbor))
			if dist < min_dist:
				min_dist = dist
				best_neighbor = neighbor

	return best_neighbor


## Повертає прямокутну область клітинок для будівель розміром NxM
func get_cells_in_area(origin_cell: Vector2i, size_in_tiles: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(size_in_tiles.x):
		for y in range(size_in_tiles.y):
			cells.append(origin_cell + Vector2i(x, y))
	return cells


## Перевіряє, чи вільні та прохідні всі клітинки під майбутню споруду
func is_area_clear(origin_cell: Vector2i, size_in_tiles: Vector2i) -> bool:
	for cell in get_cells_in_area(origin_cell, size_in_tiles):
		if not is_cell_walkable(cell):
			return false
	return true
