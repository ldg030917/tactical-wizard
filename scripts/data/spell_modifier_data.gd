class_name SpellModifierData
extends Resource

@export_category("Modifier Identity")
@export var modifier_id: String = "modifier"
@export var display_name: String = "Spell Modifier"
@export_multiline var description: String = "Changes a prepared spell."
@export_enum("damage", "range", "mana", "cast_speed", "projectile_speed", "trajectory", "area", "split", "status", "family", "utility", "duration", "collision", "targeting") var modifier_category: String = "range"
@export_enum("common", "uncommon", "rare", "epic") var rarity: String = "common"

@export_category("Compatibility")
@export var compatible_spell_forms: Array[String] = []
@export var compatible_primary_elements: Array[String] = []
@export var compatible_spell_families: Array[String] = []
@export var compatible_spell_ids: Array[String] = []
@export var incompatible_spell_ids: Array[String] = []

@export_category("Stat Multipliers")
@export_range(0.1, 3.0, 0.01) var damage_multiplier: float = 1.0
@export_range(0.1, 3.0, 0.01) var mana_cost_multiplier: float = 1.0
@export_range(0.1, 3.0, 0.01) var cast_time_multiplier: float = 1.0
@export_range(0.1, 4.0, 0.01) var range_multiplier: float = 1.0
@export_range(0.1, 4.0, 0.01) var area_multiplier: float = 1.0
@export_range(0.1, 4.0, 0.01) var projectile_speed_multiplier: float = 1.0
@export_range(0, 6, 1) var projectile_count_add: int = 0
@export_enum("unchanged", "straight", "left_turn", "right_turn", "high_lob") var trajectory_override: String = "unchanged"
@export var status_effect_override: String = ""

@export_category("Dynamic Behavior")
@export var behavior_tags: Array[String] = []
@export_range(0, 8, 1) var pierce_count: int = 0
@export_range(0, 8, 1) var ricochet_count: int = 0
@export_range(0.25, 4.0, 0.05) var duration_multiplier: float = 1.0
@export_range(0.25, 3.0, 0.05) var effect_power_multiplier: float = 1.0

@export_category("Replaceable Presentation")
@export var placeholder_icon: Texture2D
@export var debug_color: Color = Color("d9b8ff")

func is_compatible(spell: BaseSpellData) -> bool:
	if spell == null:
		return false
	if spell.spell_id in incompatible_spell_ids:
		return false
	if not compatible_spell_ids.is_empty() and spell.spell_id not in compatible_spell_ids:
		return false
	if not compatible_spell_forms.is_empty() and spell.spell_form not in compatible_spell_forms:
		return false
	if not compatible_primary_elements.is_empty() and spell.primary_element not in compatible_primary_elements:
		return false
	if not compatible_spell_families.is_empty() and spell.spell_family not in compatible_spell_families:
		return false
	return modifier_category in spell.compatible_modifier_categories or (not behavior_tags.is_empty() and (compatible_spell_forms.is_empty() or spell.spell_form in compatible_spell_forms))

func incompatibility_reason(spell: BaseSpellData) -> String:
	if spell == null:
		return "Select a base spell first."
	if is_compatible(spell):
		return ""
	if not compatible_primary_elements.is_empty() and spell.primary_element not in compatible_primary_elements:
		return "Compatible elements: %s." % ", ".join(compatible_primary_elements)
	if not compatible_spell_families.is_empty() and spell.spell_family not in compatible_spell_families:
		return "Compatible families: %s." % ", ".join(compatible_spell_families)
	return "%s cannot accept %s modifiers." % [spell.display_name, modifier_category.capitalize()]
