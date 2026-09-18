# Історія змін (CHANGES)

### Виправлення помилки виклику Object.get у Player3D.gd
- **Усунено критичну помилку при видобутку ресурсів:**
  - У `Player3D.gd` виправлено виклики `slot.item.get("tool_type")` та `slot.item.get("tool_efficiency")`.
  - У Godot GDScript метод `Object.get(property: StringName)` приймає рівно 1 аргумент (на відміну від `Dictionary.get(key, default)`). Передача другого аргументу за замовчуванням спричиняла `Invalid call to function 'get' in base 'Resource (ItemData)'. Expected 1 argument(s)`.
  - Синхронізовано зчитування коефіцієнта шкоди з полем `tool_efficiency` (зі схеми `ItemData.gd`).
  - Додано автоматичний юніт-тест `_test_player_3d_tools()` до `Main.gd` для перевірки визначення типу інструмента та його ефективності як для порожніх рук, так і при екіпірованій сокирі.

### Реалізація 3D Гібридного режиму (First-Person Гравець + Top-Down RTS Огляд Колонії)
- **3D Персонаж гравця від першої особи:**
  - Створено [`src/entities3d/player/Player3D.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/entities3d/player/Player3D.gd) та [`Player3D.tscn`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/entities3d/player/Player3D.tscn).
  - Підтримка вільного огляду мишею з захопленням курсора (`MOUSE_MODE_CAPTURED`), кут огляду голови від -85° до +85°.
  - 3D переміщення WASD, гравітація та стрибки на клавішу `Space` (`jump`).
  - Променева взаємодія `RayCast3D` (3.2м): удари та видобуток ресурсів `WorldResourceNode3D` по натисканню `ЛКМ` або `E`, врахування активного інструмента в хотбарі (сокира/кирка) та анімація удару.
  - Повна інтеграція з існуючим `InventoryComponent` (24 слоти).
- **3D RTS Камера менеджменту зверху:**
  - Створено [`src/core3d/RTSCamera3D.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/core3d/RTSCamera3D.gd) та [`RTSCamera3D.tscn`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/core3d/RTSCamera3D.tscn).
  - Камера під кутом ~55° (Dota 2 / Factorio стиль) для огляду всього поселення.
  - Переміщення WASD по площині землі, плавний зум коліщатком миші від 8м до 36м.
  - 3D Raycast кліки мишкою для видобутку ресурсів та вибору клітинок карти.
- **Безшовне перемикання режимів (`Tab`):**
  - Натискання `Tab` миттєво перемикає між режимом безпосереднього керування гравцем від 1-ї особи (`PLAYING`) та режимом огляду/менеджменту зверху (`COLONY_MODE`).
  - При переході в режим колонії RTS-камера фокусується на поточній позиції гравця, а курсор миші стає вільним для кліків.
- **3D Світ та природні ресурси:**
  - Створено [`src/world3d/World3D.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/world3d/World3D.gd) та [`World3D.tscn`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/world3d/World3D.tscn).
  - Створено [`src/world3d/WorldResourceNode3D.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/world3d/WorldResourceNode3D.gd) та [`WorldResourceNode3D.tscn`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/world3d/WorldResourceNode3D.tscn) (процедурні 3D моделі дерев з багатошаровою кроною, валунів зі скелями та кущів ягід, анімація віддачі `Tween`, реєстрація в `GridManager`).
  - Створено [`src/entities3d/items/DroppedItem3D.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/entities3d/items/DroppedItem3D.gd) та [`DroppedItem3D.tscn`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/entities3d/items/DroppedItem3D.tscn) з обертанням, левітацією та 3D магнітним підбиранням.
- **Оновлення інтерфейсу (HUD):**
  - Створено [`src/ui/hud/CrosshairUI.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/ui/hud/CrosshairUI.gd) — динамічний приціл у центрі екрана під час режиму 1-ї особи.
  - Створено [`src/ui/hud/ModeIndicatorUI.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/ui/hud/ModeIndicatorUI.gd) — інформаційна плашка поточного режиму у верхній частині екрана.
  - Інтегровано автоматичне захоплення/звільнення курсора миші при відкритті меню інвентаря (`I`) та крафту (`C`).
- **Оновлення точки входу:**
  - Оновлено [`src/core/Main.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/core/Main.gd) та [`src/core/Main.tscn`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/core/Main.tscn) для запуску у 3D просторі з валідацією всіх систем.

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
