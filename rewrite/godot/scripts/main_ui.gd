extends Control

const AppState = preload("res://scripts/app_state.gd")

var _built: bool = false
var _app_state = AppState.new()
var _content: VBoxContainer = null
var _menu: HBoxContainer = null
var _title_label: Label = null
var _subtitle_label: Label = null
var _status_label: Label = null
var _start_button: Button = null
var _settings_button: Button = null


func _ready() -> void:
	build()


func build() -> void:
	if _built:
		return
	_built = true
	resized.connect(_on_resized)

	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.015, 0.018, 0.026, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_content)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.text = "Open2Jam VOS"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.name = "Subtitle"
	_subtitle_label.text = "Godot runtime preview"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_subtitle_label)

	_menu = HBoxContainer.new()
	_menu.name = "Menu"
	_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(_menu)

	_start_button = Button.new()
	_start_button.name = "StartButton"
	_start_button.text = "Start"
	_start_button.pressed.connect(_on_start_pressed)
	_menu.add_child(_start_button)

	_settings_button = Button.new()
	_settings_button.name = "SettingsButton"
	_settings_button.text = "Settings"
	_settings_button.pressed.connect(_on_settings_pressed)
	_menu.add_child(_settings_button)

	_status_label = Label.new()
	_status_label.name = "Status"
	_status_label.text = "Ready. Export VOS charts with the Java bridge, then continue wiring Song Select."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_status_label)

	apply_layout_for_size(_layout_size())


func apply_layout_for_size(viewport_size: Vector2) -> void:
	var short_edge: float = min(viewport_size.x, viewport_size.y)
	var long_edge: float = max(viewport_size.x, viewport_size.y)
	var content_margin: float = clamp(short_edge * 0.08, 48.0, 144.0)
	var vertical_margin: float = clamp(short_edge * 0.07, 40.0, 128.0)
	var title_size: int = int(round(clamp(short_edge * 0.075, 42.0, 104.0)))
	var subtitle_size: int = int(round(clamp(short_edge * 0.03, 18.0, 42.0)))
	var status_size: int = int(round(clamp(short_edge * 0.026, 16.0, 34.0)))
	var button_size := Vector2(
			clamp(long_edge * 0.14, 160.0, 360.0),
			clamp(short_edge * 0.075, 48.0, 96.0))
	var content_separation: int = int(round(clamp(short_edge * 0.035, 20.0, 56.0)))
	var menu_separation: int = int(round(clamp(long_edge * 0.018, 16.0, 48.0)))

	if _content != null:
		_content.offset_left = content_margin
		_content.offset_top = vertical_margin
		_content.offset_right = -content_margin
		_content.offset_bottom = -vertical_margin
		_content.add_theme_constant_override("separation", content_separation)
	if _menu != null:
		_menu.add_theme_constant_override("separation", menu_separation)
	if _title_label != null:
		_title_label.add_theme_font_size_override("font_size", title_size)
	if _subtitle_label != null:
		_subtitle_label.add_theme_font_size_override("font_size", subtitle_size)
	if _status_label != null:
		_status_label.add_theme_font_size_override("font_size", status_size)
	if _start_button != null:
		_start_button.custom_minimum_size = button_size
	if _settings_button != null:
		_settings_button.custom_minimum_size = button_size


func _on_start_pressed() -> void:
	_app_state.transition_to(AppState.SONG_SELECT)
	_set_status("Song Select is the next UI loop. Runtime data loaders are ready.")


func _on_settings_pressed() -> void:
	_app_state.transition_to(AppState.SETTINGS)
	_set_status("Settings storage exists. Directory picker and key binding UI are next.")


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func _on_resized() -> void:
	apply_layout_for_size(_layout_size())


func _layout_size() -> Vector2:
	if is_inside_tree():
		return get_viewport_rect().size
	return Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 720)))
