class_name SleepOverlayUI
extends Control

## SleepOverlayUI: Екранний ефект затемнення та напис сну.
## mouse_filter = Control.MOUSE_FILTER_IGNORE гарантує, що він не блокує ввід миші.

var color_rect: ColorRect = null
var label: Label = null
var _tween: Tween = null
var _is_animating: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

	if color_rect == null:
		color_rect = ColorRect.new()
		color_rect.name = "DimRect"
		color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		color_rect.color = Color(0, 0, 0, 0)
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(color_rect)

	if label == null:
		label = Label.new()
		label.name = "SleepLabel"
		label.text = "💤 Відновлення сил..."
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_CENTER)
		label.position = Vector2(-150, -25)
		label.size = Vector2(300, 50)
		label.modulate = Color(1, 1, 1, 0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)

	if EventBus != null and EventBus.has_signal("player_sleep_started"):
		EventBus.player_sleep_started.connect(_on_player_sleep_started)


func _on_player_sleep_started(duration: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	_is_animating = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if color_rect != null:
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		color_rect.color = Color(0, 0, 0, 0)
	if label != null:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.modulate = Color(1, 1, 1, 0)

	var fade_in: float = duration * 0.35
	var stay: float = duration * 0.30
	var fade_out: float = duration * 0.35

	_tween = create_tween()
	_tween.parallel().tween_property(color_rect, "color", Color(0, 0, 0, 0.95), fade_in).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(label, "modulate", Color(1, 1, 1, 1), fade_in)
	_tween.tween_interval(stay)
	_tween.parallel().tween_property(color_rect, "color", Color(0, 0, 0, 0), fade_out).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(label, "modulate", Color(1, 1, 1, 0), fade_out)
	_tween.tween_callback(_on_player_sleep_finished)


func _on_player_sleep_finished() -> void:
	_is_animating = false
	visible = false
	if EventBus != null and EventBus.has_signal("player_sleep_finished"):
		EventBus.player_sleep_finished.emit()
