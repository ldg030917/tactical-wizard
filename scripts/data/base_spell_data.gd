class_name BaseSpellData
extends Resource

@export_category("Spell Identity")
@export var spell_id: String = "spell"
@export var display_name: String = "Unnamed Spell"
@export_multiline var description: String = "Prepared arcane formula."
@export_enum("fire", "water", "grass", "neutral") var primary_element: String = "neutral"
@export var spell_family: String = "arcane"
@export_enum("projectile", "area", "self", "melee") var spell_form: String = "projectile"
@export_enum("projectile", "cone", "damage_zone", "slow_zone", "root_field", "puddle", "wall", "barrier", "mine", "chain", "beam", "teleport", "mana_restore", "cleanse", "shield", "knockback", "explosion") var behavior_type: String = "projectile"
var element: String:
	get: return primary_element

@export_category("Base Effect")
@export_range(0.0, 500.0, 1.0) var base_power: float = 20.0
@export_range(0.0, 200.0, 1.0) var base_mana_cost: float = 20.0
@export_range(0.0, 5.0, 0.05, "suffix:s") var base_cast_time_seconds: float = 0.35
@export_range(0.0, 20.0, 0.05, "suffix:s") var base_cooldown_seconds: float = 1.0
@export_range(0.5, 60.0, 0.5, "suffix:m") var base_range_meters: float = 14.0
@export_range(0.0, 50.0, 0.5, "suffix:m/s") var projectile_speed_meters_per_second: float = 14.0
@export_range(0.0, 12.0, 0.1, "suffix:m") var base_area_radius_meters: float = 0.8
@export_range(1, 8, 1) var base_projectile_count: int = 1
@export_enum("straight", "left_turn", "right_turn", "high_lob", "stationary") var base_trajectory: String = "straight"

@export_category("Status Effect")
@export var status_effect: String = ""
@export_range(0.0, 30.0, 0.1, "suffix:s") var effect_duration_seconds: float = 0.0
@export_range(0.0, 100.0, 1.0) var effect_power: float = 0.0
@export_range(0.0, 30.0, 0.1, "suffix:s") var field_duration_seconds: float = 0.0
@export_range(0.0, 500.0, 1.0) var secondary_power: float = 0.0

@export_category("Modifier Compatibility")
@export var compatible_modifier_categories: Array[String] = []

@export_category("Replaceable Presentation")
@export var placeholder_icon: Texture2D
@export var projectile_scene: PackedScene
@export var area_scene: PackedScene
@export var debug_color: Color = Color("8fd7ff")

func family_label() -> String:
	return "%s-derived %s" % [primary_element.capitalize(), spell_family.capitalize()] if spell_family != primary_element else primary_element.capitalize()
