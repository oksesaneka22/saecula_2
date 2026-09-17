class_name RecipeData
extends Resource

## RecipeData: Схема опису рецепту крафту в грі Saecula.
## Визначає ID рецепту, назву, результат крафту (предмет та кількість),
## список необхідних інгредієнтів (ItemCost) та мінімальну епоху/рівень.

@export_group("Identity")
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Crafting Requirements")
## Список необхідних інгредієнтів (ItemCost)
@export var ingredients: Array[Resource] = [] # Array[ItemCost]
## Мінімальна епоха для доступу до рецепту (0 = Stone Age, 1 = Bronze Age, тощо)
@export var required_era: int = 0
## Час виготовлення в секундах (0.0 = миттєвий крафт у руках)
@export var craft_time: float = 0.0

@export_group("Result")
## Ресурс результуючого предмета (ItemData)
@export var result_item: Resource
## Кількість отриманих предметів
@export var result_amount: int = 1
