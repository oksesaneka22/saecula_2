extends Control

## HUDActionBar: Панель швидких дій на HUD (Будівництво, Крафт, Інвентар).
## Забезпечує прямий доступ через кліки мишею або підказки гарячих клавіш (B, C, I).

@onready var build_button: Button = $HBoxContainer/BuildButton
@onready var harvest_button: Button = $HBoxContainer.get_node_or_null("HarvestButton")
@onready var craft_button: Button = $HBoxContainer/CraftButton
@onready var inventory_button: Button = $HBoxContainer/InventoryButton
@onready var eratree_button: Button = $HBoxContainer.get_node_or_null("EraTreeButton")
@onready var roster_button: Button = $HBoxContainer.get_node_or_null("RosterButton")
@onready var admin_button: Button = $HBoxContainer.get_node_or_null("AdminButton")


func _ready() -> void:
	if build_button != null:
		build_button.pressed.connect(_on_build_button_pressed)
	if harvest_button != null:
		harvest_button.pressed.connect(_on_harvest_button_pressed)
	if EventBus != null and EventBus.has_signal("order_harvest_mode_toggled"):
		EventBus.order_harvest_mode_toggled.connect(_on_order_harvest_mode_toggled)
	if craft_button != null:
		craft_button.pressed.connect(_on_craft_button_pressed)
	if inventory_button != null:
		inventory_button.pressed.connect(_on_inventory_button_pressed)
	if eratree_button != null:
		eratree_button.pressed.connect(_on_eratree_button_pressed)
	if roster_button != null:
		roster_button.pressed.connect(_on_roster_button_pressed)
	if admin_button != null:
		admin_button.pressed.connect(_on_admin_button_pressed)


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


func _on_eratree_button_pressed() -> void:
	var hud = get_parent()
	if hud == null:
		return
	var era_ui = hud.get_node_or_null("EraTreeUI")
	if era_ui != null:
		if era_ui.visible:
			era_ui.close()
		else:
			_close_other_windows(hud)
			era_ui.open()


func _on_admin_button_pressed() -> void:
	var hud = get_parent()
	if hud == null:
		return
	var era_ui = hud.get_node_or_null("EraTreeUI")
	if era_ui != null and era_ui.visible:
		era_ui.close()

	var admin_ui = hud.get_node_or_null("AdminPanelUI")
	if admin_ui != null:
		if admin_ui.visible:
			admin_ui.close()
		else:
			_close_other_windows(hud)
			admin_ui.open()


func _close_other_windows(hud: Node) -> void:
	var era_ui = hud.get_node_or_null("EraTreeUI")
	if era_ui != null and era_ui.visible:
		era_ui.close()

	var admin_ui = hud.get_node_or_null("AdminPanelUI")
	if admin_ui != null and admin_ui.visible:
		admin_ui.close()

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


func _on_roster_button_pressed() -> void:
	if EventBus != null and EventBus.has_signal("colonist_roster_toggle_requested"):
		EventBus.colonist_roster_toggle_requested.emit()

func _on_harvest_button_pressed() -> void:
	if EventBus != null and EventBus.has_signal("order_harvest_requested"):
		EventBus.order_harvest_requested.emit()


func _on_order_harvest_mode_toggled(active: bool) -> void:
	if harvest_button != null:
		if active:
			harvest_button.text = "🌾 Збір (ЛКМ)"
			harvest_button.modulate = Color(0.6, 1.0, 0.6)
		else:
			harvest_button.text = "🌾 Збір [H]"
			harvest_button.modulate = Color.WHITE

