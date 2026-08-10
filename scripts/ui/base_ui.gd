class_name BaseUI
extends CanvasLayer

const ITEM_SLOT_SCENE := preload("res://scenes/ui/item_slot.tscn")

@onready var header_label: Label = %HeaderLabel
@onready var feedback_label: Label = %FeedbackLabel

var current_tab: String = "stash"
var workshop_page: int = 0
var selected_recipe_id: String = ""
var selected_upgrade_id: String = ""
var selected_skill_id: String = ""
var panels: Dictionary = {}
var navigation_buttons: Dictionary = {}

func _ready() -> void:
	panels = {
		"character":$Root/ContentArea/Panels/CharacterUI,
		"stash":$Root/ContentArea/Panels/StashUI,
		"spellbook":$Root/ContentArea/Panels/SpellbookUI,
		"workbench":$Root/ContentArea/Panels/CraftingUI,
		"upgrades":$Root/ContentArea/Panels/UpgradeUI,
		"skills":$Root/ContentArea/Panels/SkillUI,
		"quests":$Root/ContentArea/Panels/QuestUI,
		"vendor":$Root/ContentArea/Panels/VendorUI,
		"settings":$Root/ContentArea/Panels/SettingsUI
	}
	$Root/FacilityMenu.visible = false
	%FullscreenCheck.toggled.connect(func(value: bool) -> void: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED))
	%VSyncCheck.toggled.connect(func(value: bool) -> void: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED))
	$Root/ContentArea/Panels/SpellbookUI/Layout/Body/ConfigurationPanel/Configuration/PageSelector/Page1Button.pressed.connect(_select_workshop_page.bind(0))
	$Root/ContentArea/Panels/SpellbookUI/Layout/Body/ConfigurationPanel/Configuration/PageSelector/Page2Button.pressed.connect(_select_workshop_page.bind(1))
	$Root/ContentArea/Panels/SpellbookUI/Layout/Body/ConfigurationPanel/Configuration/PageSelector/Page3Button.pressed.connect(_select_workshop_page.bind(2))
	GameState.state_changed.connect(refresh)
	close_station()

func _process(_delta: float) -> void:
	header_label.text = "◆ %d     ▦ %d/%d     ✦ %d" % [GameState.currency, GameState.inventory_slots(GameState.stash), GameState.stash_capacity(), GameState.skill_points]

func open_tab(tab: String) -> void:
	if tab == "loadout":
		tab = "stash"
	if tab == "raid_prep":
		return
	if not panels.has(tab):
		return
	current_tab = tab
	feedback_label.text = ""
	for panel: Control in panels.values():
		panel.visible = false
	(panels[tab] as Control).visible = true
	for tab_id: String in navigation_buttons.keys():
		(navigation_buttons[tab_id] as Button).modulate = Color.WHITE if tab_id == tab else Color(0.62, 0.62, 0.72, 0.86)
	refresh()

func show_station(tab: String, station_name: String = "Refuge Facility") -> void:
	visible = true
	header_label.tooltip_text = station_name
	open_tab(tab)

func close_station() -> void:
	visible = false
	feedback_label.text = ""

func show_feedback(text: String) -> void:
	feedback_label.text = text
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_instance_valid(feedback_label) and feedback_label.text == text:
			feedback_label.text = ""
	)

func refresh() -> void:
	match current_tab:
		"character": _show_character()
		"stash": _show_stash()
		"spellbook": _show_spellbook()
		"workbench": _show_workbench()
		"upgrades": _show_upgrades()
		"skills": _show_skills()
		"quests": _show_quests()
		"vendor": _show_vendor()
		"settings": _show_settings()

func _show_character() -> void:
	var rows := (panels.character as Control).get_node("Layout/Scroll/Rows") as VBoxContainer
	_clear_rows(rows)
	for character_id: String in ContentRegistry.characters().keys():
		var character := ContentRegistry.characters()[character_id] as CharacterData
		var button := Button.new()
		button.text = "%s%s\n%s" % ["✓ " if GameState.selected_character_id == character_id else "", character.display_name, character.description]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 104)
		button.icon = UIIconFactory.icon(character.display_name.left(2).to_upper(), "neutral", 88, "portrait", character_id.hash())
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 84)
		button.disabled = GameState.selected_character_id == character_id
		button.pressed.connect(_select_character.bind(character_id))
		rows.add_child(button)

func _show_settings() -> void:
	var panel := panels.settings as Control
	(panel.get_node("%FullscreenCheck") as CheckButton).button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN

func _show_stash() -> void:
	var stash_panel := panels.stash as Control
	var rows := stash_panel.get_node("%ItemRows") as VBoxContainer
	var equipment_rows := stash_panel.get_node("%EquipmentRows") as VBoxContainer
	_clear_rows(rows)
	_clear_rows(equipment_rows)
	_build_integrated_equipment(equipment_rows)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	rows.add_child(grid)
	var ids: Array = GameState.stash.keys()
	ids.sort()
	for raw_id: Variant in ids:
		var item_id: String = str(raw_id)
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(96, 120)
		grid.add_child(card)
		var info: Dictionary = ItemDB.get_item(item_id)
		var item_slot := ITEM_SLOT_SCENE.instantiate() as ItemSlot
		item_slot.custom_minimum_size = Vector2(86, 86)
		card.add_child(item_slot)
		item_slot.configure(item_id, int(GameState.stash[item_id]), "stash", item_id, true)
		var actions := HBoxContainer.new()
		actions.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(actions)
		if str(info.get("category", "")) in ["spellbook", "focus", "dagger", "melee", "armor_head", "armor_chest", "armor", "accessory", "backpack", "medical", "mana_consumable"]:
			var equip := Button.new()
			equip.text = "↗"
			equip.tooltip_text = "Equip"
			equip.custom_minimum_size = Vector2(38, 26)
			equip.pressed.connect(_equip.bind(item_id))
			actions.add_child(equip)
		var sell := Button.new()
		sell.text = "¢"
		sell.tooltip_text = "Sell"
		sell.custom_minimum_size = Vector2(38, 26)
		sell.pressed.connect(_sell.bind(item_id))
		actions.add_child(sell)

func _build_integrated_equipment(rows: VBoxContainer) -> void:
	var labels := {"spellbook":"Spellbook", "focus":"Focus", "dagger":"Dagger", "head":"Head", "chest":"Body", "accessory_1":"Accessory 1", "accessory_2":"Accessory 2", "backpack":"Backpack", "consumable_1":"Quick 1", "consumable_2":"Quick 2"}
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	rows.add_child(grid)
	for slot: String in labels.keys():
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(145, 136)
		grid.add_child(card)
		var label := Label.new()
		label.text = str(labels[slot])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(label)
		var item_id: String = str(GameState.loadout.get(slot, ""))
		var target := ITEM_SLOT_SCENE.instantiate() as ItemSlot
		target.accepted_categories = _accepted_categories_for_loadout(slot)
		target.item_dropped.connect(_on_item_slot_drop)
		target.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.add_child(target)
		target.configure(item_id, 1 if not item_id.is_empty() else 0, "loadout", slot, true)
		if not item_id.is_empty():
			var remove := Button.new()
			remove.text = "×"
			remove.tooltip_text = "Return %s to storage" % ItemDB.display_name(item_id)
			remove.pressed.connect(_unequip.bind(slot))
			card.add_child(remove)

func _show_loadout() -> void:
	var rows := (panels.loadout as Control).get_node("%LoadoutRows") as VBoxContainer
	_clear_rows(rows)
	var labels := {"spellbook":"Carried Spellbook", "focus":"Magical Focus", "dagger":"Combat Slot 4 — Dagger", "head":"Head Ward", "chest":"Chest Ward", "accessory_1":"Accessory 1", "accessory_2":"Accessory 2", "backpack":"Field Pack", "consumable_1":"Quick Item 1", "consumable_2":"Quick Item 2"}
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	rows.add_child(grid)
	for slot: String in labels.keys():
		var card := VBoxContainer.new()
		card.custom_minimum_size = Vector2(150, 150)
		grid.add_child(card)
		var item_id: String = str(GameState.loadout.get(slot, ""))
		var label := Label.new()
		label.text = str(labels[slot])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		card.add_child(label)
		var target := ITEM_SLOT_SCENE.instantiate() as ItemSlot
		target.accepted_categories = _accepted_categories_for_loadout(slot)
		target.item_dropped.connect(_on_item_slot_drop)
		card.add_child(target)
		target.configure(item_id, 1 if not item_id.is_empty() else 0, "loadout", slot, true)
		if not item_id.is_empty():
			var remove := Button.new()
			remove.text = "×"
			remove.tooltip_text = "Move to inventory"
			remove.pressed.connect(_unequip.bind(slot))
			card.add_child(remove)
	var note := Label.new()
	note.text = "Carried spellbooks, customized pages, dagger, armor, focus, accessories, potions, and field loot are risked in the raid. Slots 1–3 require their physical spellbook."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(note)

func _show_spellbook() -> void:
	var panel := panels.spellbook as Control
	var book: SpellbookData = GameState.equipped_spellbook()
	(panel.get_node("%Title") as Label).text = "SPELL WORKSHOP — %s" % (book.display_name if book != null else "No Spellbook Equipped")
	var stats := panel.get_node("%ResultingStats") as Label
	var warning := panel.get_node("%CompatibilityWarning") as Label
	var rows := panel.get_node("%WorkshopRows") as VBoxContainer
	var socket_board := panel.get_node("%SocketBoard") as VBoxContainer
	_clear_rows(rows)
	_clear_rows(socket_board)
	var page_buttons: Array[Node] = [
		panel.get_node("Layout/Body/ConfigurationPanel/Configuration/PageSelector/Page1Button"),
		panel.get_node("Layout/Body/ConfigurationPanel/Configuration/PageSelector/Page2Button"),
		panel.get_node("Layout/Body/ConfigurationPanel/Configuration/PageSelector/Page3Button")
	]
	for index: int in range(page_buttons.size()):
		var page_button := page_buttons[index] as Button
		page_button.disabled = index == workshop_page
		page_button.text = str(index + 1)
		page_button.expand_icon = true
		var page_config: RuntimeSpellConfig = GameState.spell_config(index)
		if page_config != null and page_config.valid:
			page_button.icon = UIIconFactory.spell_icon(page_config.base_spell, 96)
			page_button.tooltip_text = page_config.behavior_description()
	var config: RuntimeSpellConfig = GameState.spell_config(workshop_page)
	panel.get_node("%TrajectoryPreview").configure(config)
	stats.text = "PAGE %d  •  %s\n%s" % [workshop_page + 1, config.base_spell.display_name if config.valid else "EMPTY", config.behavior_description()]
	warning.text = config.warning
	var page: Dictionary = GameState.spell_pages[workshop_page]
	var attachments_locked: bool = config.valid and config.base_spell.compatible_modifier_categories.is_empty()
	var socket_heading := Label.new()
	socket_heading.text = "FORMULA - ATTACHMENTS LOCKED" if attachments_locked else "FORMULA & ATTACHMENT SOCKETS"
	socket_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	socket_board.add_child(socket_heading)
	var socket_row := HBoxContainer.new()
	socket_row.alignment = BoxContainer.ALIGNMENT_CENTER
	socket_row.add_theme_constant_override("separation", 22)
	socket_board.add_child(socket_row)
	var storage_card := VBoxContainer.new()
	storage_card.custom_minimum_size = Vector2(112, 116)
	storage_card.visible = not attachments_locked
	socket_row.add_child(storage_card)
	var storage_label := Label.new()
	storage_label.text = "RETURN"
	storage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	storage_label.tooltip_text = "Drop an installed attachment here to return it to storage"
	storage_card.add_child(storage_label)
	var attachment_storage := ITEM_SLOT_SCENE.instantiate() as ItemSlot
	attachment_storage.accepted_categories = ["spell_modifier"]
	attachment_storage.item_dropped.connect(_on_item_slot_drop)
	storage_card.add_child(attachment_storage)
	attachment_storage.configure("", 0, "attachment_storage", "return_to_storage", false)
	attachment_storage.tooltip_text = "Attachment storage — drop a socketed rune here to unequip it"
	var formula_card := VBoxContainer.new()
	formula_card.custom_minimum_size = Vector2(112, 116)
	socket_row.add_child(formula_card)
	var formula_label := Label.new()
	formula_label.text = "FORMULA"
	formula_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	formula_card.add_child(formula_label)
	var formula_slot := ITEM_SLOT_SCENE.instantiate() as ItemSlot
	formula_slot.accepted_categories = ["spell"]
	formula_slot.item_dropped.connect(_on_item_slot_drop)
	formula_card.add_child(formula_slot)
	formula_slot.configure(str(page.get("spell_item", "")), 1, "spell_page", str(workshop_page), false)
	var modifier_capacity: int = 0 if attachments_locked else book.maximum_modifiers_per_page if book != null else 0
	var installed_modifiers: Array = page.get("modifiers", [])
	if attachments_locked:
		var locked_notice := Label.new()
		locked_notice.text = "SEALED FORMULA\nNo attachment runes can be installed."
		locked_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		locked_notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		locked_notice.custom_minimum_size = Vector2(230, 86)
		socket_row.add_child(locked_notice)
	for socket_index: int in range(modifier_capacity):
		var modifier_card := VBoxContainer.new()
		modifier_card.custom_minimum_size = Vector2(112, 116)
		socket_row.add_child(modifier_card)
		var modifier_label := Label.new()
		modifier_label.text = "RUNE %d" % (socket_index + 1)
		modifier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		modifier_card.add_child(modifier_label)
		var modifier_slot := ITEM_SLOT_SCENE.instantiate() as ItemSlot
		modifier_slot.accepted_categories = ["spell_modifier"]
		modifier_slot.compatible_spell = config.base_spell
		modifier_slot.item_dropped.connect(_on_item_slot_drop)
		modifier_card.add_child(modifier_slot)
		var installed_id: String = str(installed_modifiers[socket_index]) if socket_index < installed_modifiers.size() else ""
		modifier_slot.configure(installed_id, 1 if not installed_id.is_empty() else 0, "spell_attachment", "%d:%d" % [workshop_page, socket_index], not installed_id.is_empty())
		if not installed_id.is_empty():
			var unequip_button := Button.new()
			unequip_button.text = "×"
			unequip_button.tooltip_text = "Unequip %s" % ItemDB.display_name(installed_id)
			unequip_button.pressed.connect(_remove_modifier.bind(socket_index))
			modifier_card.add_child(unequip_button)
	var spell_heading := Label.new()
	spell_heading.text = "SPELL FORMULAS  •  drag a card into the formula socket"
	spell_heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(spell_heading)
	var spell_grid := GridContainer.new()
	spell_grid.columns = 4
	spell_grid.add_theme_constant_override("h_separation", 10)
	spell_grid.add_theme_constant_override("v_separation", 10)
	rows.add_child(spell_grid)
	for item_id: String in GameState.stash.keys():
		if ItemDB.spell(item_id) == null:
			continue
		var spell_card := VBoxContainer.new()
		spell_card.custom_minimum_size = Vector2(92, 92)
		spell_grid.add_child(spell_card)
		var spell_drag := ITEM_SLOT_SCENE.instantiate() as ItemSlot
		spell_card.add_child(spell_drag)
		spell_drag.configure(item_id, int(GameState.stash[item_id]), "stash", item_id, true)
	var mod_heading := Label.new()
	mod_heading.text = "ATTACHMENT RUNES  •  drag a compatible rune into an open socket"
	rows.add_child(mod_heading)
	var mod_grid := GridContainer.new()
	if attachments_locked:
		mod_heading.text = "ATTACHMENT RUNES LOCKED FOR EXPLOSION"
	mod_grid.visible = not attachments_locked
	mod_grid.columns = 4
	mod_grid.add_theme_constant_override("h_separation", 10)
	mod_grid.add_theme_constant_override("v_separation", 10)
	rows.add_child(mod_grid)
	for item_id: String in GameState.stash.keys():
		var modifier: SpellModifierData = ItemDB.modifier(item_id)
		if modifier == null:
			continue
		var modifier_card := VBoxContainer.new()
		modifier_card.custom_minimum_size = Vector2(92, 92)
		mod_grid.add_child(modifier_card)
		var modifier_drag := ITEM_SLOT_SCENE.instantiate() as ItemSlot
		modifier_card.add_child(modifier_drag)
		modifier_drag.configure(item_id, int(GameState.stash[item_id]), "stash", item_id, true)

func _show_workbench() -> void:
	var panel := panels.workbench as Control
	(panel.get_node("%Title") as Label).text = "ARCANE WORKBENCH — Level %d" % int(GameState.base_upgrades.workbench)
	var rows := panel.get_node("%RecipeRows") as VBoxContainer
	var detail := panel.get_node("%RecipeDetail") as VBoxContainer
	_clear_rows(rows)
	_clear_rows(detail)
	var available_ids: Array[String] = []
	for recipe_id: String in ContentRegistry.recipes().keys():
		var recipe := ContentRegistry.recipes()[recipe_id] as CraftingRecipeData
		if recipe.output_item == null or recipe.output_item.category in ["ammo", "weapon", "attachment"]:
			continue
		available_ids.append(recipe_id)
		var button := Button.new()
		button.text = "%s\n%s" % [recipe.display_name, recipe.description]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 72)
		button.icon = UIIconFactory.item_icon(recipe.output_item.item_id, 64)
		button.add_theme_constant_override("icon_max_width", 60)
		button.tooltip_text = recipe.description
		button.button_pressed = recipe_id == selected_recipe_id
		button.pressed.connect(_select_recipe.bind(recipe_id))
		rows.add_child(button)
	if selected_recipe_id not in available_ids and not available_ids.is_empty():
		selected_recipe_id = available_ids[0]
	var selected := ContentRegistry.recipes().get(selected_recipe_id) as CraftingRecipeData
	if selected == null:
		return
	_add_detail_title(detail, selected.display_name, selected.description)
	var output_row := HBoxContainer.new()
	detail.add_child(output_row)
	var output_slot := ITEM_SLOT_SCENE.instantiate() as ItemSlot
	output_row.add_child(output_slot)
	output_slot.configure(selected.output_item.item_id, selected.output_quantity, "preview", "output", false)
	var output_text := Label.new()
	output_text.text = "OUTPUT\n%s x%d\nRequires Workbench level %d" % [selected.output_item.display_name, selected.output_quantity, selected.required_workbench_level]
	output_row.add_child(output_text)
	var materials_title := Label.new()
	materials_title.text = "REQUIRED MATERIALS"
	detail.add_child(materials_title)
	var can_craft: bool = int(GameState.base_upgrades.workbench) >= selected.required_workbench_level and GameState.currency >= selected.currency_cost
	for ingredient: CraftIngredientData in selected.ingredients:
		if ingredient == null or ingredient.item == null:
			continue
		var material_row := HBoxContainer.new()
		detail.add_child(material_row)
		var material_slot := ITEM_SLOT_SCENE.instantiate() as ItemSlot
		material_row.add_child(material_slot)
		material_slot.configure(ingredient.item.item_id, ingredient.quantity, "preview", "material", false)
		var owned: int = int(GameState.stash.get(ingredient.item.item_id, 0))
		var material_count := Label.new()
		material_count.text = "%s\nOwned %d / Need %d" % [ingredient.item.display_name, owned, ingredient.quantity]
		material_count.modulate = Color.WHITE if owned >= ingredient.quantity else Color("ef6b67")
		material_row.add_child(material_count)
		can_craft = can_craft and owned >= ingredient.quantity
	var currency_label := Label.new()
	currency_label.text = "◆ Crowns: %d / %d" % [GameState.currency, selected.currency_cost]
	currency_label.modulate = Color.WHITE if GameState.currency >= selected.currency_cost else Color("ef6b67")
	detail.add_child(currency_label)
	var craft_button := Button.new()
	craft_button.text = "CRAFT"
	craft_button.disabled = not can_craft
	craft_button.pressed.connect(_craft.bind(selected_recipe_id))
	detail.add_child(craft_button)

func _show_upgrades() -> void:
	var panel := panels.upgrades as Control
	var rows := panel.get_node("%UpgradeRows") as VBoxContainer
	var detail := panel.get_node("%UpgradeDetail") as VBoxContainer
	_clear_rows(rows)
	_clear_rows(detail)
	var ids: Array[String] = []
	for upgrade_id: String in ContentRegistry.upgrades().keys():
		var upgrade := ContentRegistry.upgrades()[upgrade_id] as BaseUpgradeData
		ids.append(upgrade_id)
		var level: int = int(GameState.base_upgrades.get(upgrade_id, 1))
		var button := Button.new()
		button.text = "%s\nLevel %d / %d" % [upgrade.display_name, level, upgrade.maximum_level]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 70)
		button.icon = UIIconFactory.navigation_icon("upgrades", 64)
		button.add_theme_constant_override("icon_max_width", 60)
		button.pressed.connect(_select_upgrade.bind(upgrade_id))
		rows.add_child(button)
	if selected_upgrade_id not in ids and not ids.is_empty():
		selected_upgrade_id = ids[0]
	var selected := ContentRegistry.upgrades().get(selected_upgrade_id) as BaseUpgradeData
	if selected == null:
		return
	var level: int = int(GameState.base_upgrades.get(selected_upgrade_id, 1))
	_add_detail_title(detail, selected.display_name, selected.description)
	var progress := Label.new()
	progress.text = "CURRENT LEVEL %d / %d\nNext benefit: +%g" % [level, selected.maximum_level, selected.benefit_per_level]
	detail.add_child(progress)
	var material_id: String = selected.material_item.item_id if selected.material_item != null else "arcane_dust"
	var material_cost: int = selected.material_cost_per_level * level
	var material_row := HBoxContainer.new()
	detail.add_child(material_row)
	var material_slot := ITEM_SLOT_SCENE.instantiate() as ItemSlot
	material_row.add_child(material_slot)
	material_slot.configure(material_id, material_cost, "preview", "upgrade_material", false)
	var owned: int = int(GameState.stash.get(material_id, 0))
	var material_text := Label.new()
	material_text.text = "%s\nOwned %d / Need %d" % [ItemDB.display_name(material_id), owned, material_cost]
	material_text.modulate = Color.WHITE if owned >= material_cost else Color("ef6b67")
	material_row.add_child(material_text)
	var cost: int = selected.currency_cost_per_level * level
	var cost_label := Label.new()
	cost_label.text = "◆ Crowns: %d / %d" % [GameState.currency, cost]
	cost_label.modulate = Color.WHITE if GameState.currency >= cost else Color("ef6b67")
	detail.add_child(cost_label)
	var upgrade_button := Button.new()
	upgrade_button.text = "UPGRADE"
	upgrade_button.disabled = level >= selected.maximum_level or owned < material_cost or GameState.currency < cost
	upgrade_button.pressed.connect(_upgrade.bind(selected_upgrade_id))
	detail.add_child(upgrade_button)

func _show_skills() -> void:
	var panel := panels.skills as Control
	(panel.get_node("%Title") as Label).text = "ARCANE TRAINING — %d insight" % GameState.skill_points
	var rows := panel.get_node("%SkillRows") as VBoxContainer
	var detail := panel.get_node("%SkillDetail") as VBoxContainer
	_clear_rows(rows)
	_clear_rows(detail)
	var ids: Array[String] = []
	for skill_id: String in ContentRegistry.skills().keys():
		var info := ContentRegistry.skills()[skill_id] as SkillData
		ids.append(skill_id)
		var rank: int = int(GameState.skills[skill_id])
		var button := Button.new()
		button.text = "%s\nRank %d / %d" % [info.display_name, rank, info.maximum_rank]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 70)
		button.icon = UIIconFactory.navigation_icon("skills", 64)
		button.add_theme_constant_override("icon_max_width", 60)
		button.pressed.connect(_select_skill.bind(skill_id))
		rows.add_child(button)
	if selected_skill_id not in ids and not ids.is_empty():
		selected_skill_id = ids[0]
	var selected := ContentRegistry.skills().get(selected_skill_id) as SkillData
	if selected == null:
		return
	var rank: int = int(GameState.skills.get(selected_skill_id, 0))
	_add_detail_title(detail, selected.display_name, selected.description)
	var benefit := Label.new()
	benefit.text = "CURRENT RANK %d / %d\nBenefit per rank: %g%s" % [rank, selected.maximum_rank, selected.benefit_per_rank, "%%" if selected.benefit_mode == "percent" else ""]
	benefit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(benefit)
	var insight_icon := TextureRect.new()
	insight_icon.custom_minimum_size = Vector2(96, 96)
	insight_icon.texture = UIIconFactory.navigation_icon("skills", 96)
	insight_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	insight_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail.add_child(insight_icon)
	var insight := Label.new()
	insight.text = "✦ Insight available: %d\nCost: 1" % GameState.skill_points
	insight.modulate = Color.WHITE if GameState.skill_points > 0 else Color("ef6b67")
	detail.add_child(insight)
	var train_button := Button.new()
	train_button.text = "TRAIN"
	train_button.disabled = rank >= selected.maximum_rank or GameState.skill_points <= 0
	train_button.pressed.connect(_skill.bind(selected_skill_id))
	detail.add_child(train_button)

func _add_detail_title(container: VBoxContainer, title_text: String, description_text: String) -> void:
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 24)
	container.add_child(title)
	var description := Label.new()
	description.text = description_text
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(description)
	container.add_child(HSeparator.new())

func _select_recipe(recipe_id: String) -> void:
	selected_recipe_id = recipe_id
	_show_workbench()

func _select_upgrade(upgrade_id: String) -> void:
	selected_upgrade_id = upgrade_id
	_show_upgrades()

func _select_skill(skill_id: String) -> void:
	selected_skill_id = skill_id
	_show_skills()

func _show_quests() -> void:
	var rows := (panels.quests as Control).get_node("%QuestRows") as VBoxContainer
	_clear_rows(rows)
	for quest: Dictionary in GameState.quests:
		var panel := PanelContainer.new()
		rows.add_child(panel)
		var box := VBoxContainer.new()
		panel.add_child(box)
		var title := Label.new()
		title.text = "%s [%s]" % [str(quest.name), str(quest.state).to_upper()]
		title.add_theme_font_size_override("font_size", 19)
		box.add_child(title)
		var description := Label.new()
		description.text = "%s\nProgress %d/%d — Reward %d crowns + %s" % [str(quest.description), int(quest.progress), int(quest.needed), int(quest.reward_currency), ItemDB.display_name(str(quest.reward_item))]
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(description)
		if str(quest.state) == "available":
			var accept := Button.new()
			accept.text = "Accept Expedition"
			accept.pressed.connect(_accept_quest.bind(str(quest.id)))
			box.add_child(accept)
		elif str(quest.state) == "complete":
			var claim := Button.new()
			claim.text = "Claim Reward"
			claim.pressed.connect(_claim_quest.bind(str(quest.id)))
			box.add_child(claim)

func _show_vendor() -> void:
	var rows := (panels.vendor as Control).get_node("%ItemRows") as VBoxContainer
	_clear_rows(rows)
	var package := ContentRegistry.starter_packages().get("neutral_recovery") as StarterPackageData
	var package_button := Button.new()
	package_button.text = "Purchase %s — %d crowns" % [package.display_name, package.currency_cost]
	package_button.tooltip_text = package.description
	package_button.pressed.connect(_buy_package)
	rows.add_child(package_button)
	for package_id: String in ["fire_recovery", "water_recovery", "grass_recovery"]:
		var elemental_package := ContentRegistry.starter_packages().get(package_id) as StarterPackageData
		if elemental_package == null:
			continue
		var elemental_button := Button.new()
		elemental_button.text = "Purchase %s — %d crowns" % [elemental_package.display_name, elemental_package.currency_cost]
		elemental_button.tooltip_text = elemental_package.description
		elemental_button.pressed.connect(_buy_named_package.bind(package_id))
		rows.add_child(elemental_button)
	rows.add_child(HSeparator.new())
	var goods: Array[Dictionary] = [
		{"id":"health_potion", "price":72}, {"id":"mana_potion", "price":80},
		{"id":"apprentice_grimoire", "price":190}, {"id":"apprentice_wand", "price":150},
		{"id":"novice_hood", "price":175}, {"id":"small_pack", "price":170}, {"id":"arcane_dust", "price":28}
	]
	for good: Dictionary in goods:
		var button := Button.new()
		button.text = "Buy %s — %d crowns" % [ItemDB.display_name(str(good.id)), int(good.price)]
		button.pressed.connect(_buy.bind(str(good.id), int(good.price)))
		rows.add_child(button)

func _select_workshop_page(index: int) -> void:
	workshop_page = index
	_show_spellbook()
func _install_spell(item_id: String) -> void:
	_feedback(GameState.install_page_spell(workshop_page, item_id), "Base spell installed and page saved.", "Spell page is unavailable.")
func _install_modifier(item_id: String) -> void:
	var result: Dictionary = GameState.install_page_modifier(workshop_page, item_id)
	_feedback(bool(result.success), str(result.message), str(result.message))
func _remove_modifier(index: int) -> void:
	_feedback(GameState.remove_page_modifier(workshop_page, index), "Modifier returned to stash.", "Modifier could not be removed.")
func _equip(item_id: String) -> void:
	_feedback(GameState.equip_from_stash(item_id), "Equipped %s." % ItemDB.display_name(item_id), "No compatible loadout slot.")
func _unequip(slot: String) -> void:
	_feedback(GameState.unequip(slot), "Moved gear to stash.", "Slot is already empty.")
func _sell(item_id: String) -> void:
	_feedback(GameState.sell_item(item_id), "Sold %s." % ItemDB.display_name(item_id), "Item unavailable.")
func _craft(recipe_id: String) -> void:
	_feedback(GameState.craft(recipe_id), "Arcane crafting complete.", "Missing materials, crowns, or workbench level.")
func _upgrade(upgrade_id: String) -> void:
	_feedback(GameState.purchase_base_upgrade(upgrade_id), "%s upgraded." % upgrade_id.capitalize(), "Need more crowns and materials, or already maxed.")
func _skill(skill_id: String) -> void:
	_feedback(GameState.purchase_skill(skill_id), "Training applied.", "No insight or skill is maxed.")
func _accept_quest(quest_id: String) -> void:
	GameState.accept_quest(quest_id)
	feedback_label.text = "Expedition accepted."
func _claim_quest(quest_id: String) -> void:
	_feedback(GameState.claim_quest(quest_id), "Expedition reward claimed.", "Objective is not complete.")
func _buy(item_id: String, price: int) -> void:
	_feedback(GameState.buy_item(item_id, price), "Purchased %s." % ItemDB.display_name(item_id), "Not enough crowns or stash space.")
func _buy_package() -> void:
	_feedback(GameState.purchase_starter_package(), "Recovery package delivered to the stash.", "Not enough crowns.")

func _buy_named_package(package_id: String) -> void:
	_feedback(GameState.purchase_starter_package(package_id), "Recovery package delivered to the stash.", "Not enough crowns.")

func _select_character(character_id: String) -> void:
	_feedback(GameState.select_character(character_id), "Specialization selected.", "Character specialization unavailable.")

func _feedback(success: bool, good: String, bad: String) -> void:
	feedback_label.text = good if success else bad
	refresh()

func _clear_rows(rows: VBoxContainer) -> void:
	for child: Node in rows.get_children():
		child.queue_free()

func _ingredients_text(ingredients: Array[CraftIngredientData]) -> String:
	var parts: PackedStringArray = []
	for ingredient: CraftIngredientData in ingredients:
		parts.append("%s x%d" % [ingredient.item.display_name, ingredient.quantity])
	return ", ".join(parts)

func _modifier_list(modifiers: Array) -> String:
	if modifiers.is_empty():
		return "none"
	var parts: PackedStringArray = []
	for modifier_item_id: Variant in modifiers:
		parts.append(ItemDB.display_name(str(modifier_item_id)))
	return ", ".join(parts)

func _accepted_categories_for_loadout(slot: String) -> Array[String]:
	match slot:
		"spellbook": return ["spellbook"]
		"focus": return ["focus"]
		"dagger": return ["dagger", "melee"]
		"head": return ["armor_head"]
		"chest": return ["armor_chest", "armor"]
		"accessory_1", "accessory_2": return ["accessory"]
		"backpack": return ["backpack"]
		"consumable_1", "consumable_2": return ["medical", "mana_consumable", "food", "drink"]
		_: return []

func _on_item_slot_drop(payload: Dictionary, target_context: String, target_slot: String) -> void:
	var item_id: String = str(payload.get("item_id", ""))
	var success: bool = false
	if target_context == "loadout" and str(payload.get("source_context", "")) == "stash":
		success = GameState.equip_from_stash_to_slot(item_id, target_slot)
	elif target_context == "spell_page" and str(payload.get("source_context", "")) == "stash":
		success = GameState.install_page_spell(int(target_slot), item_id)
	elif target_context == "spell_attachment" and str(payload.get("source_context", "")) == "stash":
		var result: Dictionary = GameState.install_page_modifier(int(target_slot.get_slice(":", 0)), item_id)
		success = bool(result.get("success", false))
	elif target_context == "attachment_storage" and str(payload.get("source_context", "")) == "spell_attachment":
		var source_slot: String = str(payload.get("source_slot", ""))
		success = GameState.remove_page_modifier(int(source_slot.get_slice(":", 0)), int(source_slot.get_slice(":", 1)))
	_feedback(success, "Item placed in compatible slot.", "That slot rejects this item.")
