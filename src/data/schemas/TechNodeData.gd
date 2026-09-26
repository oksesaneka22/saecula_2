class_name TechNodeData
extends Resource

## TechNodeData: Ресурс вузла дерева технологій та епох (Civ / Frostpunk style).
## Містить дані дослідження, передумови, вартість, розблокування та позицію у графі.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var era_index: int = 0 ## 0: Палеоліт, 1: Неоліт, 2: Мідний вік, 3: Бронзовий/Залізний вік
@export var sub_era_id: StringName = &"" ## Ідентифікатор підепохи (напр. &"paleo_early", &"paleo_late")
@export var icon: Texture2D = null
@export var icon_symbol: String = "⚡" ## Символ-іконка для виразного відображення

## Передумови (IDs інших вузлів технологій, які потрібно відкрити спершу)
@export var prerequisites: Array[StringName] = []

## Вартість відкриття: словник ID предмету -> кількість, наприклад { &"wood": 10, &"flint": 5 }
@export var cost: Dictionary = {}

## Що розблоковує дана технологія:
@export var unlocks_recipes: Array[StringName] = [] ## ID рецептів для CraftingManager
@export var unlocks_buildings: Array[StringName] = [] ## ID споруд для BuildingPlacementController
@export var unlock_features: Array[String] = [] ## Текстовий список відкритих бонусів чи механік

## Координати вузла на полотні дерева (X: ярус/колонка, Y: висота/рядок)
@export var grid_pos: Vector2 = Vector2.ZERO
