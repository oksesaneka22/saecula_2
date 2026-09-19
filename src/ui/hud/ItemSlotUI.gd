extends Control

## ItemSlotUI: Окремий слот інвентаря / хотбара для відображення предмета.
## Відображає фон слота, рамку вибору (для хотбара), реальну текстуру предмета,
## лічильник кількості в стаку та гарячу клавішу (1-8).

signal slot_clicked(slot_index: int)

const TextureHelper = preload("res://src/core3d/TextureHelper.gd")

@export var slot_size: Vector2 = Vector2(52.0, 52.0)

var slot_index: int = 0
var is_selected: bool = false:
	set(val):
		is_selected = val
		queue_redraw()

var hotkey_number: int = 0: # 1-8 або 0 (якщо без хоткею)
	set(val):
		hotkey_number = val
		queue_redraw()

var item_id: StringName = &""
var item_count: int = 0:
	set(val):
		item_count = val
		queue_redraw()

var display_name: String = ""
var item_texture: Texture2D = null


func _ready() -> void:
	custom_minimum_size = slot_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


func set_slot_data(p_item_res: Resource, p_count: int) -> void:
	if p_item_res != null and p_count > 0:
		var raw_id: Variant = p_item_res.get("id")
		item_id = StringName(raw_id) if raw_id != null else &""
		var raw_name: Variant = p_item_res.get("display_name")
		display_name = str(raw_name) if raw_name != null else str(item_id)
		item_count = p_count
		tooltip_text = "%s (%d)" % [display_name, item_count]

		var raw_icon = p_item_res.get("icon")
		if raw_icon is Texture2D:
			item_texture = raw_icon
		else:
			item_texture = TextureHelper.get_texture(TextureHelper.get_item_texture_path(item_id))
	else:
		item_id = &""
		item_count = 0
		display_name = ""
		tooltip_text = ""
		item_texture = null
	queue_redraw()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_clicked.emit(slot_index)


func _draw() -> void:
	var r: Rect2 = Rect2(Vector2.ZERO, size)

	# 1. Фон слота
	var bg_color: Color = Color(0.12, 0.14, 0.18, 0.85)
	draw_rect(r, bg_color, true)

	# 2. Рамка слота
	var border_color: Color = Color(0.3, 0.35, 0.42, 0.7)
	if is_selected:
		border_color = Color(1.0, 0.84, 0.0, 0.95) # Золота рамка для активного слота
		draw_rect(r, border_color, false, 2.5)
	else:
		draw_rect(r, border_color, false, 1.2)

	# 3. Текстура / Іконка предмета
	if item_count > 0 and item_id != &"":
		var center: Vector2 = r.get_center()
		if item_texture == null:
			item_texture = TextureHelper.get_texture(TextureHelper.get_item_texture_path(item_id))

		if item_texture != null:
			var icon_size: Vector2 = Vector2(34.0, 34.0)
			var icon_rect: Rect2 = Rect2(center - icon_size * 0.5, icon_size)
			draw_texture_rect(item_texture, icon_rect, false)
		else:
			var item_color: Color = Color("d4a373") # Wood
			if item_id == &"stone":
				item_color = Color("8d99ae")
			elif item_id == &"flint":
				item_color = Color("2b2d42")
			elif item_id == &"berries":
				item_color = Color("d90429")
			elif item_id == &"clay":
				item_color = Color("b85333")
			elif item_id == &"straw":
				item_color = Color("e0c068")

			draw_circle(center, 14.0, item_color)
			draw_circle(center, 10.0, item_color.lightened(0.2))

		# 4. Лічильник кількості в правому нижньому кутку
		var count_str: String = str(item_count)
		var font: Font = ThemeDB.fallback_font
		var font_size: int = 13
		var text_size: Vector2 = font.get_string_size(count_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var text_pos: Vector2 = Vector2(r.size.x - text_size.x - 4.0, r.size.y - 4.0)
		draw_string(font, text_pos + Vector2(1, 1), count_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.9))
		draw_string(font, text_pos, count_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

	# 5. Номер гарячої клавіші у лівому верхньому кутку (якщо є)
	if hotkey_number > 0:
		var key_str: String = str(hotkey_number)
		var font: Font = ThemeDB.fallback_font
		var font_size: int = 11
		var key_pos: Vector2 = Vector2(4.0, 12.0)
		draw_string(font, key_pos + Vector2(1, 1), key_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.8))
		draw_string(font, key_pos, key_str, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.7, 0.75, 0.8, 0.9))
