class_name TemporaryGrassWall
extends StaticBody3D

@export_range(1.0, 60.0, 0.5, "suffix:s") var active_duration: float = 5.0
@export_range(1.0, 30.0, 0.5, "suffix:s") var dormant_duration: float = 8.0
@export_range(1.0, 500.0, 1.0) var durability: float = 85.0
@export var managed_by_region_cycle: bool = true

var active: bool = true
var timer: float = 0.0

func _ready() -> void:
	timer = active_duration
	_set_active(true)

func _physics_process(delta: float) -> void:
	if managed_by_region_cycle:
		return
	timer -= delta
	if timer > 0.0:
		return
	active = not active
	timer = active_duration if active else dormant_duration
	_set_active(active)

func take_damage(amount: float, _source: Vector3 = Vector3.ZERO, _bleed: float = 0.0, _element: String = "neutral") -> void:
	if not active:
		return
	durability -= amount
	if durability <= 0.0:
		_set_active(false)
		timer = dormant_duration

func _set_active(value: bool) -> void:
	active = value
	$Visual.visible = value
	$CollisionShape3D.set_deferred("disabled", not value)
	$NavigationObstacle3D.avoidance_enabled = value
	$NavigationObstacle3D.affect_navigation_mesh = value
