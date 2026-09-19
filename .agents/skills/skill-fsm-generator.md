# Skill: Finite State Machine (FSM) Generator for 3D Colonists & Entities

## 1. Опис та Призначення (Overview)
Цей скіл визначає стандарти проектування та генерації скінченних автоматів (FSM — Finite State Machine) для автономних **3D колоністів, NPC та сутностей** у грі **Saecula** на Godot 4.
Використовується для створення інтелектуальної поведінки жителів поселення у тривимірному просторі: пошук завдань у колонії, навігація за 3D сіткою, збір 3D ресурсів, будівництво каркасів споруд, транспортування вантажів на склади та відпочинок біля вогнища.

---

## 2. Архітектурний шаблон FSM (Node-based State Machine)

У Godot 4 застосовується **вузлова компонентна архітектура FSM**, де кожен стан є окремим вузлом `Node`, підпорядкованим батьківському вузлу `StateMachine`. Це гарантує модульність, читабельність та ізоляцію поведінки.

### Ієрархія вузлів у 3D сцені колоніста:
```text
Colonist3D (CharacterBody3D)
├── VisualBody (Node3D / MeshInstance3D)
├── CollisionShape3D (CapsuleShape3D)
├── InteractRay (RayCast3D)
├── InventoryComponent (Node)
└── StateMachine (Node)
    ├── IdleState (Node)
    ├── MoveToState3D (Node)
    ├── GatherState3D (Node)
    ├── HaulState3D (Node)
    └── BuildState3D (Node)
```

---

## 3. Стандарти коду та контракти

### 3.1. Базовий клас стану (`State.gd`)
Кожен стан наслідує базовий клас `State` і має типізований доступ до актора (`actor: CharacterBody3D`) та автомата станів (`state_machine: StateMachine`).

```gdscript
# res://src/entities/fsm/State.gd
class_name State
extends Node

var state_machine: Node = null
var actor: CharacterBody3D = null

## Викликається при вході в стан з опціональним словником параметрів
func enter(_msg: Dictionary = {}) -> void:
	pass

## Викликається при виході зі стану
func exit() -> void:
	pass

## Оновлення стану у кадрі рендерингу
func update(_delta: float) -> void:
	pass

## Оновлення фізики (рух, колізії, навігація)
func physics_update(_delta: float) -> void:
	pass
```

### 3.2. Контролер StateMachine (`StateMachine.gd`)
Керує активним станом, перемиканням та делегуванням фізичних процесів.

```gdscript
# res://src/entities/fsm/StateMachine.gd
class_name StateMachine
extends Node

signal transitioned(state_name: StringName)

@export var initial_state: State
var current_state: State = null
var states: Dictionary = {} ## Dictionary[StringName, State]

func _ready() -> void:
	var actor = get_parent() as CharacterBody3D
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.state_machine = self
			child.actor = actor

	if initial_state != null:
		transition_to(initial_state.name.to_lower())

func transition_to(target_state_name: StringName, msg: Dictionary = {}) -> void:
	if not states.has(target_state_name):
		push_warning("[StateMachine] Стан не знайдено: %s" % target_state_name)
		return
	if current_state != null:
		current_state.exit()
	current_state = states[target_state_name]
	current_state.enter(msg)
	transitioned.emit(target_state_name)

func _physics_process(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)
```

---

## 4. Специфіка для 3D середовища
1. **Гравітація та колізії:** Усі стани пересування (`MoveToState3D`, `HaulState3D`) враховують перевірку `actor.is_on_floor()` та застосовують вертикальну гравітацію.
2. **Орієнтація у просторі:** Поворот колоніста до напрямку руху виконується плавно через горизонтальний вектор `look_at(Vector3(target.x, global_position.y, target.z))`.
3. **Взаємодія з 3D об'єктами:** При зборі природних ресурсів або будівництві колоніст зупиняється на сусідній вільній 3D клітинці сітки (радіус взаємодії 1.2–2.0м).
