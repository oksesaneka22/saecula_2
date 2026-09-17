extends Node

## CraftingManager: Центральний менеджер системи крафту.
## Автоматично сканує папку 'res://data/recipes/', кешує всі доступні рецепти,
## перевіряє доступність рецептів за епохою та наявністю інгредієнтів у переданому InventoryComponent,
## а також виконує списання матеріалів та видачу результуючого предмета.

signal recipe_crafted(recipe: Resource, result_item: Resource, amount: int)
signal crafting_failed(recipe: Resource, reason: String)

const RECIPES_PATH: String = "res://data/recipes/"

var _recipes: Dictionary = {} # Dictionary[StringName, Resource]


func _ready() -> void:
	load_all_recipes()


## Сканує папку рецептів та кешує всі валідні ресурси
func load_all_recipes() -> void:
	_recipes.clear()
	var dir = DirAccess.open(RECIPES_PATH)
	if dir == null:
		push_warning("[CraftingManager] Директорію не знайдено: %s" % RECIPES_PATH)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path = RECIPES_PATH + file_name
			var recipe_res = ResourceLoader.load(full_path)
			if recipe_res != null:
				var r_id: Variant = recipe_res.get("id")
				if r_id != null and str(r_id) != "":
					_recipes[StringName(r_id)] = recipe_res
		file_name = dir.get_next()
	dir.list_dir_end()

	print("[CraftingManager] Успішно завантажено %d рецептів." % _recipes.size())


## Повертає рецепт за його ідентифікатором
func get_recipe(recipe_id: StringName) -> Resource:
	return _recipes.get(recipe_id, null)


## Повертає список усіх зареєстрованих рецептів
func get_all_recipes() -> Array[Resource]:
	var list: Array[Resource] = []
	for r in _recipes.values():
		list.append(r)
	return list


## Повертає список рецептів, доступних для вказаної епохи (або нижче)
func get_recipes_for_era(era_index: int) -> Array[Resource]:
	var list: Array[Resource] = []
	for r in _recipes.values():
		var req_era: Variant = r.get("required_era")
		if req_era is int and req_era <= era_index:
			list.append(r)
	return list


## Перевіряє, чи вистачає в інвентарі всіх необхідних інгредієнтів для крафту
func can_craft(recipe: Resource, inventory: Node) -> bool:
	if recipe == null or inventory == null:
		return false

	var ingredients: Variant = recipe.get("ingredients")
	if not (ingredients is Array):
		return false

	for cost in ingredients:
		if cost == null:
			continue
		var item: Resource = cost.get("item")
		var required_amount: int = cost.get("amount") if cost.get("amount") != null else 1
		if item == null:
			continue

		var item_id: StringName = StringName(item.get("id"))
		if not inventory.has_item(item_id, required_amount):
			return false

	return true


## Виконує крафт: перевіряє наявність матеріалів, списує їх з інвентаря та додає результат
func craft_item(recipe: Resource, inventory: Node) -> bool:
	if recipe == null or inventory == null:
		crafting_failed.emit(recipe, "Невалідний рецепт або інвентар")
		return false

	if not can_craft(recipe, inventory):
		crafting_failed.emit(recipe, "Недостатньо матеріалів для виготовлення")
		return false

	var ingredients: Array = recipe.get("ingredients")
	var result_item: Resource = recipe.get("result_item")
	var result_amount: int = recipe.get("result_amount") if recipe.get("result_amount") != null else 1

	if result_item == null:
		crafting_failed.emit(recipe, "У рецепта відсутній результат")
		return false

	# 1. Списуємо інгредієнти
	for cost in ingredients:
		var item: Resource = cost.get("item")
		var amount: int = cost.get("amount") if cost.get("amount") != null else 1
		var item_id: StringName = StringName(item.get("id"))
		inventory.remove_item(item_id, amount)

	# 2. Додаємо результат у інвентар
	var remainder: int = inventory.add_item(result_item, result_amount)
	if remainder > 0:
		# Якщо інвентар переповнений і результат не помістився повністю
		print("[CraftingManager] Увага: %d предметів не помістилося в інвентар!" % remainder)

	recipe_crafted.emit(recipe, result_item, result_amount - remainder)
	return true
