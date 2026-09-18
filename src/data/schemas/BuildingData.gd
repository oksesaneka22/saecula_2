class_name BuildingData
extends Resource

## BuildingData: Data-Driven опис споруди у грі Saecula.
## Визначає ідентифікатор, назву, опис, розмір у тайлах, прохідність,
## вартість будівництва (ItemCost) та час зведення.

@export_group("Identity")
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("Grid & Footprint")
## Розмір споруди в тайлах сітки (наприклад, 1x1 для багаття, 2x2 для складу, 3x3 для хатини)
@export var size_in_tiles: Vector2i = Vector2i(1, 1)
## Чи блокує будівля прохід для юнітів після зведення
@export var is_solid: bool = true

@export_group("Construction")
## Мінімальна епоха для доступу (0 = Кам'яний вік, 1 = Бронзовий вік тощо)
@export var required_era: int = 0
## Час роботи будівельника над спорудою (в ігрових секундах)
@export var build_time: float = 5.0
## Необхідні ресурси для побудови (масив ItemCost)
@export var construction_cost: Array[Resource] = [] # Array[ItemCost]

@export_group("Functionality")
## Професія або роль, яку забезпечує будівля (наприклад, "builder", "miner", "farmer")
@export var job_type_provided: StringName = &""
## Кількість слотів сховища (якщо будівля є складом чи скринею)
@export var storage_slots: int = 0
## Специфічна сцена для рендерингу будівлі (опціонально)
@export var custom_scene: PackedScene = null
