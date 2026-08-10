extends Node

func _ready() -> void:
	GameState.reset_save_for_debug()
	var main: Node = (load("res://scenes/main/game_root.tscn") as PackedScene).instantiate()
	await get_tree().process_frame
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	for _i: int in range(12):
		await get_tree().process_frame
	_capture("res://tests/start_capture.png")
	main.start_game()
	for _i: int in range(24):
		await get_tree().process_frame
	_capture("res://tests/base_world_capture.png")
	var base_ui := main.active_area.get_node_or_null("BaseUI") as BaseUI
	if base_ui != null:
		base_ui.show_station("stash", "Persistent Stash")
		for _i: int in range(12):
			await get_tree().process_frame
		_capture("res://tests/base_capture.png")
		base_ui.show_station("spellbook", "Runesmith's Spell Workshop")
		for _i: int in range(12):
			await get_tree().process_frame
		_capture("res://tests/spellbook_capture.png")
		base_ui.show_station("workbench", "Arcane Workbench")
		for _i: int in range(12):
			await get_tree().process_frame
		_capture("res://tests/workbench_capture.png")
	main.start_raid()
	for _i: int in range(36):
		await get_tree().process_frame
	_capture("res://tests/raid_capture.png")
	var raid := main.active_area as RaidScene
	GameState.add_raid_item("magma_basin_page", 1)
	GameState.add_raid_item("mod_ricochet_rune", 1)
	raid.hud.toggle_inventory()
	for _i: int in range(12):
		await get_tree().process_frame
	_capture("res://tests/raid_inventory_capture.png")
	raid.hud._show_spell_settings()
	for _i: int in range(12):
		await get_tree().process_frame
	_capture("res://tests/raid_spell_settings_capture.png")
	raid.hud._close_access_panels()
	_stage_spell_vfx(main.active_area as RaidScene)
	for _i: int in range(18):
		await get_tree().process_frame
	_capture("res://tests/spell_vfx_capture.png")
	main.travel_to_region("water_region")
	for _i: int in range(18):
		await get_tree().process_frame
	_capture("res://tests/water_capture.png")
	main.travel_to_region("grass_region")
	for _i: int in range(18):
		await get_tree().process_frame
	_capture("res://tests/grass_capture.png")
	GameState.reset_save_for_debug()
	get_tree().quit()

func _capture(path: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(path))

func _stage_spell_vfx(raid: RaidScene) -> void:
	var samples := [
		{"item":"fireball_page", "offset":Vector3(-5.0, 1.2, -2.0), "label":"FIRE"},
		{"item":"water_bolt_page", "offset":Vector3(-1.7, 1.2, -2.0), "label":"WATER"},
		{"item":"thorn_shot_page", "offset":Vector3(1.7, 1.2, -2.0), "label":"GRASS"},
		{"item":"arcane_bolt_page", "offset":Vector3(5.0, 1.2, -2.0), "label":"NEUTRAL"}
	]
	for sample: Dictionary in samples:
		var spell: BaseSpellData = ItemDB.spell(str(sample.item))
		var config := RuntimeSpellConfig.build(spell, [], GameState.equipped_spellbook(), ItemDB.focus(str(GameState.loadout.focus)), true)
		var projectile := spell.projectile_scene.instantiate() as SpellProjectile
		raid.temporary_effects.add_child(projectile)
		projectile.global_position = raid.player.global_position + sample.offset
		projectile.configure(raid.player, config, Vector3.FORWARD, "player", projectile.global_position + Vector3(0, 0, -10))
		projectile.set_physics_process(false)
		var label := Label3D.new()
		label.text = str(sample.label)
		label.position = Vector3(0, 1.1, 0)
		label.font_size = 26
		label.outline_size = 8
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		projectile.add_child(label)
