extends Area2D

## DroppedItem: Предмет, що лежить у світі гри (World Item Drop).
## Підтримує плавне підстрибування/погойдування, виявлення гравця,
## плавне магнітне притягання до персонажа та додавання в його інвентар.

@export var item_id: StringName = &"wood"
@export var amount: int = 1

var _item_resource: Resource = null
var _is_being_picked_up: bool = false
var _target_player: Node = null
var _anim_time: float = 0.0

const MAGNET_SPEED: float = 380.0
const PICKUP_DISTANCE: float = 14.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 # Співпадає з Player CharacterBody2D
	body_entered.connect(_on_body_entered)
	_setup_visual()


func set_item(p_item_id: StringName, p_amount: int) -> void:
	item_id = p_item_id
	amount = maxi(1, p_amount)
	_setup_visual()


func _setup_visual() -> void:
	if ItemDatabase != null:
		_item_resource = ItemDatabase.get_item(item_id)
	queue_redraw()


func _process(delta: float) -> void:
	_anim_time += delta * 4.0
	queue_redraw()

	if _is_being_picked_up and is_instance_valid(_target_player):
		var target_pos: Vector2 = _target_player.global_position
		global_position = global_position.move_toward(target_pos, MAGNET_SPEED * delta)

		if global_position.distance_to(target_pos) <= PICKUP_DISTANCE:
			_collect_to_player(_target_player)


func _on_body_entered(body: Node2D) -> void:
	if _is_being_picked_up:
		return
	if body.is_in_group("player"):
		_target_player = body
		_is_being_picked_up = true


func _collect_to_player(player: Node) -> void:
	var inv: Node = player.get("inventory")
	if inv != null and inv.has_method("add_item_by_id"):
		var remainder: int = inv.add_item_by_id(item_id, amount)
		if remainder <= 0:
			queue_free()
		else:
			# Якщо інвентар переповнений, залишаємо залишок лежати
			amount = remainder
			_is_being_picked_up = false
			_target_player = null
	else:
		# Якщо немає інвентаря, просто звільняємо
		queue_free()


func _draw() -> void:
	var float_offset: float = sin(_anim_time) * 2.5

	# Тінь на землі
	draw_ellipse(Vector2(0.0, 4.0), 6.0, 3.0, Color(0.0, 0.0, 0.0, 0.25))

	# Процедурний колір відповідно до типу предмета
	var item_color: Color = Color("d4a373") # За замовчуванням деревина
	if item_id == &"stone":
		item_color = Color("8d99ae")
	elif item_id == &"flint":
		item_color = Color("2b2d42")
	elif item_id == &"berries":
		item_color = Color("d90429")

	# Іконка / маленький прямокутник ресурсу
	draw_circle(Vector2(0.0, float_offset), 5.0, item_color)
	draw_circle(Vector2(0.0, float_offset), 3.0, item_color.lightened(0.2))
