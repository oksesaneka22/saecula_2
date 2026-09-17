# Історія змін (CHANGES)

### Покращення та аудит Ітерацій 1.1 та 1.2
- **Розділено конфліктуючі дії введення:**
  - `colony_mode_toggle` виділено на окрему клавішу `Tab` (режим симулятора колонії зі сповільненим часом за `docs/UI.md`).
  - `inventory_toggle` виділено на клавішу `I` (відкриття/закриття інтерфейсу інвентаря).
  - Додано дії `zoom_in` та `zoom_out` на коліщатко миші (Wheel Up / Wheel Down) для плавної роботи камери в Етапі 3.
- **Оновлено `GameManager.gd`:**
  - `Escape` тепер акуратно повертає з `BUILDING_MODE` у попередній стан, з `COLONY_MODE` у звичайний режим `PLAYING`, або ставить/знімає системну паузу без циклічних багів.
  - Додано еміт сигналу `EventBus.inventory_window_toggle_requested` при натисканні `I`.
- **Оновлено документацію:**
  - Оновлено таблиці керування в [README.md](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/README.md) та [Documentation.md](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/Documentation.md).
- **Валідація:**
  - Проект повторно протестовано через консоль Godot 4 у безголовому режимі: 0 помилок, 0 попереджень.

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
