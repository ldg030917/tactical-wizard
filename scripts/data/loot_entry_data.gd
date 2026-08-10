class_name LootEntryData
extends Resource

@export var item: ItemData
@export_range(0.0, 100.0, 0.1) var selection_weight: float = 1.0
@export_range(1, 99, 1) var minimum_quantity: int = 1
@export_range(1, 99, 1) var maximum_quantity: int = 1
@export_enum("any", "common", "uncommon", "rare", "epic") var minimum_raid_rarity: String = "any"
