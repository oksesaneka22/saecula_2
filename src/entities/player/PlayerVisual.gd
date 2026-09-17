extends Node2D

## PlayerVisual: Процедурний візуальний плейсхолдер персонажа гравця.
## Малює тіло, голову, напрямок погляду та тінь.
## Анімує невелике погойдування (breathe/walk bobbing) при пересуванні.

@onready var player: Node = get_parent()

var _anim_time: float = 0.0

func _process(delta: float) -> void:
	var is_moving: bool = false
	if player != null:
		var moving_val: Variant = player.get("is_moving")
		if moving_val is bool:
			is_moving = moving_val

	if is_moving:
		_anim_time += delta * 12.0
	else:
		_anim_time += delta * 2.0
	queue_redraw()


func _draw() -> void:
	var facing: Vector2 = Vector2.DOWN
	var is_moving: bool = false
	if player != null:
		var facing_val: Variant = player.get("facing_direction")
		if facing_val is Vector2:
			facing = facing_val
		var moving_val: Variant = player.get("is_moving")
		if moving_val is bool:
			is_moving = moving_val

	var bob_offset: float = sin(_anim_time) * (1.5 if is_moving else 0.5)

	# 1. Тінь під персонажем
	draw_ellipse(Vector2(0.0, 6.0), 10.0, 5.0, Color(0.0, 0.0, 0.0, 0.3))

	# 2. Тіло / Тулуб (синій комбінезон першопрохідця)
	var body_color: Color = Color("2e5a88")
	draw_circle(Vector2(0.0, -4.0 + bob_offset), 8.0, body_color)

	# 3. Голова / Обличчя
	var skin_color: Color = Color("e0ac69")
	draw_circle(Vector2(0.0, -13.0 + bob_offset), 6.0, skin_color)

	# 4. Волосся / Капюшон
	var hair_color: Color = Color("4a3525")
	draw_arc(Vector2(0.0, -14.0 + bob_offset), 6.0, PI, TAU, 12, hair_color, 2.5)

	# 5. Очі / Індикатор напрямку погляду
	var eye_pos: Vector2 = Vector2(0.0, -13.0 + bob_offset) + (facing * 3.5)
	draw_circle(eye_pos, 1.8, Color(0.1, 0.1, 0.1, 0.9))
