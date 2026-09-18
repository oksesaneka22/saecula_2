# Історія змін (CHANGES)

### Масштабування споруд (>= 8x8) та стабілізація юніт-тестів розміщення
- **Масштабування габаритів споруд колонії:**
  - На вимогу користувача всі споруди оновлені до розміру не менше 8x8 тайлів (16м x 16м):
    - [`campfire.tres`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/data/buildings/campfire.tres): Табірне вогнище збільшено до **8x8** тайлів (64 клітинки, 16x16м).
    - [`stockpile.tres`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/data/buildings/stockpile.tres): Склад ресурсів збільшено до **10x10** тайлів (100 клітинок, 20x20м, 32 слоти зберігання).
    - [`wooden_hut.tres`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/data/buildings/wooden_hut.tres): Дерев'яна хатина колоністів збільшена до **12x12** тайлів (144 клітинки, 24x24м).
- **Оновлення світу та камери ([`World3D.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/world3d/World3D.gd), [`RTSCamera3D.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/core3d/RTSCamera3D.gd)):**
  - Розширено розмір карти до 80x80 тайлів (160м x 160м).
  - Збільшено гарантовану вільну галявину появи гравця (`clear_radius = 16`), щоб природні дерева та каміння не перекривали зону для великих будівель.
  - Збільшено максимальний зум висоти RTS камери з 35м до 65м (`max_zoom_height = 65.0`, `default_zoom_height = 26.0`) для огляду будівельних комплексів.
  - Оновлено геометрію та 3D Billboard шрифти у [`BuildingGhost3D.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/world3d/BuildingGhost3D.gd).
- **Виправлення та ізоляція юніт-тестів розміщення ([`Main.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/core/Main.gd)):**
  - Усунено `Assertion failed: Empty lawn must be valid for stockpile placement`, яка виникала через випадковий спавн дерева або каменю на тестових координатах (20, 20).
  - Тепер тест використовує виділену ділянку (34, 34) із тимчасовим збереженням та відновленням стану клітинок у `GridManager`, що забезпечує 100% стабільність і незалежність від генератора псевдовипадкових чисел.

### Ітерація 6.1: Схема будівлі та система Blueprint Preview (Етап 6)
- **Створено Data-Driven схему будівлі ([`BuildingData.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/data/schemas/BuildingData.gd)):**
  - Опис розмірів у тайлах сітки (`size_in_tiles: Vector2i`), твердості/прохідності (`is_solid: bool`), епохи (`required_era: int`), часу зведення (`build_time: float`), вартості матеріалів (`construction_cost: Array[Resource]`), професії робітника (`job_type_provided: StringName`) та слотів сховища (`storage_slots: int`).
- **Створено початкові конфігурації будівель:**
  - [`campfire.tres`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/data/buildings/campfire.tres): Багаття.
  - [`stockpile.tres`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/data/buildings/stockpile.tres): Склад ресурсів.
  - [`wooden_hut.tres`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/data/buildings/wooden_hut.tres): Дерев'яна хатина.
- **Створено контролер розміщення споруд ([`BuildingPlacementController.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/systems/building/BuildingPlacementController.gd)):**
  - Зареєстровано в `project.godot` як глобальний Autoload `BuildingPlacementController`.
  - Автоматично сканує `res://data/buildings/` та реєструє всі споруди.
  - Методи: `get_building(id)`, `get_all_buildings()`, `start_placement(building)`, `cancel_placement()`, `update_hover(origin_cell)`, `can_place_at(building, origin_cell)`, `confirm_placement()`.
  - Розраховує займану площу будь-якого розміру (`get_occupied_cells`) та перевіряє межі карти, прохідність клітинок та наявність перешкод через `GridManager`.
- **Створено 3D прев'ю креслення ([`BuildingGhost3D.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/world3d/BuildingGhost3D.gd) та [`BuildingGhost3D.tscn`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/world3d/BuildingGhost3D.tscn)):**
  - Напівпрозорий динамічний меш, що масштабується під розмір будівлі та точно прив'язується до 3D сітки тайлів (крок 2.0м).
  - Динамічне підсвічування: **смарагдово-зелений** при вільній галявині, **яскравo-червоний** при наведенні на дерева, скелі, воду або за межі карти.
  - 3D Billboard текст над спорудою з назвою, габаритами та підказками керування.
- **Інтерфейс вибору креслень ([`BuildMenuUI.gd`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/ui/hud/BuildMenuUI.gd) та [`BuildMenuUI.tscn`](file:///C:/Users/Sasha/OneDrive%20-%20UCU/Робочий%20стіл/work_dir/personal/saecula_2/src/ui/hud/BuildMenuUI.tscn)):**
  - Відкривається/закривається клавішею **`B`** (`build_mode_toggle`) або кнопкою інтерфейсу.
  - Відображає картки всіх будівель, вартість, розмір, опис та кнопку "Розмістити".
- **Інтеграція керування в RTSCamera3D та World3D:**
  - У режимі розміщення миша вільно пересуває привид по 3D поверхні.
  - Натискання `ЛКМ` підтверджує встановлення креслення (`placement_confirmed`), а `ПКМ` або `Esc` скасовує режим та повертає попередній стан гри.
