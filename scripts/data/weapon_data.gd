class_name WeaponData
extends Resource

@export_category("Identity")
@export var item_id: String = ""
@export var display_name: String = "Weapon"
@export_enum("pistol", "automatic", "shotgun", "melee") var category: String = "pistol"
@export_multiline var description: String = "Replaceable weapon configuration."

@export_category("Ballistics")
@export_range(0.0, 200.0, 0.5) var damage: float = 20.0
@export_range(0.1, 30.0, 0.1, "suffix:shots/s") var fire_rate: float = 3.0
@export_range(0, 100, 1) var magazine_size: int = 8
@export_range(0.0, 10.0, 0.05, "suffix:s") var reload_duration: float = 1.5
@export_range(0.0, 30.0, 0.1, "suffix:degrees") var spread_degrees: float = 4.0
@export_range(0.5, 100.0, 0.5, "suffix:m") var effective_range: float = 25.0
@export_range(1, 20, 1) var projectile_count: int = 1
@export var ammo_type: String = "ammo_light"

@export_category("Economy and Attachments")
@export_range(0, 5000, 1) var base_value: int = 100
@export var attachment_slots: Array[String] = ["sight", "muzzle", "magazine", "grip"]

@export_category("Replaceable Visual")
@export var placeholder_model_scene: PackedScene
