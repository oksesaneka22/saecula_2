extends Control

## CrosshairUI: Приціл для режиму гри від першої особи (First-Person).
## Відображається лише в режимі прямого керування гравцем (PLAYING)
## та ховається при відкритому інвентарі, меню крафту або переході в режим поселення (RTS).

@export var dot_radius: float = 2.5
@export var dot_color: Color = Color(1.0, 1.0, 1.0, 0.75)
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 0.5)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.game_state_changed.connect(_on_game_state_changed)
	_update_visibility()


func _process(_delta: float) -> void:
	# Якщо курсор захоплено і стан PLAYING - приціл активний
	var should_be_visible: bool = (
		GameManager.current_state == GameManager.GameState.PLAYING and
		Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	)
	if visible != should_be_visible:
		visible = should_be_visible


func _on_game_state_changed(_new_state: int, _old_state: int) -> void:
	_update_visibility()


func _update_visibility() -> void:
	visible = (
		GameManager.current_state == GameManager.GameState.PLAYING and
		Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	)


func _draw() -> void:
	var center: Vector2 = size / 2.0
	# Зовнішнє напівпрозоре коло
	draw_circle(center, dot_radius + 1.0, outline_color)
	# Внутрішня біла точка прицілу
	draw_circle(center, dot_radius, dot_color)
