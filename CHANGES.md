# Історія змін (CHANGES)

### Ітерація 4.4: UI швидкого доступу (Hotbar) та Інвентар гравця
- Створено компонент слота інтерфейсу [`src/ui/hud/ItemSlotUI.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/ui/hud/ItemSlotUI.gd):
  - Розмір 52x52 px, процедурне малювання фону, рамок, кольорів предметів, кількості в стаку та гарячих клавіш 1–8.
  - Золота рамка для активного слота.
- Створено панель швидкого доступу [`src/ui/hud/HotbarUI.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/ui/hud/HotbarUI.gd):
  - 8 слотів по центру внизу екрана (Preset Bottom Center).
  - Підтримка вибору активного слота цифрами 1–8 або кліком миші.
  - Автоматична синхронізація з першими 8 слотами інвентаря гравця.
- Створено вікно повного інвентаря [`src/ui/hud/InventoryUI.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/ui/hud/InventoryUI.gd):
  - Сітка 6x4 (24 слоти), затемнення фону, заголовок та підказка керування.
  - Відкриття/закриття за клавішею `I` (або `Escape` для закриття).
  - Центрування за допомогою відносних якорів (Anchor Presets) для адаптивності під 1080p та 1440p.
- Створено сцену [`src/ui/hud/HUD.tscn`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/ui/hud/HUD.tscn) (`CanvasLayer`) та підключено до [`Main.tscn`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/core/Main.tscn).
- Оновлено `Documentation.md` (додано Розділ 12 "Користувацький інтерфейс: Hotbar та Інвентар").

### Виправлення помилки виклику `is_cell_solid` у `GridManager.gd`
- Додано метод `is_cell_solid(map_pos: Vector2i) -> bool` до `GridManager.gd`.

### Ітерація 4.3: Природні об'єкти на карті (Дерево, Камінь, Кущ) та дроп
- Створено сутність ресурсу `WorldResourceNode.gd` та `WorldResourceNode.tscn` (`TREE`, `ROCK`, `BUSH`).
- Створено сутність дропу `DroppedItem.gd` та `DroppedItem.tscn` з магнітним притяганням.
- Додано видобуток на `E` та лівий клік миші у `Player.gd`.
- Спавн дерев, каменів та ягід у `World.gd`.

### Ітерація 4.2: Універсальний компонент інвентаря (`InventoryComponent.gd`)
- Створено клас слота `InventorySlot.gd` та `InventoryComponent.gd`.
- Додано `InventoryComponent` до `Player.tscn`.

### Ітерація 4.1: Схеми предметів (Data-Driven ItemData & ItemDatabase)
- Створено схему предметів `ItemData.gd`, `ItemCost.gd`, базові предмети в `data/items/`.
- Створено Autoload реєстр `ItemDatabase.gd`.

### Ітерація 3.2: Плавна камера з зумом (GameCamera2D)
- Створено контролер камери з зумом через `Tween`.

### Ітерація 3.1: Рух персонажа та візуал гравця
- Створено контролер персонажа `Player.gd` та процедурний візуал `PlayerVisual.gd`.
