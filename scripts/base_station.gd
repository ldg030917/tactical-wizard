@tool
class_name BaseStation
extends Node3D

@export_category("Station Identity")
@export var station_id: String = "stash"
@export var display_name: String = "피난처 시설"
@export_multiline var interaction_description: String = "사용:"

@export_category("Progression")
@export_range(1, 3, 1) var level: int = 1
@export var linked_upgrade: BaseUpgradeData

@export_category("Replaceable Visual")
@export var replacement_visual_scene: PackedScene
@export_enum("station", "storage", "loadout", "workbench", "upgrade", "training", "spellbook", "terminal") var visual_kind: String = "station"

@onready var station_label: Label3D = %StationLabel
@onready var level_two_module: Node3D = %LevelTwoModule
@onready var level_three_module: Node3D = %LevelThreeModule

func _ready() -> void:
	add_to_group("interactable")
	_build_identity_visual()
	station_label.text = display_name
	level_two_module.visible = level >= 2
	level_three_module.visible = level >= 3

func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() or station_label == null:
		return
	_build_identity_visual()
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

func _build_identity_visual() -> void:
	var placeholder := get_node_or_null("Visual/PlaceholderStation") as Node3D
	var visual := get_node_or_null("Visual") as Node3D
	if placeholder == null or visual == null or visual.get_node_or_null("IdentityVisual") != null or visual_kind == "station":
		return
	placeholder.visible = false
	var root := Node3D.new()
	root.name = "IdentityVisual"
	visual.add_child(root)
	match visual_kind:
		"storage":
			_add_box(root, Vector3(0, 0.48, 0), Vector3(2.15, 0.82, 1.35), Color("493622"))
			_add_box(root, Vector3(0, 0.98, 0.08), Vector3(2.18, 0.22, 1.4), Color("684a29"))
			_add_box(root, Vector3(0, 0.75, -0.7), Vector3(0.28, 0.9, 0.12), Color("d2a948"), 1.4)
		"loadout":
			_add_box(root, Vector3(-0.92, 0.85, 0), Vector3(0.16, 1.7, 0.5), Color("463426"))
			_add_box(root, Vector3(0.92, 0.85, 0), Vector3(0.16, 1.7, 0.5), Color("463426"))
			_add_box(root, Vector3(0, 1.55, 0), Vector3(2.0, 0.16, 0.5), Color("715534"))
			_add_box(root, Vector3(-0.48, 0.92, -0.18), Vector3(0.58, 0.75, 0.18), Color("8c7448"))
			_add_box(root, Vector3(0.48, 0.82, -0.18), Vector3(0.18, 0.95, 0.18), Color("c6a84c"), 0.8)
		"workbench":
			_add_box(root, Vector3(0, 0.82, 0), Vector3(2.3, 0.22, 1.25), Color("604326"))
			_add_box(root, Vector3(-0.92, 0.38, 0.38), Vector3(0.18, 0.8, 0.18), Color("3d2b1c"))
			_add_box(root, Vector3(0.92, 0.38, 0.38), Vector3(0.18, 0.8, 0.18), Color("3d2b1c"))
			_add_sphere(root, Vector3(-0.55, 1.12, 0), 0.25, Color("45d8e8"), 2.5)
			_add_sphere(root, Vector3(0.2, 1.08, -0.12), 0.18, Color("e05e32"), 2.2)
			_add_box(root, Vector3(0.72, 1.05, 0), Vector3(0.48, 0.08, 0.62), Color("c7aa66"), 0.7)
		"upgrade":
			_add_cylinder(root, Vector3(0, 0.34, 0), 0.95, 0.68, Color("4b5060"))
			_add_cylinder(root, Vector3(0, 0.78, 0), 0.62, 0.22, Color("b08d3f"), 1.0)
			_add_sphere(root, Vector3(0, 1.32, 0), 0.4, Color("b76cff"), 4.0)
		"training":
			_add_torus(root, Vector3(0, 0.1, 0), 1.35, Color("8b62ff"), 2.8)
			for angle: float in [0.0, 2.094, 4.188]:
				_add_cylinder(root, Vector3(cos(angle) * 1.4, 0.48, sin(angle) * 1.4), 0.14, 0.9, Color("6fe6ff"), 2.0)
		"spellbook":
			_add_box(root, Vector3(0, 0.55, 0.18), Vector3(1.15, 1.1, 0.75), Color("3e354b"))
			_add_box(root, Vector3(-0.38, 1.18, -0.12), Vector3(0.72, 0.08, 0.92), Color("c9b477"), 1.0, Vector3(22, 0, 0))
			_add_box(root, Vector3(0.38, 1.18, -0.12), Vector3(0.72, 0.08, 0.92), Color("c9b477"), 1.0, Vector3(22, 0, 0))
			_add_sphere(root, Vector3(0, 1.55, -0.12), 0.18, Color("9f63ff"), 3.0)
		"terminal":
			_add_box(root, Vector3(0, 0.65, 0.15), Vector3(1.35, 1.3, 0.9), Color("26333b"))
			_add_box(root, Vector3(0, 1.05, -0.48), Vector3(0.92, 0.58, 0.08), Color("54d7ff"), 3.0, Vector3(-12, 0, 0))
			_add_box(root, Vector3(0, 0.08, 0), Vector3(2.2, 0.16, 1.35), Color("38434a"))

func _material(color: Color, emission_energy: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.72
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_energy
	return material

func _add_box(parent: Node3D, position_value: Vector3, size_value: Vector3, color: Color, emission: float = 0.0, rotation_value: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh.material = _material(color, emission)
	var instance := MeshInstance3D.new()
	instance.position = position_value
	instance.rotation_degrees = rotation_value
	instance.mesh = mesh
	parent.add_child(instance)

func _add_sphere(parent: Node3D, position_value: Vector3, radius: float, color: Color, emission: float = 0.0) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.material = _material(color, emission)
	var instance := MeshInstance3D.new()
	instance.position = position_value
	instance.mesh = mesh
	parent.add_child(instance)

func _add_cylinder(parent: Node3D, position_value: Vector3, radius: float, height: float, color: Color, emission: float = 0.0) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.material = _material(color, emission)
	var instance := MeshInstance3D.new()
	instance.position = position_value
	instance.mesh = mesh
	parent.add_child(instance)

func _add_torus(parent: Node3D, position_value: Vector3, outer_radius: float, color: Color, emission: float = 0.0) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = outer_radius - 0.16
	mesh.outer_radius = outer_radius
	mesh.material = _material(color, emission)
	var instance := MeshInstance3D.new()
	instance.position = position_value
	instance.mesh = mesh
	parent.add_child(instance)
