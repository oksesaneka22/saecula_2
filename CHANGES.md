# Історія змін (CHANGES)

### Виправлення зависання при завершенні будівництва вогнища та помилки сигналів часу
- **Усунено критичну невідповідність аргументів сигналу `day_time_updated` ([`Main.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/core/Main.gd)):**
  - Виправлено сигнатуру обробника `_on_day_time_updated(hour: int, minute: int)` відповідно до визначення в [`EventBus.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/core/EventBus.gd) та виклику в [`GameManager.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/core/GameManager.gd) (2 аргументи замість 3).
  - Припинено безперервне генерування помилок рушія в консоль щохвилини ігрового часу (`Method expected 3 argument(s), but called with 2`), що спричиняло постійні перехоплення стеку зневаджувачем рушія.
- **Усунено зависання/фріз (hitch) при спавні вогнища ([`BuildingEntity3D.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/world3d/BuildingEntity3D.gd)):**
  - Вимкнено `_fire_light.shadow_enabled = false` у джерелі світла вогню (`OmniLight3D`). У рушії Godot 4 динамічне увімкнення тіней для всенаправлених точкових джерел світла змушує рушій синхронно в головному потоці виділяти Shadow Atlas та компілювати кубічні шейдери глибини тіней, що спричиняло різке падіння кадрів (зависання) у момент появи готового вогнища.
  - Оптимізовано процедурну генерацію геометрії вогнища та складу: переведено на спільне використання ресурсів `BoxMesh` та `CylinderMesh` замість масового створення окремих мешів для кожного камінця та колоди.
- **Виправлено юніт-тест видобутку та замикання ([`WorldResourceNode3D.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/world3d/WorldResourceNode3D.gd), [`Main.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/core/Main.gd)):**
  - Додано емісію сигналу `EventBus.item_dropped` та `EventBus.resource_harvested` при знищенні ноди ресурсу.
  - У юніт-тесті `_test_harvest_and_drop` використано типізований масив-обгортку для коректного захоплення змінної за посиланням у лямбда-функції GDScript.
  - Усі 8 комплексних тестів проходять зі 100% успіхом без жодної помилки або попередження рушія.

### Зміна габаритів будівель (Campfire 2x2, Stockpile 6x6, Hut 8x8) та повернення стартового майданчика будівлі на спавні
- **Оновлено конфігураційні ресурси споруд у `data/buildings/`:**
  - [`campfire.tres`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/data/buildings/campfire.tres): Змінено розмір `size_in_tiles` на **2x2** (4 клітинки, 4х4м). Час зведення встановлено на 4.0 сек.
  - [`stockpile.tres`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/data/buildings/stockpile.tres): Змінено розмір `size_in_tiles` на **6x6** (36 клітинок, 12х12м). Зберігає 32 слоти, час зведення 6.0 сек.
  - [`wooden_hut.tres`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/data/buildings/wooden_hut.tres): Змінено розмір `size_in_tiles` на **8x8** (64 клітинки, 16х16м). Час зведення 10.0 сек.
- **Адаптовано процедурні 3D моделі ([`BuildingEntity3D.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/world3d/BuildingEntity3D.gd)):**
  - Вогнище: пропорційно відмасштабовано радіус кам'яного кола (1.4м), зменшено валуни (0.5м x 0.35м x 0.5м), адаптовано конус полум'я (1.5м) та світло `OmniLight3D` (висота 1.0м).
  - Склад: оновлено платформу під 12м x 12м, кутові стовпчики та декоративні ящики з товарами.
  - Хатина: оновлено стіни зрубу 16м x 16м, двосхилий дах-призму, дубові двері та настінний ліхтар.
  - Динамічна висота 3D Billboard (`Label3D`) під кожен розмір будівлі.
- **Відновлено стартовий будівельний майданчик на спавні ([`World3D.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/world3d/World3D.gd)):**
  - Додано метод `_spawn_starter_construction_site()` в `_ready()`.
  - Автоматично інстанціює 2x2 майданчик вогнища безпосередньо перед гравцем (`spawn_cell + Vector2i(-1, -4)`).
  - Майданчик коректно займає 4 клітинки в `GridManager`, відображає список необхідних матеріалів і готовий до взаємодії через `E` / `ЛКМ`.
- **Стартовий набір інструментів та ресурсів для гравця ([`Player3D.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/entities3d/player/Player3D.gd)):**
  - При старті гри гравець автоматично отримує кам'яну сокиру, кам'яне кайло, 12 деревини та 8 каменю для миттєвого тестування будівництва та збору.
- **Стабілізовано та оновлено юніт-тести ([`Main.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/core/Main.gd)):**
  - Перевірка габаритів 2x2 для вогнища, 6x6 для складу, 8x8 для хатини.
  - Тестування повного життєвого циклу будівництва на 4 клітинках для 2x2 майданчика.
  - Усі 8 юніт-тестів проходять бездоганно з кодом завершення 0 та 0 помилок.
