class_name ItemSlot
extends PanelContainer

signal item_dropped(payload: Dictionary, target_context: String, target_slot: String)

@export_category("Slot Rules")
@export var slot_context: String = "inventory"
@export var slot_key: String = ""
@export var accepted_categories: Array[String] = []
@export var accepted_primary_elements: Array[String] = []
@export var accepted_families: Array[String] = []
@export var can_drag_item: bool = true

var item_id: String = ""
var quantity: int = 0
var compatible_spell: BaseSpellData
var base_style := StyleBoxFlat.new()

@onready var icon: TextureRect = %Icon
@onready var label: Label = %Label
@onready var amount_label: Label = %Amount
@onready var element_badge: Label = %ElementBadge

func _ready() -> void:
	# The card owns dragging and dropping. Its artwork and text must never consume
	# the pointer event, otherwise only the uncovered border starts a drag.
	for visual: Control in [$SlotContents, icon, label, amount_label, element_badge]:
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base_style.bg_color = Color(0.07, 0.055, 0.09, 0.95)
	base_style.border_color = Color(0.32, 0.27, 0.38, 1)
	base_style.set_border_width_all(2)
	base_style.set_corner_radius_all(7)
	add_theme_stylebox_override("panel", base_style)
	mouse_entered.connect(func() -> void:
		base_style.border_color = Color.WHITE
		base_style.set_border_width_all(4)
		icon.scale = Vector2.ONE * 1.06)
	mouse_exited.connect(func() -> void:
		base_style.set_border_width_all(2)
		base_style.border_color = ElementSystem.color(_item_primary(ItemDB.resource(item_id))) if not item_id.is_empty() else Color(0.32, 0.27, 0.38, 1)
		icon.scale = Vector2.ONE)

func configure(id: String, amount: int, context: String, key: String, draggable: bool = true) -> void:
	item_id = id
	quantity = amount
	slot_context = context
	slot_key = key
	can_drag_item = draggable
	if not is_node_ready():
		await ready
	var item := ItemDB.resource(item_id)
	if item != null:
		if item.base_spell != null:
			label.text = item.base_spell.display_name
		elif item.spell_modifier != null:
			label.text = item.spell_modifier.display_name
		else:
			label.text = item.display_name
	elif context == "attachment_storage":
		label.text = "RETURN RUNE"
	elif context in ["spell_attachment", "raid_spell_attachment"]:
		label.text = "EMPTY RUNE"
	elif context in ["spell_page", "raid_spell_page"]:
		label.text = "EMPTY FORMULA"
	else:
		label.text = ("EMPTY " + key.replace("_", " ").to_upper()).strip_edges()
	amount_label.text = "x%d" % quantity if quantity > 1 else ""
	icon.texture = UIIconFactory.item_icon(item_id, 96) if item != null else UIIconFactory.navigation_icon("inventory", 96)
	tooltip_text = build_tooltip(item)
	if item != null:
		var primary: String = _item_primary(item)
		base_style.border_color = ElementSystem.color(primary)
		element_badge.text = primary.left(1).to_upper()
		element_badge.modulate = ElementSystem.color(primary).lightened(0.25)
	else:
		element_badge.text = ""

func _get_drag_data(_at_position: Vector2) -> Variant:
	if not can_drag_item or item_id.is_empty() or quantity <= 0:
		return null
	var preview := duplicate() as Control
	preview.custom_minimum_size = Vector2(86, 86)
	set_drag_preview(preview)
	return {"kind":"item", "item_id":item_id, "amount":1, "source_context":slot_context, "source_slot":slot_key}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var compatible := _is_payload_compatible(data)
	base_style.border_color = Color("62df91") if compatible else Color("e05f67")
	base_style.set_border_width_all(4)
	return compatible

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	base_style.set_border_width_all(2)
	base_style.border_color = ElementSystem.color(_item_primary(ItemDB.resource(item_id))) if not item_id.is_empty() else Color(0.32, 0.27, 0.38, 1)
	if _is_payload_compatible(data):
		item_dropped.emit(data as Dictionary, slot_context, slot_key)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and base_style != null:
		base_style.set_border_width_all(2)
		base_style.border_color = ElementSystem.color(_item_primary(ItemDB.resource(item_id))) if not item_id.is_empty() else Color(0.32, 0.27, 0.38, 1)

func _is_payload_compatible(data: Variant) -> bool:
	if not data is Dictionary or str(data.get("kind", "")) != "item":
		return false
	var item := ItemDB.resource(str(data.get("item_id", "")))
	if item == null:
		return false
	if not accepted_categories.is_empty() and item.category not in accepted_categories:
		return false
	if not accepted_primary_elements.is_empty() and _item_primary(item) not in accepted_primary_elements:
		return false
	if not accepted_families.is_empty() and item.item_family not in accepted_families:
		return false
	if compatible_spell != null and item.spell_modifier != null and not item.spell_modifier.is_compatible(compatible_spell):
		return false
	return true

func build_tooltip(item: ItemData) -> String:
	if item == null:
		return "Drop a compatible item here."
	if item.base_spell != null:
		var spell := item.base_spell
		if spell.spell_id == "explosion":
			return "%s\nPrimary: Fire | Family: Cataclysm\nDamage 500 | Mana 100%% | Cast 1.00s\nOnce per expedition | No attachments\nDestroys forward enemies, structures, walls, and existing loot." % spell.display_name
		return "%s\nPrimary: %s  •  Family: %s\nDamage/Power %.0f  •  Mana %.0f  •  Cast %.2fs\nRange %.1fm  •  Speed %.1fm/s  •  Status %s" % [spell.display_name, spell.primary_element.capitalize(), spell.spell_family.capitalize(), spell.base_power, spell.base_mana_cost, spell.base_cast_time_seconds, spell.base_range_meters, spell.projectile_speed_meters_per_second, spell.status_effect if not spell.status_effect.is_empty() else "None"]
	if item.spell_modifier != null:
		var modifier := item.spell_modifier
		return "%s\n%s\nElements: %s  •  Families: %s\nDamage x%.2f  •  Mana x%.2f  •  Range x%.2f  •  Trajectory %s" % [modifier.display_name, modifier.description, ", ".join(modifier.compatible_primary_elements) if not modifier.compatible_primary_elements.is_empty() else "Any", ", ".join(modifier.compatible_spell_families) if not modifier.compatible_spell_families.is_empty() else "Any", modifier.damage_multiplier, modifier.mana_cost_multiplier, modifier.range_multiplier, modifier.trajectory_override.replace("_", " ")]
	if item.dagger != null:
		var dagger := item.dagger
		return "%s\nDamage %.0f  •  Speed %.2f/s  •  Range %.1fm\nPrimary: %s  •  Family: %s  •  Effect: %s" % [dagger.display_name, dagger.damage, dagger.attack_speed, dagger.attack_range, dagger.primary_element.capitalize(), dagger.weapon_family.capitalize(), dagger.status_effect if not dagger.status_effect.is_empty() else "None"]
	return "%s\n%s\n%s  •  %d crowns  •  %.2fkg" % [item.display_name, item.description, item.category.replace("_", " ").capitalize(), item.value_crowns, item.weight_kg]

func _item_primary(item: ItemData) -> String:
	if item == null:
		return "neutral"
	if item.base_spell != null:
		return item.base_spell.primary_element
	if item.dagger != null:
		return item.dagger.primary_element
	return item.primary_element
