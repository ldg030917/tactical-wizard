class_name ArmorData
extends Resource

@export_category("Armor")
@export var armor_id: String = "armor"
@export var display_name: String = "Ward Armor"
@export_enum("head", "chest") var armor_slot: String = "chest"
@export_range(0.0, 200.0, 1.0) var defense: float = 0.0
@export_range(0.0, 0.65, 0.01) var fire_resistance: float = 0.0
@export_range(0.0, 0.65, 0.01) var water_resistance: float = 0.0
@export_range(0.0, 0.65, 0.01) var grass_resistance: float = 0.0
@export_range(0.0, 0.65, 0.01) var neutral_resistance: float = 0.0
@export_range(0.0, 1.0, 0.01) var injury_reduction: float = 0.0
@export_range(0.0, 0.8, 0.01) var movement_penalty: float = 0.0
@export_range(1.0, 1000.0, 1.0) var durability: float = 100.0

