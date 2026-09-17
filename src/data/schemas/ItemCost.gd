class_name ItemCost
extends Resource

## ItemCost: Схема пари предмет + кількість
## Використовується для рецептів, витрат на будівництво, переходів епох.

@export var item: Resource # ItemData (взаємна типізація Resource для уникнення циклічних залежностей)
@export var amount: int = 1
