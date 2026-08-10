class_name HealingCircle
extends Area3D

@export_category("Healing Zone")
@export_range(1.0, 30.0, 0.5, "suffix:s") var default_duration_seconds: float = 8.0
@export_range(0.1, 5.0, 0.1, "suffix:s") var healing_tick_seconds: float = 0.8

@onready var visual: Node3D = %Visual
@onready var boundary: MeshInstance3D = %Boundary
@onready var rune_north: MeshInstance3D = %RuneNorth
@onready var rune_south: MeshInstance3D = %RuneSouth

var owner_player: PlayerController
var spell_config: RuntimeSpellConfig
var duration_remaining: float = 8.0
var tick_remaining: float = 0.0

func configure(player: PlayerController, config: RuntimeSpellConfig) -> void:
	owner_player = player
	spell_config = config
	duration_remaining = config.base_spell.effect_duration_seconds if config != null else default_duration_seconds
	if is_node_ready():
		_apply_size()

func _ready() -> void:
	_apply_size()

func _process(delta: float) -> void:
	if spell_config == null:
		return
	duration_remaining -= delta
	tick_remaining -= delta
	visual.rotation.y += delta * 0.9
	var pulse: float = 1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.06
	rune_north.rotation.y += delta * 2.4
	rune_south.rotation.y -= delta * 2.4
	rune_north.scale.y = 0.08 * pulse
	rune_south.scale.y = 0.08 * pulse
	if tick_remaining <= 0.0:
		tick_remaining = healing_tick_seconds
		if owner_player != null and global_position.distance_to(owner_player.global_position) <= spell_config.area_radius:
			owner_player.restore_health(spell_config.damage_or_healing * healing_tick_seconds / maxf(1.0, spell_config.base_spell.effect_duration_seconds))
	if duration_remaining <= 0.0:
		queue_free()

func _apply_size() -> void:
	if spell_config == null or boundary == null:
		return
	var diameter: float = spell_config.area_radius * 2.0
	boundary.scale = Vector3(diameter, 0.05, diameter)
	var seed: float = float(posmod(spell_config.base_spell.spell_id.hash(), 1000)) / 67.0
	boundary.material_override = VisualFactory.elemental_spell_material(spell_config.base_spell.primary_element, spell_config.base_spell.debug_color, 2.5, seed)
	rune_north.material_override = VisualFactory.elemental_spell_material(spell_config.base_spell.primary_element, spell_config.base_spell.debug_color, 4.0, seed + 2.0)
	rune_south.material_override = VisualFactory.elemental_spell_material(spell_config.base_spell.primary_element, spell_config.base_spell.debug_color, 4.0, seed + 4.0)
