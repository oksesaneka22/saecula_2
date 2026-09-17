extends Camera2D

## GameCamera2D: Плавна 2D камера гравця
## Інтерактивне масштабування (коліщатко миші).

# ------------------------------------------------------------------------------
# Налаштування камери (Camera Settings)
# ------------------------------------------------------------------------------
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.5
@export var zoom_step: float = 0.15
@export var zoom_duration: float = 0.15

var _target_zoom: float = 1.0
var _zoom_tween: Tween

# ------------------------------------------------------------------------------
# Життєвий цикл (Lifecycle)
# ------------------------------------------------------------------------------
func _ready() -> void:
	# Вимикаємо position_smoothing: оскільки камера є дочірнім вузлом CharacterBody2D,
	# внутрішній алгоритм згладжування Camera2D намагається згладжувати локальну позицію (0,0),
	# що при частоті 60Hz створює фазове биття (стробоскопічний ефект вібрації) на 144Hz моніторах.
	position_smoothing_enabled = false
	_target_zoom = zoom.x


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("zoom_in"):
		zoom_in()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("zoom_out"):
		zoom_out()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------------------
# Логіка масштабування (Zooming)
# ------------------------------------------------------------------------------
func zoom_in() -> void:
	set_target_zoom(_target_zoom + zoom_step)


func zoom_out() -> void:
	set_target_zoom(_target_zoom - zoom_step)


func set_target_zoom(new_zoom: float) -> void:
	_target_zoom = clampf(new_zoom, min_zoom, max_zoom)

	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()

	_zoom_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_property(self, "zoom", Vector2(_target_zoom, _target_zoom), zoom_duration)
