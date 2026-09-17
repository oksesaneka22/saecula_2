# Документація проекту Saecula

## 1. Загальна конфігурація рушія (Godot 4.x)
- **Версія конфігурації:** `config_version=5` (Godot 4.x).
- **Рендерер:** `gl_compatibility` (OpenGL 3 / WebGL 2 сумісний рендерер) для найвищої сумісності та плавної продуктивності без оверхеду важких шейдерів.
- **Піксельна точність (Pixel Snap):**
  - `snap_2d_transforms_to_pixel = true`
  - `snap_2d_vertices_to_pixel = true`
  - `default_texture_filter = 0` (Nearest) для чіткого відмалювання піксель-арту та тайлів.

## 2. Підтримка роздільної здатності (Resolution & Stretch Mode)
- **Базовий Viewport:** 1920x1080 (Full HD, 16:9).
- **Підтримка 2K QHD:** 2560x1440 (16:9).
- **Режим розтягування (Stretch Mode):**
  - `mode = "canvas_items"` — 2D вузли та канвас масштабуються відповідно до співвідношення сторін без спотворення пікселів.
  - `aspect = "keep"` — запобігає розтягуванню пропорцій.
  - Усі елементи інтерфейсу (HUD, інвентар, меню) використовують адаптивні якорі (`Anchors & Containers`) замість абсолютних координат, що забезпечує однаково ідеальний вигляд як на 1080p, так і на 1440p моніторах.

## 3. Модульна структура директорій (Directory Layout)
```
saecula_2/
├── assets/                  # Ресурси гри
│   ├── audio/               # Звукові ефекти та музика
│   ├── fonts/               # Шрифти
│   ├── sprites/             # Спрайти та тайлсети
│   └── ui/                  # Текстури інтерфейсу
├── data/                    # Data-Driven ресурси (.tres)
│   ├── buildings/           # Схеми та параметри будівель
│   ├── eras/                # Дерева епох та умови переходу
│   ├── items/               # Визначення предметів
│   ├── recipes/             # Рецепти крафту
│   └── schemas/             # GDScript схеми даних (Custom Resources)
├── src/                     # Вихідний код логіки гри
│   ├── core/                # Глобальні Autoloads та базові менеджери
│   ├── entities/            # Ігрові сутності
│   │   ├── colonist/        # Логіка жителів
│   │   ├── fsm/             # Скінченний автомат станів (State Machine)
│   │   └── player/          # Персонаж гравця
│   ├── systems/             # Підсистеми колонії
│   │   ├── building/        # Будівельні майданчики та креслення
│   │   ├── inventory/       # Компонент інвентаря
│   │   ├── jobs/            # JobManager та черга замовлень
│   │   └── logistics/       # Склади та доставка
│   ├── ui/                  # Інтерфейс користувача (Control вузли)
│   │   ├── colony_ui/       # Панель поселення та робітників
│   │   ├── hud/             # Гарячі клавіші, індикатори
│   │   └── tech_tree_ui/    # Дерево досліджень
│   └── world/               # Тайлова сітка (GridManager, світ)
```

## 4. Мапа клавіш введення (Input Map)
| Дія (Action) | Призначення | Клавіші за замовчуванням |
| :--- | :--- | :--- |
| `move_up` | Рух вгору | `W`, `Up Arrow` |
| `move_down` | Рух вниз | `S`, `Down Arrow` |
| `move_left` | Рух ліворуч | `A`, `Left Arrow` |
| `move_right` | Рух праворуч | `D`, `Right Arrow` |
| `interact` | Взаємодія / Збір | `E` |
| `cancel` | Скасування / Меню / Пауза | `Escape` |
| `colony_mode_toggle` | Перемикання в режим колонії | `Tab` |
| `inventory_toggle` | Відкрити/закрити інвентар | `I` |
| `zoom_in` | Наближення камери | `Mouse Wheel Up` |
| `zoom_out` | Віддалення камери | `Mouse Wheel Down` |
| `primary_action` | Основна дія (удар/вибір) | `Left Mouse Button` |
| `secondary_action`| Додаткова дія (скасування/меню)| `Right Mouse Button` |
| `hotbar_1`..`hotbar_9` | Швидкий вибір предметів | Цифри `1`–`9` |

Усі клавіші прив'язані через `physical_keycode`, завдяки чому керування WASD працює коректно незалежно від мовної розкладки клавіатури гравця.

## 5. Глобальні сінглтони (Autoloads)

### 5.1. `EventBus` (`res://src/core/EventBus.gd`)
Слугує центральною шиною сигналів. Підсистеми не викликають методи один одного напряму, а підписуються на події:
- **Життєвий цикл та час:** `game_state_changed(new_state, old_state)`, `game_speed_changed(new_speed)`, `day_time_updated(hour, minute)`, `day_passed(day_number)`.
- **Гравець:** `player_stats_changed`, `player_interacted_with_world`, `player_died`.
- **Інвентар та ресурси:** `inventory_window_toggle_requested`, `inventory_changed`, `item_picked_up`, `item_dropped`, `resource_harvested`.
- **Будівництво:** `building_placement_requested`, `building_placement_canceled`, `construction_site_placed`, `building_completed`, `building_demolished`.
- **Система замовлень (Jobs):** `job_created`, `job_assigned`, `job_completed`, `job_canceled`.
- **Колоністи:** `colonist_spawned`, `colonist_died`, `colonist_profession_changed`, `colonist_state_changed`.
- **Епохи:** `era_advanced(new_era_id, previous_era_id)`, `technology_unlocked(tech_id)`.
- **UI:** `floating_text_requested`, `notification_posted`, `hotbar_slot_selected`.

### 5.2. `GameManager` (`res://src/core/GameManager.gd`)
Керує загальним станом гри та симуляцією часу доби:
- **Стани гри (`GameState`):**
  - `INITIALIZING` — завантаження ресурсів і світу.
  - `PLAYING` — стандартний режим керування персонажем у реальному часі (`time_scale = 1.0`).
  - `COLONY_MODE` — режим огляду/менеджменту колонії на клавішу `Tab` зі сповільненим часом (`time_scale = 0.5`).
  - `BUILDING_MODE` — активний вибір точки будівництва (при натисканні `Escape` повертає у гру та скасовує привид споруди).
  - `PAUSED` — системна пауза (`get_tree().paused = true`).
  - `GAME_OVER` — завершення гри.
- **Методи:**
  - `change_state(new_state: GameState) -> void`
  - `toggle_pause() -> void`
  - `set_time_scale(new_scale: float) -> void`
  - `get_current_hour() -> int`, `get_current_minute() -> int`, `get_time_string() -> String`

### 5.3. `GridManager` (`res://src/world/GridManager.gd`)
Центральний менеджер тайлової сітки та навігації юнітів:
- **Константи:** `TILE_SIZE = 32`.
- **Пошук шляхів:** Внутрішній екземпляр `AStarGrid2D` (розмір за замовчуванням 128x128 тайлів, `HEURISTIC_MANHATTAN`, `DIAGONAL_MODE_NEVER` для унеможливлення зрізання кутів стін).
- **Методи:**
  - `world_to_map(world_pos: Vector2) -> Vector2i`: переведення світових пікселів у тайловий індекс клітинки.
  - `map_to_world(map_pos: Vector2i) -> Vector2`: отримання світових координат центру тайла.
  - `is_within_bounds(map_pos: Vector2i) -> bool`: перевірка знаходження клітинки в межах сітки.
  - `is_cell_walkable(map_pos: Vector2i) -> bool`: перевірка прохідності клітинки.
  - `set_cell_solid(map_pos: Vector2i, solid: bool) -> void`: позначення перешкоди чи проходу.
  - `set_cell_weight(map_pos: Vector2i, weight: float) -> void`: зміна вартості руху через клітинку (дороги/болото).
  - `register_occupant(map_pos: Vector2i, occupant: Node, is_solid: bool) -> bool`: прив'язка об'єкта до клітинки.
  - `unregister_occupant(map_pos: Vector2i, set_walkable: bool) -> void`: звільнення клітинки.
  - `get_world_path(from_world: Vector2, to_world: Vector2) -> PackedVector2Array`: отримання масиву точок шляху. Якщо кінцева точка зайнята (дерево, стіна), функція автоматично перенаправляє шлях на найближчого вільного сусіда.
  - `get_closest_walkable_neighbor(from_cell: Vector2i, target_cell: Vector2i) -> Vector2i`: знаходження найближчої прохідної клітинки з 4 сусідніх сторін.
  - `is_area_clear(origin_cell: Vector2i, size_in_tiles: Vector2i) -> bool`: перевірка доступності площі для розміщення споруд.
