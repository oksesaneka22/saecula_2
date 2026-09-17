# Історія змін (CHANGES)

### Додано інтерфейс крафту (CraftingUI)
- Створено контролер інтерфейсу [`src/ui/hud/CraftingUI.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/ui/hud/CraftingUI.gd) та інтегровано в [`HUD.tscn`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/ui/hud/HUD.tscn).
- Додано гарячу клавішу **`C`** (`crafting_toggle`) у [`project.godot`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/project.godot).
- Вікно автоматично відображає всі доступні рецепти:
  - Кам'яна сокира (2 дерева + 2 кременю)
  - Кам'яна кирка (2 дерева + 3 каменю)
  - Багаття (4 дерева + 4 каменю)
- Динамічний підрахунок ресурсів гравця у форматі: `Назва: наявна_кількість / потрібна_кількість` (підсвічується зеленим, коли вистачає, або червоним, коли недостатньо).
- Кнопка «Скрафтити» активується автоматично лише при достатній кількості інгредієнтів.

### Ітерація 5.1: Схема рецептів та менеджер крафту (CraftingManager)
- Створено схему даних рецептів [`src/data/schemas/RecipeData.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/data/schemas/RecipeData.gd):
  - Підтримка списку інгредієнтів (`ItemCost`), результату крафту, кількості, часу виготовлення та вимоги до епохи (`required_era`).
- Створено нові предмети інструментів у `data/items/`:
  - `stone_axe.tres` (Кам'яна сокира, ефективність 2.0x проти дерев).
  - `stone_pickaxe.tres` (Кам'яна кирка, ефективність 2.0x проти каменю).
  - `campfire.tres` (Багаття).
- Створено базові рецепти у `data/recipes/`:
  - `craft_stone_axe.tres`: 2 дерева + 2 кременю $\to$ 1 `stone_axe`.
  - `craft_stone_pickaxe.tres`: 2 дерева + 3 каменю $\to$ 1 `stone_pickaxe`.
  - `craft_campfire.tres`: 4 дерева + 4 каменю $\to$ 1 `campfire`.
- Створено та зареєстровано як Autoload [`src/systems/crafting/CraftingManager.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/systems/crafting/CraftingManager.gd):
  - Автоматичне сканування папки рецептів `res://data/recipes/`.
  - Методи `get_recipe()`, `get_all_recipes()`, `get_recipes_for_era()`.
  - Метод валідації `can_craft(recipe, inventory) -> bool`.
  - Метод виконання `craft_item(recipe, inventory) -> bool`: списання матеріалів, видача результату та емісія сигналу `recipe_crafted`.
- Додано автоматичний юніт-тест повного циклу крафту сокири в [`src/core/Main.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/core/Main.gd).
- Оновлено `Documentation.md` (додано Розділ 13 "Система крафту").

### Ітерація 4.4: UI швидкого доступу (Hotbar) та Інвентар гравця
- Створено компонент слота інтерфейсу `ItemSlotUI.gd`.
- Створено панель швидкого доступу `HotbarUI.gd` (8 слотів).
- Створено вікно повного інвентаря `InventoryUI.gd` (24 слоти на клавішу `I` / `Tab`).
- Створено сцену `HUD.tscn` (`CanvasLayer`) та підключено до `Main.tscn`.

### Виправлення помилки виклику `is_cell_solid` у `GridManager.gd`
- Додано метод `is_cell_solid(map_pos: Vector2i) -> bool` до `GridManager.gd`.

### Ітерація 4.3: Природні об'єкти на карті (Дерево, Камінь, Кущ) та дроп
- Створено сутність ресурсу `WorldResourceNode.gd` та `WorldResourceNode.tscn` (`TREE`, `ROCK`, `BUSH`).
- Створено сутність дропу `DroppedItem.gd` та `DroppedItem.tscn` з магнітним притяганням.
- Додано видобуток на `E` та лівий клік миші у `Player.gd`.
- Спавн дерев, каменів та ягід у `World.gd`.

### Ітерація 4.2: Універсальний компонент інвентаря (`InventoryComponent.gd`)
- Створено клас слота `InventorySlot.gd` та `InventoryComponent.gd`.
- Додано `InventoryComponent` до `Player.tscn`.

### Ітерація 4.1: Схеми предметів (Data-Driven ItemData & ItemDatabase)
- Створено схему предметів `ItemData.gd`, `ItemCost.gd`, базові предмети в `data/items/`.
- Створено Autoload реєстр `ItemDatabase.gd`.
