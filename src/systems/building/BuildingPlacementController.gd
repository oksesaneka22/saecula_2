extends Node

## BuildingPlacementController: Керує системою креслень та розміщенням споруд (Blueprint Preview).
## Відповідає за вибір будівлі, розрахунок площі сітки, перевірку перешкод (валідацію),
## динамічну зміну кольору привида (зелений/червоний) та підтвердження розміщення.

signal placement_started(building: BuildingData)
signal placement_canceled()
signal placement_hover_updated(cell: Vector2i, is_valid: bool)
signal placement_confirmed(building: BuildingData, cell: Vector2i)
signal building_registered(building: BuildingData)

const BUILDINGS_DIR: String = "res://data/buildings/"

var _buildings: Dictionary = {} # StringName -> BuildingData
var _active_building: BuildingData = null
var _current_cell: Vector2i = Vector2i(-9999, -9999)
var _is_valid: bool = false
var _is_placing: bool = false
var _prev_game_state: int = 1 # GameManager.GameState.PLAYING


func _ready() -> void:
	_load_all_buildings()
	EventBus.building_placement_requested.connect(_on_building_placement_requested)
	EventBus.building_placement_canceled.connect(_on_building_placement_canceled)


## Завантажує всі наявні .tres файли будівель з папки res://data/buildings/
func _load_all_buildings() -> void:
	_buildings.clear()
	var dir = DirAccess.open(BUILDINGS_DIR)
	if dir == null:
		push_warning("[BuildingPlacementController] Не вдалося відкрити директорію: %s" % BUILDINGS_DIR)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var clean_name = file_name.trim_suffix(".remap")
			if clean_name.ends_with(".tres") or clean_name.ends_with(".res"):
				var full_path = BUILDINGS_DIR.path_join(clean_name)
				var bld_res = load(full_path)
				if bld_res is BuildingData:
					var bld_id: StringName = bld_res.id
					if bld_id == &"":
						bld_id = StringName(clean_name.get_basename())
						bld_res.id = bld_id
					_buildings[bld_id] = bld_res
					building_registered.emit(bld_res)
		file_name = dir.get_next()
	dir.list_dir_end()

	print("[BuildingPlacementController] Успішно завантажено %d споруд." % _buildings.size())


## Повертає конфігурацію будівлі за ідентифікатором
func get_building(building_id: StringName) -> BuildingData:
	return _buildings.get(building_id, null)


## Повертає масив усіх зареєстрованих споруд
func get_all_buildings() -> Array[BuildingData]:
	var result: Array[BuildingData] = []
	for b in _buildings.values():
		result.append(b)
	return result


## Чи активний наразі режим розміщення креслення
func is_placing() -> bool:
	return _is_placing


## Повертає поточну активну будівлю для розміщення
func get_active_building() -> BuildingData:
	return _active_building


## Повертає поточні координати наведення на сітці
func get_current_hover_cell() -> Vector2i:
	return _current_cell


## Чи валідне поточне місце для встановлення
func is_current_placement_valid() -> bool:
	return _is_valid


## Починає розміщення будівлі
func start_placement(building: BuildingData) -> void:
	if building == null:
		return

	_active_building = building
	_is_placing = true
	_is_valid = false
	_current_cell = Vector2i(-9999, -9999)

	if GameManager != null:
		_prev_game_state = GameManager.current_state
		GameManager.change_state(GameManager.GameState.BUILDING_MODE)

	placement_started.emit(_active_building)


## Починає розміщення будівлі за її ідентифікатором
func start_placement_by_id(building_id: StringName) -> void:
	var bld = get_building(building_id)
	if bld != null:
		start_placement(bld)
	else:
		push_warning("[BuildingPlacementController] Споруду '%s' не знайдено!" % str(building_id))


## Скасовує поточне розміщення
func cancel_placement() -> void:
	if not _is_placing:
		return

	_is_placing = false
	_active_building = null
	_is_valid = false
	_current_cell = Vector2i(-9999, -9999)

	if GameManager != null and GameManager.current_state == GameManager.GameState.BUILDING_MODE:
		GameManager.change_state(_prev_game_state)

	placement_canceled.emit()


## Повертає список усіх клітинок сітки, які займає споруда заданого розміру
func get_occupied_cells(origin_cell: Vector2i, size_in_tiles: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var sx: int = maxi(size_in_tiles.x, 1)
	var sy: int = maxi(size_in_tiles.y, 1)
	for dx in range(sx):
		for dy in range(sy):
			cells.append(Vector2i(origin_cell.x + dx, origin_cell.y + dy))
	return cells


## Перевіряє, чи можна розмістити споруду на вказаних координатах (origin)
func can_place_at(building: BuildingData, origin_cell: Vector2i) -> bool:
	if building == null:
		return false

	var occupied: Array[Vector2i] = get_occupied_cells(origin_cell, building.size_in_tiles)
	for cell in occupied:
		# 1. Клітинка має бути в межах карти
		if not GridManager.is_within_bounds(cell):
			return false
		# 2. Клітинка має бути прохідною (не скеля, не вода, не дерево)
		if not GridManager.is_cell_walkable(cell):
			return false
		# 3. Клітинка не повинна містити інших сутностей (об'єктів або будівель)
		if GridManager.get_occupant(cell) != null:
			return false

	return true


## Оновлює поточні координати курсора над сіткою та перераховує валідність
func update_hover(origin_cell: Vector2i) -> void:
	if not _is_placing or _active_building == null:
		return

	if _current_cell == origin_cell and _is_valid == can_place_at(_active_building, origin_cell):
		return

	_current_cell = origin_cell
	_is_valid = can_place_at(_active_building, origin_cell)
	placement_hover_updated.emit(_current_cell, _is_valid)


## Підтверджує розміщення споруди у поточній позиції
func confirm_placement() -> bool:
	if not _is_placing or _active_building == null:
		return false

	if not _is_valid:
		return false

	var placed_building = _active_building
	var placed_cell = _current_cell

	placement_confirmed.emit(placed_building, placed_cell)
	EventBus.construction_site_placed.emit(null, placed_building.id, placed_cell)

	cancel_placement()
	return true


func _on_building_placement_requested(building_id: StringName) -> void:
	start_placement_by_id(building_id)


func _on_building_placement_canceled() -> void:
	cancel_placement()
