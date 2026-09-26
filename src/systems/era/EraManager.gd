extends Node
const TechNodeDataScript = preload("res://src/data/schemas/TechNodeData.gd")

## EraManager: Центральний менеджер дерева технологій, епох та підепох (Civilization / Frostpunk style).
## Керує прогресом цивілізації, дослідженнями, перевіркою вартості та ступінчастим переходом між підепохами й епохами.

# ------------------------------------------------------------------------------
# Сигнали
# ------------------------------------------------------------------------------
signal era_changed(new_era_index: int, era_name: String)
signal sub_era_changed(new_sub_era_id: StringName, sub_era_name: String)
signal tech_unlocked(tech_id: StringName, tech_data: Resource)
signal tech_research_failed(tech_id: StringName, reason: String)
signal tech_tree_updated()

# ------------------------------------------------------------------------------
# Константи епох
# ------------------------------------------------------------------------------
const ERA_NAMES: Array[String] = [
	"Палеоліт (Кам'яний вік)",
	"Неоліт (Перше поселення)",
	"Енеоліт (Мідна доба)",
	"Бронзовий та Залізний вік"
]

const ERA_DESCRIPTIONS: Array[String] = [
	"Первісна епоха виживання: примітивні рубила, підтримання полум'я, збір дарів природи та перший нічний прихисток.",
	"Епоха осілого способу життя: заготовка сіна та волокон, виготовлення мотузок, зведення модульних дерев'яних будинків та комор.",
	"Початок ремесел та обробки корисних копалин: видобуток прибережної глини та кременю, ліплення посуду та первинні інструменти.",
	"Розквіт цивілізації та архітектури: ковальство, кам'яні печі, міцні фортифікаційні споруди та довговічні знаряддя праці."
]

const ERA_ICONS: Array[String] = [
	"🔥",
	"🌾",
	"🏺",
	"⚔️"
]

# ------------------------------------------------------------------------------
# Структура підепох (Sub-Eras)
# Кожна епоха містить послідовні підепохи.
# Перехід на наступну підепоху можливий ТІЛЬКИ після завершення ВСІХ досліджень попередньої!
# ------------------------------------------------------------------------------
const SUB_ERAS: Array[Dictionary] = [
	# ЕПОХА 0: Палеоліт
	{
		"id": &"paleo_early",
		"era_index": 0,
		"name": "Ранній Палеоліт (Перший вогонь)",
		"description": "Опанування первісного виживання та ручних смолоскипів для орієнтації в сутінках.",
		"icon": "🏕️",
		"tech_ids": [&"primitive_survival", &"fire_mastery"]
	},
	{
		"id": &"paleo_late",
		"era_index": 0,
		"name": "Пізній Палеоліт (Кам'яні знаряддя)",
		"description": "Оббивка кременю для виготовлення сокир, кайла та облаштування першого сховища колонії.",
		"icon": "🪨",
		"tech_ids": [&"stone_flaking", &"primitive_shelter"]
	},
	# ЕПОХА 1: Неоліт
	{
		"id": &"neo_early",
		"era_index": 1,
		"name": "Ранній Неоліт (Землеробство та волокна)",
		"description": "Косіння високої трави, заготівля сіна та скручування волокон у міцні мотузки.",
		"icon": "🌾",
		"tech_ids": [&"agriculture_and_fiber", &"rope_weaving"]
	},
	{
		"id": &"neo_late",
		"era_index": 1,
		"name": "Пізній Неоліт (Теслярство та архітектура)",
		"description": "Виготовлення важкого молота та зведення повнорозмірних хатин і перекриттів Going Medieval.",
		"icon": "🛖",
		"tech_ids": [&"carpentry_hammer", &"wooden_architecture"]
	},
	# ЕПОХА 2: Енеоліт
	{
		"id": &"eneo_early",
		"era_index": 2,
		"name": "Ранній Енеоліт (Гончарство та кераміка)",
		"description": "Збір берегової глини та випалювання водонепроникного посуду для запасів води.",
		"icon": "🏺",
		"tech_ids": [&"clay_pottery"]
	},
	{
		"id": &"eneo_late",
		"era_index": 2,
		"name": "Пізній Енеоліт (Мідь та фортифікація)",
		"description": "Виплавка першої самородної міді та спорудження міцних укріплених селищ.",
		"icon": "🧱",
		"tech_ids": [&"copper_smelting", &"fortified_settlement"]
	},
	# ЕПОХА 3: Бронзовий та Залізний вік
	{
		"id": &"metal_bronze",
		"era_index": 3,
		"name": "Бронзова Доба (Міцні сплави)",
		"description": "Литво бронзових знарядь праці з високим запасом міцності та продуктивності.",
		"icon": "🛡️",
		"tech_ids": [&"bronze_alloys"]
	},
	{
		"id": &"metal_iron",
		"era_index": 3,
		"name": "Залізна Доба (Ковальство та розквіт)",
		"description": "Високотемпературне кричне залізо, кування ідеальних інструментів та палати цивілізації.",
		"icon": "⚔️",
		"tech_ids": [&"iron_working"]
	}
]

# ------------------------------------------------------------------------------
# Змінні стану
# ------------------------------------------------------------------------------
var current_era: int = 0
var current_sub_era_index: int = 0
var _technologies: Dictionary = {} ## tech_id: StringName -> TechNodeData
var _unlocked_techs: Dictionary = {} ## tech_id: StringName -> bool

# ------------------------------------------------------------------------------
# Життєвий цикл
# ------------------------------------------------------------------------------
func _ready() -> void:
	_init_technology_tree()
	print("[EraManager] Дерево епох успішно ініціалізовано. Усього технологій: %d, Підепох: %d. Поточна епоха: %s (%s)" % [
		_technologies.size(),
		SUB_ERAS.size(),
		get_current_era_name(),
		get_current_sub_era_name()
	])


# ------------------------------------------------------------------------------
# Ініціалізація дерева технологій
# Координати grid_pos оптимізовано під вертикальне дерево-ліс:
# X - горизонтальна позиція гілки/стовбура
# Y - вертикальний рівень (0: корінь зверху -> униз до листя)
# ------------------------------------------------------------------------------
func _init_technology_tree() -> void:
	_technologies.clear()
	_unlocked_techs.clear()

	# ==========================================================================
	# ЕПОХА 0: ПАЛЕОЛІТ (Кам'яний вік)
	# ==========================================================================
	# Підепоха 0.1: Ранній Палеоліт (Перший вогонь)
	_register_tech(
		&"primitive_survival",
		"Первісне виживання",
		"Базові інстинкти збирання гілок, кременю та пошуку ягід серед дикої природи. Корінь виживання роду.",
		0,
		&"paleo_early",
		"🏕️",
		[],
		{}, # Стартова технологія, безкоштовно
		[&"craft_campfire"],
		[&"campfire"],
		["Збір ягід та деревини", "Базове вогнище для сну та світла"],
		Vector2(0.5, 0.0), # Корінь зверху
		true # Вже вивчено на старті
	)

	_register_tech(
		&"fire_mastery",
		"Приборкання вогню",
		"Використання сухої трави та дерев'яних смолоскипів для освітлення густої темряви та безпечного пересування вночі.",
		0,
		&"paleo_early",
		"🕯️",
		[&"primitive_survival"],
		{ &"wood": 5, &"stone": 2 },
		[&"craft_torch"],
		[],
		["Смолоскип у руці (мобільне світло)", "Встановлення факелів у землю на ПКМ"],
		Vector2(0.5, 1.0)
	)

	# Підепоха 0.2: Пізній Палеоліт (Кам'яні знаряддя)
	_register_tech(
		&"stone_flaking",
		"Оббивка кременю",
		"Техніка розколювання каменю для створення гострих робочих кромок сокир та рубил.",
		0,
		&"paleo_late",
		"🪓",
		[&"fire_mastery"],
		{ &"wood": 6, &"stone": 4 },
		[&"craft_stone_axe", &"craft_stone_pickaxe"],
		[],
		["Кам'яна сокира (швидка вирубка дерев)", "Кам'яне кайло (видобуток каменю та руди)"],
		Vector2(0.0, 2.0)
	)

	_register_tech(
		&"primitive_shelter",
		"Первісний прихисток",
		"Створення захищеної стоянки та настилу для зберігання знайдених припасів колонії.",
		0,
		&"paleo_late",
		"📦",
		[&"fire_mastery"],
		{ &"wood": 10, &"stone": 6 },
		[],
		[&"stockpile"],
		["Склад / Сховище ресурсів (12 слотів)", "Логістичний облік матеріалів колонії"],
		Vector2(1.0, 2.0)
	)

	# ==========================================================================
	# ЕПОХА 1: НЕОЛІТ (Перше поселення)
	# ==========================================================================
	# Підепоха 1.1: Ранній Неоліт (Землеробство та волокна)
	_register_tech(
		&"agriculture_and_fiber",
		"Трав'яні волокна та коса",
		"Виготовлення ручної коси з кременю для скошування високої дикої трави та заготівлі соломи.",
		1,
		&"neo_early",
		"🌾",
		[&"stone_flaking"],
		{ &"wood": 10, &"stone": 8, &"flint": 2 },
		[&"craft_scythe"],
		[],
		["Коса для трави", "Заготівля сіна та соломи", "Перехід у Неоліт"],
		Vector2(0.5, 3.0)
	)

	_register_tech(
		&"rope_weaving",
		"Плетіння мотузок",
		"Скручування висушених стебел соломи у міцні канати та мотузки для скріплення конструкцій.",
		1,
		&"neo_early",
		"🪢",
		[&"agriculture_and_fiber"],
		{ &"straw": 12 },
		[&"craft_rope"],
		[],
		["Виготовлення міцних мотузок з соломи", "Основа для будівництва та складних знарядь"],
		Vector2(0.5, 4.0)
	)

	# Підепоха 1.2: Пізній Неоліт (Теслярство та архітектура)
	_register_tech(
		&"carpentry_hammer",
		"Будівельна теслярська справа",
		"Виготовлення важкого кам'яного молота на міцному мотузяному кріпленні. Прискорює будівництво споруд удвічі (5 ударів замість 10).",
		1,
		&"neo_late",
		"🔨",
		[&"rope_weaving", &"primitive_shelter"],
		{ &"wood": 12, &"stone": 8, &"rope": 2 },
		[&"craft_hammer"],
		[],
		["Будівельний молоток", "Зведення конструкцій за 5 махів замість 10"],
		Vector2(0.0, 5.0)
	)

	_register_tech(
		&"wooden_architecture",
		"Модульне зодчество хатин",
		"Конструювання повнорозмірних дерев'яних хатин, балок-опор, підлоги, стін, дверей та солом'яних дахів.",
		1,
		&"neo_late",
		"🛖",
		[&"rope_weaving", &"primitive_shelter"],
		{ &"wood": 20, &"straw": 16, &"rope": 3 },
		[],
		[&"wooden_hut", &"modular_floor", &"modular_pillar", &"modular_wall", &"modular_door", &"modular_roof"],
		["Дерев'яна хатина (житло колоністів)", "Модульні компоненти Going Medieval: підлога, колони, стіни, дах"],
		Vector2(1.0, 5.0)
	)

	# ==========================================================================
	# ЕПОХА 2: ЕНЕОЛІТ (Мідний вік)
	# ==========================================================================
	# Підепоха 2.1: Ранній Енеоліт (Гончарство та кераміка)
	_register_tech(
		&"clay_pottery",
		"Гончарство та кераміка",
		"Видобуток пластичної берегової глини та формування водонепроникних глечиків і ємностей для зберігання.",
		2,
		&"eneo_early",
		"🏺",
		[&"wooden_architecture"],
		{ &"clay": 15, &"flint": 6, &"wood": 15 },
		[],
		[],
		["Обробка прибережної глини", "Місткості для чистих запасів води", "Перехід у Мідну добу"],
		Vector2(0.5, 6.0)
	)

	# Підепоха 2.2: Пізній Енеоліт (Мідь та фортифікація)
	_register_tech(
		&"copper_smelting",
		"Первинна пірометалургія",
		"Будівництво глиняних печей високого тиску та виплавка самородної міді для перших металевих клинів.",
		2,
		&"eneo_late",
		"🔥",
		[&"clay_pottery"],
		{ &"clay": 25, &"stone": 20, &"wood": 30 },
		[],
		[],
		["Мідні зливки", "Мідні сокири з підвищеною міцністю (+50% ресурсомісткість)"],
		Vector2(0.0, 7.0)
	)

	_register_tech(
		&"fortified_settlement",
		"Укріплене селище",
		"Будівництво міцних дерев'яних палісадів, сторожових веж та кам'яно-глиняних складів.",
		2,
		&"eneo_late",
		"🏰",
		[&"clay_pottery", &"carpentry_hammer"],
		{ &"wood": 35, &"stone": 25, &"clay": 15 },
		[],
		[],
		["Подвоєна місткість складів (24 слоти)", "Зниження витрат енергії на будівництво"],
		Vector2(1.0, 7.0)
	)

	# ==========================================================================
	# ЕПОХА 3: БРОНЗОВИЙ ТА ЗАЛІЗНИЙ ВІК
	# ==========================================================================
	# Підепоха 3.1: Бронзова Доба
	_register_tech(
		&"bronze_alloys",
		"Бронзове литво",
		"Сплав міді та олова, що породжує неперевершену міцність лез сокир, доліт та будівельних кірок.",
		3,
		&"metal_bronze",
		"🛡️",
		[&"copper_smelting"],
		{ &"clay": 30, &"stone": 40, &"wood": 40 },
		[],
		[],
		["Бронзове спорядження", "Високопродуктивний видобуток валунів та деревини"],
		Vector2(0.5, 8.0)
	)

	# Підепоха 3.2: Залізна Доба
	_register_tech(
		&"iron_working",
		"Залізне ковальство",
		"Високотемпературне горно, кричне залізо та ковані сокири і кайла найвищого ґатунку.",
		3,
		&"metal_iron",
		"⚔️",
		[&"bronze_alloys", &"fortified_settlement"],
		{ &"stone": 50, &"wood": 50, &"clay": 35 },
		[],
		[],
		["Ковані залізні інструменти", "Кам'яна кладка та величні палати цивілізації", "Вершина розвитку"],
		Vector2(0.5, 9.0)
	)

	_update_era_from_techs()


func _register_tech(
	id: StringName,
	d_name: String,
	desc: String,
	era: int,
	sub_era: StringName,
	symbol: String,
	prereqs: Array[StringName],
	costs: Dictionary,
	recipes: Array[StringName],
	buildings: Array[StringName],
	features: Array[String],
	pos: Vector2,
	initially_unlocked: bool = false
) -> void:
	var tech := TechNodeDataScript.new()
	tech.id = id
	tech.display_name = d_name
	tech.description = desc
	tech.era_index = era
	tech.sub_era_id = sub_era
	tech.icon_symbol = symbol
	tech.prerequisites = prereqs
	tech.cost = costs
	tech.unlocks_recipes = recipes
	tech.unlocks_buildings = buildings
	tech.unlock_features = features
	tech.grid_pos = pos

	_technologies[id] = tech
	if initially_unlocked:
		_unlocked_techs[id] = true


# ------------------------------------------------------------------------------
# Публічні запити та гетери
# ------------------------------------------------------------------------------
func get_all_techs() -> Array[Resource]:
	var result: Array[Resource] = []
	for tech in _technologies.values():
		result.append(tech)
	return result


func get_tech(tech_id: StringName) -> Resource:
	return _technologies.get(tech_id, null)


func get_techs_for_era(era_index: int) -> Array[Resource]:
	var result: Array[Resource] = []
	for tech in _technologies.values():
		if tech.era_index == era_index:
			result.append(tech)
	return result


func get_techs_for_sub_era(sub_era_id: StringName) -> Array[Resource]:
	var result: Array[Resource] = []
	for tech in _technologies.values():
		if tech.sub_era_id == sub_era_id:
			result.append(tech)
	return result


func is_tech_unlocked(tech_id: StringName) -> bool:
	return _unlocked_techs.get(tech_id, false)


func get_current_era() -> int:
	return current_era


func get_current_era_name() -> String:
	if current_era >= 0 and current_era < ERA_NAMES.size():
		return ERA_NAMES[current_era]
	return "Невідома епоха"


func get_current_era_description() -> String:
	if current_era >= 0 and current_era < ERA_DESCRIPTIONS.size():
		return ERA_DESCRIPTIONS[current_era]
	return ""


# ------------------------------------------------------------------------------
# Робота з підепохами (Sub-Eras)
# ------------------------------------------------------------------------------
func get_all_sub_eras() -> Array[Dictionary]:
	return SUB_ERAS


func get_sub_eras_for_era(era_index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for sub in SUB_ERAS:
		if sub.era_index == era_index:
			result.append(sub)
	return result


func get_sub_era_by_id(sub_era_id: StringName) -> Dictionary:
	for sub in SUB_ERAS:
		if sub.id == sub_era_id:
			return sub
	return {}


func get_sub_era_index(sub_era_id: StringName) -> int:
	for i in range(SUB_ERAS.size()):
		if SUB_ERAS[i].id == sub_era_id:
			return i
	return -1


func get_current_sub_era() -> Dictionary:
	if current_sub_era_index >= 0 and current_sub_era_index < SUB_ERAS.size():
		return SUB_ERAS[current_sub_era_index]
	return {}


func get_current_sub_era_name() -> String:
	var sub := get_current_sub_era()
	return sub.get("name", "")


func is_sub_era_completed(sub_era_id: StringName) -> bool:
	var sub := get_sub_era_by_id(sub_era_id)
	if sub.is_empty():
		return false
	var tech_ids: Array = sub.get("tech_ids", [])
	for tid in tech_ids:
		if not is_tech_unlocked(tid):
			return false
	return true


func is_sub_era_unlocked(sub_era_id: StringName) -> bool:
	var idx: int = get_sub_era_index(sub_era_id)
	if idx <= 0:
		return true # Перша підепоха (paleo_early) відкрита завжди
	# Перехід на нову підепоху ТІЛЬКИ після завершення ВСІХ досліджень минулої
	var prev_sub := SUB_ERAS[idx - 1]
	return is_sub_era_completed(prev_sub.id)


func get_unlocked_tech_count() -> int:
	var count: int = 0
	for u in _unlocked_techs.values():
		if u:
			count += 1
	return count


func get_total_tech_count() -> int:
	return _technologies.size()


# ------------------------------------------------------------------------------
# Перевірка можливості дослідження
# ------------------------------------------------------------------------------
func can_research(tech_id: StringName, inventory: Node = null) -> bool:
	if is_tech_unlocked(tech_id):
		return false

	var tech: Resource = get_tech(tech_id)
	if tech == null:
		return false

	# 1. Перевірка розблокування підепохи:
	# Перехід на нову підепоху тільки після того як завершив всі дослідження минулої!
	if not is_sub_era_unlocked(tech.sub_era_id):
		return false

	# 2. Перевірка передумов (усі батьківські технології мають бути відкриті)
	for pre_id in tech.prerequisites:
		if not is_tech_unlocked(pre_id):
			return false

	# 3. Якщо передано інвентар, перевіряємо наявність необхідних ресурсів
	if inventory != null:
		for item_id in tech.cost.keys():
			var req_amount: int = tech.cost[item_id]
			if inventory.get_item_count(item_id) < req_amount:
				return false

	return true


func is_prerequisites_met(tech_id: StringName) -> bool:
	var tech: Resource = get_tech(tech_id)
	if tech == null:
		return false

	# Підепоха має бути розблокована
	if not is_sub_era_unlocked(tech.sub_era_id):
		return false

	# Батьківські технології мають бути вивчені
	for pre_id in tech.prerequisites:
		if not is_tech_unlocked(pre_id):
			return false
	return true


# ------------------------------------------------------------------------------
# Виконання дослідження
# ------------------------------------------------------------------------------
func research_tech(tech_id: StringName, inventory: Node = null) -> bool:
	if is_tech_unlocked(tech_id):
		tech_research_failed.emit(tech_id, "Технологія вже вивчена")
		return false

	var tech: Resource = get_tech(tech_id)
	if tech == null:
		tech_research_failed.emit(tech_id, "Невідома технологія")
		return false

	# Перевірка доступності підепохи
	if not is_sub_era_unlocked(tech.sub_era_id):
		tech_research_failed.emit(tech_id, "Підепоха заблокована! Спершу завершіть усі дослідження попередньої підепохи.")
		return false

	# Перевірка передумов
	if not is_prerequisites_met(tech_id):
		tech_research_failed.emit(tech_id, "Не виконані попередні дослідження")
		return false

	# Перевірка та списання ресурсів
	if inventory != null and not tech.cost.is_empty():
		for item_id in tech.cost.keys():
			var req_amount: int = tech.cost[item_id]
			if inventory.get_item_count(item_id) < req_amount:
				var item_name: String = String(item_id)
				var item_res = ItemDatabase.get_item(item_id)
				if item_res != null:
					item_name = item_res.display_name
				tech_research_failed.emit(tech_id, "Не вистачає ресурсу: %s (%d шт.)" % [item_name, req_amount])
				return false

		# Списуємо ресурси
		for item_id in tech.cost.keys():
			var req_amount: int = tech.cost[item_id]
			inventory.remove_item(item_id, req_amount)

	# Відкриваємо технологію
	_unlocked_techs[tech_id] = true
	print("[EraManager] 💡 Технологію '%s' успішно досліджено!" % tech.display_name)

	# Сповіщення в EventBus
	if EventBus != null:
		EventBus.technology_unlocked.emit(tech_id)
		if EventBus.has_signal("notification_posted"):
			EventBus.notification_posted.emit("Досліджено!", "Відкрито технологію: %s" % tech.display_name, 1) # SUCCESS

	tech_unlocked.emit(tech_id, tech)

	# Перевірка на перехід у нову підепоху та епоху
	_update_era_from_techs()

	tech_tree_updated.emit()
	return true


func unlock_tech_cheat(tech_id: StringName) -> bool:
	if not _technologies.has(tech_id):
		return false
	_unlocked_techs[tech_id] = true
	var tech: Resource = _technologies[tech_id]
	if EventBus != null:
		EventBus.technology_unlocked.emit(tech_id)
	tech_unlocked.emit(tech_id, tech)
	_update_era_from_techs()
	tech_tree_updated.emit()
	print("[EraManager] 🪄 Чіт-розблокування технології: %s" % tech.display_name)
	return true


func unlock_all_techs_cheat() -> void:
	for id in _technologies.keys():
		_unlocked_techs[id] = true
	_update_era_from_techs()
	tech_tree_updated.emit()
	print("[EraManager] 🪄 Всі технології дерева успішно досліджено!")


func reset_techs_cheat() -> void:
	_unlocked_techs.clear()
	_unlocked_techs[&"primitive_survival"] = true
	current_era = 0
	current_sub_era_index = 0
	tech_tree_updated.emit()
	print("[EraManager] 🪄 Прогрес досліджень скинуто до початку Палеоліту.")


# ------------------------------------------------------------------------------
# Оновлення поточної підепохи та епохи
# ------------------------------------------------------------------------------
func _update_era_from_techs() -> void:
	# 1. Розрахунок поточної підепохи
	var highest_sub_idx: int = 0
	for i in range(SUB_ERAS.size()):
		var sub := SUB_ERAS[i]
		if is_sub_era_completed(sub.id):
			highest_sub_idx = mini(i + 1, SUB_ERAS.size() - 1)
		else:
			highest_sub_idx = i
			break

	set_sub_era_index(highest_sub_idx)

	# 2. Розрахунок епохи на базі активної підепохи
	var target_era: int = SUB_ERAS[current_sub_era_index].era_index
	if target_era != current_era:
		set_era(target_era)


func set_sub_era_index(idx: int) -> void:
	var old_idx: int = current_sub_era_index
	current_sub_era_index = clampi(idx, 0, SUB_ERAS.size() - 1)
	if current_sub_era_index != old_idx:
		var sub := SUB_ERAS[current_sub_era_index]
		print("[EraManager] 🌿 ПІДЕПОХА ЗМІНИЛАСЯ: %s -> %s!" % [SUB_ERAS[old_idx].name, sub.name])
		sub_era_changed.emit(sub.id, sub.name)
		if EventBus != null and EventBus.has_signal("notification_posted"):
			EventBus.notification_posted.emit("НОВА ПІДЕПОХА!", "Розблоковано: %s" % sub.name, 1)


func set_era(new_era: int) -> void:
	var old_era: int = current_era
	current_era = clampi(new_era, 0, ERA_NAMES.size() - 1)
	if current_era != old_era:
		var old_id: StringName = StringName("era_%d" % old_era)
		var new_id: StringName = StringName("era_%d" % current_era)
		print("[EraManager] 🏛️ ЕПОХА ЗМІНИЛАСЯ: %s -> %s!" % [ERA_NAMES[old_era], ERA_NAMES[current_era]])
		if EventBus != null:
			EventBus.era_advanced.emit(new_id, old_id)
			if EventBus.has_signal("notification_posted"):
				EventBus.notification_posted.emit("НОВА ЕПОХА!", "Поселення перейшло у: %s" % ERA_NAMES[current_era], 1)
		era_changed.emit(current_era, ERA_NAMES[current_era])
		tech_tree_updated.emit()
