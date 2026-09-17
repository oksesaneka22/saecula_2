# Історія змін (CHANGES)

### Виправлення вібрації/джиттеру камери (`position_smoothing`)
- **Аналіз причини на основі відеозапису:**
  - Коли `Camera2D` є дочірнім вузлом `CharacterBody2D`, увімкнений параметр `position_smoothing_enabled = true` намагається розраховувати лаг відносно локальних координат вузла.
  - На моніторах з частотою оновлення понад 60Hz (144Hz / 165Hz / 240Hz) фізичний такт рушія (60 fps) і частота рендерингу не збігаються, через що виникає фазове биття (стробоскопічний джиттер — камера запізнюється на випадкову частку кадру і ривком наздоганяє персонажа).
- **Виправлення:**
  - Вимкнено `position_smoothing_enabled = false` у [`src/core/GameCamera2D.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/core/GameCamera2D.gd) та [`src/entities/player/Player.tscn`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/entities/player/Player.tscn).
  - Тепер камера жорстко та миттєво прив'язана до персонажа: координати камери ідеально відповідають позиції гравця кожен кадр без фазових розривів.
  - Зум коліщатком миші продовжує працювати плавно через `Tween`.

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
