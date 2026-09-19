# Історія змін (CHANGES)

### Ітерація 7.2: Меню споруд та розміщення блупрінтів (Factorio Blueprints & Build Menu UI)
- **Оновлено розміри споруд (за запитом користувача):**
  - Склад ресурсів (`stockpile`): змінено розмір на **4x4 тайли (8x8м)** (було 6x6).
  - Дерев'яна хатина (`wooden_hut`): змінено розмір на **6x6 тайлів (12x12м)** (було 8x8).
  - Оновлено ресурсні файли `stockpile.tres`, `wooden_hut.tres`, 2D клас `StockpileBuilding.gd` та модульні тести перевірки зайнятих тайлів у `Main.gd`.
- **Створено голографічну систему візуалізації блупрінтів (`src/world3d/BlueprintVisualHelper.gd`):**
  - Factorio-style напівпрозорий ціановий/неоновий матеріал з емісією та м'яким пульсуванням.
  - Генерація точних голограм силуету споруд для табірного вогнища (`campfire` 2x2), складу (`stockpile` 6x6), дерев'яної хатини (`wooden_hut` 8x8) та універсальних споруд.
- **Оновлено візуалізацію встановлення `BuildingGhost3D.gd`:**
  - При переміщенні курсору миші поверхнею сітки відтворюється не просто плоский прямокутник, а 3D каркас майбутньої будівлі.
  - Динамічне підсвічування зеленим кольором (якщо тайли вільні та прохідні) або яскраво-червоним (при наявності перешкод).
- **Оновлено будівельний майданчик `ConstructionSite3D.gd`:**
  - Після кліку встановлення креслення на карті залишається повноцінна голограма споруди (Factorio Blueprint), яка пульсує доки триває доставка матеріалів та будівництво.
  - Оновлено 3D Billboard текст: «📐 КРЕСЛЕННЯ: [Назва] [NxN]», перелік ресурсів, статус внесених матеріалів та прогрес будівництва.
  - Повне збереження механіки підходу гравця на `E`/клік для внесення деревини та каменю й зведення споруди.
- **Покращено інтерфейс вибору споруд `BuildMenuUI` (`src/ui/hud/BuildMenuUI.gd`, `BuildMenuUI.tscn`):**
  - Додано затемнення фону (`DimOverlay`) для фокусування уваги, клік по якому закриває меню.
  - Додано категорії споруд: «Усі споруди», «Базові», «Сховища», «Житло & Праця».
  - Картки споруд містять прев'ю текстур, габарити в тайлах та метрах, детальні описи, особливості (обігрів, сховище, робоче місце) та перевірку необхідних ресурсів в інвентарі гравця і на складах колонії.
  - Кнопка «📐 Встановити креслення» миттєво переводить у режим встановлення блупрінта.
- **Створено панель швидких дій на HUD `HUDActionBar` (`src/ui/hud/HUDActionBar.gd`, `HUD.tscn`):**
  - Додано видимі кнопки швидкого доступу на HUD у нижньому правому кутку: «🔨 Будівництво [B]», «🛠️ Крафт [C]», «🎒 Інвентар [I]».
- **Покращено поведінку камери та контролера будівництва:**
  - `World3D.gd`: при активації режиму будівництва камера RTS плавно центрується безпосередньо над поточною позицією гравця.
  - `BuildingPlacementController.gd`: підтримка безперервного розміщення кількох блупрінтів при затиснутій клавіші `Shift`, вихід по `ПКМ` або `Escape`.
- **Модульне тестування (`src/core/Main.gd`):**
  - Додано тест №10 `_test_blueprint_and_build_menu()`: валідація створення голографічних матеріалів, генерації геометрії блупрінтів, наявності голограми на `ConstructionSite3D` та відкриття/закриття `BuildMenuUI`.

### Ітерація 7.1: Скриня та зона складу (Stockpile & Colony Logistics)
- **Розширено EventBus (`src/core/EventBus.gd`):**
  - Додано події логістики: `stockpile_registered(stockpile)`, `stockpile_unregistered(stockpile)`, `colony_storage_updated(item_id, total_amount)`, `storage_ui_requested(storage_node)`, `storage_ui_closed()`.
- **Створено глобальний Autoload `LogisticsManager` (`src/systems/logistics/LogisticsManager.gd`):**
  - Централізований облік усіх складів, контейнерів та сховищ колонії.
  - Методи: `register_stockpile(node)`, `unregister_stockpile(node)`, `get_available_item_count(item_id)`, `get_total_stored_items()`, `find_stockpile_with_item(item_id, min_amount)`, `find_stockpile_with_space(item_id, amount)`, `deposit_item(item_id, amount)`, `withdraw_item(item_id, amount)`.
  - Додано `LogisticsManager="*res://src/systems/logistics/LogisticsManager.gd"` в `project.godot`.
- **Створено 2D сутність `StockpileBuilding.gd` (`src/world/buildings/StockpileBuilding.gd`):**
  - Власний `InventoryComponent` на 32 слоти.
  - Автоматична реєстрація в `LogisticsManager` та клітинок у `GridManager`.
  - Малювання розміченого дерев'яного настилу 6x6 клітинок.
- **Оновлено 3D споруду `BuildingEntity3D.gd`:**
  - Автоматична реєстрація споруди в `LogisticsManager` при `storage_slots > 0` (зокрема склад `stockpile`).
  - Методи: `get_available_item_count(item_id)`, `withdraw_item(item_id, count)`, `deposit_item(item_id, count)`, `interact_storage(player)`.
  - 3D Billboard показує заповненість сховища (`[Склад: X/32 слотів (Y реч.)]`).
- **Створено інтерфейс передачі предметів `StorageUI` (`src/ui/storage/StorageUI.gd`, `StorageUI.tscn`):**
  - Адаптивне двоколонкове модальне вікно (інвентар гравця 24 слоти зліва, склад 32 слоти справа).
  - Швидкі кнопки перенесення: "⬇ Покласти все на склад" та "⬆ Забрати все в інвентар".
  - Перенесення предметів в один клік миші між гравцем і складом.
  - Підтримка клавіш `Escape`, `E`, `I` та кліку поза вікном для закриття.
  - Інтегровано у вузол `HUD.tscn`.
- **Підтримка взаємодії зі сховищем у режимах FPS та RTS:**
  - `Player3D.gd`: перевірка наявності `interact_storage` при натисканні `E` або `ЛКМ`.
  - `RTSCamera3D.gd`: відкриття складу кліком миші у вільному режимі колонії.
- **Модульне тестування в `Main.gd`:**
  - Додано тест №9: комплексна перевірка реєстрації, обліку ресурсів, внесення, вилучення та автоматичного зняття з обліку 2D і 3D складів.

### Перехід на статичні файли текстур замість суто процедурних описів у коді
- **Створено структуру директорій та набір статичних текстур (`res://assets/textures/`):**
  - `assets/textures/terrain/`: `grass.png` — текстура трав'яного покриву поверхні землі.
  - `assets/textures/resources/`: `wood_bark.png`, `foliage.png`, `rock.png`, `rock_dark.png`, `bush.png`, `berries.png` — текстури природних ресурсів (стовбур дерева, крона, скелі, кущі, ягоди).
  - `assets/textures/buildings/`: `campfire_stone.png`, `log_wood.png`, `fire.png`, `wood_planks.png`, `wood_post.png`, `crate.png`, `hut_wall.png`, `hut_roof.png`, `hut_door.png`, `site_ground.png`, `rope.png`, `generic_building.png` — текстури будівельних елементів споруд та майданчиків.
  - `assets/textures/items/`: `wood.png`, `stone.png`, `flint.png`, `berries.png`, `stone_axe.png`, `stone_pickaxe.png`, `campfire.png`, `generic_item.png` — текстури предметів та інструментів.
  - Усі файли створено у форматі PNG (32x32 пікселі) з коректними заголовками зображення, що дозволяє Godot автоматично імпортувати їх через `ResourceLoader`, а розробнику — вільно замінювати на власні ассет-паки або малюнки без зміни коду.
- **Створено центральний помічник [`TextureHelper.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/core3d/TextureHelper.gd):**
  - Кешує завантажені `Texture2D` ресурси через `ResourceLoader.load()`.
  - Метод `create_material(path, fallback_color, roughness, uv_scale, emission_enabled, emission_color, emission_energy)`: формує `StandardMaterial3D` з підключенням текстури файлу, чистим кольором мультиплікації `Color.WHITE` (усуває небажане забарвлення користувацьких текстур) та фільтрацією `TEXTURE_FILTER_NEAREST_WITH_MIPMAPS` для збереження чіткості пікселів у RTS та FPS ракурсах.
  - Метод `get_item_texture_path(item_id)`: централізовано зіставляє ідентифікатор предмета з файлом текстури.
- **Інтегровано статичні текстури у всі 3D сутності проекту:**
  - [`World3D.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/world3d/World3D.gd): земля використовує `TextureHelper.PATH_TERRAIN_GRASS` з тайлінгом UV за розміром карти.
  - [`WorldResourceNode3D.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/world3d/WorldResourceNode3D.gd): стовбур, хвоя/листя, валуни та кущі ягід використовують відповідні текстури з `assets/textures/resources/`.
  - [`BuildingEntity3D.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/world3d/BuildingEntity3D.gd): вогнище, склад та дерев'яна хатина використовують текстури з `assets/textures/buildings/`.
  - [`ConstructionSite3D.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/world3d/ConstructionSite3D.gd): основа будівельного майданчика, розмічальні палі та огороджувальні троси використовують текстури з `assets/textures/buildings/`.
  - [`DroppedItem3D.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/entities3d/items/DroppedItem3D.gd): 3D моделі дропу підтягують текстури з `assets/textures/items/`.

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
