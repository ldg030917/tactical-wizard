class_name StartScreen
extends CanvasLayer

signal start_requested

@onready var menu_panel: Control = %MenuPanel
@onready var settings_panel: Control = %SettingsPanel

func _ready() -> void:
	%StartButton.icon = UIIconFactory.navigation_icon("start", 96)
	%StartButton.tooltip_text = "Start Game"
	%SettingsButton.icon = UIIconFactory.navigation_icon("settings", 96)
	%SettingsButton.tooltip_text = "Settings"
	%QuitButton.icon = UIIconFactory.navigation_icon("exit", 96)
	%QuitButton.tooltip_text = "Quit Game"
	for button: Button in [%StartButton, %SettingsButton, %QuitButton]:
		button.expand_icon = true
	%StartButton.pressed.connect(func() -> void: start_requested.emit())
	%SettingsButton.pressed.connect(_show_settings)
	%QuitButton.pressed.connect(func() -> void: get_tree().quit())
	%SettingsBackButton.pressed.connect(_hide_settings)
	%FullscreenCheck.toggled.connect(func(value: bool) -> void:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED))
	%VSyncCheck.toggled.connect(func(value: bool) -> void:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED))
	_hide_settings()

func _show_settings() -> void:
	menu_panel.visible = false
	settings_panel.visible = true

func _hide_settings() -> void:
	menu_panel.visible = true
	settings_panel.visible = false
