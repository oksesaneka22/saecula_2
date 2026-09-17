# Skill: Data-Driven Resource Schemas (Items, Recipes, Buildings, Eras)

## 1. Опис та Призначення (Overview)
Цей скіл встановлює правила проектування даних за принципом **Data-Driven Design** у Godot 4 за допомогою кастомних `Resource` (`.tres`).

### Чому це критично важливо:
* Повна ізоляція даних від логіки.
* Щоб додати новий предмет (наприклад, "Мідний злиток"), новий рецепт або нову будівлю, **не потрібно змінювати код гри** — достатньо створити файл `.tres`.
* Мінімізує помилки при роботі зі штучним інтелектом (Gemini 3.8 Flash може безпечно генерувати контент, не ризикуючи зламати скрипти рушія).

---

## 2. Схеми ресурсів

Всі схеми розміщуються у директорії: `res://src/data/schemas/`.

### 2.1. Допоміжна структура витрат (`ItemCost.gd`)
Використовується скрізь, де потрібна пара "Предмет + Кількість" (рецепти, вартість будівель, перехід між епохами).

```gdscript
# res://src/data/schemas/ItemCost.gd
class_name ItemCost
extends Resource

@export var item: ItemData
@export var amount: int = 1
```

---

### 2.2. Схема предмета (`ItemData.gd`)

```gdscript
# res://src/data/schemas/ItemData.gd
class_name ItemData
extends Resource

enum Category {
	RESOURCE,    ## Сировина (дерево, камінь, руда)
	MATERIAL,    ## Оброблений матеріал (дошки, злитки, цегла)
	TOOL,        ## Інструменти (сокира, кирка, молоток)
	FOOD,        ## Їжа (ягоди, хліб, м'ясо)
	WEAPON       ## Зброя (спис, меч, лук)
}

enum ToolType {
	NONE,
	AXE,
	PICKAXE,
	HAMMER,
	SWORD
}

@export_group("Identity")
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("Properties")
@export var category: Category = Category.RESOURCE
@export var max_stack: int = 64
@export var tool_type: ToolType = ToolType.NONE
## Рівень інструменту (0 = руки, 1 = камінь, 2 = бронза, 3 = залізо)
@export var tier: int = 0
@export var tool_efficiency: float = 1.0
```

---

### 2.3. Схема рецепта крафту (`RecipeData.gd`)

```gdscript
# res://src/data/schemas/RecipeData.gd
class_name RecipeData
extends Resource

@export var id: StringName = &""
@export var result_item: ItemData
@export var result_count: int = 1
@export var craft_time: float = 1.0

## Епоха, в якій стає доступним рецепт
@export var required_era_id: StringName = &"stone_age"

## Робоче місце (наприклад, "hands", "crafting_bench", "bloomery", "forge")
@export var crafting_station: StringName = &"hands"

## Масив інгредієнтів
@export var ingredients: Array[ItemCost] = []
```

---

### 2.4. Схема будівлі / Креслення (`BuildingData.gd`)

```gdscript
# res://src/data/schemas/BuildingData.gd
class_name BuildingData
extends Resource

@export_group("Identity")
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var texture: Texture2D
@export var preview_texture: Texture2D

@export_group("Grid & Footprint")
## Розмір споруди в тайлах (наприклад, 1x1 для скрині, 3x3 для будинку)
@export var size_in_tiles: Vector2i = Vector2i(1, 1)
## Чи блокує будівля прохід для агентів
@export var is_solid: bool = true

@export_group("Construction")
@export var required_era_id: StringName = &"stone_age"
## Час роботи колоніста-будівельника над спорудою
@export var build_time: float = 5.0
## Необхідні ресурси для побудови
@export var construction_cost: Array[ItemCost] = []

@export_group("Functionality")
## Тип професії або робочого місця, яке дає будівля
@export var job_type_provided: StringName = &""
## Місткість зберігання (якщо це склад або скриня)
@export var storage_slots: int = 0
```

---

### 2.5. Схема епохи (`EraData.gd`)

```gdscript
# res://src/data/schemas/EraData.gd
class_name EraData
extends Resource

@export var id: StringName = &"stone_age"
@export var display_name: String = "Кам'яний вік"
@export var order_index: int = 0
@export_multiline var description: String = ""

## Що необхідно принести до Ратуші/Столу досліджень для переходу в цю епоху
@export var unlock_cost: Array[ItemCost] = []

## Списки розблокованого контенту
@export var unlocked_recipes: Array[RecipeData] = []
@export var unlocked_buildings: Array[BuildingData] = []
```

---

## 3. Реєстр та Завантажувач (`ItemDatabase.gd`)

Для швидкого доступу до предметів за `id` використовується глобальний реєстр:

```gdscript
# res://src/core/ItemDatabase.gd
class_name ItemDatabase
extends Node

static var items: Dictionary = {} # StringName -> ItemData
static var recipes: Dictionary = {} # StringName -> RecipeData
static var buildings: Dictionary = {} # StringName -> BuildingData

static func get_item(item_id: StringName) -> ItemData:
	return items.get(item_id, null)

static func get_building(building_id: StringName) -> BuildingData:
	return buildings.get(building_id, null)

## Завантаження всіх .tres з папки
static func load_all_resources(path: String, target_dict: Dictionary) -> void:
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".res")):
				var res = load(path.path_join(file_name))
				if "id" in res and res.id != &"":
					target_dict[res.id] = res
			file_name = dir.get_next()
```

---

## 4. Інструкції для Gemini 3.8 Flash при роботі з даними

1. **Ніколи не хардкодити властивості предметів у коді дій:** Не пиши `if item_name == "axe": damage = 5`. Використовуй `item.tool_type == ItemData.ToolType.AXE` та `item.tool_efficiency`.
2. **Тип `StringName` для ідентифікаторів:** Використовуй `&"stone"` замість `"stone"`. Це оптимізує пам'ять та порівняння ключів у Godot.
3. **Експорт типів:** Завжди використовуй `@export var ...` для можливості редагування ресурсів через Інспектор Godot.
