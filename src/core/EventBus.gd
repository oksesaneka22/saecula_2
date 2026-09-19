extends Node

## EventBus: Глобальна шина подій для проекту Saecula.
## Забезпечує повністю decoupled (слабкозв'язану) взаємодію між підсистемами гри:
## сутностями (гравець, колоністи), світом (GridManager, ресурси), будівництвом, логістикою та UI.

# ------------------------------------------------------------------------------
# 1. Події життєвого циклу гри та часу (Game Lifecycle & Time)
# ------------------------------------------------------------------------------
## Викликається при зміні основного стану гри (див. GameManager.GameState)
signal game_state_changed(new_state: int, old_state: int)

## Викликається при зміні швидкості часу гри
signal game_speed_changed(new_speed: float)

## Викликається щосекунди ігрового часу (день/ніч цикл)
signal day_time_updated(current_hour: int, current_minute: int)

## Викликається при зміні доби
signal day_passed(day_number: int)


# ------------------------------------------------------------------------------
# 2. Події персонажа гравця (Player Events)
# ------------------------------------------------------------------------------
## Зміна здоров'я/витривалості персонажа гравця
signal player_stats_changed(current_hp: float, max_hp: float, current_stamina: float, max_stamina: float)

## Гравець взаємодіє з об'єктом у світі
signal player_interacted_with_world(target_node: Node, map_coords: Vector2i)

## Гравець загинув
signal player_died


# ------------------------------------------------------------------------------
# 3. Події інвентаря та предметів (Inventory & Items)
# ------------------------------------------------------------------------------
## Запит на відкриття/закриття інтерфейсу повного інвентаря (клавіша I)
signal inventory_window_toggle_requested

## Зміна вмісту інвентаря конкретної сутності/складу
signal inventory_changed(owner_node: Node)

## Гравець або колоніст підібрав предмет у світі
signal item_picked_up(collector: Node, item_id: StringName, amount: int)

## Предмет викинуто у світ на координати
signal item_dropped(item_id: StringName, amount: int, world_position: Vector2)

## Ресурс успішно добуто в світі (рубання дерева, видобуток каменю тощо)
signal resource_harvested(source_node: Node, item_id: StringName, amount: int, world_position: Vector2)


# ------------------------------------------------------------------------------
# 4. Події будівництва та креслень (Building & Placement)
# ------------------------------------------------------------------------------
## Запит на перехід у режим попереднього перегляду розміщення споруди (Blueprint Ghost)
signal building_placement_requested(building_id: StringName)

## Запит на скасування режиму розміщення споруди
signal building_placement_canceled

## Будівельний майданчик встановлено на карті (створено ConstructionSite)
signal construction_site_placed(site_node: Node, building_id: StringName, map_coords: Vector2i)

## Споруду повністю зведено та введено в експлуатацію
signal building_completed(building_node: Node, building_id: StringName, map_coords: Vector2i)

## Споруду знищено або демонтовано
signal building_demolished(building_id: StringName, map_coords: Vector2i)

## Встановлення воксельного блоку (дерево/камінь) гравцем у світі
signal block_placed(block_type: StringName, grid_coord: Vector3i)

## Знищення / добуток воксельного блоку
signal block_destroyed(block_type: StringName, grid_coord: Vector3i)


# ------------------------------------------------------------------------------
# 5. Події системи завдань колонії (Job System a-la Minecolonies)
# ------------------------------------------------------------------------------
## Створено нове завдання для колонії
signal job_created(job_id: StringName, job_type: int, target_position: Vector2)

## Завдання призначено на конкретного колоніста
signal job_assigned(job_id: StringName, colonist_node: Node)

## Завдання успішно виконано
signal job_completed(job_id: StringName, colonist_node: Node)

## Завдання скасовано або повернено у чергу
signal job_canceled(job_id: StringName, reason: String)


# ------------------------------------------------------------------------------
# 6. Події колоністів (Colonist Simulation)
# ------------------------------------------------------------------------------
## Новий житель прибув у поселення
signal colonist_spawned(colonist_node: Node)

## Житель загинув або залишив поселення
signal colonist_died(colonist_node: Node, cause: String)

## Житель змінив свою професію/роль
signal colonist_profession_changed(colonist_node: Node, new_profession: StringName)

## Житель змінив стан FSM
signal colonist_state_changed(colonist_node: Node, new_state_name: StringName)


# ------------------------------------------------------------------------------
# 7. Події розвитку та епох (Era Progression & Tech)
# ------------------------------------------------------------------------------
## Перехід у нову епоху (Кам'яний -> Бронзовий -> Залізний тощо)
signal era_advanced(new_era_id: StringName, previous_era_id: StringName)

## Розблоковано нову технологію/рецепт
signal technology_unlocked(tech_id: StringName)


# ------------------------------------------------------------------------------
# 8. Події інтерфейсу та зворотного зв'язку (UI & Feedback)
# ------------------------------------------------------------------------------
## Запит на відображення спливаючого тексту у світі (+1 Дерево, Помилка тощо)
signal floating_text_requested(text: String, world_position: Vector2, color: Color)

## Запит на сповіщення гравця (Toast / System Notification)
signal notification_posted(title: String, message: String, notification_type: int)

## Зміна вибору активного слота на хотбарі
signal hotbar_slot_selected(slot_index: int)


# ------------------------------------------------------------------------------
# 9. Події логістики та складів (Logistics & Storage)
# ------------------------------------------------------------------------------
## Новий склад або контейнер зареєстровано в логістичній системі
signal stockpile_registered(stockpile_node: Node)

## Склад видалено або знято з обліку
signal stockpile_unregistered(stockpile_node: Node)

## Оновлено сумарну кількість предметів на складах колонії
signal colony_storage_updated(item_id: StringName, total_count: int)

## Запит на відкриття інтерфейсу сховища (Stockpile / Container)
signal storage_ui_requested(storage_node: Node)

## Інтерфейс сховища закрито
signal storage_ui_closed
