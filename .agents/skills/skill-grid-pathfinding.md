# Skill: 3D Grid & Pathfinding System (AStarGrid2D on X-Z Plane)

## 1. Опис та Призначення (Overview)
Цей скіл описує стандарти роботи з **3D сіткою (Grid)** у грі **Saecula** (3D пісочниця-колонія та виживання від 1-ї особи / RTS-режим) на рушії Godot 4.
Світ гри є тривимірним (3D), де горизонтальний рух і логічна сітка колонії прив'язані до площини **X-Z**, а вісь **Y** відповідає за висоту (вертикальність, ландшафт, штабелювання воксельних блоків).

Для колонії використовується гібридний високопродуктивний підхід: **`AStarGrid2D`** для дискретної сітки розміщення споруд, вокселів і пошуку шляху колоністів у 3D просторі:
* Працює безпосередньо з координатами клітинок (cell `Vector2i(x, z)`).
* Розмір клітинки в 3D просторі: **`TILE_SIZE_3D = 1.0` метр**, що ідеально співпадає 1:1 з розміром воксельних блоків (`1.0 x 1.0 x 1.0м`).
* Дозволяє миттєво позначати клітинки як непрохідні (`set_point_solid`) при встановленні воксельних блоків (`WorldBlock3D`), зведенні 3D будівель або природних ресурсів.
* Не вимагає повільного перепікання (baking) NavMesh у реальному часі для сотень юнітів.

---

## 2. Стандарти розмірів та координати у 3D світі

* **Розмір 3D тайла (клітинки):** `TILE_SIZE_3D = 1.0` метра (1 метр = 1 воксельний блок Minecraft-style).
* **Система координат:**
  * **3D Світові координати (`Vector3`):** абсолютна позиція сутностей у метрах `(X - горизонталь, Y - висота, Z - глибина)`.
  * **Тайлові координати (`Vector2i`):** дискретний індекс клітинки сітки `Vector2i(tile_x, tile_z)`.
  * **Воксельні координати (`Vector3i`):** дискретні координати блоків у воксельній сітці `Vector3i(x, y, z)`.
* **Формули перетворення:**
  * `world_to_map_3d(world_pos: Vector3) -> Vector2i`: `Vector2i(int(floor(world_pos.x / TILE_SIZE_3D)), int(floor(world_pos.z / TILE_SIZE_3D)))`
  * `map_to_world_3d(map_pos: Vector2i, y: float = 0.0) -> Vector3`: `Vector3((map_pos.x * TILE_SIZE_3D) + (TILE_SIZE_3D * 0.5), y, (map_pos.y * TILE_SIZE_3D) + (TILE_SIZE_3D * 0.5))` (центр клітинки в 3D).

---

## 3. Менеджер сітки `GridManager.gd` (Autoload Singleton)

```gdscript
# res://src/world/GridManager.gd
extends Node

signal cell_solid_changed(cell: Vector2i, is_solid: bool)
signal cell_weight_changed(cell: Vector2i, weight: float)
signal grid_initialized(width: int, height: int)

const TILE_SIZE: int = 32 ## 2D піксельний розмір (для UI та 2D міні-карт)
const TILE_SIZE_3D: float = 1.0 ## 3D розмір клітинки в метрах (1 тайл = 1x1м)

@export var grid_width: int = 128
@export var grid_height: int = 128

var astar_grid: AStarGrid2D = AStarGrid2D.new()
var _occupants: Dictionary = {} ## Vector2i -> Node

func world_to_map_3d(world_pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / TILE_SIZE_3D)), int(floor(world_pos.z / TILE_SIZE_3D)))

func map_to_world_3d(map_pos: Vector2i, y: float = 0.0) -> Vector3:
	return Vector3(
		(float(map_pos.x) * TILE_SIZE_3D) + (TILE_SIZE_3D * 0.5),
		y,
		(float(map_pos.y) * TILE_SIZE_3D) + (TILE_SIZE_3D * 0.5)
	)

func is_cell_walkable(map_pos: Vector2i) -> bool:
	if not is_within_bounds(map_pos):
		return false
	return not astar_grid.is_point_solid(map_pos)

func set_cell_solid(map_pos: Vector2i, solid: bool) -> void:
	if not is_within_bounds(map_pos):
		return
	if astar_grid.is_point_solid(map_pos) == solid:
		return
	astar_grid.set_point_solid(map_pos, solid)
	cell_solid_changed.emit(map_pos, solid)

func get_world_path_3d(from_pos: Vector3, to_pos: Vector3) -> PackedVector3Array:
	var from_cell: Vector2i = world_to_map_3d(from_pos)
	var to_cell: Vector2i = world_to_map_3d(to_pos)
	if not is_within_bounds(from_cell) or not is_within_bounds(to_cell):
		return PackedVector3Array()

	if astar_grid.is_point_solid(to_cell):
		to_cell = get_closest_walkable_neighbor(from_cell, to_cell)
		if to_cell == Vector2i(-1, -1):
			return PackedVector3Array()

	var id_path: Array[Vector2i] = astar_grid.get_id_path(from_cell, to_cell)
	var path_3d: PackedVector3Array = PackedVector3Array()
	for cell in id_path:
		path_3d.append(map_to_world_3d(cell, 0.0))
	return path_3d
```

---

## 4. Паттерн пересування 3D колоніста за вейпоінтами

Коли 3D колоніст отримує шлях через `GridManager.get_world_path_3d()`, він переміщується між точками `PackedVector3Array` у горизонтальній площині X-Z з урахуванням 3D фізики:

```gdscript
var current_path_3d: PackedVector3Array = PackedVector3Array()
var path_index: int = 0

func follow_path_3d(delta: float) -> void:
	if path_index >= current_path_3d.size():
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var target_pt: Vector3 = current_path_3d[path_index]
	var diff: Vector3 = target_pt - global_position
	diff.y = 0.0 # Рух у площині X-Z

	if diff.length() < 0.35:
		path_index += 1
		if path_index >= current_path_3d.size():
			velocity.x = 0.0
			velocity.z = 0.0
			return
		target_pt = current_path_3d[path_index]
		diff = target_pt - global_position
		diff.y = 0.0

	var dir: Vector3 = diff.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	move_and_slide()
```

---

## 5. Взаємні колізії споруд та воксельних блоків

* **Блоки блокують споруди:** Споруда (`BuildingPlacementController.can_place_at`) не може бути розміщена на клітинках, де вже розташовані воксельні блоки (`BlockManager.has_blocks_in_area`).
* **Споруди блокують блоки:** Блоки (`BlockManager.can_place_block_at`) не можуть бути розміщені всередині існуючих 3D будівель або будівельних майданчиків.
