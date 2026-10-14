class_name ItemCost
extends Resource

## ItemCost: Схема пари предмет + кількість
## Використовується для рецептів, витрат на будівництво, переходів епох.

@export var item: ItemData
@export var amount: int = 1
