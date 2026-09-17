# Skill: 2D Grid & Pathfinding System (AStarGrid2D & TileMap)

## 1. Опис та Призначення (Overview)
Цей скіл описує стандарти роботи з 2D сіткою (Grid), розміщенням об'єктів у тайлових координатах та швидким пошуком шляхів (Pathfinding) для колоністів у грі **Saecula** на Godot 4.

Для пісочниці-колонії ідеальним вибором є **`AStarGrid2D`**:
* Працює безпосередньо з тайловими координатами (cell `Vector2i(x, y)`).
* Дозволяє миттєво позначати клітинки як непрохідні (`set_point_solid`) при будівництві стін або спавні дерев.
* Підтримує зміну вартості проходу (`weight_scale`): дороги роблять рух швидшим, болото чи багнюка — повільнішим.
* Висока продуктивність для сотень юнітів без потреби перепікання (baking) NavMesh у реальному часі.

---

## 2. Стандарти розмірів та координат

* **Розмір тайла за замовчуванням:** `32x32` пікселів (константа `TILE_SIZE`).
* **Система координат:**
  * **Світові координати (`Vector2`):** абсолютна позиція сутностей у пікселях на екрані.
  * **Тайлові координати (`Vector2i`):** дискретний індекс клітинки в сітці `(col, row)`.
* **Формули перетворення:**
  * `world_to_map(world_pos: Vector2) -> Vector2i`: `Vector2i((world_pos / TILE_SIZE).floor())`
  * `map_to_world(map_pos: Vector2i) -> Vector2`: `(Vector2(map_pos) * TILE_SIZE) + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)` (центр клітинки).

---

## 3. Базовий клас `GridManager.gd` (Autoload або Core Service)

```gdscript
# res://src/world/GridManager.gd
class_name GridManager
extends Node

## Сигнали зміни стану сітки
signal cell_occupied_changed(cell: Vector2i, is_solid: bool)
signal pathfinding_updated()

## Розмір тайла у пікселях
const TILE_SIZE: int = 32

## Розміри ігрової сітки (у клітинках)
@export var grid_width: int = 128
@export var grid_height: int = 128

var astar_grid: AStarGrid2D = AStarGrid2D.new()

## Словник об'єктів на сітці: Vector2i -> Node
var _occupants: Dictionary = {}

func _ready() -> void:
	_initialize_grid()

func _initialize_grid() -> void:
	astar_grid.region = Rect2i(0, 0, grid_width, grid_height)
	astar_grid.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	astar_grid.offset = Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER # Чисте пересування по 4 напрямках для тайлових ігор
	astar_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	astar_grid.update()

## Конвертація координат
func world_to_map(world_pos: Vector2) -> Vector2i:
	return Vector2i((world_pos / float(TILE_SIZE)).floor())

func map_to_world(map_pos: Vector2i) -> Vector2:
	return (Vector2(map_pos) * float(TILE_SIZE)) + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)

## Перевірка чи клітинка в межах карти
func is_within_bounds(map_pos: Vector2i) -> bool:
	return map_pos.x >= 0 and map_pos.x < grid_width and map_pos.y >= 0 and map_pos.y < grid_height

## Чи вільна клітинка для проходу
func is_cell_walkable(map_pos: Vector2i) -> bool:
	if not is_within_bounds(map_pos):
		return false
	return not astar_grid.is_point_solid(map_pos)

## Позначити клітинку як тверду (стіна, дерево, будівля)
func set_cell_solid(map_pos: Vector2i, solid: bool) -> void:
	if not is_within_bounds(map_pos):
		return
	astar_grid.set_point_solid(map_pos, solid)
	cell_occupied_changed.emit(map_pos, solid)

## Змінити вагу клітинки (наприклад, дороги = 0.5, бруд = 1.5)
func set_cell_weight(map_pos: Vector2i, weight: float) -> void:
	if not is_within_bounds(map_pos):
		return
	astar_grid.set_point_weight_scale(map_pos, weight)

## Зареєструвати об'єкт, який займає клітинку
func register_occupant(map_pos: Vector2i, occupant: Node, is_solid: bool = true) -> bool:
	if not is_within_bounds(map_pos) or _occupants.has(map_pos):
		return false
	_occupants[map_pos] = occupant
	if is_solid:
		set_cell_solid(map_pos, true)
	return true

## Звільнити клітинку
func unregister_occupant(map_pos: Vector2i) -> void:
	if _occupants.has(map_pos):
		_occupants.erase(map_pos)
		set_cell_solid(map_pos, false)

## Отримати список точок світового шляху між двома світовими координатами
func get_world_path(from_world: Vector2, to_world: Vector2) -> PackedVector2Array:
	var from_cell: Vector2i = world_to_map(from_world)
	var to_cell: Vector2i = world_to_map(to_world)
	
	if not is_within_bounds(from_cell) or not is_within_bounds(to_cell):
		return PackedVector2Array()
	
	# Якщо цільова клітинка тверда (наприклад, дерево чи склад), шукаємо сусідню вільну
	if astar_grid.is_point_solid(to_cell):
		to_cell = get_closest_walkable_neighbor(from_cell, to_cell)
		if to_cell == Vector2i(-1, -1):
			return PackedVector2Array()

	var id_path: Array[Vector2i] = astar_grid.get_id_path(from_cell, to_cell)
	var world_path: PackedVector2Array = PackedVector2Array()
	
	for cell in id_path:
		world_path.append(map_to_world(cell))
	
	return world_path

## Пошук сусідньої прохідної клітинки до непрохідного об'єкта
func get_closest_walkable_neighbor(from_cell: Vector2i, target_cell: Vector2i) -> Vector2i:
	var neighbors: Array[Vector2i] = [
		target_cell + Vector2i.UP,
		target_cell + Vector2i.DOWN,
		target_cell + Vector2i.LEFT,
		target_cell + Vector2i.RIGHT
	]
	
	var best_neighbor: Vector2i = Vector2i(-1, -1)
	var min_dist: float = INF
	
	for n in neighbors:
		if is_cell_walkable(n):
			var d: float = from_cell.distance_to(n)
			if d < min_dist:
				min_dist = d
				best_neighbor = n
				
	return best_neighbor
```

---

## 4. Паттерн слідування по сітці для колоніста

Коли колоніст отримує шлях через `GridManager.get_world_path()`, він рухається від точки до точки по масиву `PackedVector2Array`:

```gdscript
# Фрагмент коду руху колоніста за шляхом
var current_path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0

func follow_path(delta: float) -> void:
	if path_index >= current_path.size():
		velocity = Vector2.ZERO
		return
	
	var target_point: Vector2 = current_path[path_index]
	var distance_to_target: float = global_position.distance_to(target_point)
	
	if distance_to_target < 4.0:
		path_index += 1
		if path_index >= current_path.size():
			velocity = Vector2.ZERO
			return
		target_point = current_path[path_index]
	
	var direction: Vector2 = (target_point - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()
```

---

## 5. Інструкції для Gemini 3.8 Flash

1. **Не змішувати TileMap coordinates і World coordinates:** У коді завжди чітко розрізняй назви: `map_pos` або `cell_pos` (типу `Vector2i`) та `world_pos` (типу `Vector2`).
2. **Не розраховувати шлях кожного кадру:** Шлях рахується один раз при виникненні нового завдання або зміні перешкод на карті.
3. **Обробка взаємодії з непрохідними об'єктами:** Якщо колоніст рубає дерево або будує стіну, його ціль руху — це **сусідня прохідна клітинка** (`get_closest_walkable_neighbor`), а не сама клітинка дерева чи стіни!
