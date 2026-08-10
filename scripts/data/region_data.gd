class_name RegionData
extends Resource

@export_category("Region Identity")
@export var region_id: String = "neutral_frontier"
@export var display_name: String = "Neutral Frontier"
@export_multiline var description: String = "A basic expedition region."
@export_enum("fire", "water", "grass", "neutral") var primary_element: String = "neutral"
@export var scene: PackedScene

@export_category("Entry and Progression")
@export_range(0, 5000, 1) var entry_cost: int = 0
@export var required_ticket_id: String = ""
@export_range(1, 5, 1) var difficulty_tier: int = 1

@export_category("Regional Content")
@export var loot_table: LootTableData
@export var enemy_pool: Array[EnemyData] = []
@export_enum("none", "burn_zones", "water_slow", "temporary_grass_walls") var hazard_type: String = "none"
@export_range(0.0, 100.0, 0.5) var hazard_power: float = 0.0
@export var visual_color: Color = Color("e7d89c")

