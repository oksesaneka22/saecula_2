class_name StateMachine
extends Node

## StateMachine: Менеджер автоматів станів (Node-based FSM).
## Керує переходами між станами та передачею подій оновлення в активний стан.

signal transitioned(state_name: StringName)

@export var initial_state: Node = null
var current_state: Node = null
var states: Dictionary = {} ## Dictionary[StringName, Node]


func _ready() -> void:
	_init_states()


func _init_states() -> void:
	var parent_actor = get_parent() as CharacterBody3D
	states.clear()
	for child in get_children():
		if child.has_method("enter") and child.has_method("exit"):
			var s_name := StringName(child.name.to_lower())
			states[s_name] = child
			child.set("state_machine", self)
			child.set("actor", parent_actor)

	if initial_state != null:
		var init_name := StringName(initial_state.name.to_lower())
		transition_to(init_name)
	elif not states.is_empty():
		var first_key: StringName = states.keys()[0]
		transition_to(first_key)


func transition_to(target_state_name: StringName, msg: Dictionary = {}) -> void:
	var key := StringName(target_state_name.to_lower())
	if not states.has(key):
		push_warning("[StateMachine] Стан '%s' не зареєстровано в автоматі!" % target_state_name)
		return

	if current_state != null and current_state.has_method("exit"):
		current_state.exit()

	current_state = states[key]
	if current_state.has_method("enter"):
		current_state.enter(msg)
	transitioned.emit(target_state_name)


func _process(delta: float) -> void:
	if current_state != null and current_state.has_method("update"):
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state != null and current_state.has_method("physics_update"):
		current_state.physics_update(delta)
