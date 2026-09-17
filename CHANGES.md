# Історія змін (CHANGES)

### Виправлення помилки парсингу `Could not find type "ItemData"` в `ItemDatabase` та `Main`
- **Причина проблеми:**
  - В рушії Godot скрипти `Autoload` парсяться й компілюються раніше, ніж створюється та оновлюється глобальний кеш імен класів `class_name` (`.godot/global_script_class_cache.cfg`).
  - Через це пряме використання статичного типу `ItemData` всередині `ItemDatabase.gd` та `Main.gd` призводило до помилки парсера: `Could not find type "ItemData" in the current scope`.
- **Виправлення:**
  - У [`src/core/ItemDatabase.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/core/ItemDatabase.gd) замінено статичний тип `ItemData` на базовий `Resource`, додано `preload("res://src/data/schemas/ItemData.gd")` та динамічне визначення ідентифікаторів ресурсів.
  - У [`src/core/Main.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/core/Main.gd) оновлено сигнатуру валідації на використання `Resource`.
  - Успішно протестовано як у `headless`, так і в графічному режимі запуску `godot --path "." --quit`.

### Ітерація 4.1: Схеми предметів (Data-Driven ItemData & ItemDatabase)
- Створено схему предметів `src/data/schemas/ItemData.gd` (`class_name ItemData`).
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
