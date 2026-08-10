class_name LootTableData
extends Resource

@export_category("Loot Table")
@export var table_id: String = "loot_table"
@export var display_name: String = "Loot Table"
@export var minimum_rolls: int = 1
@export var maximum_rolls: int = 3
@export var entries: Array[LootEntryData] = []

func roll(rng: RandomNumberGenerator) -> Dictionary:
	var result: Dictionary = {}
	if entries.is_empty():
		return result
	var rolls: int = rng.randi_range(minimum_rolls, maximum_rolls)
	var total_weight: float = 0.0
	for entry: LootEntryData in entries:
		if entry != null and entry.item != null:
			total_weight += entry.selection_weight
	if total_weight <= 0.0:
		return result
	for _i: int in range(rolls):
		var choice: float = rng.randf_range(0.0, total_weight)
		for entry: LootEntryData in entries:
			if entry == null or entry.item == null:
				continue
			choice -= entry.selection_weight
			if choice <= 0.0:
				var item_id: String = entry.item.item_id
				var amount: int = rng.randi_range(entry.minimum_quantity, maxi(entry.minimum_quantity, entry.maximum_quantity))
				result[item_id] = int(result.get(item_id, 0)) + amount
				break
	return result
