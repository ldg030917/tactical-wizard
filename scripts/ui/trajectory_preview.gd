class_name TrajectoryPreview
extends Control

var config: RuntimeSpellConfig
var animation_time: float = 0.0

func configure(spell_config: RuntimeSpellConfig) -> void:
	config = spell_config
	queue_redraw()

func _process(delta: float) -> void:
	animation_time += delta
	queue_redraw()

func _draw() -> void:
	draw_style_box(_panel_style(), Rect2(Vector2.ZERO, size))
	if config == null or not config.valid or config.base_spell == null:
		draw_string(ThemeDB.fallback_font, Vector2(30, size.y * 0.55), "Drop a spell formula here", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.65, 0.65, 0.72))
		return
	var element_color: Color = ElementSystem.color(config.base_spell.primary_element)
	var icon: Texture2D = UIIconFactory.spell_icon(config.base_spell, 96)
	draw_texture_rect(icon, Rect2(24, size.y * 0.5 - 48, 96, 96), false)
	var start := Vector2(142, size.y * 0.55)
	var finish := Vector2(size.x - 62, size.y * 0.55)
	match config.behavior_type:
		"cone":
			var cone := PackedVector2Array([start, finish + Vector2(0, -54), finish + Vector2(0, 54)])
			draw_colored_polygon(cone, Color(element_color, 0.23))
			draw_polyline(PackedVector2Array([finish + Vector2(0, -54), start, finish + Vector2(0, 54)]), element_color, 3.0)
		"damage_zone", "slow_zone", "root_field", "puddle", "mine":
			draw_dashed_line(start, finish, element_color, 3.0, 8.0)
			draw_circle(finish, 34.0 + sin(animation_time * 3.0) * 4.0, Color(element_color, 0.2))
			draw_arc(finish, 36.0, 0, TAU, 32, element_color, 4.0)
		"wall", "barrier":
			draw_dashed_line(start, finish, element_color, 3.0, 8.0)
			draw_rect(Rect2(finish - Vector2(8, 58), Vector2(16, 116)), Color(element_color, 0.45), true)
		"chain":
			var points := PackedVector2Array([start, start.lerp(finish, .38) + Vector2(0,-25), start.lerp(finish,.68)+Vector2(0,28), finish])
			draw_polyline(points, element_color, 5.0)
		"beam":
			draw_line(start, finish, Color.WHITE, 8.0)
			draw_line(start, finish, element_color, 4.0)
		"teleport":
			draw_dashed_line(start, finish, element_color, 4.0, 14.0)
			draw_circle(finish, 24.0, Color(element_color, 0.35))
		_:
			_draw_projectile_path(start, finish, element_color)
	for index: int in range(config.modifiers.size()):
		var socket_center := Vector2(160 + index * 38, 28)
		draw_circle(socket_center, 13.0, Color(0.22, 0.12, 0.3, 0.95))
		draw_arc(socket_center, 13.0, 0, TAU, 16, Color("bc82ff"), 2.0)

func _draw_projectile_path(start: Vector2, finish: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index: int in range(25):
		var t: float = float(index) / 24.0
		var point: Vector2 = start.lerp(finish, t)
		if config.trajectory == "high_lob":
			point.y -= sin(t * PI) * 82.0
		elif config.trajectory in ["left_turn", "right_turn"]:
			point.y += sin(t * PI) * (55.0 if config.trajectory == "left_turn" else -55.0)
		points.append(point)
	draw_polyline(points, color, 4.0, true)
	var orb_position: Vector2 = points[int(posmod(int(animation_time * 16.0), points.size()))]
	draw_circle(orb_position, 7.0, Color.WHITE)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.02, 0.045, 0.88)
	style.border_color = Color(0.3, 0.22, 0.42, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	return style
