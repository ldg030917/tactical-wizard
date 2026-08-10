class_name BaseUpgradeData
extends Resource

@export var upgrade_id: String = "storage"
@export var display_name: String = "Storage"
@export_multiline var description: String = "Improves the base."
@export_range(1, 5, 1) var maximum_level: int = 3
@export_range(0, 5000, 1) var currency_cost_per_level: int = 180
@export var material_item: ItemData
@export_range(0, 20, 1) var material_cost_per_level: int = 2
@export_range(0.0, 100.0, 1.0) var benefit_per_level: float = 20.0
