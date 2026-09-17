# Історія змін (CHANGES)

### Ітерація 2.1: Реалізація GridManager та AStarGrid2D
- Створено [`src/world/GridManager.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/world/GridManager.gd) згідно з вимогами `skill-grid-pathfinding.md`:
  - Розмір тайла за замовчуванням `TILE_SIZE = 32`.
  - Ініціалізація `AStarGrid2D` на 128x128 тайлів, режим руху `DIAGONAL_MODE_NEVER` для чистого 4-напрямного переміщення та запобігання зрізанню кутів будівель, `HEURISTIC_MANHATTAN`.
  - Методи конвертації координат `world_to_map()` та `map_to_world()` (повертає центр клітинки).
  - Методи керування прохідністю: `is_cell_walkable()`, `set_cell_solid()`, `set_cell_weight()`.
  - Реєстрація сутностей та об'єктів на сітці: `register_occupant()`, `unregister_occupant()`, `get_occupant()`.
  - Алгоритм пошуку найближчого прохідного сусіда: `get_closest_walkable_neighbor()` для збору ресурсів і підходу до непрохідних об'єктів.
  - Отримання світового шляху: `get_world_path()` з автоматичним підходом до об'єкта, якщо кінцева точка є твердою.
  - Перевірка чистоти зони під будівлі `is_area_clear()`.
- Зареєстровано `GridManager` як глобальний Autoload у `project.godot`.
- Оновлено `Documentation.md`, додано опис функціоналу `GridManager`.
- Проведено валідацію через запуск у консолі рушія `godot --headless`.

### Покращення та аудит Ітерацій 1.1 та 1.2
- Розділено конфліктуючі дії введення (`Tab` для `colony_mode_toggle`, `I` для `inventory_toggle`, додано `zoom_in`/`zoom_out`).
- Покращено поведінку повернення станів у `GameManager.gd` при натисканні `Escape`.

### Ітерація 1.2: Реалізація EventBus та GameManager (Autoloads)
- Створено глобальну шину подій `src/core/EventBus.gd` з основними сигналами гри.
- Створено центральний контролер станів `src/core/GameManager.gd`.
- Зареєстровано `EventBus` та `GameManager` у секції `[autoload]` файлу `project.godot`.

### Оновлення документації: Інструкція із запуску в README
- Додано в `README.md` інструкції щодо запуску через Godot Editor (GUI) та CLI (`--headless`).

### Ітерація 1.1: Ініціалізація структури папок та конфігурації Godot 4
- Створено модульну структуру директорій проекту (`assets/`, `data/`, `src/`).
- Створено `project.godot` з роздільною здатністю 1920x1080 / 2560x1440, режимом `canvas_items` та мапою дій.
- Створено початкову кореневу сцену `src/core/Main.tscn` та `icon.svg`.
