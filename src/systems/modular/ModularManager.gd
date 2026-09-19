extends Node

## ModularManager: Менеджер модульного будівництва у стилі Going Medieval.
## Керує розміщенням та перевіркою структурних залежностей компонентів:
## 1. Підлога (modular_floor) — базова основа на землі.
## 2. Стіни (modular_wall), Опори (modular_pillar), Двері (modular_door) — потребують наявності підлоги!
## 3. Стеля/Дах (modular_roof) — потребує наявності стін або опор (макс. проліт 5 тайлів)!

signal blueprint_placed(piece: Node3D)
signal piece_built(piece: Node3D)
signal piece_removed(piece: Node3D)

const ModularPiece3DScript = preload("res://src/world3d/modular/ModularPiece3D.gd")

var _floors: Dictionary = {}      # Vector2i -> ModularPiece3D
var _structures: Dictionary = {}  # Vector2i -> ModularPiece3D (wall, pillar, door)
var _roofs: Dictionary = {}       # Vector2i -> ModularPiece3D (ceiling/roof)
var _all_pieces: Array[Node3D] = []

var container: Node3D = null


func _ready() -> void:
	print("[ModularManager] Менеджер модульного будівництва Going Medieval ініціалізовано.")


func set_container(p_container: Node3D) -> void:
	container = p_container


func has_floor(cell: Vector2i) -> bool:
	return _floors.has(cell) and is_instance_valid(_floors[cell])


func has_built_floor(cell: Vector2i) -> bool:
	return has_floor(cell) and _floors[cell].is_built


func has_structure(cell: Vector2i) -> bool:
	return _structures.has(cell) and is_instance_valid(_structures[cell])


func has_wall_or_pillar(cell: Vector2i) -> bool:
	if not has_structure(cell):
		return false
	var piece = _structures[cell]
	return piece.piece_type in [&"modular_wall", &"modular_pillar", &"modular_door"]


func has_built_wall_or_pillar(cell: Vector2i) -> bool:
	return has_wall_or_pillar(cell) and _structures[cell].is_built


func has_roof(cell: Vector2i) -> bool:
	return _roofs.has(cell) and is_instance_valid(_roofs[cell])


func has_built_roof(cell: Vector2i) -> bool:
	return has_roof(cell) and _roofs[cell].is_built


## Перевіряє, чи підтримується стеля на даній клітинці (стіна/опора на місці або в межах прольоту до 5 тайлів)
func can_support_roof(cell: Vector2i, max_span: int = 5) -> bool:
	if has_wall_or_pillar(cell):
		return true

	var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d in dirs:
		for step in range(1, max_span + 1):
			var check_cell = cell + (d * step)
			if has_wall_or_pillar(check_cell):
				return true

	return false


## Перевіряє, чи є збудовані опори/стіни для завершення стелі
func has_built_support_for_roof(cell: Vector2i, max_span: int = 5) -> bool:
	if has_built_wall_or_pillar(cell):
		return true

	var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d in dirs:
		for step in range(1, max_span + 1):
			var check_cell = cell + (d * step)
			if has_built_wall_or_pillar(check_cell):
				return true

	return false


## Перевіряє правила Going Medieval при розміщенні креслення
func can_place_modular_piece(piece_type: StringName, cell: Vector2i) -> bool:
	if not GridManager.is_within_bounds(cell):
		return false

	# Воксельні блоки заважають будь-якому будівництву
	if BlockManager != null and BlockManager.has_blocks_in_area(cell, Vector2i(1, 1)):
		return false

	match piece_type:
		&"modular_floor":
			if has_floor(cell):
				return false
			if not GridManager.is_cell_walkable(cell) and not has_structure(cell):
				return false
			return true

		&"modular_pillar", &"modular_wall", &"modular_door":
			# ПРАВИЛО: Не можна ставити стіни та опори до того, як буде підлога!
			if not has_floor(cell):
				return false
			if has_structure(cell):
				return false
			return true

		&"modular_roof":
			# ПРАВИЛО: Не можна ставити стелю до того, як будуть стіни чи опори!
			if not can_support_roof(cell):
				return false
			if has_roof(cell):
				return false
			return true

		_:
			return false


## Розміщує синє креслення модульної частини у 3D світі
func place_blueprint(piece_type: StringName, cell: Vector2i, rot_deg: float = 0.0) -> Node3D:
	if not can_place_modular_piece(piece_type, cell):
		return null

	var target_parent = _get_spawn_parent()
	var piece = ModularPiece3DScript.new()
	target_parent.add_child(piece)
	piece.setup_piece(piece_type, cell, false, rot_deg)

	match piece_type:
		&"modular_floor":
			_floors[cell] = piece
		&"modular_pillar", &"modular_wall", &"modular_door":
			_structures[cell] = piece
		&"modular_roof":
			_roofs[cell] = piece

	_all_pieces.append(piece)
	piece.tree_exited.connect(_on_piece_tree_exited.bind(piece))

	blueprint_placed.emit(piece)
	EventBus.construction_site_placed.emit(piece, piece_type, cell)
	return piece


## Розбиває велике креслення дерев'яної хатини на окремі модульні компоненти Going Medieval
func place_prefab_hut_blueprints(origin_cell: Vector2i, size_in_tiles: Vector2i, rot_index: int = 0) -> Array[Node3D]:
	var placed_pieces: Array[Node3D] = []
	var w: int = maxi(size_in_tiles.x, 2)
	var h: int = maxi(size_in_tiles.y, 2)

	# 1. По всій площі встановлюємо креслення підлоги
	for dx in range(w):
		for dy in range(h):
			var cell := origin_cell + Vector2i(dx, dy)
			if not has_floor(cell):
				var fl = place_blueprint(&"modular_floor", cell, 0.0)
				if fl != null:
					placed_pieces.append(fl)

	# 2. Визначаємо клітинку та орієнтацію дверей на основі rot_index
	var door_cell := origin_cell + Vector2i(w / 2, 0)
	var door_rot: float = 0.0
	match rot_index % 4:
		0:
			door_cell = origin_cell + Vector2i(w / 2, 0)
			door_rot = 0.0
		1:
			door_cell = origin_cell + Vector2i(w - 1, h / 2)
			door_rot = 90.0
		2:
			door_cell = origin_cell + Vector2i(w / 2, h - 1)
			door_rot = 180.0
		3:
			door_cell = origin_cell + Vector2i(0, h / 2)
			door_rot = 270.0

	# 3. 4 кути — вертикальні колоди-опори (modular_pillar)
	var corners = [
		origin_cell,
		origin_cell + Vector2i(w - 1, 0),
		origin_cell + Vector2i(0, h - 1),
		origin_cell + Vector2i(w - 1, h - 1)
	]
	for c in corners:
		if not has_structure(c):
			var pil = place_blueprint(&"modular_pillar", c, 0.0)
			if pil != null:
				placed_pieces.append(pil)

	# 4. Периметр стін та двері
	# Горизонтальні стіни (y = 0 та y = h - 1)
	for dx in range(1, w - 1):
		var c_front := origin_cell + Vector2i(dx, 0)
		if not has_structure(c_front):
			if c_front == door_cell:
				var d = place_blueprint(&"modular_door", c_front, door_rot)
				if d != null:
					placed_pieces.append(d)
			else:
				var wl = place_blueprint(&"modular_wall", c_front, 0.0)
				if wl != null:
					placed_pieces.append(wl)

		var c_back := origin_cell + Vector2i(dx, h - 1)
		if not has_structure(c_back):
			if c_back == door_cell:
				var d = place_blueprint(&"modular_door", c_back, door_rot)
				if d != null:
					placed_pieces.append(d)
			else:
				var wl = place_blueprint(&"modular_wall", c_back, 0.0)
				if wl != null:
					placed_pieces.append(wl)

	# Вертикальні стіни (x = 0 та x = w - 1)
	for dy in range(1, h - 1):
		var c_left := origin_cell + Vector2i(0, dy)
		if not has_structure(c_left):
			if c_left == door_cell:
				var d = place_blueprint(&"modular_door", c_left, door_rot)
				if d != null:
					placed_pieces.append(d)
			else:
				var wl = place_blueprint(&"modular_wall", c_left, 90.0)
				if wl != null:
					placed_pieces.append(wl)

		var c_right := origin_cell + Vector2i(w - 1, dy)
		if not has_structure(c_right):
			if c_right == door_cell:
				var d = place_blueprint(&"modular_door", c_right, door_rot)
				if d != null:
					placed_pieces.append(d)
			else:
				var wl = place_blueprint(&"modular_wall", c_right, 90.0)
				if wl != null:
					placed_pieces.append(wl)

	# 5. По всій площі встановлюємо солом'яну стелю (modular_roof)
	for dx in range(w):
		for dy in range(h):
			var cell := origin_cell + Vector2i(dx, dy)
			if not has_roof(cell):
				var rf = place_blueprint(&"modular_roof", cell, 0.0)
				if rf != null:
					placed_pieces.append(rf)

	print("[ModularManager] Розміщено креслення хатини (%dx%d) з %d окремих модульних компонентів." % [w, h, placed_pieces.size()])
	return placed_pieces


func notify_piece_built(piece: Node3D) -> void:
	piece_built.emit(piece)


func _on_piece_tree_exited(piece: Node3D) -> void:
	if piece == null:
		return
	var cell: Vector2i = piece.get("cell_coord")
	if _floors.get(cell) == piece:
		_floors.erase(cell)
	if _structures.get(cell) == piece:
		_structures.erase(cell)
	if _roofs.get(cell) == piece:
		_roofs.erase(cell)
	_all_pieces.erase(piece)
	piece_removed.emit(piece)


func remove_piece(piece: Node3D) -> void:
	if piece != null and is_instance_valid(piece):
		piece.queue_free()


func get_all_blueprints() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for p in _all_pieces:
		if is_instance_valid(p) and not p.get("is_built"):
			result.append(p)
	return result


func get_piece_at(cell: Vector2i, category: String) -> Node3D:
	match category:
		"floor":
			return _floors.get(cell, null)
		"structure":
			return _structures.get(cell, null)
		"roof":
			return _roofs.get(cell, null)
	return null


func clear_all() -> void:
	for p in _all_pieces:
		if is_instance_valid(p):
			p.queue_free()
	_floors.clear()
	_structures.clear()
	_roofs.clear()
	_all_pieces.clear()


func _get_spawn_parent() -> Node:
	if container != null and is_instance_valid(container):
		return container

	var scene = get_tree().current_scene
	if scene != null:
		var buildings = scene.find_child("Buildings", true, false)
		if buildings != null:
			container = buildings
			return container
		return scene
	return self
