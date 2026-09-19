# Skill: Data-Driven Resource Schemas in 3D (Items, Recipes, Buildings, Blocks)

## 1. Опис та Призначення (Overview)
Цей скіл встановлює правила проектування даних за принципом **Data-Driven Design** у Godot 4 за допомогою кастомних `Resource` (`.tres`) для 3D гри **Saecula**.

### Чому це критично важливо:
* Повна ізоляція даних від логіки рендерингу та 3D фізики.
* Додавання нових 3D будівель, рецептів чи воксельних блоків виконується виключно створенням `.tres` файлів без зміни рушійного коду.

---

## 2. Схеми ресурсів

Усі схеми розміщуються у директорії: `res://src/data/schemas/`.

### 2.1. Допоміжна структура витрат (`ItemCost.gd`)
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

enum Category { RESOURCE, MATERIAL, TOOL, FOOD, WEAPON }
enum ToolType { NONE, AXE, PICKAXE, HAMMER, SWORD }

@export_group("Identity")
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("Properties")
@export var category: Category = Category.RESOURCE
@export var max_stack: int = 64
@export var tool_type: ToolType = ToolType.NONE
@export var tier: int = 0
@export var tool_efficiency: float = 1.0
```

---

### 2.3. Схема споруди у 3D світі (`BuildingData.gd`)
У 3D світі гри розмір споруди задається у тайлах `size_in_tiles: Vector2i`.
Оскільки розмір тайла у 3D просторі становить **`TILE_SIZE_3D = 1.0` метра**, розмір у тайлах точно відповідає фізичному розміру споруди в метрах:
* **Вогнище (Campfire):** `4x4` тайли = `4.0 x 4.0` метра
* **Склад (Stockpile):** `6x6` тайлів = `6.0 x 6.0` метра
* **Дерев'яна хатина (Wooden Hut):** `10x10` тайлів = `10.0 x 10.0` метра

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
## Розмір споруди в тайлах (1 тайл = 1.0м в 3D просторі)
@export var size_in_tiles: Vector2i = Vector2i(1, 1)
## Чи блокує споруда прохід для агентів
@export var is_solid: bool = true

@export_group("Construction")
@export var required_era_id: StringName = &"stone_age"
@export var build_time: float = 5.0
@export var construction_cost: Array[ItemCost] = []

@export_group("Functionality")
@export var job_type_provided: StringName = &""
@export var storage_slots: int = 0
```

---

### 2.4. Воксельні блоки (Minecraft-Style Voxel Blocks)
* Предмети категорій `wood` та `stone` підтримують розміщення як кубічні блоки `1.0 x 1.0 x 1.0м` (`WorldBlock3D`).
* Блоки автоматично взаємодіють з 3D сіткою `GridManager` та блокують розміщення споруд (`BuildingPlacementController`).
