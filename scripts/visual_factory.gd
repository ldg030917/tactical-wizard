class_name VisualFactory
extends RefCounted

const FIRE_SPELL_SHADER := preload("res://shaders/spells/fire_spell.gdshader")
const WATER_SPELL_SHADER := preload("res://shaders/spells/water_spell.gdshader")
const GRASS_SPELL_SHADER := preload("res://shaders/spells/grass_spell.gdshader")
const NEUTRAL_SPELL_SHADER := preload("res://shaders/spells/neutral_spell.gdshader")

const SPELL_PALETTES := {
	"fire":{"core":Color("f52b0a"), "accent":Color("ff6508")},
	"water":{"core":Color("1055e8"), "accent":Color("23c8ff")},
	"grass":{"core":Color("07963a"), "accent":Color("52ed63")},
	"neutral":{"core":Color("ffd45c"), "accent":Color("fffbe0")}
}

static func material(color: Color, emission_strength: float = 0.0, transparent: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.78
	if transparent or color.a < 0.999:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission_strength > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission_strength
	return mat

static func elemental_spell_material(element_or_family: String, variation_color: Color = Color.WHITE, intensity: float = 3.5, variant_seed: float = 0.0) -> ShaderMaterial:
	var primary: String = ElementSystem.normalize_primary(element_or_family)
	var palette: Dictionary = SPELL_PALETTES.get(primary, SPELL_PALETTES.neutral)
	var core: Color = palette.core
	if variation_color != Color.WHITE:
		core = core.lerp(variation_color, 0.28)
	var shader_material := ShaderMaterial.new()
	match primary:
		"fire": shader_material.shader = FIRE_SPELL_SHADER
		"water": shader_material.shader = WATER_SPELL_SHADER
		"grass": shader_material.shader = GRASS_SPELL_SHADER
		_: shader_material.shader = NEUTRAL_SPELL_SHADER
	shader_material.set_shader_parameter("spell_color", core)
	shader_material.set_shader_parameter("accent_color", palette.accent)
	shader_material.set_shader_parameter("intensity", intensity)
	shader_material.set_shader_parameter("variant_seed", variant_seed)
	return shader_material

static func spell_core_color(element_or_family: String) -> Color:
	var primary: String = ElementSystem.normalize_primary(element_or_family)
	return SPELL_PALETTES.get(primary, SPELL_PALETTES.neutral).core

static func spell_accent_color(element_or_family: String) -> Color:
	var primary: String = ElementSystem.normalize_primary(element_or_family)
	return SPELL_PALETTES.get(primary, SPELL_PALETTES.neutral).accent

static func add_box(parent: Node, size: Vector3, position: Vector3, color: Color, name: String = "Box") -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material(color)
	mesh_node.mesh = mesh
	mesh_node.position = position
	parent.add_child(mesh_node)
	return mesh_node

static func add_sphere(parent: Node, radius: float, height: float, position: Vector3, color: Color, name: String = "Sphere") -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh.material = material(color)
	mesh_node.mesh = mesh
	mesh_node.position = position
	parent.add_child(mesh_node)
	return mesh_node

static func add_cylinder(parent: Node, radius: float, height: float, position: Vector3, color: Color, name: String = "Cylinder") -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.material = material(color)
	mesh_node.mesh = mesh
	mesh_node.position = position
	parent.add_child(mesh_node)
	return mesh_node

static func add_static_box(parent: Node, size: Vector3, position: Vector3, color: Color, name: String = "Obstacle") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 0
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	var visual := Node3D.new()
	visual.name = "Visual"
	body.add_child(visual)
	add_box(visual, size, Vector3.ZERO, color)
	parent.add_child(body)
	return body

static func add_label_3d(parent: Node, text: String, position: Vector3, color: Color = Color.WHITE) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.font_size = 34
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)
	return label
