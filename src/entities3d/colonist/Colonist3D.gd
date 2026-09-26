class_name Colonist3D
extends CharacterBody3D

## Colonist3D: 3D сутність поселенця (колоніста) у Saecula.
## Має стилізоване лоу-полі тіло, анімації ходьби та праці, власний інвентар,
## ім'я та спеціалізацію, керується кінцевим автоматом (FSM) та автономно
## виконує завдання (будівництво, рубку дерев, перенесення ресурсів на склад).

const TextureHelper = preload("res://src/core3d/TextureHelper.gd")
const Job = preload("res://src/systems/jobs/Job.gd")
const InventoryComponentScript = preload("res://src/systems/inventory/InventoryComponent.gd")
const StateMachine = preload("res://src/entities/fsm/StateMachine.gd")

const ColonistIdleState3D = preload("res://src/entities3d/colonist/states/ColonistIdleState3D.gd")
const ColonistMoveToState3D = preload("res://src/entities3d/colonist/states/ColonistMoveToState3D.gd")
const ColonistHarvestState3D = preload("res://src/entities3d/colonist/states/ColonistHarvestState3D.gd")
const ColonistHaulState3D = preload("res://src/entities3d/colonist/states/ColonistHaulState3D.gd")
const ColonistBuildState3D = preload("res://src/entities3d/colonist/states/ColonistBuildState3D.gd")
const ColonistRestState3D = preload("res://src/entities3d/colonist/states/ColonistRestState3D.gd")

@export var colonist_name: String = "Добриня"
@export var profession: StringName = &"settler" ## builder, lumberjack, hauler, settler
@export var walk_speed: float = 3.5
@export var max_health: float = 100.0
@export var current_health: float = 100.0

var current_job: Job = null
var inventory: InventoryComponent = null
var state_machine: StateMachine = null

# Візуальні елементи
var visual_root: Node3D = null
var torso_mesh: MeshInstance3D = null
var head_mesh: MeshInstance3D = null
var left_arm_pivot: Node3D = null
var right_arm_pivot: Node3D = null
var left_leg_pivot: Node3D = null
var right_leg_pivot: Node3D = null
var hand_tool_root: Node3D = null
var carried_cargo_root: Node3D = null
var label_3d: Label3D = null

# Анімація
var _walk_cycle: float = 0.0
var _is_walking: bool = false
var _swing_tween: Tween = null
var _status_text: String = "Очікує"


func _ready() -> void:
	add_to_group("colonists")
	add_to_group("interactable")

	_setup_collision()
	_setup_inventory()
	_setup_visual_body()
	_setup_label_3d()
	_setup_fsm()

	# Реєстрація в JobManager
	if JobManager != null:
		JobManager.register_colonist(self)

	_update_label()


func _exit_tree() -> void:
	if JobManager != null:
		JobManager.unregister_colonist(self)


var is_following_player: bool = false
var target_follow_node: Node3D = null

func setup_colonist(p_name: String, p_profession: StringName) -> void:
	colonist_name = p_name
	profession = p_profession
	_apply_profession_colors()
	_update_label()


## Зміна професії поселенця гравцем або системою
func set_profession(new_prof: StringName) -> void:
	profession = new_prof
	_apply_profession_colors()
	_update_label()
	if EventBus != null:
		EventBus.colonist_profession_changed.emit(self, new_prof)
	# Якщо колоніст виконував роботу, яка суперечить новому фаху - звільняємо її
	if current_job != null and current_job.required_profession != &"" and current_job.required_profession != profession:
		if JobManager != null:
			JobManager.release_job(current_job, "Зміна професії робітника")
		current_job = null
		if state_machine != null:
			state_machine.transition_to(&"idle")


## Взаємодія з гравцем на клавішу E: відкриття діалогу / картки поселенця
func interact(player: Node) -> void:
	print("[Colonist3D] Гравець взаємодіє з поселенцем '%s' (фах: %s)" % [colonist_name, get_profession_name()])
	if EventBus != null and EventBus.has_signal("colonist_dialog_requested"):
		EventBus.colonist_dialog_requested.emit(self)


## Наказ гравця: Слідувати за гравцем
func order_follow(target: Node3D) -> void:
	if current_job != null:
		if JobManager != null:
			JobManager.release_job(current_job, "Отримано наказ слідувати за гравцем")
		current_job = null
	is_following_player = true
	target_follow_node = target
	set_status_display("🚶 Слідує за гравцем")
	if state_machine != null:
		state_machine.transition_to(&"moveto", {
			"target_pos": target.global_position,
			"next_state": &"idle",
			"arrival_distance": 2.5
		})


## Наказ гравця: Зупинитися та повернутися до вільної праці
func order_stop_follow() -> void:
	is_following_player = false
	target_follow_node = null
	set_status_display("💤 Вільний")
	if state_machine != null:
		state_machine.transition_to(&"idle")


func get_profession_name() -> String:
	match profession:
		&"builder":
			return "Будівельник"
		&"lumberjack":
			return "Лісоруб"
		&"hauler":
			return "Вантажник"
		&"settler":
			return "Поселенець"
		_:
			return "Робітник"


# ------------------------------------------------------------------------------
# Призначення та реакція на завдання (Job Assignment)
# ------------------------------------------------------------------------------
func assign_job(job: Job) -> void:
	if job == null or state_machine == null:
		return

	current_job = job

	match job.type:
		Job.JobType.BUILD:
			state_machine.transition_to(&"moveto", {
				"target_pos": job.target_world_pos,
				"next_state": &"build",
				"arrival_distance": 2.2,
				"next_msg": { "target_node": job.target_node }
			})
		Job.JobType.HARVEST:
			state_machine.transition_to(&"moveto", {
				"target_pos": job.target_world_pos,
				"next_state": &"harvest",
				"arrival_distance": 1.6,
				"next_msg": { "target_node": job.target_node }
			})
		Job.JobType.HAUL:
			state_machine.transition_to(&"moveto", {
				"target_pos": job.target_world_pos,
				"next_state": &"haul",
				"arrival_distance": 1.8,
				"next_msg": { "stage": 1 }
			})
		_:
			state_machine.transition_to(&"moveto", {
				"target_pos": job.target_world_pos,
				"next_state": &"idle",
				"arrival_distance": 1.5
			})


func is_resting() -> bool:
	return state_machine != null and state_machine.current_state != null and state_machine.current_state.name == "Rest"


func set_status_display(text: String) -> void:
	_status_text = text
	_update_label()


func get_status_text() -> String:
	return _status_text


func take_damage(amount: float) -> void:
	current_health = clampf(current_health - amount, 0.0, max_health)
	if current_health <= 0.0:
		if EventBus != null and EventBus.has_signal("colonist_died"):
			EventBus.colonist_died.emit(self)
		queue_free()


func heal(amount: float) -> void:
	current_health = clampf(current_health + amount, 0.0, max_health)


func _update_label() -> void:
	if label_3d == null:
		return
	var follow_suffix := " 🐾" if is_following_player else ""
	var prof_icon := "🔨"
	match profession:
		&"builder": prof_icon = "🔨"
		&"lumberjack": prof_icon = "🪓"
		&"hauler": prof_icon = "📦"
		&"settler": prof_icon = "🌾"
		_: prof_icon = "👤"

	label_3d.text = "%s%s\n[%s %s]\n%s" % [
		colonist_name,
		follow_suffix,
		prof_icon,
		get_profession_name(),
		_status_text
	]


# ------------------------------------------------------------------------------
# Візуальна побудова лоу-полі колоніста
# ------------------------------------------------------------------------------
func _setup_collision() -> void:
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	col.shape = cap
	col.position = Vector3(0, 0.85, 0)
	add_child(col)


func _setup_inventory() -> void:
	inventory = InventoryComponentScript.new()
	inventory.name = "InventoryComponent"
	inventory.set("slot_count", 8)
	add_child(inventory)


func _setup_visual_body() -> void:
	visual_root = Node3D.new()
	visual_root.name = "VisualRoot"
	add_child(visual_root)

	# 1. ТОРС
	torso_mesh = MeshInstance3D.new()
	torso_mesh.name = "Torso"
	var torso_box := BoxMesh.new()
	torso_box.size = Vector3(0.5, 0.6, 0.28)
	torso_mesh.mesh = torso_box
	torso_mesh.position = Vector3(0, 0.88, 0)
	torso_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	visual_root.add_child(torso_mesh)

	# 2. ГОЛОВА ТА ШАПКА
	head_mesh = MeshInstance3D.new()
	head_mesh.name = "Head"
	var head_box := BoxMesh.new()
	head_box.size = Vector3(0.32, 0.32, 0.32)
	head_mesh.mesh = head_box
	head_mesh.position = Vector3(0, 1.34, 0)
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color("FFDCB1") # Світла шкіра
	head_mesh.material_override = head_mat
	visual_root.add_child(head_mesh)

	# Очі
	var eye_l := MeshInstance3D.new()
	var eye_box := BoxMesh.new()
	eye_box.size = Vector3(0.06, 0.06, 0.05)
	eye_l.mesh = eye_box
	eye_l.position = Vector3(0.08, 1.34, 0.16)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color("2C3E50")
	eye_l.material_override = eye_mat
	visual_root.add_child(eye_l)

	var eye_r := MeshInstance3D.new()
	eye_r.mesh = eye_box
	eye_r.position = Vector3(-0.08, 1.34, 0.16)
	eye_r.material_override = eye_mat
	visual_root.add_child(eye_r)

	# 3. РУКИ (Півоти у плечах)
	left_arm_pivot = Node3D.new()
	left_arm_pivot.name = "LeftArmPivot"
	left_arm_pivot.position = Vector3(0.32, 1.12, 0)
	visual_root.add_child(left_arm_pivot)

	var left_arm := MeshInstance3D.new()
	var arm_box := BoxMesh.new()
	arm_box.size = Vector3(0.14, 0.5, 0.14)
	left_arm.mesh = arm_box
	left_arm.position = Vector3(0, -0.22, 0)
	left_arm.material_override = head_mat
	left_arm_pivot.add_child(left_arm)

	right_arm_pivot = Node3D.new()
	right_arm_pivot.name = "RightArmPivot"
	right_arm_pivot.position = Vector3(-0.32, 1.12, 0)
	visual_root.add_child(right_arm_pivot)

	var right_arm := MeshInstance3D.new()
	right_arm.mesh = arm_box
	right_arm.position = Vector3(0, -0.22, 0)
	right_arm.material_override = head_mat
	right_arm_pivot.add_child(right_arm)

	# Контейнер для інструментів у правій руці
	hand_tool_root = Node3D.new()
	hand_tool_root.name = "HandToolRoot"
	hand_tool_root.position = Vector3(0, -0.42, 0.12)
	right_arm_pivot.add_child(hand_tool_root)

	# Контейнер для ящиків/вантажу в обіймах
	carried_cargo_root = Node3D.new()
	carried_cargo_root.name = "CarriedCargoRoot"
	carried_cargo_root.position = Vector3(0, 0.85, 0.3)
	visual_root.add_child(carried_cargo_root)

	# 4. НОГИ (Півоти у стегнах)
	var leg_box := BoxMesh.new()
	leg_box.size = Vector3(0.18, 0.55, 0.18)
	var pants_mat := StandardMaterial3D.new()
	pants_mat.albedo_color = Color("3E2723") # Коричневі штани

	left_leg_pivot = Node3D.new()
	left_leg_pivot.name = "LeftLegPivot"
	left_leg_pivot.position = Vector3(0.14, 0.58, 0)
	visual_root.add_child(left_leg_pivot)

	var left_leg := MeshInstance3D.new()
	left_leg.mesh = leg_box
	left_leg.position = Vector3(0, -0.27, 0)
	left_leg.material_override = pants_mat
	left_leg_pivot.add_child(left_leg)

	right_leg_pivot = Node3D.new()
	right_leg_pivot.name = "RightLegPivot"
	right_leg_pivot.position = Vector3(-0.14, 0.58, 0)
	visual_root.add_child(right_leg_pivot)

	var right_leg := MeshInstance3D.new()
	right_leg.mesh = leg_box
	right_leg.position = Vector3(0, -0.27, 0)
	right_leg.material_override = pants_mat
	right_leg_pivot.add_child(right_leg)

	_apply_profession_colors()


func _apply_profession_colors() -> void:
	if torso_mesh == null:
		return

	var tunic_mat := StandardMaterial3D.new()
	match profession:
		&"builder":
			tunic_mat.albedo_color = Color("8D5B4C") # Помаранчево-бурий будівельник
		&"lumberjack":
			tunic_mat.albedo_color = Color("C0392B") # Червона туніка лісоруба
		&"hauler":
			tunic_mat.albedo_color = Color("2980B9") # Синя туніка вантажника
		&"settler":
			tunic_mat.albedo_color = Color("D5C4A1") # Натуральне лляне полотно
		_:
			tunic_mat.albedo_color = Color("27AE60")

	torso_mesh.material_override = tunic_mat


func _setup_label_3d() -> void:
	label_3d = Label3D.new()
	label_3d.name = "StatusLabel"
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.no_depth_test = false
	label_3d.font_size = 24
	label_3d.outline_size = 6
	label_3d.outline_modulate = Color(0, 0, 0, 0.95)
	label_3d.modulate = Color(1.0, 0.95, 0.7, 1.0)
	label_3d.position = Vector3(0, 1.9, 0)
	add_child(label_3d)


func _setup_fsm() -> void:
	state_machine = StateMachine.new()
	state_machine.name = "StateMachine"
	add_child(state_machine)

	var idle := ColonistIdleState3D.new()
	idle.name = "Idle"
	state_machine.add_child(idle)

	var moveto := ColonistMoveToState3D.new()
	moveto.name = "MoveTo"
	state_machine.add_child(moveto)

	var harvest := ColonistHarvestState3D.new()
	harvest.name = "Harvest"
	state_machine.add_child(harvest)

	var haul := ColonistHaulState3D.new()
	haul.name = "Haul"
	state_machine.add_child(haul)

	var build := ColonistBuildState3D.new()
	build.name = "Build"
	state_machine.add_child(build)

	var rest := ColonistRestState3D.new()
	rest.name = "Rest"
	state_machine.add_child(rest)

	state_machine.initial_state = idle
	state_machine._init_states()


# ------------------------------------------------------------------------------
# Анімації та зміна інструментів
# ------------------------------------------------------------------------------
func play_walk_animation(delta: float) -> void:
	_is_walking = true
	_walk_cycle += delta * 10.0

	var leg_angle := sin(_walk_cycle) * 0.5
	var arm_angle := -sin(_walk_cycle) * 0.4

	if left_leg_pivot != null:
		left_leg_pivot.rotation.x = leg_angle
	if right_leg_pivot != null:
		right_leg_pivot.rotation.x = -leg_angle

	# Руки рухаються протилежно до ніг
	if left_arm_pivot != null:
		left_arm_pivot.rotation.x = arm_angle
	if right_arm_pivot != null and _swing_tween == null:
		right_arm_pivot.rotation.x = -arm_angle

	# Легке погойдування корпусу
	if visual_root != null:
		visual_root.position.y = abs(sin(_walk_cycle * 2.0)) * 0.05


func stop_walk_animation() -> void:
	_is_walking = false
	if left_leg_pivot != null:
		left_leg_pivot.rotation.x = 0.0
	if right_leg_pivot != null:
		right_leg_pivot.rotation.x = 0.0
	if left_arm_pivot != null:
		left_arm_pivot.rotation.x = 0.0
	if right_arm_pivot != null and _swing_tween == null:
		right_arm_pivot.rotation.x = 0.0
	if visual_root != null:
		visual_root.position.y = 0.0


func play_swing_animation() -> void:
	if right_arm_pivot == null:
		return

	if _swing_tween != null and _swing_tween.is_valid():
		_swing_tween.kill()

	_swing_tween = create_tween()
	_swing_tween.tween_property(right_arm_pivot, "rotation:x", deg_to_rad(-80), 0.15)
	_swing_tween.tween_property(right_arm_pivot, "rotation:x", deg_to_rad(45), 0.1)
	_swing_tween.tween_property(right_arm_pivot, "rotation:x", 0.0, 0.15)


func show_hand_tool(tool_id: StringName) -> void:
	hide_hand_items()
	if hand_tool_root == null:
		return

	var tool_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	var mat := StandardMaterial3D.new()

	match tool_id:
		&"stone_axe":
			box.size = Vector3(0.12, 0.45, 0.2)
			mat.albedo_color = Color("7F8C8D")
		&"stone_pickaxe":
			box.size = Vector3(0.12, 0.45, 0.3)
			mat.albedo_color = Color("95A5A6")
		&"hammer":
			box.size = Vector3(0.15, 0.4, 0.22)
			mat.albedo_color = Color("D35400")
		&"scythe":
			box.size = Vector3(0.08, 0.55, 0.35)
			mat.albedo_color = Color("BDC3C7")
		_:
			box.size = Vector3(0.1, 0.3, 0.1)
			mat.albedo_color = Color("FFFFFF")

	tool_mesh.mesh = box
	tool_mesh.material_override = mat
	hand_tool_root.add_child(tool_mesh)


func show_carried_cargo(item_id: StringName) -> void:
	hide_hand_items()
	if carried_cargo_root == null:
		return

	var cargo_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 0.35, 0.35)
	var mat := StandardMaterial3D.new()
	match item_id:
		&"wood":
			mat.albedo_color = Color("8B5A2B")
		&"stone":
			mat.albedo_color = Color("7F8C8D")
		&"straw":
			mat.albedo_color = Color("E1B12C")
		_:
			mat.albedo_color = Color("C0392B")

	cargo_mesh.mesh = box
	cargo_mesh.material_override = mat
	carried_cargo_root.add_child(cargo_mesh)

	# Підіймаємо обидві руки вперед тримаючи вантаж
	if left_arm_pivot != null:
		left_arm_pivot.rotation.x = deg_to_rad(-45)
	if right_arm_pivot != null:
		right_arm_pivot.rotation.x = deg_to_rad(-45)


func hide_hand_items() -> void:
	if hand_tool_root != null:
		for child in hand_tool_root.get_children():
			child.get_parent().remove_child(child)
			child.queue_free()
	if carried_cargo_root != null:
		for child in carried_cargo_root.get_children():
			child.get_parent().remove_child(child)
			child.queue_free()

	if not _is_walking:
		if left_arm_pivot != null:
			left_arm_pivot.rotation.x = 0.0
		if right_arm_pivot != null:
			right_arm_pivot.rotation.x = 0.0
