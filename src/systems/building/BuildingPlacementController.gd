extends Node

## BuildingPlacementController: Керує системою креслень та розміщенням споруд (Blueprint Preview).
## Відповідає за вибір будівлі, обертання (R), розрахунок площі сітки, перевірку перешкод (валідацію),
## динамічну зміну кольору привида (зелений/червоний) та підтвердження розміщення.

signal placement_started(building: BuildingData)
signal placement_canceled()
signal placement_hover_updated(cell: Vector2i, is_valid: bool)
signal placement_confirmed(building: BuildingData, cell: Vector2i)
signal placement_rotation_changed(rot_index: int, rot_degrees: float)
signal building_registered(building: BuildingData)

const BUILDINGS_DIR: String = "res://data/buildings/"

var _buildings: Dictionary = {} # StringName -> BuildingData
var _active_building: BuildingData = null
var _current_cell: Vector2i = Vector2i(-9999, -9999)
var _is_valid: bool = false
var _is_placing: bool = false
var _prev_game_state: int = 1 # GameManager.GameState.PLAYING

var current_rotation: int = 0 ## 0: 0°, 1: 90°, 2: 180°, 3: 270°


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


## Повертає список усіх зареєстрованих споруд
func get_all_buildings() -> Array[BuildingData]:
	var list: Array[BuildingData] = []
	for b in _buildings.values():
		list.append(b)
	return list


## Чи активний зараз режим встановлення креслення
func is_placing() -> bool:
	return _is_placing


## Поточна активна будівля для встановлення
func get_active_building() -> BuildingData:
	return _active_building


## Повертає поточні координати наведення на сітці
func get_current_hover_cell() -> Vector2i:
	return _current_cell


## Чи валідне поточне місце для встановлення
func is_current_placement_valid() -> bool:
	return _is_valid


## Розраховує 3D світовий центр будівлі за її тайловою прив'язкою та розмірами
func get_building_world_center(origin_cell: Vector2i, size_in_tiles: Vector2i) -> Vector3:
	var center_x: float = (float(origin_cell.x) + float(size_in_tiles.x) * 0.5) * GridManager.TILE_SIZE_3D
	var center_z: float = (float(origin_cell.y) + float(size_in_tiles.y) * 0.5) * GridManager.TILE_SIZE_3D
	return Vector3(center_x, 0.0, center_z)


## Повертає ефективний розмір будівлі з урахуванням поточного повороту на 90/270 градусів
func get_effective_size(building: BuildingData) -> Vector2i:
	if building == null:
		return Vector2i(1, 1)
	if current_rotation % 2 == 1:
		return Vector2i(building.size_in_tiles.y, building.size_in_tiles.x)
	return building.size_in_tiles


## Обертає активне креслення на 90 градусів за годинниковою стрілкою
func rotate_placement(step: int = 1) -> void:
	current_rotation = (current_rotation + step) % 4
	if current_rotation < 0:
		current_rotation += 4
	var rot_deg: float = float(current_rotation) * 90.0
	placement_rotation_changed.emit(current_rotation, rot_deg)
	if _active_building != null and _current_cell != Vector2i(-9999, -9999):
		_is_valid = can_place_at(_active_building, _current_cell)
		placement_hover_updated.emit(_current_cell, _is_valid)


func get_rotation_degrees_y() -> float:
	return float(current_rotation) * 90.0


## Початок процесу розміщення будівлі
func start_placement(building: BuildingData) -> void:
	if building == null:
		return

	_active_building = building
	_is_placing = true
	_current_cell = Vector2i(-9999, -9999)
	_is_valid = false
	current_rotation = 0

	# Запам'ятовуємо попередній стан гри та перемикаємо у BUILDING_MODE
	if GameManager != null:
		_prev_game_state = GameManager.current_state
		GameManager.change_state(GameManager.GameState.BUILDING_MODE)

	placement_started.emit(_active_building)
	placement_rotation_changed.emit(0, 0.0)


## Початок процесу розміщення будівлі за її id
func start_placement_by_id(building_id: StringName) -> void:
	var bld = get_building(building_id)
	if bld != null:
		start_placement(bld)
	else:
		push_warning("[BuildingPlacementController] Споруду не знайдено: %s" % str(building_id))


## Скасування режиму розміщення
func cancel_placement() -> void:
	if not _is_placing:
		return

	_is_placing = false
	_active_building = null
	_current_cell = Vector2i(-9999, -9999)
	_is_valid = false
	current_rotation = 0

	if GameManager != null and GameManager.current_state == GameManager.GameState.BUILDING_MODE:
		GameManager.change_state(_prev_game_state)

	placement_canceled.emit()


## Повертає масив координат клітинок, які займатиме будівля
func get_occupied_cells(origin_cell: Vector2i, size_in_tiles: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(size_in_tiles.x):
		for y in range(size_in_tiles.y):
			cells.append(Vector2i(origin_cell.x + x, origin_cell.y + y))
	return cells


## Перевіряє, чи можна розмістити будівлю у заданій точці сітки
func can_place_at(building: BuildingData, origin_cell: Vector2i) -> bool:
	if building == null:
		return false

	# Модульні елементи Going Medieval перевіряються окремо через ModularManager
	if building.id.begins_with("modular_"):
		if ModularManager != null:
			return ModularManager.can_place_modular_piece(building.id, origin_cell)
		return false

	var eff_size: Vector2i = get_effective_size(building)
	var occupied: Array[Vector2i] = get_occupied_cells(origin_cell, eff_size)
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

	# 4. Воксельні блоки (WorldBlock3D) заважають зведенню споруди
	if BlockManager != null and BlockManager.has_blocks_in_area(origin_cell, eff_size):
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
func confirm_placement(keep_placing: bool = false) -> bool:
	if not _is_placing or _active_building == null:
		return false

	if not _is_valid:
		return false

	var placed_building = _active_building
	var placed_cell = _current_cell
	var placed_rot = current_rotation
	var eff_size = get_effective_size(placed_building)

	if placed_building.id == &"wooden_hut":
		if ModularManager != null:
			ModularManager.place_prefab_hut_blueprints(placed_cell, eff_size, placed_rot)
	elif placed_building.id.begins_with("modular_"):
		if ModularManager != null:
			ModularManager.place_blueprint(placed_building.id, placed_cell, float(placed_rot) * 90.0)
	else:
		placement_confirmed.emit(placed_building, placed_cell)
		EventBus.construction_site_placed.emit(null, placed_building.id, placed_cell)

	var should_continue: bool = keep_placing or Input.is_key_pressed(KEY_SHIFT)
	if should_continue:
		_is_valid = can_place_at(_active_building, _current_cell)
		placement_hover_updated.emit(_current_cell, _is_valid)
	else:
		cancel_placement()

	return true


func _unhandled_input(event: InputEvent) -> void:
	if not _is_placing:
		return

	# Клавіша 'R' обертає активне креслення на 90 градусів
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			rotate_placement(1)
			get_viewport().set_input_as_handled()


func _on_building_placement_requested(building_id: StringName) -> void:
	start_placement_by_id(building_id)


func _on_building_placement_canceled() -> void:
	cancel_placement()
