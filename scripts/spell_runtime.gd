class_name RuntimeSpellConfig
extends RefCounted

var base_spell: BaseSpellData
var modifiers: Array[SpellModifierData] = []
var damage_or_healing: float = 0.0
var mana_cost: float = 0.0
var cast_time: float = 0.0
var cooldown: float = 0.0
var range_meters: float = 0.0
var projectile_speed: float = 0.0
var area_radius: float = 0.0
var projectile_count: int = 1
var trajectory: String = "straight"
var status_effect: String = ""
var behavior_type: String = "projectile"
var effect_duration: float = 0.0
var effect_power: float = 0.0
var secondary_power: float = 0.0
var behavior_tags: Array[String] = []
var pierce_count: int = 0
var ricochet_count: int = 0
var valid: bool = false
var warning: String = ""

static func build(spell: BaseSpellData, installed_modifiers: Array[SpellModifierData], book: SpellbookData, focus: FocusData, require_carried_spellbook: bool = false) -> RuntimeSpellConfig:
	var config := RuntimeSpellConfig.new()
	config.base_spell = spell
	if spell == null:
		config.warning = "기본 주문이 장착되지 않았습니다."
		return config
	if require_carried_spellbook and book == null:
		config.warning = "이 페이지가 든 마도서를 휴대해야 시전할 수 있습니다."
		return config
	config.damage_or_healing = spell.base_power
	config.mana_cost = spell.base_mana_cost
	config.cast_time = spell.base_cast_time_seconds
	config.cooldown = spell.base_cooldown_seconds
	config.range_meters = spell.base_range_meters
	config.projectile_speed = spell.projectile_speed_meters_per_second
	config.area_radius = spell.base_area_radius_meters
	config.projectile_count = spell.base_projectile_count
	config.trajectory = spell.base_trajectory
	config.status_effect = spell.status_effect
	config.behavior_type = spell.behavior_type
	config.effect_duration = spell.field_duration_seconds if spell.field_duration_seconds > 0.0 else spell.effect_duration_seconds
	config.effect_power = spell.effect_power
	config.secondary_power = spell.secondary_power
	for modifier: SpellModifierData in installed_modifiers:
		if modifier == null or not modifier.is_compatible(spell):
			config.warning = modifier.incompatibility_reason(spell) if modifier != null else "부착 룬 리소스가 없습니다."
			return config
		config.modifiers.append(modifier)
		config.damage_or_healing *= modifier.damage_multiplier
		config.mana_cost *= modifier.mana_cost_multiplier
		config.cast_time *= modifier.cast_time_multiplier
		config.range_meters *= modifier.range_multiplier
		config.area_radius *= modifier.area_multiplier
		config.projectile_speed *= modifier.projectile_speed_multiplier
		config.projectile_count += modifier.projectile_count_add
		if modifier.trajectory_override != "unchanged":
			config.trajectory = modifier.trajectory_override
		if not modifier.status_effect_override.is_empty():
			config.status_effect = modifier.status_effect_override
		for tag: String in modifier.behavior_tags:
			if tag not in config.behavior_tags:
				config.behavior_tags.append(tag)
		config.pierce_count += modifier.pierce_count
		config.ricochet_count += modifier.ricochet_count
		config.effect_duration *= modifier.duration_multiplier
		config.effect_power *= modifier.effect_power_multiplier
	if book != null:
		config.cast_time /= maxf(0.1, book.casting_speed_multiplier)
		config.mana_cost *= book.mana_efficiency_multiplier
	if focus != null:
		config.damage_or_healing *= focus.damage_multiplier
		config.cast_time /= maxf(0.1, focus.casting_speed_multiplier)
		config.mana_cost *= focus.mana_efficiency_multiplier
	config.damage_or_healing = snappedf(config.damage_or_healing, 0.1)
	config.mana_cost = snappedf(config.mana_cost, 0.1)
	config.cast_time = snappedf(config.cast_time, 0.01)
	config.valid = true
	return config

func behavior_description() -> String:
	if not valid or base_spell == null:
		return warning
	if base_spell.spell_id == "explosion":
		return "불 / 대재앙 | 피해 500 | 마나 100% | 시전 1.00초 | 원정당 1회 | 부착 룬 잠김"
	var localized_behaviors: Array[String] = []
	for tag: String in behavior_tags:
		localized_behaviors.append(KoreanLocalization.behavior(tag))
	var behavior_label: String = " + ".join(localized_behaviors) if not localized_behaviors.is_empty() else KoreanLocalization.behavior(behavior_type)
	return "%s / %s | 위력 %.0f | 마나 %.0f | 시전 %.2f초 | %.1fm | %s | %s | x%d" % [KoreanLocalization.element(base_spell.primary_element), KoreanLocalization.family(base_spell.spell_family), damage_or_healing, mana_cost, cast_time, range_meters, KoreanLocalization.trajectory(trajectory), behavior_label, projectile_count]
