extends Control

const AppState = preload("res://scripts/app_state.gd")

var _built: bool = false
var _app_state = AppState.new()
var _status_label: Label = null


func _ready() -> void:
	build()


func build() -> void:
	if _built:
		return
	_built = true

	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.015, 0.018, 0.026, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 64.0
	content.offset_top = 56.0
	content.offset_right = -64.0
	content.offset_bottom = -56.0
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 20)
	add_child(content)

	var title := Label.new()
	title.name = "Title"
	title.text = "Open2Jam VOS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "Godot runtime preview"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	content.add_child(subtitle)

	var menu := HBoxContainer.new()
	menu.name = "Menu"
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	menu.add_theme_constant_override("separation", 16)
	content.add_child(menu)

	var start_button := Button.new()
	start_button.name = "StartButton"
	start_button.text = "Start"
	start_button.custom_minimum_size = Vector2(160.0, 48.0)
	start_button.pressed.connect(_on_start_pressed)
	menu.add_child(start_button)

	var settings_button := Button.new()
	settings_button.name = "SettingsButton"
	settings_button.text = "Settings"
	settings_button.custom_minimum_size = Vector2(160.0, 48.0)
	settings_button.pressed.connect(_on_settings_pressed)
	menu.add_child(settings_button)

	_status_label = Label.new()
	_status_label.name = "Status"
	_status_label.text = "Ready. Export VOS charts with the Java bridge, then continue wiring Song Select."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status_label)


func _on_start_pressed() -> void:
	_app_state.transition_to(AppState.SONG_SELECT)
	_set_status("Song Select is the next UI loop. Runtime data loaders are ready.")


func _on_settings_pressed() -> void:
	_app_state.transition_to(AppState.SETTINGS)
	_set_status("Settings storage exists. Directory picker and key binding UI are next.")


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
