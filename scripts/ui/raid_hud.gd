class_name RaidHUD
extends CanvasLayer

const ITEM_SLOT_SCENE := preload("res://scenes/ui/item_slot.tscn")

@onready var vitals: Label = %Vitals
@onready var spell_status: Label = %SpellStatus
@onready var spell_pages: Label = %SpellPages
@onready var combat_slots: HBoxContainer = %CombatSlots
@onready var health_gauge: ProgressBar = %HealthGauge
@onready var mana_gauge: ProgressBar = %ManaGauge
@onready var stamina_gauge: ProgressBar = %StaminaGauge
@onready var consumables: Label = %Consumables
@onready var cast_progress: ProgressBar = %CastProgress
@onready var objective: Label = %Objective
@onready var bleeding_indicator: Label = %BleedingIndicator
@onready var interaction_prompt: Label = %InteractionPrompt
@onready var extraction_status: Label = %ExtractionStatus
@onready var message_label: Label = %MessageLabel
@onready var reticle: Label = %AimReticle
@onready var inventory_panel: PanelContainer = $HUDRoot/InventoryUI
@onready var inventory_rows: VBoxContainer = $HUDRoot/InventoryUI.get_node("%ItemRows")
@onready var equipment_rows: VBoxContainer = $HUDRoot/InventoryUI.get_node("%EquipmentRows")
@onready var capacity_summary: Label = $HUDRoot/InventoryUI.get_node("%CapacitySummary")
@onready var spell_settings_panel: PanelContainer = $HUDRoot/RaidSpellSettings
@onready var raid_page_buttons: HBoxContainer = $HUDRoot/RaidSpellSettings.get_node("%PageButtons")
@onready var raid_fixed_sockets: HBoxContainer = $HUDRoot/RaidSpellSettings.get_node("%FixedSockets")
@onready var raid_library_rows: VBoxContainer = $HUDRoot/RaidSpellSettings.get_node("%LibraryRows")
@onready var loot_panel: PanelContainer = $HUDRoot/LootWindow
@onready var loot_title: Label = $HUDRoot/LootWindow.get_node("%Title")
@onready var loot_rows: VBoxContainer = $HUDRoot/LootWindow.get_node("%LootRows")

var raid: RaidScene
var player: PlayerController
var weather_name: String = "Clear"
var selected_container: LootContainer
var combat_slot_buttons: Array[Button] = []
var raid_workshop_page: int = 0

func _ready() -> void:
	$HUDRoot/LootWindow.get_node("%CloseButton").pressed.connect(func() -> void: loot_panel.visible = false)
	$HUDRoot/InventoryUI.get_node("%CloseButton").pressed.connect(_close_access_panels)
	$HUDRoot/InventoryUI.get_node("%SpellsButton").pressed.connect(_show_spell_settings)
	$HUDRoot/RaidSpellSettings.get_node("%CloseButton").pressed.connect(_close_access_panels)
	$HUDRoot/RaidSpellSettings.get_node("%InventoryButton").pressed.connect(_show_inventory)
	GameState.state_changed.connect(refresh_inventory)
	for index: int in range(4):
		var button := Button.new()
		button.custom_minimum_size = Vector2(82, 82)
		button.expand_icon = true
		button.text = str(index + 1)
		button.tooltip_text = "Combat slot %d" % (index + 1)
		button.pressed.connect(func() -> void: if player != null: player.select_combat_slot(index))
		combat_slots.add_child(button)
		combat_slot_buttons.append(button)

func configure(raid_scene: RaidScene, player_controller: PlayerController, current_weather: String) -> void:
	raid = raid_scene
	player = player_controller
	weather_name = current_weather
	refresh_inventory()
	refresh_spell_settings()

func _process(_delta: float) -> void:
	if player == null:
		return
	var conditions: PackedStringArray = []
	if player.bleeding:
		conditions.append("BLEEDING")
	if player.burn_remaining > 0.0:
		conditions.append("BURNING")
	if player.slow_remaining > 0.0:
		conditions.append("CHILLED")
	if player.poison_remaining > 0.0:
		conditions.append("POISONED")
	for body_part: String in player.injuries.keys():
		if float(player.injuries[body_part]) > 0.05:
			conditions.append("%s INJURY" % body_part.replace("_", " ").to_upper())
	var condition_text: String = "  |  " + ", ".join(conditions) if not conditions.is_empty() else ""
	vitals.text = "HP %d/%d   MANA %d/%d   STA %d/%d   WARD %d%s" % [int(player.health), int(player.max_health), int(player.mana), int(player.max_mana), int(player.stamina), int(player.max_stamina), int(player.ward), condition_text]
	health_gauge.max_value = player.max_health
	health_gauge.value = player.health
	mana_gauge.max_value = player.max_mana
	mana_gauge.value = player.mana
	stamina_gauge.max_value = player.max_stamina
	stamina_gauge.value = player.stamina
	bleeding_indicator.visible = player.bleeding
	var config := player.current_spell_config()
	var mana_cost: int = int(ceil(config.mana_cost)) if config != null and config.valid else 0
	spell_status.text = "%s  |  %s  |  CURRENT ELEMENT: %s  |  Cost %d  |  Cooldown %.1fs" % [player.current_spellbook_name(), player.current_spell_name() if player.active_combat_slot < 3 else _dagger_name(), player.current_primary_element().to_upper(), mana_cost, player.cooldown_remaining()]
	var slot_text := "[1] %s    [2] %s    [3] %s    [4] %s" % [_page_name(0), _page_name(1), _page_name(2), _dagger_name()]
	spell_pages.text = slot_text
	_update_combat_slot_icons()
	consumables.text = "[F] %s x%d\n[G] %s x%d" % [ItemDB.display_name("health_potion"), int(GameState.raid_inventory.get("health_potion", 0)), ItemDB.display_name("mana_potion"), int(GameState.raid_inventory.get("mana_potion", 0))]
	cast_progress.visible = player.casting
	cast_progress.value = player.cast_progress_ratio() * 100.0
	objective.text = "%s  |  %s: %s  |  Pack %d/%d (%.1f kg)" % [GameState.active_quest_text(), raid.region_display_name, weather_name, GameState.inventory_slots(GameState.raid_inventory), GameState.raid_capacity(), GameState.inventory_weight(GameState.raid_inventory)]
	interaction_prompt.text = "◇  E" if not player.nearby_interaction.is_empty() else ""
	interaction_prompt.tooltip_text = player.nearby_interaction
	reticle.text = "◎" if config != null and config.valid and config.behavior_type != "projectile" else "+"
	reticle.position = get_viewport().get_mouse_position() - Vector2(13, 19)

func _page_name(index: int) -> String:
	if player == null or index >= player.page_configs.size():
		return "Empty"
	var config: RuntimeSpellConfig = player.page_configs[index]
	var name: String = config.base_spell.display_name if config != null and config.valid else "Empty"
	var element := config.base_spell.primary_element.to_upper() if config != null and config.valid else "NEUTRAL"
	return ("> " if player.active_combat_slot == index else "") + "%s <%s>" % [name, element]

func _dagger_name() -> String:
	if player == null:
		return "Empty Dagger"
	var dagger := player.equipped_dagger()
	var name := dagger.display_name if dagger != null else "Empty Dagger"
	var element := dagger.primary_element.to_upper() if dagger != null else "NEUTRAL"
	return ("> " if player.active_combat_slot == 3 else "") + "%s <%s>" % [name, element]

func _update_combat_slot_icons() -> void:
	if combat_slot_buttons.size() != 4:
		return
	for index: int in range(3):
		var config: RuntimeSpellConfig = player.page_configs[index] if index < player.page_configs.size() else null
		var spell: BaseSpellData = config.base_spell if config != null and config.valid else null
		combat_slot_buttons[index].icon = UIIconFactory.spell_icon(spell, 96) if spell != null else UIIconFactory.icon("?", "neutral", 96)
		combat_slot_buttons[index].tooltip_text = "%s\n%s" % [spell.display_name if spell != null else "Empty Spell Slot", config.behavior_description() if config != null else ""]
		combat_slot_buttons[index].disabled = config == null or not config.valid
		var enough_mana: bool = config != null and player.mana + 0.001 >= config.mana_cost
		combat_slot_buttons[index].modulate = Color.WHITE if player.active_combat_slot == index else Color(0.64, 0.64, 0.72, 0.92) if enough_mana else Color(0.48, 0.3, 0.34, 0.82)
	var dagger_id: String = str(GameState.loadout.get("dagger", ""))
	combat_slot_buttons[3].icon = UIIconFactory.item_icon(dagger_id, 96)
	combat_slot_buttons[3].tooltip_text = _dagger_name() + "\nSpace: melee attack"
	combat_slot_buttons[3].modulate = Color.WHITE if player.active_combat_slot == 3 else Color(0.52, 0.52, 0.6, 0.86)

func toggle_inventory() -> void:
	var opening: bool = not inventory_panel.visible and not spell_settings_panel.visible
	_close_access_panels()
	if opening:
		inventory_panel.visible = true
		loot_panel.visible = false
		refresh_inventory()

func _show_inventory() -> void:
	spell_settings_panel.visible = false
	inventory_panel.visible = true
	loot_panel.visible = false
	refresh_inventory()

func _show_spell_settings() -> void:
	inventory_panel.visible = false
	spell_settings_panel.visible = true
	loot_panel.visible = false
	refresh_spell_settings()

func _close_access_panels() -> void:
	inventory_panel.visible = false
	spell_settings_panel.visible = false

func refresh_inventory() -> void:
	if inventory_rows == null:
		return
	_clear(inventory_rows)
	_clear(equipment_rows)
	_build_raid_equipment()
	capacity_summary.text = "Field pack %d/%d slots  |  Secure %d/2: %s" % [GameState.inventory_slots(GameState.raid_inventory), GameState.raid_capacity(), GameState.inventory_slots(GameState.raid_secure), _items_text(GameState.raid_secure)]
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	inventory_rows.add_child(grid)
	var ids: Array = GameState.raid_inventory.keys()
	ids.sort()
	for raw_id: Variant in ids:
		var item_id: String = str(raw_id)
		var row := VBoxContainer.new()
		row.custom_minimum_size = Vector2(96, 124)
		grid.add_child(row)
		var item_slot := ITEM_SLOT_SCENE.instantiate() as ItemSlot
		row.add_child(item_slot)
		item_slot.configure(item_id, int(GameState.raid_inventory[item_id]), "raid_inventory", item_id, true)
		var actions := HBoxContainer.new()
		actions.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(actions)
		var category: String = str(ItemDB.get_item(item_id).get("category", ""))
		if category in ["medical", "mana_consumable", "food", "drink"]:
			var use_button := Button.new()
			use_button.text = "✚"
			use_button.tooltip_text = "Use item"
			use_button.pressed.connect(_use_item.bind(item_id))
			actions.add_child(use_button)
		elif category in ["spell", "spellbook", "focus", "dagger", "melee", "armor_head", "armor_chest", "accessory", "backpack", "armor"]:
			var equip_button := Button.new()
			equip_button.text = "↗"
			equip_button.tooltip_text = "Equip"
			equip_button.pressed.connect(_equip_item.bind(item_id))
			actions.add_child(equip_button)
		var secure_button := Button.new()
		secure_button.text = "◇"
		secure_button.tooltip_text = "Move to protected slots"
		secure_button.pressed.connect(_secure_item.bind(item_id))
		actions.add_child(secure_button)
		var discard_button := Button.new()
		discard_button.text = "×"
		discard_button.tooltip_text = "Discard"
		discard_button.pressed.connect(_discard_item.bind(item_id))
		actions.add_child(discard_button)
	if GameState.raid_inventory.is_empty():
		var empty := Label.new()
		empty.text = "The field pack is empty. Search arcane containers and fallen foes."
		inventory_rows.add_child(empty)

func _build_raid_equipment() -> void:
	var labels := {"spellbook":"Book", "focus":"Focus", "dagger":"Dagger", "head":"Head", "chest":"Body", "accessory_1":"Acc. 1", "accessory_2":"Acc. 2", "backpack":"Pack"}
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	equipment_rows.add_child(grid)
	for slot: String in labels.keys():
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(112, 128)
		grid.add_child(card)
		var title := Label.new()
		title.text = str(labels[slot])
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(title)
		var item_id: String = str(GameState.loadout.get(slot, ""))
		var target := ITEM_SLOT_SCENE.instantiate() as ItemSlot
		target.accepted_categories = _raid_slot_categories(slot)
		target.item_dropped.connect(_on_raid_equipment_drop)
		target.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.add_child(target)
		target.configure(item_id, 1 if not item_id.is_empty() else 0, "raid_loadout", slot, false)
		if not item_id.is_empty():
			var remove := Button.new()
			remove.text = "×"
			remove.tooltip_text = "Move to field pack"
			remove.pressed.connect(_unequip_raid_slot.bind(slot))
			card.add_child(remove)

func refresh_spell_settings() -> void:
	if raid_page_buttons == null:
		return
	_clear(raid_page_buttons)
	_clear(raid_fixed_sockets)
	_clear(raid_library_rows)
	for page_index: int in range(3):
		var page_button := Button.new()
		page_button.custom_minimum_size = Vector2(0, 68)
		page_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var config := GameState.spell_config(page_index)
		page_button.icon = UIIconFactory.spell_icon(config.base_spell, 64) if config.valid else UIIconFactory.icon("?", "neutral", 64)
		page_button.add_theme_constant_override("icon_max_width", 58)
		page_button.text = "PAGE %d\n%s" % [page_index + 1, config.base_spell.display_name if config.valid else "Empty"]
		page_button.disabled = page_index == raid_workshop_page
		page_button.pressed.connect(_select_raid_workshop_page.bind(page_index))
		raid_page_buttons.add_child(page_button)
	var page: Dictionary = GameState.spell_pages[raid_workshop_page]
	var spell := ItemDB.spell(str(page.get("spell_item", "")))
	var attachments_locked: bool = spell != null and spell.compatible_modifier_categories.is_empty()
	var formula_slot := ITEM_SLOT_SCENE.instantiate() as ItemSlot
	formula_slot.accepted_categories = ["spell"]
	formula_slot.item_dropped.connect(_on_raid_spell_drop)
	formula_slot.configure(str(page.get("spell_item", "")), 1, "raid_spell_page", str(raid_workshop_page), false)
	raid_fixed_sockets.add_child(formula_slot)
	var book := GameState.equipped_spellbook()
	var installed: Array = page.get("modifiers", [])
	var capacity: int = 0 if attachments_locked else book.maximum_modifiers_per_page if book != null else 0
	if attachments_locked:
		var locked_notice := Label.new()
		locked_notice.text = "ATTACHMENTS LOCKED\nExplosion is a sealed formula."
		locked_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		raid_fixed_sockets.add_child(locked_notice)
	for socket_index: int in range(capacity):
		var card := VBoxContainer.new()
		raid_fixed_sockets.add_child(card)
		var modifier_slot := ITEM_SLOT_SCENE.instantiate() as ItemSlot
		modifier_slot.accepted_categories = ["spell_modifier"]
		modifier_slot.compatible_spell = spell
		modifier_slot.item_dropped.connect(_on_raid_spell_drop)
		card.add_child(modifier_slot)
		var installed_id: String = str(installed[socket_index]) if socket_index < installed.size() else ""
		modifier_slot.configure(installed_id, 1 if not installed_id.is_empty() else 0, "raid_spell_attachment", "%d:%d" % [raid_workshop_page, socket_index], false)
		if not installed_id.is_empty():
			var remove := Button.new()
			remove.text = "×"
			remove.tooltip_text = "Return rune to field pack"
			remove.pressed.connect(_remove_raid_modifier.bind(socket_index))
			card.add_child(remove)
	var library_grid := GridContainer.new()
	library_grid.columns = 5
	library_grid.add_theme_constant_override("h_separation", 8)
	library_grid.add_theme_constant_override("v_separation", 8)
	raid_library_rows.add_child(library_grid)
	for raw_id: Variant in GameState.raid_inventory.keys():
		var item_id: String = str(raw_id)
		if ItemDB.spell(item_id) == null and ItemDB.modifier(item_id) == null:
			continue
		if attachments_locked and ItemDB.modifier(item_id) != null:
			continue
		var item_slot := ITEM_SLOT_SCENE.instantiate() as ItemSlot
		library_grid.add_child(item_slot)
		item_slot.configure(item_id, int(GameState.raid_inventory[item_id]), "raid_inventory", item_id, true)

func _select_raid_workshop_page(page_index: int) -> void:
	raid_workshop_page = page_index
	if player != null:
		player.select_spell_page(page_index)
	refresh_spell_settings()

func _on_raid_spell_drop(payload: Dictionary, target_context: String, target_slot: String) -> void:
	if raid == null or str(payload.get("source_context", "")) != "raid_inventory":
		return
	var item_id: String = str(payload.get("item_id", ""))
	if target_context == "raid_spell_page":
		raid.equip_raid_spell_to_page(item_id, int(target_slot))
	elif target_context == "raid_spell_attachment":
		var result: Dictionary = raid.install_raid_modifier(int(target_slot.get_slice(":", 0)), item_id)
		if not bool(result.get("success", false)):
			show_message(str(result.get("message", "Rune could not be installed.")))
	refresh_spell_settings()

func _on_raid_equipment_drop(payload: Dictionary, _target_context: String, target_slot: String) -> void:
	if raid != null and str(payload.get("source_context", "")) == "raid_inventory":
		raid.equip_raid_item_to_slot(str(payload.get("item_id", "")), target_slot)

func _remove_raid_modifier(socket_index: int) -> void:
	if raid != null and not raid.remove_raid_modifier(raid_workshop_page, socket_index):
		show_message("Field pack is full; the rune could not be removed.")

func _unequip_raid_slot(slot: String) -> void:
	if raid != null and not raid.unequip_raid_slot(slot):
		show_message("Field pack is full; the item could not be unequipped.")

func _raid_slot_categories(slot: String) -> Array[String]:
	match slot:
		"spellbook": return ["spellbook"]
		"focus": return ["focus"]
		"dagger": return ["dagger", "melee"]
		"head": return ["armor_head"]
		"chest": return ["armor_chest", "armor"]
		"accessory_1", "accessory_2": return ["accessory"]
		"backpack": return ["backpack"]
		_: return []

func show_loot(container: LootContainer) -> void:
	selected_container = container
	loot_panel.visible = true
	inventory_panel.visible = false
	spell_settings_panel.visible = false
	loot_title.text = container.container_name
	refresh_loot()

func dismiss_loot() -> void:
	selected_container = null
	loot_panel.visible = false

func refresh_loot() -> void:
	_clear(loot_rows)
	if selected_container == null or selected_container.contents.is_empty():
		var empty := Label.new()
		empty.text = "Nothing remains."
		loot_rows.add_child(empty)
		return
	for item_id: String in selected_container.contents.keys():
		var row := HBoxContainer.new()
		loot_rows.add_child(row)
		var item_slot := ITEM_SLOT_SCENE.instantiate() as ItemSlot
		row.add_child(item_slot)
		item_slot.configure(item_id, int(selected_container.contents[item_id]), "loot", item_id, false)
		var button := Button.new()
		button.text = "←"
		button.tooltip_text = "Take %s" % ItemDB.display_name(item_id)
		button.pressed.connect(_take_loot.bind(item_id))
		row.add_child(button)

func set_extraction_status(text: String) -> void:
	extraction_status.text = text

func show_message(text: String) -> void:
	message_label.text = text
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_instance_valid(message_label) and message_label.text == text:
			message_label.text = ""
	)

func _use_item(item_id: String) -> void:
	var category: String = str(ItemDB.get_item(item_id).get("category", ""))
	if category == "medical":
		GameState.remove_raid_item(item_id, 1)
		var info: Dictionary = ItemDB.get_item(item_id)
		player.restore_health(float(info.get("heal", 0.0)))
		if bool(info.get("stops_bleed", false)):
			player.bleeding = false
	elif category == "mana_consumable":
		player.use_mana_consumable(item_id)
	elif category in ["food", "drink"]:
		GameState.remove_raid_item(item_id, 1)
		player.restore_health(float(ItemDB.get_item(item_id).get("heal", 0.0)))
	refresh_inventory()

func _equip_item(item_id: String) -> void:
	if raid != null:
		raid.equip_raid_item(item_id)

func _secure_item(item_id: String) -> void:
	if not GameState.secure_item(item_id):
		show_message("Secure slot is full, too small, or rejects equipped gear.")
	refresh_inventory()

func _discard_item(item_id: String) -> void:
	GameState.remove_raid_item(item_id, 1)
	refresh_inventory()

func _take_loot(item_id: String) -> void:
	if selected_container == null:
		return
	if not selected_container.take_item(item_id):
		show_message("Field pack is full. Discard or secure something first.")
	refresh_loot()
	refresh_inventory()

func _clear(container: Container) -> void:
	for child: Node in container.get_children():
		child.queue_free()

func _items_text(items: Dictionary) -> String:
	if items.is_empty():
		return "empty"
	var parts: PackedStringArray = []
	for item_id: String in items.keys():
		parts.append("%s x%d" % [ItemDB.display_name(item_id), int(items[item_id])])
	return ", ".join(parts)
