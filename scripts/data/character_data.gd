class_name CharacterData
extends Resource

@export_category("Specialization")
@export var character_id: String = "mana_specialist"
@export var display_name: String = "Mana Specialist"
@export_multiline var description: String = "A flexible mage specialization. It never restricts equipment or elements."

@export_category("Bonuses")
@export_range(0.5, 2.0, 0.01) var health_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.01) var mana_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.01) var stamina_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.01) var movement_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.01) var healing_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.01) var mana_regeneration_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.01) var potion_use_speed_multiplier: float = 1.0
@export_range(0.5, 2.0, 0.01) var loot_speed_multiplier: float = 1.0
@export_range(0, 12, 1) var carrying_capacity_bonus: int = 0

