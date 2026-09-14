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
		label.text = "룬 회수"
	elif context in ["spell_attachment", "raid_spell_attachment"]:
		label.text = "빈 룬 슬롯"
	elif context in ["spell_page", "raid_spell_page"]:
		label.text = "빈 주문식"
	else:
		label.text = "비어 있음"
	amount_label.text = "x%d" % quantity if quantity > 1 else ""
	icon.texture = UIIconFactory.item_icon(item_id, 96) if item != null else UIIconFactory.navigation_icon("inventory", 96)
	tooltip_text = build_tooltip(item)
	if item != null:
		var primary: String = _item_primary(item)
		base_style.border_color = ElementSystem.color(primary)
		element_badge.text = {"fire":"불", "water":"물", "grass":"풀", "neutral":"중"}.get(primary, "중")
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
		return "호환 아이템을 여기에 놓으세요."
	if item.base_spell != null:
		var spell := item.base_spell
		if spell.spell_id == "explosion":
			return "%s\n주 원소: 불 | 계열: 대재앙\n피해 500 | 마나 100%% | 시전 1.00초\n원정당 1회 | 부착 룬 불가\n전방의 적, 구조물, 벽, 기존 전리품을 파괴합니다." % spell.display_name
		return "%s\n주 원소: %s  •  계열: %s\n피해/위력 %.0f  •  마나 %.0f  •  시전 %.2f초\n사거리 %.1fm  •  속도 %.1fm/초  •  상태 %s" % [spell.display_name, KoreanLocalization.element(spell.primary_element), KoreanLocalization.family(spell.spell_family), spell.base_power, spell.base_mana_cost, spell.base_cast_time_seconds, spell.base_range_meters, spell.projectile_speed_meters_per_second, KoreanLocalization.status(spell.status_effect)]
	if item.spell_modifier != null:
		var modifier := item.spell_modifier
		var elements := Array(modifier.compatible_primary_elements).map(func(value: String) -> String: return KoreanLocalization.element(value))
		var families := Array(modifier.compatible_spell_families).map(func(value: String) -> String: return KoreanLocalization.family(value))
		return "%s\n%s\n원소: %s  •  계열: %s\n피해 x%.2f  •  마나 x%.2f  •  사거리 x%.2f  •  궤적 %s" % [modifier.display_name, modifier.description, ", ".join(elements) if not elements.is_empty() else "모두", ", ".join(families) if not families.is_empty() else "모두", modifier.damage_multiplier, modifier.mana_cost_multiplier, modifier.range_multiplier, KoreanLocalization.trajectory(modifier.trajectory_override)]
	if item.dagger != null:
		var dagger := item.dagger
		return "%s\n피해 %.0f  •  속도 %.2f/초  •  사거리 %.1fm\n주 원소: %s  •  계열: %s  •  효과: %s" % [dagger.display_name, dagger.damage, dagger.attack_speed, dagger.attack_range, KoreanLocalization.element(dagger.primary_element), KoreanLocalization.family(dagger.weapon_family), KoreanLocalization.status(dagger.status_effect)]
	return "%s\n%s\n%s  •  %d 크라운  •  %.2fkg" % [item.display_name, item.description, KoreanLocalization.category(item.category), item.value_crowns, item.weight_kg]

func _item_primary(item: ItemData) -> String:
	if item == null:
		return "neutral"
	if item.base_spell != null:
		return item.base_spell.primary_element
	if item.dagger != null:
		return item.dagger.primary_element
	return item.primary_element
