GAME_DESC.md is always more important data source than DESCRIPTION.md

when you need textures for game, just generate empty images in folder with textures, they will be just placeholders which i will change later


Always look At /docs (this is also prioritazed data about world design)

## Технічний стек
- Рушій: Godot 4.x (НЕ Godot 3).
- Мова: Суворо типізований GDScript
- Графіка: 2D Top-Down, фіксована сітка 32x32 пікселі.
- Роздільна здатність (Screen Resolution): обов'язкова і стабільна підтримка 2560x1440 (2K QHD) та 1920x1080 (Full HD), співвідношення 16:9. Налаштування розтягування Godot 4: `window/stretch/mode = "canvas_items"`, `window/stretch/aspect = "keep"` (або `"expand"`), адаптивний UI без розмиття на обох роздільних здатностях.


## Архітектурні правила
1. Жодних масивних дерев `if/else` для штучного інтелекту: поведінка поселенців будується ТІЛЬКИ на State Machine (FSM).
2. Дані окремо від коду: будь-який предмет, будівля чи технологія мають бути окремим `CustomResource` (`.tres`), а не змінними всередині класів.
3. Комунікація між системами: тільки через сигнали (`signal task_completed`) або звернення до глобальних синглтонів (`JobBoard`, `InventoryManager`).
4. Заборонено спамити в `_process(delta)`: пошук шляхів `AStarGrid2D` та перевірка завдань викликаються по таймеру або за подією, а не кожен кадр.

## Правила синтаксису Godot 4 (Anti-Hallucination)
- Використовуй `CharacterBody2D`, а НЕ `KinematicBody2D`.
- Анотації: `@export`, `@onready` замість старих ключових слів.
- Рендер колізій і шарів: перевіряти бітові маски через константи.


DO NOT Generate all of the things at once, many features will be added later. generate only specific thing asked

After generating code, write in Documentation.md all needed documentation for code and in file CHANGES.md write what you have done with simple words, like log of changes

After generating code change all .md files when you think is needed, but to change /docs files is restricted, you can only suggest to add change

If you create some textures, create empty files in textures folder(you can still generate some texture placeholder using code)
