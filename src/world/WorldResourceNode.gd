extends StaticBody2D

## WorldResourceNode: Природний ресурсний об'єкт на карті світу (Дерево, Валун, Кущ ягід).
## Блокує тайл у GridManager як solid, має запас міцності (health),
## реагує на удари/видобуток (harvest), ефект тремтіння при ударі,
## та спавнить DroppedItem після знищення, звільняючи клітинку в GridManager.

enum ResourceType {
	TREE,       ## Дерево -> спавнить wood
	ROCK,       ## Кам'яна брила -> спавнить stone / flint
	BUSH        ## Кущ диких ягід -> спавнить berries
}

const DroppedItemScene = preload("res://src/entities/items/DroppedItem.tscn")

@export var resource_type: ResourceType = ResourceType.TREE
@export var max_health: float = 3.0
@export var current_health: float = 3.0
@export var drop_item_id: StringName = &"wood"
@export var drop_min_amount: int = 2
@export var drop_max_amount: int = 4

var _cell: Vector2i = Vector2i.ZERO
var _shake_tween: Tween = null
var _shake_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("resource_nodes")
	current_health = max_health

	# Автоматично прив'язуємось до найближчого центру клітинки сітки
	_cell = GridManager.world_to_map(global_position)
	global_position = GridManager.map_to_world(_cell)

	# Реєструємо себе в GridManager як тверду перешкоду
	GridManager.register_occupant(_cell, self, true)
	queue_redraw()


## Видобуток ресурсу (виклик від гравця або колоніста)
## tool_type: тип інструменту (AXE для дерева, PICKAXE для каменю, тощо)
## efficiency: коефіцієнт ефективності (базово 1.0)
func harvest(damage: float = 1.0, tool_type: int = 0) -> void:
	# Бонус ефективності відповідного інструменту
	var effective_damage: float = damage
	if resource_type == ResourceType.TREE and tool_type == 1: # AXE
		effective_damage *= 2.0
	elif resource_type == ResourceType.ROCK and tool_type == 2: # PICKAXE
		effective_damage *= 2.0

	current_health -= effective_damage
	_play_hit_effect()

	if current_health <= 0.0:
		_destroy_and_drop()


func _play_hit_effect() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()

	_shake_tween = create_tween()
	_shake_tween.tween_property(self, "_shake_offset", Vector2(-3.0, 0.0), 0.04)
	_shake_tween.tween_property(self, "_shake_offset", Vector2(3.0, 0.0), 0.04)
	_shake_tween.tween_property(self, "_shake_offset", Vector2.ZERO, 0.04)
	_shake_tween.step_finished.connect(func(_idx): queue_redraw())


func _destroy_and_drop() -> void:
	# Звільняємо клітинку в GridManager
	GridManager.unregister_occupant(_cell, true)

	# Спавнимо дроп
	var drop_count: int = randi_range(drop_min_amount, drop_max_amount)
	var drop = DroppedItemScene.instantiate()
	drop.global_position = global_position
	drop.set_item(drop_item_id, drop_count)
	get_parent().add_child(drop)

	queue_free()


func _draw() -> void:
	var pos: Vector2 = _shake_offset

	match resource_type:
		ResourceType.TREE:
			# Тінь
			draw_ellipse(pos + Vector2(0.0, 8.0), 12.0, 6.0, Color(0.0, 0.0, 0.0, 0.3))
			# Стовбур
			draw_rect(Rect2(pos.x - 4.0, pos.y - 2.0, 8.0, 12.0), Color("6b4226"))
			# Крона дерева (зелені нашарування)
			draw_circle(pos + Vector2(0.0, -12.0), 14.0, Color("2d6a4f"))
			draw_circle(pos + Vector2(-5.0, -16.0), 10.0, Color("40916c"))
			draw_circle(pos + Vector2(5.0, -14.0), 11.0, Color("52b788"))

		ResourceType.ROCK:
			# Тінь
			draw_ellipse(pos + Vector2(0.0, 6.0), 11.0, 5.0, Color(0.0, 0.0, 0.0, 0.3))
			# Валун (багатокутна кам'яна форма)
			var rock_pts: PackedVector2Array = [
				pos + Vector2(-10.0, 4.0),
				pos + Vector2(-12.0, -4.0),
				pos + Vector2(-4.0, -12.0),
				pos + Vector2(8.0, -10.0),
				pos + Vector2(12.0, -2.0),
				pos + Vector2(10.0, 6.0),
				pos + Vector2(0.0, 8.0)
			]
			draw_colored_polygon(rock_pts, Color("6c757d"))
			draw_polyline(rock_pts, Color("495057"), 1.5)

		ResourceType.BUSH:
			# Тінь
			draw_ellipse(pos + Vector2(0.0, 6.0), 10.0, 4.0, Color(0.0, 0.0, 0.0, 0.25))
			# Кущ
			draw_circle(pos + Vector2(-4.0, 0.0), 8.0, Color("38b000"))
			draw_circle(pos + Vector2(4.0, 1.0), 7.0, Color("70e000"))
			draw_circle(pos + Vector2(0.0, -4.0), 8.0, Color("007200"))
			# Червоні ягідки
			draw_circle(pos + Vector2(-3.0, -2.0), 2.0, Color("d90429"))
			draw_circle(pos + Vector2(3.0, -4.0), 2.0, Color("d90429"))
			draw_circle(pos + Vector2(1.0, 2.0), 2.0, Color("d90429"))
