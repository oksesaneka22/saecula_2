extends Node

## JobManager: Центральний менеджер доручень та робіт колонії (Minecolonies-стиль).
## Організує глобальну чергу завдань (будівництво, рубку лісу, перенесення ресурсів на склад),
## призначає завдання вільним колоністам згідно з їхньою спеціалізацією та відстанню.

const Job = preload("res://src/systems/jobs/Job.gd")

signal job_created(job: Job)
signal job_assigned(job: Job, colonist: Node)
signal job_completed(job: Job, colonist: Node)
signal job_canceled(job: Job, reason: String)

var _pending_jobs: Array[Job] = []
var _active_jobs: Array[Job] = []
var _completed_jobs: Array[Job] = []
var _colonists: Array[Node] = []

## Автоматичне сканування безгосподарних предметів (dropped items) на мапі
var auto_create_haul_jobs: bool = true
var _haul_scan_timer: float = 0.0


func _ready() -> void:
	print("[JobManager] Менеджер завдань колонії успішно ініціалізовано.")

	# Підписка на події розміщення будмайданчиків
	if EventBus != null:
		if EventBus.has_signal("construction_site_placed"):
			EventBus.construction_site_placed.connect(_on_construction_site_placed)
		if EventBus.has_signal("item_dropped"):
			EventBus.item_dropped.connect(_on_item_dropped)


func _process(delta: float) -> void:
	# Періодичне очищення недійсних завдань
	_haul_scan_timer += delta
	if _haul_scan_timer >= 2.0:
		_haul_scan_timer = 0.0
		_cleanup_invalid_jobs()


# ------------------------------------------------------------------------------
# Керування жителями колонії (Colonist Registry)
# ------------------------------------------------------------------------------
func register_colonist(colonist: Node) -> void:
	if colonist == null or _colonists.has(colonist):
		return
	_colonists.append(colonist)
	if not colonist.tree_exited.is_connected(unregister_colonist.bind(colonist)):
		colonist.tree_exited.connect(unregister_colonist.bind(colonist))
	if EventBus != null and EventBus.has_signal("colonist_spawned"):
		EventBus.colonist_spawned.emit(colonist)
	print("[JobManager] Зареєстровано поселенця '%s'. Усього жителів: %d" % [
		colonist.name,
		_colonists.size()
	])


func unregister_colonist(colonist: Node) -> void:
	if colonist == null or not _colonists.has(colonist):
		return
	# Якщо колоніст виконував завдання — повертаємо його в чергу
	for job in _active_jobs:
		if job.assigned_colonist == colonist:
			release_job(job, "Колоніст вибув")
			break
	_colonists.erase(colonist)
	var col_name: String = colonist.name if is_instance_valid(colonist) else "Unknown"
	print("[JobManager] Поселенця '%s' знято з обліку. Залишилось: %d" % [
		col_name,
		_colonists.size()
	])
	if EventBus != null and EventBus.has_signal("colonist_died"):
		EventBus.colonist_died.emit(colonist, "Unregistered")


func get_all_colonists() -> Array[Node]:
	var active: Array[Node] = []
	for c in _colonists:
		if is_instance_valid(c) and not c.is_queued_for_deletion():
			active.append(c)
	return active


func get_colonists_count() -> int:
	return get_all_colonists().size()


# ------------------------------------------------------------------------------
# Створення та публікація завдань (Job Creation)
# ------------------------------------------------------------------------------
func create_job(
	type: Job.JobType,
	target_pos: Vector3,
	target_node: Node = null,
	priority: int = 1,
	required_prof: StringName = &"",
	data: Dictionary = {}
) -> Job:
	# Запобігаємо створенню однакових завдань для однієї цілі
	if target_node != null and is_instance_valid(target_node):
		for existing in _pending_jobs:
			if existing.target_node == target_node and existing.type == type:
				return existing
		for existing in _active_jobs:
			if existing.target_node == target_node and existing.type == type:
				return existing

	var job := Job.new(type, target_pos, target_node, priority, required_prof, data)
	_pending_jobs.append(job)
	_sort_pending_jobs()

	job_created.emit(job)
	if EventBus != null and EventBus.has_signal("job_created"):
		EventBus.job_created.emit(job.id, job.type, Vector2(target_pos.x, target_pos.z))

	print("[JobManager] 📋 Створено нове завдання: %s [%s] на (%0.1f, %0.1f, %0.1f)" % [
		job.get_type_name(),
		job.id,
		target_pos.x,
		target_pos.y,
		target_pos.z
	])
	return job


# ------------------------------------------------------------------------------
# Запит та видача завдань колоністам (Job Request & Dispatch)
# ------------------------------------------------------------------------------
func request_job(colonist: Node) -> Job:
	if colonist == null or _pending_jobs.is_empty():
		return null

	var colonist_pos: Vector3 = colonist.global_position if colonist is Node3D else Vector3.ZERO
	var colonist_prof: StringName = colonist.get("profession") if "profession" in colonist else &""

	var best_job: Job = null
	var best_index: int = -1
	var min_distance: float = INF

	for i in range(_pending_jobs.size()):
		var job: Job = _pending_jobs[i]
		if job == null or job.status != Job.JobStatus.PENDING:
			continue

		# Перевірка валідності цільового вузла (якщо є)
		if job.target_node != null and not is_instance_valid(job.target_node):
			continue

		# Перевірка професії
		if not job.required_profession.is_empty():
			if not colonist_prof.is_empty() and colonist_prof != job.required_profession:
				continue

		var dist: float = colonist_pos.distance_to(job.target_world_pos)
		# Перший або з вищим пріоритетом / ближчий за відстанню
		if best_job == null:
			best_job = job
			best_index = i
			min_distance = dist
		elif job.priority > best_job.priority:
			best_job = job
			best_index = i
			min_distance = dist
		elif job.priority == best_job.priority and dist < min_distance:
			best_job = job
			best_index = i
			min_distance = dist

	if best_job != null and best_index >= 0:
		_pending_jobs.remove_at(best_index)
		best_job.status = Job.JobStatus.ASSIGNED
		best_job.assigned_colonist = colonist
		_active_jobs.append(best_job)

		job_assigned.emit(best_job, colonist)
		if EventBus != null and EventBus.has_signal("job_assigned"):
			EventBus.job_assigned.emit(best_job.id, colonist)

		print("[JobManager] 🔨 Завдання %s [%s] призначено робітнику '%s'" % [
			best_job.get_type_name(),
			best_job.id,
			colonist.name
		])
		return best_job

	return null


# ------------------------------------------------------------------------------
# Завершення або скасування завдань
# ------------------------------------------------------------------------------
func complete_job(job: Job) -> void:
	if job == null:
		return

	job.status = Job.JobStatus.COMPLETED
	var colonist = job.assigned_colonist
	_active_jobs.erase(job)
	_pending_jobs.erase(job)

	_completed_jobs.append(job)
	if _completed_jobs.size() > 50:
		_completed_jobs.pop_front()

	job_completed.emit(job, colonist)
	if EventBus != null and EventBus.has_signal("job_completed"):
		EventBus.job_completed.emit(job.id, colonist)

	print("[JobManager] ✅ Завдання %s [%s] успішно виконано!" % [
		job.get_type_name(),
		job.id
	])


func release_job(job: Job, reason: String = "") -> void:
	if job == null:
		return

	_active_jobs.erase(job)
	job.assigned_colonist = null
	job.status = Job.JobStatus.PENDING

	# Якщо цільовий об'єкт живий — повертаємо в чергу
	if job.target_node == null or is_instance_valid(job.target_node):
		_pending_jobs.append(job)
		_sort_pending_jobs()

	job_canceled.emit(job, reason)
	if EventBus != null and EventBus.has_signal("job_canceled"):
		EventBus.job_canceled.emit(job.id, reason)

	print("[JobManager] ⚠️ Завдання %s [%s] повернуто в чергу: %s" % [
		job.get_type_name(),
		job.id,
		reason
	])


func cancel_jobs_for_target(target: Node, reason: String = "Target removed") -> void:
	if target == null:
		return
	var to_cancel: Array[Job] = []
	for j in _pending_jobs:
		if j.target_node == target:
			to_cancel.append(j)
	for j in _active_jobs:
		if j.target_node == target:
			to_cancel.append(j)
	for j in to_cancel:
		cancel_job(j, reason)


func cancel_job(job: Job, reason: String = "Canceled") -> void:
	if job == null:
		return

	_active_jobs.erase(job)
	_pending_jobs.erase(job)
	job.status = Job.JobStatus.CANCELLED
	job.assigned_colonist = null

	job_canceled.emit(job, reason)
	if EventBus != null and EventBus.has_signal("job_canceled"):
		EventBus.job_canceled.emit(job.id, reason)


func clear_all_jobs() -> void:
	_pending_jobs.clear()
	_active_jobs.clear()


func get_pending_jobs_count() -> int:
	return _pending_jobs.size()


func get_active_jobs_count() -> int:
	return _active_jobs.size()


func _sort_pending_jobs() -> void:
	_pending_jobs.sort_custom(func(a: Job, b: Job) -> bool:
		return a.priority > b.priority
	)


func _cleanup_invalid_jobs() -> void:
	var valid_pending: Array[Job] = []
	for j in _pending_jobs:
		if j != null and (j.target_node == null or is_instance_valid(j.target_node)):
			valid_pending.append(j)
	_pending_jobs = valid_pending

	var valid_active: Array[Job] = []
	for j in _active_jobs:
		if j != null and (j.target_node == null or is_instance_valid(j.target_node)):
			valid_active.append(j)
	_active_jobs = valid_active


# ------------------------------------------------------------------------------
# Обробники зовнішніх подій (EventBus hooks)
# ------------------------------------------------------------------------------
func _on_construction_site_placed(site_node: Node, building_id: StringName, _map_coords: Vector2i) -> void:
	if site_node == null or not is_instance_valid(site_node):
		return
	var site3d := site_node as Node3D
	var pos := site3d.global_position if site3d != null else Vector3.ZERO
	# Створюємо завдання будівництва з високим пріоритетом (2) для будівельників
	create_job(
		Job.JobType.BUILD,
		pos,
		site_node,
		2,
		&"builder",
		{ "building_id": building_id }
	)


func _on_item_dropped(item_id: StringName, amount: int, world_pos_2d: Vector2) -> void:
	if not auto_create_haul_jobs:
		return
	var pos_3d := Vector3(world_pos_2d.x, 0.5, world_pos_2d.y)
	create_job(
		Job.JobType.HAUL,
		pos_3d,
		null,
		1,
		&"hauler",
		{ "item_id": item_id, "amount": amount }
	)
