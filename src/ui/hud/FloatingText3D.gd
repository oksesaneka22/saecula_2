class_name FloatingText3D
extends Node3D

## FloatingText3D: Спливаючий 3D текст для візуалізації підбору предметів,
## здобутих ресурсів (+1 Дерево), прогресу будівництва та попереджень.
## Завжди розвернений до камери (Billboard), плавно піднімається та розчиняється.

var _label: Label3D = null

var text: String:
	get:
		return _label.text if _label != null else ""
var _lifetime: float = 0.9
var _elapsed: float = 0.0
var _upward_speed: float = 1.4
var _start_color: Color = Color.WHITE
var _horizontal_drift: Vector3 = Vector3.ZERO


func _ready() -> void:
	_ensure_label()


func _ensure_label() -> void:
	if _label == null:
		_label = Label3D.new()
		_label.name = "Label3D"
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.no_depth_test = true
		_label.fixed_size = false
		_label.font_size = 28
		_label.outline_size = 8
		_label.outline_modulate = Color(0, 0, 0, 0.9)
		add_child(_label)


func setup(text: String, color: Color = Color.WHITE, duration: float = 0.9, upward_speed: float = 1.4) -> void:
	_ensure_label()
	_label.text = text
	_start_color = color
	_label.modulate = color
	_lifetime = duration
	_upward_speed = upward_speed
	_elapsed = 0.0

	# Невеликий випадковий дрейф у сторони для органічності кількох одночасних написів
	_horizontal_drift = Vector3(
		randf_range(-0.25, 0.25),
		0.0,
		randf_range(-0.25, 0.25)
	)

	# Початковий поп-скейл (0.5 -> 1.15 -> 1.0)
	scale = Vector3(0.5, 0.5, 0.5)


func _process(delta: float) -> void:
	_elapsed += delta

	# Рух угору та плавний дрейф
	position.y += _upward_speed * delta
	position += _horizontal_drift * delta

	# Анімація розміру на початку (0.0 - 0.15с)
	if _elapsed < 0.15:
		var p: float = _elapsed / 0.15
		var s: float = lerpf(0.5, 1.1, p)
		scale = Vector3(s, s, s)
	elif _elapsed < 0.25:
		var p: float = (_elapsed - 0.15) / 0.10
		var s: float = lerpf(1.1, 1.0, p)
		scale = Vector3(s, s, s)
	else:
		scale = Vector3.ONE

	# Згасання прозорості у другій половині життя
	var fade_start: float = _lifetime * 0.6
	if _elapsed >= fade_start:
		var fade_progress: float = (_elapsed - fade_start) / (_lifetime - fade_start)
		var current_color: Color = _start_color
		current_color.a = clampf(1.0 - fade_progress, 0.0, 1.0)
		if _label != null:
			_label.modulate = current_color

	if _elapsed >= _lifetime:
		queue_free()
