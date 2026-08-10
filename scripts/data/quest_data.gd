class_name QuestData
extends Resource

@export_category("Identity")
@export var quest_id: String = "quest"
@export var display_title: String = "Contract"
@export_multiline var description: String = "Complete the objective."
@export var quest_npc_id: String = "mara_quill"
@export_range(0, 100, 1) var sort_order: int = 0

@export_category("Objective")
@export_enum("item", "kill", "extract", "visit") var objective_type: String = "item"
@export var target_id: String = ""
@export_range(1, 100, 1) var required_amount: int = 1
@export var prerequisite_quest_id: String = ""

@export_category("Rewards")
@export_range(0, 10000, 1) var reward_currency: int = 100
@export var reward_item: ItemData
@export_range(0, 10, 1) var reward_skill_points: int = 1

func to_runtime_dictionary(is_first: bool) -> Dictionary:
	return {
		"id":quest_id, "name":display_title, "description":description,
		"type":objective_type, "target":target_id, "needed":required_amount,
		"progress":0, "state":"available" if is_first or prerequisite_quest_id.is_empty() else "locked",
		"reward_currency":reward_currency,
		"reward_item":reward_item.item_id if reward_item != null else "",
		"reward_skill_points":reward_skill_points, "prerequisite":prerequisite_quest_id,
		"npc":quest_npc_id
	}
