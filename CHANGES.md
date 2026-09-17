# Історія змін (CHANGES)

### Гарячі клавіші F11 (Повний екран) та F12 (Вихід)
- Додано дії `toggle_fullscreen` на клавішу **F11** та `quit_game` на клавішу **F12** у [`project.godot`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/project.godot).
- У [`src/core/GameManager.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/core/GameManager.gd) реалізовано:
  - `toggle_fullscreen()` — плавне перемикання між віконним режимом та нативним повноекранним режимом через `DisplayServer.window_set_mode()`.
  - `quit_game()` — швидке та безпечне закриття гри через `get_tree().quit()`.
  - Обробка дій відбувається в `_unhandled_input()` із пріоритетом (працює навіть під час паузи, оскільки `GameManager.process_mode = PROCESS_MODE_ALWAYS`).
- Оновлено таблиці керування в [README.md](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/README.md) та [Documentation.md](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/Documentation.md).

### Ітерація 3.1: Рух персонажа та візуал гравця
- Створено контролер персонажа `src/entities/player/Player.gd` (`CharacterBody2D`):
  - 8-напрямний плавний рух через `Input.get_vector("move_left", "move_right", "move_up", "move_down")`.
  - Нормалізація діагональної швидкості.
  - Налаштовано швидкість (140 px/s), прискорення (1200 px/s²) та тертя (1400 px/s²).
  - Вектор погляду `facing_direction` (Vector2).
  - Інтеграція з `GridManager`: додано `get_current_cell()` та `get_interaction_cell()`.
- Створено візуальний процедурний компонент `src/entities/player/PlayerVisual.gd`.
- Створено сцену `src/entities/player/Player.tscn` з колізією `CircleShape2D` (радіус 8 пікселів).
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
