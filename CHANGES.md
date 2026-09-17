# Історія змін (CHANGES)

### Виправлення помилки виклику `is_cell_solid` у `GridManager.gd`
- **Причина проблеми:**
  - В автотесті [`src/core/Main.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/core/Main.gd) викликався метод `GridManager.is_cell_solid(cell)`, але в `GridManager.gd` була лише зворотна перевірка `is_cell_walkable(cell)`.
- **Виправлення:**
  - Додано метод `is_cell_solid(map_pos: Vector2i) -> bool` до [`src/world/GridManager.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/world/GridManager.gd).
  - Тест у `Main.gd` тепер проходить успішно, запуск гри відбувається без жодних повідомлень про помилки.

### Ітерація 4.3: Природні об'єкти на карті (Дерево, Камінь, Кущ) та дроп
- Створено сутність ресурсу [`src/world/WorldResourceNode.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/world/WorldResourceNode.gd) та сцену [`WorldResourceNode.tscn`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/world/WorldResourceNode.tscn) (`StaticBody2D`):
  - Типи `ResourceType`: `TREE` (Дерево), `ROCK` (Камінь), `BUSH` (Кущ ягід).
  - При спавні реєструє свою клітинку в `GridManager.register_occupant(cell, self, true)`.
  - Метод `harvest(damage, tool_type)` з бонусом для відповідних інструментів (сокира/кирка) та процедурним тремтінням спрайта (Tween shake).
  - При руйнуванні звільняє клітинку в `GridManager` і спавнить випадіння предметів.
  - Процедурне відмалювання через `_draw()` (стовбур, листяні шари крони, валуни та ягідні кущі).
- Створено сутність дропу [`src/entities/items/DroppedItem.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/entities/items/DroppedItem.gd) та сцену [`DroppedItem.tscn`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/entities/items/DroppedItem.tscn) (`Area2D`):
  - Анімація погойдування над землею.
  - Магнітне притягання до гравця на швидкості 380 px/s при наближенні та автоматичне додавання до інвентаря гравця.
- Оновлено керування в [`src/entities/player/Player.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/entities/player/Player.gd):
  - Додано взаємодію на клавішу `E` (збір об'єкта перед собою).
  - Додано взаємодію лівим кліком миші (`primary_action`) у радіусі до 2.5 клітинок від гравця.
- Процедурний спавн ресурсів у [`src/world/World.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/world/World.gd):
  - Карта генерує дерева, валуни та ягідні кущі за межами стартової позиції гравця.
- Додано юніт-тест видобутку та звільнення клітинки сітки в [`src/core/Main.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/core/Main.gd).
- Оновлено `Documentation.md` (додано Розділ 11 "Природні ресурси та дроп предметів").

### Ітерація 4.2: Універсальний компонент інвентаря (`InventoryComponent.gd`)
- Створено клас слота `src/systems/inventory/InventorySlot.gd` (`RefCounted`).
- Створено універсальний компонент `src/systems/inventory/InventoryComponent.gd` (`Node`).
- Додано `InventoryComponent` як дочірній вузол до `Player.tscn`.
- Написано й успішно виконано юніт-тести в `src/core/Main.gd`.

### Виправлення помилки завантаження скриптів `Player.gd` та спаму `is_moving` у `PlayerVisual.gd`
- У `Player.gd` типізацію змінено на безпечний `Node`.
- У `PlayerVisual.gd` додано безпечні гетери властивостей через `.get()`.

### Виправлення помилки парсингу `Could not find type "ItemData"` в `ItemDatabase` та `Main`
- В `ItemDatabase.gd` та `Main.gd` усунуто жорстку залежність від глобального кешу `class_name`.

### Ітерація 4.1: Схеми предметів (Data-Driven ItemData & ItemDatabase)
- Створено схему предметів `src/data/schemas/ItemData.gd`.
- Створено допоміжну схему витрат `src/data/schemas/ItemCost.gd`.
- Створено базові предмети Кам'яного віку у `data/items/` (`wood.tres`, `stone.tres`, `flint.tres`, `berries.tres`).
- Створено та зареєстровано як Autoload реєстр `src/core/ItemDatabase.gd`.
- Оновлено `Documentation.md` (додано Розділ 9 "Data-Driven схеми предметів").

### Виправлення вібрації/джиттеру камери (`position_smoothing`)
- Вимкнено `position_smoothing_enabled = false` у `GameCamera2D.gd` та `Player.tscn`.

### Виправлення тремтіння (джиттеру/вібрації) при русі персонажа та камери
- Вимкнено `snap_2d_transforms_to_pixel = false` та `snap_2d_vertices_to_pixel = false` у `project.godot`.
- Перенесено `GameCamera2D` всередину `Player.tscn`.

### Ітерація 3.2: Плавна камера з зумом (GameCamera2D)
- Створено контролер камери `src/core/GameCamera2D.gd` (`Camera2D`).
- Плавне масштабування коліщатком миші (`zoom_in` / `zoom_out`) в діапазоні від 0.5x до 2.5x через інтерполяцію `Tween`.

### Гарячі клавіші F11 (Повний екран) та F12 (Вихід)
- Додано дії `toggle_fullscreen` на клавішу **F11** та `quit_game` на клавішу **F12** у `project.godot`.
- У `GameManager.gd` реалізовано методи перемикання повного екрану та швидкого виходу.

### Ітерація 3.1: Рух персонажа та візуал гравця
- Створено контролер персонажа `src/entities/player/Player.gd` (`CharacterBody2D`).
- Створено візуальний процедурний компонент `src/entities/player/PlayerVisual.gd`.
- Створено сцену `src/entities/player/Player.tscn` з колізією `CircleShape2D`.
- Інстанційовано `Player.tscn` у сцену світу `World.tscn`.

### Адаптація розміру карти світу під 1080p та 1440p
- У `World.gd` розмір карти оновлено до 80x50 тайлів (2560x1600 px).

### Виправлення завантаження текстур тайлів (Ітерація 2.2)
- Переписано `src/world/GroundLayer.gd` на процедурну генерацію `ImageTexture` в рантаймі.

### Ітерація 2.2: Базова тестова сцена світу з TileMapLayer
- Створено тайлсет-плейсхолдер, шар поверхні `GroundLayer.gd`, сцену `World.tscn` та відладку на `F3`.

### Ітерація 2.1: Реалізація GridManager та AStarGrid2D
- Створено `GridManager.gd` з `AStarGrid2D` та зареєстровано як Autoload.

### Покращення та аудит Ітерацій 1.1 та 1.2
- Розділено конфліктуючі дії введення (`Tab` для `colony_mode_toggle`, `I` для `inventory_toggle`, додано `zoom_in`/`zoom_out`).
- Покращено поведінку повернення станів у `GameManager.gd` при натисканні `Escape`.

### Ітерація 1.2: Реалізація EventBus та GameManager (Autoloads)
- Створено шину подій `EventBus.gd` та менеджер станів `GameManager.gd`.

### Ітерація 1.1: Ініціалізація структури папок та конфігурації Godot 4
- Створено структуру папок, `project.godot` (1920x1080 / 2560x1440), кореневу сцену `Main.tscn`.
