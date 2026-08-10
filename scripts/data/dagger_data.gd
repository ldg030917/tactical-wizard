class_name DaggerData
extends Resource

@export_category("Identity")
@export var dagger_id: String = "dagger"
@export var display_name: String = "Field Dagger"
@export_enum("fire", "water", "grass", "neutral") var primary_element: String = "neutral"
@export var weapon_family: String = "dagger"

@export_category("Melee Combat")
@export_range(1.0, 200.0, 1.0) var damage: float = 24.0
@export_range(0.1, 5.0, 0.05, "suffix:attacks/s") var attack_speed: float = 1.4
@export_range(0.5, 5.0, 0.1, "suffix:m") var attack_range: float = 2.1
@export_range(0.0, 100.0, 1.0) var stamina_cost: float = 18.0
@export_range(1.0, 180.0, 1.0, "suffix:degrees") var attack_arc_degrees: float = 95.0
@export var status_effect: String = ""
@export_range(0, 3, 1) var attachment_slots: int = 0

@export_category("Replaceable Presentation")
@export var placeholder_icon: Texture2D
@export var placeholder_visual: PackedScene
@export var debug_color: Color = Color("f3df9b")

