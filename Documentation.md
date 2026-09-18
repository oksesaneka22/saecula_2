# Документація проекту Saecula

## 1. Загальна конфігурація рушія (Godot 4.x)
- **Версія конфігурації:** `config_version=5` (Godot 4.x).
- **Рендерер:** `gl_compatibility` (OpenGL 3 / WebGL 2 сумісний рендерер) для найвищої сумісності та плавної продуктивності без оверхеду важких шейдерів.
- **Піксельна точність (Pixel Snap):**
  - `snap_2d_transforms_to_pixel = false` (вимкнено для безвібраційної субпіксельної інтерполяції камери).
  - `snap_2d_vertices_to_pixel = false`
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
│   ├── items/               # Визначення предметів (wood, stone, flint, berries, stone_axe, stone_pickaxe, campfire)
│   ├── recipes/             # Рецепти крафту (craft_stone_axe.tres, craft_stone_pickaxe.tres, craft_campfire.tres)
│   └── schemas/             # GDScript схеми даних (ItemData.gd, ItemCost.gd, RecipeData.gd)
├── src/                     # Вихідний код логіки гри
│   ├── core/                # Глобальні Autoloads (EventBus, GameManager, ItemDatabase)
│   ├── core3d/              # 3D камери та контролери огляду (RTSCamera3D.gd, RTSCamera3D.tscn)
│   ├── entities/            # 2D Ігрові сутності
│   ├── entities3d/          # 3D Ігрові сутності
│   │   ├── items/           # 3D Дроп предметів (DroppedItem3D.gd, DroppedItem3D.tscn)
│   │   └── player/          # 3D Гравець від 1-ї особи (Player3D.gd, Player3D.tscn)
│   ├── systems/             # Підсистеми колонії
│   │   ├── building/        # Будівельні майданчики та креслення
│   │   ├── crafting/        # Менеджер крафту (CraftingManager.gd)
│   │   ├── inventory/       # Компонент інвентаря (InventoryComponent.gd, InventorySlot.gd)
│   │   ├── jobs/            # JobManager та черга замовлень
│   │   └── logistics/       # Склади та доставка
│   ├── ui/                  # Інтерфейс користувача (Control вузли)
│   │   └── hud/             # HotbarUI, InventoryUI, CraftingUI, ItemSlotUI, CrosshairUI, ModeIndicatorUI
│   ├── world/               # 2D сітка та системи
│   └── world3d/             # 3D Світ (World3D.gd, World3D.tscn, WorldResourceNode3D.gd, WorldResourceNode3D.tscn)
```

## 4. Мапа клавіш введення (Input Map)
| Дія (Action) | Призначення | Клавіші за замовчуванням |
| :--- | :--- | :--- |
| `move_up` | Рух вгору / вперед | `W`, `Up Arrow` |
| `move_down` | Рух вниз / назад | `S`, `Down Arrow` |
| `move_left` | Рух ліворуч | `A`, `Left Arrow` |
| `move_right` | Рух праворуч | `D`, `Right Arrow` |
| `jump` | Стрибок у режимі 1-ї особи | `Space` |
| `interact` | Взаємодія / Збір перед собою | `E` |
| `primary_action` | Основна дія / Видобуток кліком | `Left Mouse Button` |
| `cancel` | Скасування / Меню / Пауза | `Escape` |
| `colony_mode_toggle` | Перемикання: Гравець (1st-Person) <-> Колонія (Top-Down RTS) | `Tab` |
| `inventory_toggle` | Відкрити/закрити інвентар | `I` |
| `crafting_toggle` | Відкрити/закрити меню крафту | `C` |
| `toggle_fullscreen` | Повноекранний режим | `F11` |
| `quit_game` | Вийти з гри | `F12` |
| `toggle_debug_grid` | Увімкнути/вимкнути відладочну сітку | `F3` |
| `zoom_in` | Наближення камери | `Mouse Wheel Up` |
| `zoom_out` | Віддалення камери | `Mouse Wheel Down` |
| `secondary_action`| Додаткова дія (скасування/меню)| `Right Mouse Button` |
| `hotbar_1`..`hotbar_8` | Швидкий вибір предметів | Цифри `1`–`8` |

## 5. Глобальні сінглтони (Autoloads)

### 5.1. `EventBus` (`res://src/core/EventBus.gd`)
Слугує центральною шиною сигналів. Підсистеми не викликають методи один одного напряму, а підписуються на події.

### 5.2. `GameManager` (`res://src/core/GameManager.gd`)
Керує загальним станом гри (`GameState`), вікном програми (`toggle_fullscreen`, `quit_game`) та симуляцією часу доби.
Перемикає режими за клавішею `Tab` (`PLAYING` <-> `COLONY_MODE`).

### 5.3. `GridManager` (`res://src/world/GridManager.gd`)
Центральний менеджер тайлової сітки (32x32 у 2D, 2.0м у 3D) та навігації юнітів на базі `AStarGrid2D`.
Надає методи просторової трансформації:
- `world_to_map_3d(world_pos: Vector3) -> Vector2i`
- `map_to_world_3d(map_pos: Vector2i, y: float = 0.0) -> Vector3`
- `get_world_path_3d(from_world: Vector3, to_world: Vector3, y: float = 0.0) -> PackedVector3Array`

### 5.4. `ItemDatabase` (`res://src/core/ItemDatabase.gd`)
Глобальний реєстр даних предметів гри. Сканує директорію `res://data/items/`, кешує знайдені `.tres` ресурси та надає миттєвий доступ через `ItemDatabase.get_item(&"id")`.

### 5.5. `CraftingManager` (`res://src/systems/crafting/CraftingManager.gd`)
Центральний менеджер крафту. Сканує `res://data/recipes/`, кешує рецепти, перевіряє доступність за епохою та наявністю матеріалів в інвентарі, списує ресурси та створює новий предмет.

## 6. Компонент інвентаря (`InventoryComponent.gd`)
- **Призначення:** Модульний контейнер зберігання предметів для гравця, жителів, скринь, будівельних складів.
- **Слоти (`InventorySlot.gd`):** Зберігають `item: Resource` та `count: int`.
- **Сигнали:** `inventory_updated`, `slot_changed(slot_index)`, `item_added(item, amount)`, `item_removed(item_id, amount)`.
- **API:**
  - `add_item(item: Resource, amount: int) -> int` — додає предмети зі стакуванням до `max_stack`, повертає залишок.
  - `add_item_by_id(item_id: StringName, amount: int) -> int` — додає предмет напряму через `ItemDatabase`.
  - `remove_item(item_id: StringName, amount: int, allow_partial: bool = false) -> bool` — видаляє вказану кількість.
  - `has_item(item_id: StringName, amount: int = 1) -> bool` — перевіряє наявність предметів.
  - `get_item_count(item_id: StringName) -> int` — повертає загальну кількість предметів у всіх слотах.
  - `get_all_items() -> Array[Dictionary]` — повертає всі непорожні слоти для UI та збереження.

## 7. Користувацький інтерфейс: Hotbar, Інвентар, Крафт, Приціл та Індикатор режиму (`HUD.tscn`)
- **Шар інтерфейсу (`CanvasLayer`, layer = 10):** Завжди відмальовується поверх 3D світу без спотворень.
- **`CrosshairUI` (`Control`):** Акуратний приціл по центру екрана, активний лише в режимі First-Person при захопленій мишці.
- **`ModeIndicatorUI` (`PanelContainer`):** Стильна плашка у верхній частині екрана, що повідомляє поточний режим ("РЕЖИМ ГРАВЦЯ (1st Person)" або "РЕЖИМ ПОСЕЛЕННЯ (Top-Down RTS)") та підказку `[Tab]`.
- **`ItemSlotUI` (`Control`):** Універсальний слот 52x52 px. Відображає рамку, іконку ресурсу, лічильник стаку та гарячу клавішу.
- **`HotbarUI` (`Control`):** Розташований по центру внизу екрана (Anchor Preset `Center Bottom`). Відображає перші 8 слотів.
- **`InventoryUI` (`Control`):** Повне вікно інвентаря на 24 слоти (6x4). Відкривається/закривається на `I` або `Escape`. При відкритті звільняє курсор миші.
- **`CraftingUI` (`Control`):** Меню крафту знарядь та предметів. Відкривається/закривається на `C` або `Escape`. Показує інгредієнти, перевіряє наявність у реальному часі та миттєво створює предмети.

## 8. 3D Архітектура та гібридний режим камер (First-Person Player + Top-Down RTS Colony Mode)

### 8.1. Контролер гравця від першої особи (`Player3D.gd`, `Player3D.tscn`)
- **Тип вузла:** `CharacterBody3D`, група `"player"`.
- **Огляд мишею:** При активному режимі курсор захоплюється (`MOUSE_MODE_CAPTURED`). Рух миші обертає персонажа по осі Y та голову (`Head`) по осі X з обмеженням [-85°, +85°].
- **Рух:** WASD переміщення з урахуванням напрямку погляду, гравітація та стрибки на клавішу `Space` (`jump`).
- **Взаємодія/Видобуток:** `RayCast3D` довжиною 3.2м спрямований вперед від камери. При натисканні `ЛКМ` або `E` перевіряє колізію з `WorldResourceNode3D`, визначає екіпірований у хотбарі інструмент (сокира/кирка) та викликає `harvest(damage, tool_type)` з динамічним помахом голови.
- **Інвентар:** Містить вбудований компонент `InventoryComponent` (24 слоти).

### 8.2. RTS Камера менеджменту зверху (`RTSCamera3D.gd`, `RTSCamera3D.tscn`)
- **Тип вузла:** `Node3D` (базовий якір на площині землі) + дочірня `Camera3D`, нахилена під кутом ~55° (Dota 2 / Factorio стиль).
- **Керування:**
  - `WASD`: переміщення якірної точки над картою поселення.
  - `Коліщатко миші` (`zoom_in` / `zoom_out`): плавний зум висоти від 8м до 36м.
  - `ЛКМ`: 3D Raycast проекція променя курсора у світ (`project_ray_origin` / `project_ray_normal`). Клік по ресурсу видобуває його; клік по землі визначає точну клітинку сітки для майбутнього будівництва.

### 8.3. 3D Світ та процедурні ресурси (`World3D.gd`, `World3D.tscn`)
- **Вузол `World3D`:**
  - `WorldEnvironment`: процедурний скайбокс (`ProceduralSkyMaterial`), тональна компресія та м'яке фонове освітлення.
  - `DirectionalLight3D`: сонячне світло з підтримкою динамічних тіней (`shadow_enabled = true`).
  - `Ground`: земля з колізією (`StaticBody3D`) та зеленим матеріалом поверхні.
  - Спавнить гравця `Player3D` та камеру `RTSCamera3D`.
  - Процедурно генерує 3D ресурси (дерева, каміння, кущі) за межами зони появи гравця.
  - Реагує на зміну стану гри через `EventBus.game_state_changed`:
    - `PLAYING`: активує `Player3D`, захоплює курсор, ховає RTS-камеру.
    - `COLONY_MODE` / `BUILDING_MODE`: деактивує рух гравця, фокусує RTS-камеру на поточній позиції гравця, робить курсор видимим.

### 8.4. 3D Природні ресурси (`WorldResourceNode3D.gd`, `WorldResourceNode3D.tscn`)
- **Тип вузла:** `StaticBody3D`, група `"resource_nodes"`.
- **Процедурні моделі:**
  - `TREE`: стовбур із циліндричної геометрії та багатошарова крона з 3 конусів різних відтінків зеленого кольору.
  - `ROCK`: багатогранна основна скеля та бічний камінь з акцентним кутом.
  - `BUSH`: листяний кущ зі сферичної форми та грона яскраво-червоних ягід.
- **Фізика та механіка:**
  - Блокує клітинку у `GridManager` на площині X-Z.
  - Реагує на видобуток `harvest(damage, tool_type)` з подвійним бонусом для профільних інструментів (сокира для дерева, кирка для каменю).
  - Анімація удару через 3D scale/wobble `Tween`.
  - При вичерпанні міцності очищає клітинку в `GridManager` та спавнить `DroppedItem3D`.

### 8.5. 3D Дроп предметів (`DroppedItem3D.gd`, `DroppedItem3D.tscn`)
- **Тип вузла:** `Area3D`.
- **Візуалізація:** Процедурна 3D модель відповідного предмета (дерев'яний брус, камінь, кремінь, ягоди, сокира, багаття тощо).
- **Поведінка:** Повільно обертається та погойдується над землею. При наближенні гравця у радіусі 3.5м плавно притягується магнітом та зараховується в інвентар через `InventoryComponent.add_item_by_id`.
