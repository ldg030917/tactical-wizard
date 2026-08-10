class_name SkillData
extends Resource

@export var skill_id: String = "health"
@export var display_name: String = "Skill"
@export_multiline var description: String = "Improves a player statistic."
@export_range(1, 10, 1) var maximum_rank: int = 3
@export_range(0.0, 100.0, 0.5) var benefit_per_rank: float = 10.0
@export_enum("flat", "percent") var benefit_mode: String = "flat"
