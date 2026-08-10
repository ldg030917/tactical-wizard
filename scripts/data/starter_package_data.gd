class_name StarterPackageData
extends Resource

@export_category("Package")
@export var package_id: String = "starter_package"
@export var display_name: String = "Apprentice Recovery Kit"
@export_multiline var description: String = "A fallback kit for a mage with no field equipment."
@export_range(0, 5000, 1) var currency_cost: int = 120
@export var item_ids: Array[String] = []
@export var quantities: Array[int] = []

func contents() -> Dictionary:
	var result: Dictionary = {}
	for index: int in range(mini(item_ids.size(), quantities.size())):
		result[item_ids[index]] = maxi(1, quantities[index])
	return result
