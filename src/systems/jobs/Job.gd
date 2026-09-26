class_name Job
extends RefCounted

## Job: Структура одиниці роботи в поселенні (Minecolonies / RimWorld стиль).
## Представляє завдання, яке створюється гравцем, спорудами або подіями світу
## та автономно береться на виконання 3D колоністами за чергою пріоритетів.

enum JobType {
	BUILD,      ## Будівництво або зведення 3D споруди за кресленням (ConstructionSite3D)
	HARVEST,    ## Збір або добування природних ресурсів (дерево, камінь, глина, тощо)
	HAUL,       ## Перенесення розкиданих предметів (DroppedItem3D) на склад (Stockpile)
	CRAFT,      ## Крафт або переробка матеріалів
	FARM        ## Збір або обробка полів/рослинності
}

enum JobStatus {
	PENDING,    ## Очікує вільного та відповідного робітника
	ASSIGNED,   ## Закріплено за робітником, виконується переміщення або дія
	COMPLETED,  ## Роботу завершено успішно
	CANCELLED   ## Скасовано гравцем або через знищення цільового об'єкта
}

var id: StringName = &""
var type: JobType = JobType.BUILD
var status: JobStatus = JobStatus.PENDING
var priority: int = 1 ## Більше значення = вищий пріоритет (наприклад, 1 = нормальний, 2 = високий)

var target_world_pos: Vector3 = Vector3.ZERO
var target_map_pos: Vector2i = Vector2i.ZERO
var target_node: Node = null

var required_profession: StringName = &"" ## Якщо не порожньо (наприклад &"builder", &"lumberjack"), береться лише відповідним жителем
var assigned_colonist: Node = null
var data: Dictionary = {}


func _init(
	p_type: JobType = JobType.BUILD,
	p_world_pos: Vector3 = Vector3.ZERO,
	p_target_node: Node = null,
	p_priority: int = 1,
	p_profession: StringName = &"",
	p_data: Dictionary = {}
) -> void:
	id = StringName("job_%d_%d" % [Time.get_ticks_msec(), randi() % 100000])
	type = p_type
	target_world_pos = p_world_pos
	target_node = p_target_node
	priority = p_priority
	required_profession = p_profession
	data = p_data
	status = JobStatus.PENDING


func get_type_name() -> String:
	match type:
		JobType.BUILD:
			return "Будівництво"
		JobType.HARVEST:
			return "Видобуток"
		JobType.HAUL:
			return "Доставка"
		JobType.CRAFT:
			return "Крафт"
		JobType.FARM:
			return "Фермерство"
		_:
			return "Завдання"
