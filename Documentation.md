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
│   ├── entities/            # Ігрові сутності
│   │   ├── colonist/        # Логіка жителів
│   │   ├── fsm/             # Скінченний автомат станів (State Machine)
│   │   ├── items/           # Дроп предметів (DroppedItem.tscn, DroppedItem.gd)
│   │   └── player/          # Персонаж гравця (Player.tscn, Player.gd)
│   ├── systems/             # Підсистеми колонії
│   │   ├── building/        # Будівельні майданчики та креслення
│   │   ├── crafting/        # Менеджер крафту (CraftingManager.gd)
│   │   ├── inventory/       # Компонент інвентаря (InventoryComponent.gd, InventorySlot.gd)
│   │   ├── jobs/            # JobManager та черга замовлень
│   │   └── logistics/       # Склади та доставка
│   ├── ui/                  # Інтерфейс користувача (Control вузли)
│   │   ├── colony_ui/       # Панель поселення та робітників
│   │   ├── hud/             # Гарячі клавіші (HotbarUI), вікно інвентаря (InventoryUI), меню крафту (CraftingUI), ItemSlotUI
│   │   └── tech_tree_ui/    # Дерево досліджень
│   └── world/               # Тайлова сітка (GridManager, World.tscn, GroundLayer, WorldResourceNode)
```

## 4. Мапа клавіш введення (Input Map)
| Дія (Action) | Призначення | Клавіші за замовчуванням |
| :--- | :--- | :--- |
| `move_up` | Рух вгору | `W`, `Up Arrow` |
| `move_down` | Рух вниз | `S`, `Down Arrow` |
| `move_left` | Рух ліворуч | `A`, `Left Arrow` |
| `move_right` | Рух праворуч | `D`, `Right Arrow` |
| `interact` | Взаємодія / Збір перед собою | `E` |
| `primary_action` | Основна дія / Видобуток кліком | `Left Mouse Button` |
| `cancel` | Скасування / Меню / Пауза | `Escape` |
| `colony_mode_toggle` | Перемикання в режим колонії | `Tab` |
| `inventory_toggle` | Відкрити/закрити інвентар | `I` |
| `crafting_toggle` | Відкрити/закрити меню крафту | `C` |
| `toggle_fullscreen` | Повноекранний режим | `F11` |
| `quit_game` | Вийти з гри | `F12` |
| `toggle_debug_grid` | Увімкнути/вимкнути відладочну сітку | `F3` |
| `zoom_in` | Наближення камери | `Mouse Wheel Up` |
| `zoom_out` | Віддалення камери | `Mouse Wheel Down` |
| `secondary_action`| Додаткова дія (скасування/меню)| `Right Mouse Button` |
| `hotbar_1`..`hotbar_9` | Швидкий вибір предметів | Цифри `1`–`9` |

## 5. Глобальні сінглтони (Autoloads)

### 5.1. `EventBus` (`res://src/core/EventBus.gd`)
Слугує центральною шиною сигналів. Підсистеми не викликають методи один одного напряму, а підписуються на події.

### 5.2. `GameManager` (`res://src/core/GameManager.gd`)
Керує загальним станом гри, вікном програми (`toggle_fullscreen`, `quit_game`) та симуляцією часу доби.

### 5.3. `GridManager` (`res://src/world/GridManager.gd`)
Центральний менеджер тайлової сітки (32x32) та навігації юнітів на базі `AStarGrid2D`. Підтримує реєстрацію та відслідковування об'єктів `occupants`.

### 5.4. `ItemDatabase` (`res://src/core/ItemDatabase.gd`)
Глобальний реєстр даних предметів гри. Сканує директорію `res://data/items/`, кешує знайдені `.tres` ресурси та надає миттєвий доступ через `ItemDatabase.get_item(&"id")`.

### 5.5. `CraftingManager` (`res://src/systems/crafting/CraftingManager.gd`)
Центральний менеджер крафту. Сканує `res://data/recipes/`, кешує рецепти, перевіряє доступність за епохою та наявністю матеріалів в інвентарі, списує ресурси та створює новий предмет.

## 6. Світ та тайлова поверхня (`World.tscn`)
- **Вузол `World` (`src/world/World.gd`):** Керує генерацією та розмірами карти (80x50 тайлів, 2560x1600 px), спавнить природні ресурси (дерева, каміння, кущі) за межами зони появи гравця.
- **Вузол `GroundLayer` (`TileMapLayer`, `src/world/GroundLayer.gd`):** Рендерить базові тайли поверхні за допомогою процедурного рантайм-атласу `ImageTexture`.
- **Відладка (`F3`):** Натискання `F3` перемикає функцію `_draw()`, яка малює напівпрозорі лінії сітки 32x32 поверх карти та контур меж.

## 7. Персонаж гравця (`Player.tscn`)
- **Тип вузла:** `CharacterBody2D`, група `"player"`.
- **Контролер `Player.gd`:**
  - Плавний 8-напрямний рух із нормалізацією діагоналі через `Input.get_vector()`.
  - Швидкість ходьби: 140 px/s з прискоренням (1200 px/s²) та тертям зупинки (1400 px/s²).
  - Напрямок погляду: `facing_direction` (Vector2).
  - Взаємодія з сіткою: `get_current_cell() -> Vector2i`, `get_interaction_cell() -> Vector2i`.
  - Взаємодія: натискання `E` (збір тайла перед собою) або клік лівою кнопкою миші у радіусі до 2.5 тайлів.
  - Інвентар: дочірній вузол `InventoryComponent` (24 слоти).
- **Колізія `CollisionShape2D`:** `CircleShape2D` з радіусом 8 пікселів (оптимально для 32x32 тайлів, не застряє в кутах).
- **Візуал `PlayerVisual.gd`:** Процедурний рендер персонажа (тіло, голова, капюшон, тінь, напрямок очей, процедурне погойдування тіла при ходьбі).

## 8. Камера гри (`GameCamera2D.gd`)
- **Тип вузла:** `Camera2D` безпосередньо всередині `Player.tscn`.
- **Згладжування позиції:** Вимкнено для усунення розриву кадрів і вібрації на високогерцових екранах (144Hz+).
- **Плавний зум:** Обробка дій `zoom_in` та `zoom_out` (коліщатко миші) в діапазоні від `0.5x` до `2.5x` з використанням плавного `Tween`.

## 9. Data-Driven схеми предметів
- **`ItemCost` (`src/data/schemas/ItemCost.gd`):** Зв'язка предмет + кількість.
- **`ItemData` (`src/data/schemas/ItemData.gd`):**
  - Категорії: `RESOURCE`, `MATERIAL`, `TOOL`, `FOOD`, `WEAPON`.
  - Типи інструментів: `NONE`, `AXE`, `PICKAXE`, `HAMMER`, `SWORD`.
  - Рівні технологій (Tier 0-3), ефективність, розмір стаку.
- **Базові предмети Кам'яного віку:**
  - `data/items/wood.tres` (Деревина)
  - `data/items/stone.tres` (Камінь)
  - `data/items/flint.tres` (Кремінь)
  - `data/items/berries.tres` (Дикі ягоди)
  - `data/items/stone_axe.tres` (Кам'яна сокира)
  - `data/items/stone_pickaxe.tres` (Кам'яна кирка)
  - `data/items/campfire.tres` (Багаття)

## 10. Компонент інвентаря (`InventoryComponent.gd`)
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

## 11. Природні ресурси та дроп предметів (`WorldResourceNode.gd`, `DroppedItem.gd`)
- **`WorldResourceNode` (`StaticBody2D`):**
  - Типи: `TREE` (Дерево), `ROCK` (Камінь/Валун), `BUSH` (Кущ диких ягід).
  - Автоматично блокує свою клітинку в `GridManager.register_occupant(cell, self, true)`.
  - Має запас міцності `health`, процедурну анімацію тремтіння при ударі через `Tween`.
  - При вичерпанні міцності звільняє клітинку в `GridManager` та спавнить `DroppedItem`.
- **`DroppedItem` (`Area2D`):**
  - Плаває/погойдується над землею.
  - При появі гравця в зоні дії автоматично магнітиться на швидкості 380 px/s і додається в інвентар гравця через `add_item_by_id`.

## 12. Користувацький інтерфейс: Hotbar, Інвентар та Меню крафту (`HUD.tscn`, `HotbarUI.gd`, `InventoryUI.gd`, `CraftingUI.gd`)
- **Шар інтерфейсу (`CanvasLayer`, layer = 10):** Завжди відмальовується поверх ігрового світу без прив'язки до зуму камери.
- **`ItemSlotUI` (`Control`):**
  - Універсальний слот 52x52 px.
  - Відображає рамку слота (золота рамка при виборі), колір/іконку ресурсу, лічильник стаку та номер гарячої клавіші (1–8).
- **`HotbarUI` (`Control`):**
  - Розташований по центру внизу екрана (Anchor Preset `Center Bottom`).
  - Відображає перші 8 слотів інвентаря гравця.
  - Вибір активного слота підтримується клавішами `1`..`8` або кліком миші.
- **`InventoryUI` (`Control`):**
  - Повне вікно інвентаря на 24 слоти (сітка 6x4).
  - Відкривається/закривається натисканням клавіші `I` або `Tab`.
  - Може бути закрите клавішею `Escape`.
  - Центрується відносно екрана через `CenterContainer` (повна адаптивність під 1080p та 1440p).
- **`CraftingUI` (`Control`):**
  - Меню виготовлення знарядь праці та предметів.
  - Відкривається та закривається натисканням клавіші `C` або закривається на `Escape`.
  - Динамічно показує актуальний список рецептів поточної епохи, кількість наявних у гравця інгредієнтів та стан готовності (кнопка активна, лише якщо ресурсів достатньо).

## 13. Система крафту (`RecipeData.gd`, `CraftingManager.gd`)
- **Схема `RecipeData`:**
  - `id`: унікальний ідентифікатор рецепту (`StringName`).
  - `ingredients`: масив ресурсів `ItemCost` (предмет + необхідна кількість).
  - `result_item`: створений предмет (`ItemData`).
  - `result_amount`: кількість одержаних предметів.
  - `required_era`: мінімальна епоха для доступу до рецепту.
- **Менеджер `CraftingManager` (Autoload):**
  - Автоматично сканує директорію `res://data/recipes/`.
  - Метод `can_craft(recipe, inventory) -> bool`: перевіряє наявність усіх складових.
  - Метод `craft_item(recipe, inventory) -> bool`: списує витрачені матеріали та поміщає створений інструмент/предмет в інвентар.
  - Сигнали: `recipe_crafted(recipe, result_item, amount)`, `crafting_failed(recipe, reason)`.
- **Базові рецепти:**
  - `craft_stone_axe.tres`: 2 дерева + 2 кременю $\to$ 1 `stone_axe`.
  - `craft_stone_pickaxe.tres`: 2 дерева + 3 каменю $\to$ 1 `stone_pickaxe`.
  - `craft_campfire.tres`: 4 дерева + 4 каменю $\to$ 1 `campfire`.
