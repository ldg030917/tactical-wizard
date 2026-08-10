class_name FocusData
extends Resource

@export_category("Focus Identity")
@export var focus_id: String = "focus"
@export var display_name: String = "Apprentice Wand"
@export_multiline var description: String = "A simple catalyst for prepared spells."

@export_category("Casting Bonuses")
@export_range(0.5, 2.0, 0.01) var damage_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.01) var casting_speed_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.01) var mana_efficiency_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.01) var projectile_stability_multiplier: float = 1.0
@export_range(0, 6, 1) var maximum_modifier_complexity: int = 4

@export_category("Replaceable Presentation")
@export var placeholder_visual_scene: PackedScene
@export var placeholder_icon: Texture2D
