@tool
class_name BaseStation
extends Node3D

@export_category("Station Identity")
@export var station_id: String = "stash"
@export var display_name: String = "Refuge Station"
@export_multiline var interaction_description: String = "Use"

@export_category("Progression")
@export_range(1, 3, 1) var level: int = 1
@export var linked_upgrade: BaseUpgradeData

@export_category("Replaceable Visual")
@export var replacement_visual_scene: PackedScene

@onready var station_label: Label3D = %StationLabel
@onready var level_two_module: Node3D = %LevelTwoModule
@onready var level_three_module: Node3D = %LevelThreeModule

func _ready() -> void:
	add_to_group("interactable")
	station_label.text = display_name
	level_two_module.visible = level >= 2
	level_three_module.visible = level >= 3

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() or station_label == null:
		return
	station_label.text = display_name
	level_two_module.visible = level >= 2
	level_three_module.visible = level >= 3

func get_interaction_text(_player: PlayerController) -> String:
	return "%s %s" % [interaction_description, display_name]

func interact(_player: PlayerController) -> void:
	var base: Node = _base_scene()
	if base.has_method("open_tab"):
		base.open_tab(station_id)

func _base_scene() -> Node:
	var node: Node = get_parent()
	while node != null:
		if node is BaseScene:
			return node
		node = node.get_parent()
	return get_parent()
