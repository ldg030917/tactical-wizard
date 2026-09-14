extends Node3D

@onready var rune_arch: MeshInstance3D = $RuneArch
@onready var portal_surface: MeshInstance3D = $PortalSurface
@onready var portal_light: OmniLight3D = $PortalLight

var elapsed := 0.0

func _process(delta: float) -> void:
	elapsed += delta
	rune_arch.rotate_z(delta * 0.38)
	portal_surface.rotate_z(-delta * 0.2)
	var pulse := (sin(elapsed * 2.4) + 1.0) * 0.5
	portal_surface.scale = Vector3.ONE * lerpf(0.94, 1.04, pulse) * Vector3(1.0, 1.0, 0.09)
	portal_light.light_energy = lerpf(4.0, 6.2, pulse)
