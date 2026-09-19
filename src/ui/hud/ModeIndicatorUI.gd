extends PanelContainer

## ModeIndicatorUI: Індикатор поточного ігрового режиму.
## Показує стан "РЕЖИМ ГРАВЦЯ (1st Person)" або "РЕЖИМ ПОСЕЛЕННЯ (RTS)"
## та підказку перемикання за клавішею Tab.

@onready var label: Label = $MarginContainer/Label



var _fps_timer: float = 0.0
var _current_fps: int = 60

func _process(delta: float) -> void:
	_fps_timer += delta
	if _fps_timer >= 0.4:
		_fps_timer = 0.0
		_current_fps = Engine.get_frames_per_second()
		_update_label(GameManager.current_state)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EventBus.game_state_changed.connect(_on_game_state_changed)
	_update_label(GameManager.current_state)


func _on_game_state_changed(new_state: int, _old_state: int) -> void:
	_update_label(new_state)


func _update_label(state: int) -> void:
	if label == null:
		return

	match state:
		GameManager.GameState.PLAYING:
			label.text = "🎯 РЕЖИМ ГРАВЦЯ (1st Person) • [Tab] Колонія (RTS) • FPS: %d" % _current_fps
			label.modulate = Color("A8DADC")
		GameManager.GameState.COLONY_MODE:
			label.text = "🏰 РЕЖИМ ПОСЕЛЕННЯ (RTS) • [Tab] Гравець • FPS: %d" % _current_fps
			label.modulate = Color("F4A261")
		GameManager.GameState.BUILDING_MODE:
			label.text = "🔨 РЕЖИМ БУДІВНИЦТВА • [ЛКМ] Розмістити | [Esc] Скасувати • FPS: %d" % _current_fps
			label.modulate = Color("2A9D8F")
		_:
			label.text = ""
