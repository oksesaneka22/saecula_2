class_name ItemData
extends Resource

## ItemData: Data-Driven опис предмета у грі Saecula.
## Визначає ідентифікатор, назву, категорію, тип інструменту, рівень (tier),
## максимальний розмір стаку та візуальну іконку.

enum Category {
	RESOURCE,    ## Сировина (дерево, камінь, руда)
	MATERIAL,    ## Оброблений матеріал (дошки, злитки, мотузка, цегла)
	TOOL,        ## Інструменти (сокира, кирка, молоток)
	FOOD,        ## Їжа (ягоди, хліб, смажене м'ясо)
	WEAPON       ## Зброя (спис, меч, лук)
}

enum ToolType {
	NONE,
	AXE,
	PICKAXE,
	HAMMER,
	SWORD
}

@export_group("Identity")
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("Properties")
@export var category: Category = Category.RESOURCE
@export var max_stack: int = 64
@export var tool_type: ToolType = ToolType.NONE
## Рівень інструменту (0 = руки, 1 = камінь/кремінь, 2 = бронза, 3 = залізо)
@export var tier: int = 0
@export var tool_efficiency: float = 1.0
