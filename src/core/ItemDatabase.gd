extends Node

const TextureHelper = preload("res://src/core3d/TextureHelper.gd")

## ItemDatabase: Глобальний реєстр предметів гри Saecula.
## Автоматично сканує та кешує ресурси з папки `data/items/`.
## Надає методи швидкого доступу get_item(id), has_item(id) та get_all_items().

const ItemDataScript = preload("res://src/data/schemas/ItemData.gd")
const ITEMS_DIR: String = "res://data/items/"

var _items: Dictionary = {} # Dictionary[StringName, Resource]

func _ready() -> void:
	load_items_from_directory(ITEMS_DIR)


## Завантажує всі файли ресурсів .tres із вказаної директорії
func load_items_from_directory(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		push_warning("[ItemDatabase] Не вдалося відкрити директорію: %s" % path)
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	var loaded_count: int = 0

	while file_name != "":
		if not dir.current_is_dir() and (file_name.ends_with(".tres") or file_name.ends_with(".res")):
			var file_path: String = path.path_join(file_name)
			var res: Resource = load(file_path)
			var item := res as ItemData
			if item != null and item.id != &"":
				if item.icon == null:
					var tex: Texture2D = TextureHelper.get_texture(TextureHelper.get_item_texture_path(item.id))
					if tex != null:
						item.icon = tex
				_items[item.id] = item
				loaded_count += 1
		file_name = dir.get_next()

	dir.list_dir_end()
	print("[ItemDatabase] Успішно завантажено %d предметів." % loaded_count)


## Отримує об'єкт ItemData за його ідентифікатором (StringName)
func get_item(item_id: StringName) -> ItemData:
	return _items.get(item_id, null)


## Перевіряє існування предмета в базі за ID
func has_item(item_id: StringName) -> bool:
	return _items.has(item_id)


## Отримує список усіх зареєстрованих предметів
func get_all_items() -> Array:
	return _items.values()
