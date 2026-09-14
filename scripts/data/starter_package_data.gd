class_name StarterPackageData
extends Resource

@export_category("Package")
@export var package_id: String = "starter_package"
@export var display_name: String = "수습생 복구 세트"
@export_multiline var description: String = "현장 장비가 없는 마법사를 위한 보급 세트입니다."
@export_range(0, 5000, 1) var currency_cost: int = 120
@export var item_ids: Array[String] = []
@export var quantities: Array[int] = []

func contents() -> Dictionary:
	var result: Dictionary = {}
	for index: int in range(mini(item_ids.size(), quantities.size())):
		result[item_ids[index]] = maxi(1, quantities[index])
	return result
