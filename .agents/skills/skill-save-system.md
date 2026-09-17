# Skill: World Serialization & Save/Load System

## 1. Опис та Призначення (Overview)
Цей скіл описує стандарт збереження та завантаження ігрового світу (**Save & Load System**) для гри **Saecula** на Godot 4.

Для пісочниці-колонії збереження має охоплювати:
1. Поточну епоху та відкриті технології.
2. Стан інвентаря гравця та його позицію.
3. Усі побудовані споруди на сітці (Grid) та їхні внутрішні склади.
4. Стан колоністів (позиції, здоров'я, інвентар, професії).
5. Природні ресурси карти (зрубані дерева, викопані жили).

---

## 2. Формат збереження даних (JSON-серіалізація)

Для відладки та прозорості використовується серіалізація у формат **JSON** або **ConfigFile** у безпечній директорії `user://saves/slot_X.json`.

Кожна сутність або підсистема реалізує два контракти:
* `to_dict() -> Dictionary`
* `from_dict(data: Dictionary) -> void`

---

## 3. Шаблон структури даних файлу збереження

```json
{
  "save_version": 1,
  "timestamp": 1726590000,
  "era": {
    "current_era_id": "bronze_age",
    "unlocked_techs": ["copper_smelting", "agriculture", "wooden_frame"]
  },
  "player": {
    "position": {"x": 256.0, "y": 384.0},
    "health": 100.0,
    "inventory": [
      {"item_id": "flint_axe", "count": 1},
      {"item_id": "wood", "count": 42}
    ]
  },
  "world": {
    "cleared_tiles": [{"x": 10, "y": 12}, {"x": 10, "y": 13}]
  },
  "buildings": [
    {
      "building_id": "builder_hut",
      "map_pos": {"x": 15, "y": 20},
      "current_hp": 200.0,
      "storage": [
        {"item_id": "stone", "count": 12}
      ]
    }
  ],
  "colonists": [
    {
      "id": "col_1",
      "name": "Тарас",
      "profession": "builder",
      "position": {"x": 480.0, "y": 640.0},
      "inventory": []
    }
  ]
}
```

---

## 4. Базовий клас `SaveManager.gd`

```gdscript
# res://src/core/SaveManager.gd
class_name SaveManager
extends Node

const SAVE_DIR: String = "user://saves/"
const DEFAULT_SAVE_NAME: String = "world_save.json"

signal save_started()
signal save_completed(success: bool)
signal load_completed(success: bool)

## Збереження гри
func save_game(file_name: String = DEFAULT_SAVE_NAME) -> bool:
	save_started.emit()
	
	var save_data: Dictionary = {
		"save_version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"era": EraManager.serialize(),
		"player": _get_player_data(),
		"buildings": _get_buildings_data(),
		"colonists": _get_colonists_data()
	}
	
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)
		
	var path: String = SAVE_DIR.path_join(file_name)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: Не вдалося відкрити файл для запису: %s" % path)
		save_completed.emit(false)
		return false
		
	var json_string: String = JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()
	
	save_completed.emit(true)
	return true

## Завантаження гри
func load_game(file_name: String = DEFAULT_SAVE_NAME) -> bool:
	var path: String = SAVE_DIR.path_join(file_name)
	if not FileAccess.file_exists(path):
		push_error("SaveManager: Файл збереження не знайдено: %s" % path)
		load_completed.emit(false)
		return false
		
	var file = FileAccess.open(path, FileAccess.READ)
	var json_string: String = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("SaveManager: Помилка парсингу JSON у файлі: %s" % path)
		load_completed.emit(false)
		return false
		
	var save_data: Dictionary = json.data
	_apply_save_data(save_data)
	
	load_completed.emit(true)
	return true

func _get_player_data() -> Dictionary:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("to_dict"):
		return player.to_dict()
	return {}

func _get_buildings_data() -> Array:
	var list: Array = []
	var buildings = get_tree().get_nodes_in_group("buildings")
	for b in buildings:
		if b.has_method("to_dict"):
			list.append(b.to_dict())
	return list

func _get_colonists_data() -> Array:
	var list: Array = []
	var colonists = get_tree().get_nodes_in_group("colonists")
	for c in colonists:
		if c.has_method("to_dict"):
			list.append(c.to_dict())
	return list

func _apply_save_data(data: Dictionary) -> void:
	# 1. Відновлення епохи
	if data.has("era"):
		EraManager.deserialize(data["era"])
	
	# 2. Відновлення гравця
	var player = get_tree().get_first_node_in_group("player")
	if player and data.has("player") and player.has_method("from_dict"):
		player.from_dict(data["player"])
		
	# 3. Відновлення споруд на сітці
	if data.has("buildings"):
		var building_manager = get_tree().get_first_node_in_group("building_manager")
		if building_manager and building_manager.has_method("restore_buildings"):
			building_manager.restore_buildings(data["buildings"])
```

---

## 5. Інструкції для Gemini 3.8 Flash

1. **Ізоляція серіалізації:** Сутності самі знають, як серіалізувати свій стан через `to_dict()` та `from_dict()`. `SaveManager` не повинен вручну перебирати приватні поля об'єктів.
2. **Безпечне збереження векторів:** Завжди серіалізуй `Vector2` як `{"x": pos.x, "y": pos.y}` або використовуй `var_to_str()` / `str_to_var()`, щоб уникнути втрати точності в JSON.
3. **Відновлення через групи вузлів:** Використовуй групи Godot (`"player"`, `"colonists"`, `"buildings"`) для швидкого збору об'єктів світу без спагеті-залежностей.
