extends PanelContainer

## ModeIndicatorUI: Індикатор поточного ігрового режиму.
## Показує стан "РЕЖИМ ГРАВЦЯ (1st Person)" або "РЕЖИМ ПОСЕЛЕННЯ (RTS)"
## та підказку перемикання за клавішею Tab.

@onready var label: Label = $MarginContainer/Label


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
			label.text = "🎯 РЕЖИМ ГРАВЦЯ (1st Person) • Натисніть [Tab] для огляду колонії (RTS)"
			label.modulate = Color("A8DADC")
		GameManager.GameState.COLONY_MODE:
			label.text = "🏰 РЕЖИМ ПОСЕЛЕННЯ (Top-Down RTS) • Натисніть [Tab] для повернення до гравця"
			label.modulate = Color("F4A261")
		GameManager.GameState.BUILDING_MODE:
			label.text = "🔨 РЕЖИМ БУДІВНИЦТВА • [ЛКМ] Розмістити | [Esc] Скасувати"
			label.modulate = Color("2A9D8F")
		_:
			label.text = ""
