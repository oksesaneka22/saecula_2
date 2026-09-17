# Skill: Finite State Machine (FSM) Generator for Colonists & Entities

## 1. Опис та Призначення (Overview)
Цей скіл визначає стандарти проектування та генерації скінченних автоматів (FSM — Finite State Machine) для автономних колоністів та NPC у Godot 4.
Використовується для створення поведінки жителів поселення (пошук роботи, пересування, збір ресурсів, будівництво, відпочинок, перенесення предметів).

---

## 2. Архітектурний шаблон FSM (Node-based State Machine)

У Godot 4 рекомендується **вузлова архітектура FSM** (компонентний підхід), де кожен стан є окремим вузлом під батьківським `StateMachine`. Це забезпечує максимальну модульність та ізоляцію поведінки.

### Ієрархія вузлів у сцені:
```text
Colonist (CharacterBody2D)
├── Visuals (Sprite2D / AnimatedSprite2D)
├── CollisionShape2D
├── NavigationAgent2D
├── InventoryComponent
└── StateMachine (Node)
    ├── IdleState (Node)
    ├── MoveToState (Node)
    ├── GatherState (Node)
    ├── HaulState (Node)
    └── BuildState (Node)
```

---

## 3. Стандарти коду та контракти

### 3.1. Базовий клас стану (`State.gd`)
Кожен стан наслідує базовий клас `State` і має доступ до сутності (`actor`) та автомата станів (`state_machine`).

```gdscript
# res://src/entities/fsm/State.gd
class_name State
extends Node

## Посилання на батьківський автомат станів
var state_machine: StateMachine = null
## Посилання на сутність (наприклад, Colonist)
var actor: CharacterBody2D = null

## Викликається при вході у стан
func enter(_msg: Dictionary = {}) -> void:
	pass

## Викликається при виході зі стану
func exit() -> void:
	pass

## Аналог _process() для активного стану
func update(_delta: float) -> void:
	pass

## Аналог _physics_process() для активного стану
func physics_update(_delta: float) -> void:
	pass

## Допоміжний перехід у новий стан
func transition_to(target_state_name: String, msg: Dictionary = {}) -> void:
	if state_machine:
		state_machine.change_state(target_state_name, msg)
```

---

### 3.2. Автомат станів (`StateMachine.gd`)

```gdscript
# res://src/entities/fsm/StateMachine.gd
class_name StateMachine
extends Node

signal state_changed(old_state_name: String, new_state_name: String)

@export var initial_state: State
var current_state: State = null
var states: Dictionary = {} # String -> State

func _ready() -> void:
	var actor: CharacterBody2D = get_parent() as CharacterBody2D
	
	# Автоматична реєстрація всіх дочірніх станів
	for child in get_children():
		if child is State:
			states[child.name.to_lower()] = child
			child.state_machine = self
			child.actor = actor
	
	# Активація початкового стану
	if initial_state:
		change_state(initial_state.name.to_lower())

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func change_state(target_state_name: String, msg: Dictionary = {}) -> void:
	var key: String = target_state_name.to_lower()
	if not states.has(key):
		push_error("StateMachine: Стан не знайдено: %s" % target_state_name)
		return
	
	var old_state_name: String = ""
	if current_state:
		old_state_name = current_state.name
		current_state.exit()
	
	current_state = states[key]
	current_state.enter(msg)
	state_changed.emit(old_state_name, current_state.name)
```

---

## 4. Приклади типових станів для Saecula

### 4.1. `IdleState.gd` (Очікування / Пошук завдання)
```gdscript
# res://src/entities/colonist/states/IdleState.gd
class_name ColonistIdleState
extends State

@export var search_interval: float = 1.0
var _timer: float = 0.0

func enter(_msg: Dictionary = {}) -> void:
	_timer = 0.0
	if actor.has_method("play_animation"):
		actor.play_animation("idle")

func update(delta: float) -> void:
	_timer += delta
	if _timer >= search_interval:
		_timer = 0.0
		_look_for_job()

func _look_for_job() -> void:
	var colonist: Colonist = actor as Colonist
	if not colonist:
		return
		
	# Запит завдання у глобального JobManager
	var job = JobManager.request_job_for(colonist)
	if job:
		colonist.assign_job(job)
		transition_to("moveto", {"target_pos": job.target_position, "next_state": "work"})
```

### 4.2. `MoveToState.gd` (Пересування за навігацією)
```gdscript
# res://src/entities/colonist/states/MoveToState.gd
class_name ColonistMoveToState
extends State

var _target_pos: Vector2 = Vector2.ZERO
var _next_state: String = "idle"
var _arrival_distance: float = 16.0

func enter(msg: Dictionary = {}) -> void:
	_target_pos = msg.get("target_pos", actor.global_position)
	_next_state = msg.get("next_state", "idle")
	_arrival_distance = msg.get("arrival_distance", 16.0)
	
	var colonist: Colonist = actor as Colonist
	if colonist and colonist.nav_agent:
		colonist.nav_agent.target_position = _target_pos

func physics_update(_delta: float) -> void:
	var colonist: Colonist = actor as Colonist
	if not colonist or not colonist.nav_agent:
		transition_to("idle")
		return
	
	if colonist.global_position.distance_to(_target_pos) <= _arrival_distance or colonist.nav_agent.is_navigation_finished():
		colonist.velocity = Vector2.ZERO
		colonist.move_and_slide()
		transition_to(_next_state)
		return
	
	var next_path_pos: Vector2 = colonist.nav_agent.get_next_path_position()
	var direction: Vector2 = colonist.global_position.direction_to(next_path_pos)
	colonist.velocity = direction * colonist.move_speed
	colonist.move_and_slide()
```

---

## 5. Інструкції для Gemini 3.8 Flash при генерації станів

1. **Сувора типізація:** Кожна змінна та значення, що повертається функцією, повинна мати явний тип (`_delta: float`, `msg: Dictionary = {}`, `-> void`).
2. **Параметри через словник `msg`:** Передавай контекст між станами (ціль руху, ID об'єкта, рецепт) через словник `enter(msg: Dictionary)`.
3. **Обнулення швидкості:** При виході зі стану руху або переході в дію обов'язково обнуляй `actor.velocity = Vector2.ZERO`.
4. **Не блокувати логіку:** Уникай `await get_tree().create_timer()` всередині станів без крайньої необхідності; використовуй дельта-таймери в `update()` або таймери вузлів.
