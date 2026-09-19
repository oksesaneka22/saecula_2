extends Node

## BlockManager: Менеджер воксельних блоків (дерево, камінь) у стилі Minecraft.
## Забезпечує перевірку сітки, розміщення 1x1x1м кубів, видалення та зв'язок із сіткою GridManager.

const WorldBlock3DScript = preload("res://src/world3d/blocks/WorldBlock3D.gd")

const BLOCK_SIZE: float = 1.0
const PLACEABLE_BLOCKS: Array[StringName] = [&"wood", &"stone"]

var _blocks: Dictionary = {} # Vector3i -> WorldBlock3D
var blocks_container: Node = null


func _ready() -> void:
	print("[BlockManager] Менеджер воксельних блоків ініціалізовано.")


## Перевіряє, чи є предмет здатним до встановлення як воксельний блок
func is_placeable_block(item_id: StringName) -> bool:
	return item_id in PLACEABLE_BLOCKS


## Конвертує світові координати у воксельну сітку Vector3i
func world_to_block_coord(pos: Vector3) -> Vector3i:
	return Vector3i(floori(pos.x), floori(pos.y), floori(pos.z))


## Конвертує координату сітки Vector3i у центр воксельного блоку
func block_coord_to_world(coord: Vector3i) -> Vector3:
	return Vector3(float(coord.x) + 0.5, float(coord.y) + 0.5, float(coord.z) + 0.5)


## Перевіряє можливість розміщення блоку в цільовій клітинці
func can_place_block_at(coord: Vector3i, excluded_aabb: AABB = AABB()) -> bool:
	if coord.y < 0:
		return false

	if _blocks.has(coord):
		return false

	# Заборона ставити блок всередині тіла гравця
	if excluded_aabb.size != Vector3.ZERO:
		var block_aabb := AABB(Vector3(coord.x, coord.y, coord.z), Vector3.ONE)
		if block_aabb.intersects(excluded_aabb):
			return false

	# Заборона ставити блоки всередині споруд, будівельних майданчиків або природних об'єктів
	if GridManager != null:
		var tile_pos := Vector2i(coord.x, coord.z)
		if GridManager.get_occupant(tile_pos) != null:
			return false

	# Межі ігрової карти
	if GridManager != null:
		var max_x: float = float(GridManager.grid_width) * GridManager.TILE_SIZE_3D
		var max_z: float = float(GridManager.grid_height) * GridManager.TILE_SIZE_3D
		if coord.x < 0 or coord.x >= int(max_x) or coord.z < 0 or coord.z >= int(max_z):
			return false

	return true


## Створює та встановлює блок у 3D світі
func place_block(block_type: StringName, coord: Vector3i, custom_container: Node = null) -> Node:
	if _blocks.has(coord):
		return null

	var container: Node = custom_container
	if container == null:
		container = blocks_container
	if container == null:
		container = self

	var block: Node = WorldBlock3DScript.new()
	container.add_child(block)
	if block.has_method("setup_block"):
		block.setup_block(block_type, coord)

	_blocks[coord] = block
	if block.has_signal("destroyed"):
		block.destroyed.connect(_on_block_destroyed)

	# Якщо блок стоїть на землі (Y=0), блокуємо клітинку 2D сітки для проходу колоністів
	if coord.y == 0 and GridManager != null and block is Node3D:
		var map_pos: Vector2i = GridManager.world_to_map_3d(block.position)
		GridManager.set_cell_solid(map_pos, true)

	EventBus.block_placed.emit(block_type, coord)
	return block


func _on_block_destroyed(coord: Vector3i) -> void:
	if _blocks.has(coord):
		_blocks.erase(coord)

	# Звільняємо клітинку сітки якщо на рівні землі не залишилось інших перешкод
	if coord.y == 0 and GridManager != null:
		var center: Vector3 = block_coord_to_world(coord)
		var map_pos: Vector2i = GridManager.world_to_map_3d(center)
		GridManager.set_cell_solid(map_pos, false)


## Перевіряє, чи є воксельні блоки у вертикальному стовпчику за тайловими координатами
func has_block_at_tile(tile_pos: Vector2i, min_y: int = 0, max_y: int = 16) -> bool:
	for y in range(min_y, max_y):
		if _blocks.has(Vector3i(tile_pos.x, y, tile_pos.y)):
			return true
	return false


## Перевіряє, чи є хоча б один воксельний блок у прямокутній зоні споруди
func has_blocks_in_area(origin_cell: Vector2i, size_in_tiles: Vector2i, min_y: int = 0, max_y: int = 16) -> bool:
	for dx in range(size_in_tiles.x):
		for dy in range(size_in_tiles.y):
			var cell := Vector2i(origin_cell.x + dx, origin_cell.y + dy)
			if has_block_at_tile(cell, min_y, max_y):
				return true
	return false


## Видаляє блок за координатою (з ефектом руйнування)
func remove_block(coord: Vector3i) -> bool:
	if _blocks.has(coord):
		var block: Node = _blocks[coord]
		if is_instance_valid(block) and block.has_method("destroy_block"):
			block.destroy_block()
		_blocks.erase(coord)
		return true
	return false


func get_block(coord: Vector3i) -> Node:
	return _blocks.get(coord, null)


func has_block(coord: Vector3i) -> bool:
	return _blocks.has(coord)


func get_block_count() -> int:
	return _blocks.size()


func get_all_blocks() -> Array:
	var result: Array = []
	for b in _blocks.values():
		if is_instance_valid(b):
			result.append(b)
	return result


func clear_all_blocks() -> void:
	for b in _blocks.values():
		if is_instance_valid(b):
			b.queue_free()
	_blocks.clear()
