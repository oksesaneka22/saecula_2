# Skill: 3D World Serialization & Save/Load System

## 1. Опис та Призначення (Overview)
Цей скіл описує стандарт збереження та завантаження ігрового 3D світу (**3D Save & Load System**) для гри **Saecula** на Godot 4.

Збереження 3D пісочниці-колонії охоплює:
1. Поточну епоху та відкриті технології.
2. Стан інвентаря гравця, швидкі слоти хотбару та 3D позицію гравця `(x, y, z)`.
3. Усі воксельні блоки у світі (`BlockManager` 3D grid `Vector3i -> block_type`).
4. Усі зведені 3D споруди (`BuildingEntity3D`) та незавершені майданчики (`ConstructionSite3D`) з їхніми внутрішніми складами.
5. Стан 3D колоністів (позиції `Vector3`, здоров'я, інвентар, професії).
6. Природні ресурси 3D карти (`WorldResourceNode3D`).

---

## 2. Формат збереження даних (JSON-серіалізація)

Файл зберігається у форматі **JSON** у безпечній директорії користувача `user://saves/slot_X.json`.

```json
{
  "save_version": 2,
  "timestamp": 1726750000,
  "era": {
    "current_era_id": "stone_age",
    "unlocked_techs": ["basic_tools", "fire_pit"]
  },
  "player": {
    "position": {"x": 60.0, "y": 0.1, "z": 60.0},
    "rotation_y": 0.0,
    "active_slot": 0,
    "inventory": [
      {"item_id": "stone_axe", "count": 1},
      {"item_id": "stone_pickaxe", "count": 1},
      {"item_id": "wood", "count": 32},
      {"item_id": "stone", "count": 32}
    ]
  },
  "voxel_blocks": [
    {"type": "wood", "coord": {"x": 25, "y": 0, "z": 25}},
    {"type": "stone", "coord": {"x": 25, "y": 1, "z": 25}}
  ],
  "buildings": [
    {
      "building_id": "campfire",
      "origin_cell": {"x": 58, "y": 54},
      "current_hp": 150.0,
      "storage": []
    },
    {
      "building_id": "stockpile",
      "origin_cell": {"x": 40, "y": 40},
      "current_hp": 250.0,
      "storage": [
        {"item_id": "wood", "count": 64}
      ]
    }
  ]
}
```
