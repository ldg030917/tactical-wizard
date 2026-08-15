class_name ElementalHazardZone
extends Area3D

@export_enum("fire", "water") var hazard_element: String = "fire"
@export_range(0.0, 50.0, 0.5) var power_per_second: float = 7.0
@export_range(0.1, 1.0, 0.05) var water_slow_multiplier: float = 0.5
@export_range(1.0, 20.0, 0.5, "suffix:m") var radius: float = 3.0

var affected_players: Array[PlayerController] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	var shape := $CollisionShape3D.shape as CylinderShape3D
	shape.radius = radius
	$Visual.scale = Vector3(radius, 0.05, radius)
	$Visual.material_override = VisualFactory.material(ElementSystem.color(hazard_element), 1.4, true)

func _physics_process(delta: float) -> void:
	# In a network raid, hazard authority belongs to the dedicated server. Client
	# copies are visual only and must never apply a second local damage path.
	if NetworkManager.is_network_game() and not multiplayer.is_server():
		return
	for player: PlayerController in affected_players:
		if not is_instance_valid(player) or player.dead:
			continue
		if hazard_element == "fire":
			var source_label := "hazard:%s:%s" % [hazard_element, get_path()]
			player.take_damage(power_per_second * delta, global_position, 0.0, "fire", source_label)
			player.apply_status("burn", 0.4, power_per_second * 0.35, source_label)
		else:
			player.apply_status("slow", 0.35, 1.0 - water_slow_multiplier)

func _on_body_entered(body: Node3D) -> void:
	if body is PlayerController and body not in affected_players:
		affected_players.append(body)

func _on_body_exited(body: Node3D) -> void:
	if body is PlayerController:
		affected_players.erase(body)
