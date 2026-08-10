class_name EnemyData
extends Resource

@export_category("Identity")
@export var enemy_id: String = "monster"
@export var display_name: String = "Arcane Creature"
@export_enum("monster", "mage", "construct", "boss", "scavenger", "creature", "guard") var behavior_type: String = "monster"
@export_enum("fire", "water", "grass", "neutral") var primary_element: String = "neutral"
@export_range(1, 5, 1) var difficulty_tier: int = 1

@export_category("Health and Movement")
@export_range(1.0, 500.0, 1.0) var maximum_health: float = 55.0
@export_range(0.1, 15.0, 0.1, "suffix:m/s") var movement_speed: float = 2.6

@export_category("Perception")
@export_range(1.0, 50.0, 0.5, "suffix:m") var detection_range_meters: float = 12.0
@export_range(1.0, 60.0, 0.5, "suffix:m") var hearing_range_meters: float = 16.0
@export_range(0.5, 30.0, 0.5, "suffix:m") var attack_range_meters: float = 9.0

@export_category("Combat and Rewards")
@export_range(1.0, 100.0, 1.0) var attack_damage: float = 9.0
@export_range(0.1, 5.0, 0.05, "suffix:s") var attack_interval_seconds: float = 1.2
@export var weapon: WeaponData
@export var prepared_spell: BaseSpellData
@export var loot_table: LootTableData
@export_range(0.0, 1.0, 0.01) var fire_resistance: float = 0.0
@export_range(0.0, 1.0, 0.01) var ice_resistance: float = 0.0
@export_range(0.0, 0.65, 0.01) var elemental_resistance: float = 0.0

@export_category("Replaceable Visual")
@export var visual_scene: PackedScene
@export var debug_color: Color = Color("a36f4f")
