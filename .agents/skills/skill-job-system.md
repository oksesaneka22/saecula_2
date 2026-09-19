# Skill: Minecolonies-Style Job & Work-Order System in 3D

## 1. Опис та Призначення (Overview)
Цей скіл описує архітектуру системи замовлень на роботу (**3D Job & Work-Order System**), яка є стрижнем ігроладу колонії у стилі *Minecolonies* у 3D світі гри **Saecula**.

### Принцип автономії проти прямого контролю:
* Гравець не керує жителями безпосередньо — він діє як лідер колонії у 3D світі (вид від 1-ї особи або RTS-огляд зверху).
* Гравець або споруди створюють **3D Завдання (`Job`)**:
  * "Побудувати споруду за 3D кресленням [Blueprint / ConstructionSite3D]"
  * "Зрубати 3D дерево або розколоти скелю [Harvest / WorldResourceNode3D]"
  * "Доставити ресурси на 3D склад [Haul / BuildingEntity3D]"
  * "Виготовити знаряддя у 3D майстерні [Craft]"
* Автономні 3D робітники знаходять завдання, розраховують 3D маршрут через `GridManager`, доставляють ресурси та виконують роботу.

---

## 2. Структура завдання (`Job.gd`)

```gdscript
# res://src/systems/jobs/Job.gd
class_name Job
extends RefCounted

enum JobType {
	BUILD,      ## Будівництво 3D споруди за кресленням
	HARVEST,    ## Збір природних 3D ресурсів (дерево, камінь)
	HAUL,       ## Перенесення предметів на 3D склад або будмайданчик
	CRAFT,      ## Крафт на верстаку або у вогнищі
	FARM        ## Обробіток 3D полів
}

enum JobStatus {
	PENDING,    ## Очікує вільного робітника
	ASSIGNED,   ## Робітник призначений і прямує до мети
	SUSPENDED,  ## Призупинено (наприклад, брак матеріалів)
	COMPLETED,  ## Успішно завершено
	CANCELLED   ## Скасовано гравцем
}

var id: String = ""
var type: JobType = JobType.BUILD
var status: JobStatus = JobStatus.PENDING
var priority: int = 1

## Координати місця виконання у 3D світі
var target_map_pos: Vector2i = Vector2i.ZERO
var target_world_pos: Vector3 = Vector3.ZERO

## Цільовий 3D вузол (ConstructionSite3D, WorldResourceNode3D, BuildingEntity3D)
var target_node: Node3D = null

## Необхідна професія робітника
var required_profession: StringName = &""

## Необхідні ресурси
var required_items: Array[ItemCost] = []

## Призначений колоніст
var assigned_colonist_id: String = ""
```

---

## 3. Взаємодія з 3D об'єктами
* **Будівельний майданчик (`ConstructionSite3D`):** Колоніст-будівельник приходить на вільну клітинку біля майданчика, завантажує необхідні ресурси (дерево, камінь), виконує анімацію будівництва протягом `build_time`, після чого майданчик трансформується у повноцінну споруду `BuildingEntity3D`.
* **Склад (`BuildingEntity3D` зі сховищем):** Зареєстрований у `LogisticsManager` для автоматичного пошуку та резервування ресурсів колоністами.
