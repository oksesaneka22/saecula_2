class_name State
extends Node

## State: Базовий клас стану для скінченного автомата (FSM).
## Використовується автономними колоністами, тваринами та іншими AI-сутностями.

var state_machine: Node = null
var actor: CharacterBody3D = null


## Викликається при вході у даний стан
func enter(_msg: Dictionary = {}) -> void:
	pass


## Викликається при виході з даного стану
func exit() -> void:
	pass


## Оновлення стану кожного кадру рендерингу
func update(_delta: float) -> void:
	pass


## Оновлення фізики та переміщення
func physics_update(_delta: float) -> void:
	pass
