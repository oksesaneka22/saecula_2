extends Control

## HUDActionBar: Панель швидких дій на HUD (Будівництво, Крафт, Інвентар).
## Забезпечує прямий доступ через кліки мишею або підказки гарячих клавіш (B, C, I).

@onready var build_button: Button = $HBoxContainer/BuildButton
@onready var craft_button: Button = $HBoxContainer/CraftButton
@onready var inventory_button: Button = $HBoxContainer/InventoryButton


func _ready() -> void:
	if build_button != null:
		build_button.pressed.connect(_on_build_button_pressed)
	if craft_button != null:
		craft_button.pressed.connect(_on_craft_button_pressed)
	if inventory_button != null:
		inventory_button.pressed.connect(_on_inventory_button_pressed)


func _on_build_button_pressed() -> void:
	var hud = get_parent()
	if hud == null:
		return
	var build_menu = hud.get_node_or_null("BuildMenuUI")
	if build_menu != null:
		if build_menu.visible:
			build_menu.close()
		else:
			# Закриваємо інші вікна перед відкриттям
			_close_other_windows(hud)
			build_menu.open()


func _on_craft_button_pressed() -> void:
	var hud = get_parent()
	if hud == null:
		return
	var craft_ui = hud.get_node_or_null("CraftingUI")
	if craft_ui != null:
		if craft_ui.visible:
			craft_ui.close()
		else:
			_close_other_windows(hud)
			craft_ui.open()


func _on_inventory_button_pressed() -> void:
	var hud = get_parent()
	if hud == null:
		return
	var inv_ui = hud.get_node_or_null("InventoryUI")
	if inv_ui != null:
		if inv_ui.visible:
			inv_ui.close()
		else:
			_close_other_windows(hud)
			inv_ui.open()


func _close_other_windows(hud: Node) -> void:
	var build_menu = hud.get_node_or_null("BuildMenuUI")
	if build_menu != null and build_menu.visible:
		build_menu.close()

	var craft_ui = hud.get_node_or_null("CraftingUI")
	if craft_ui != null and craft_ui.visible:
		craft_ui.close()

	var inv_ui = hud.get_node_or_null("InventoryUI")
	if inv_ui != null and inv_ui.visible:
		inv_ui.close()

	var storage_ui = hud.get_node_or_null("StorageUI")
	if storage_ui != null and storage_ui.visible:
		storage_ui.close()
