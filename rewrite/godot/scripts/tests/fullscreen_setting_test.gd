extends SceneTree

const AppState = preload("res://scripts/app_state.gd")
const MainUi = preload("res://scripts/main_ui.gd")


func _init() -> void:
	var settings_path := "user://fullscreen-setting-test.cfg"
	_remove_settings_file(settings_path)
	var ui = MainUi.new()
	ui.set_settings_path(settings_path)
	ui.build()
	if not _expect_bool(ui.has_method("last_requested_window_mode"), true, "window mode request method"):
		return
	if not _expect_bool(ui.has_method("last_requested_vsync_mode"), true, "vsync mode request method"):
		return

	ui.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.SETTINGS, "settings state"):
		return
	_settings_node(ui, "FullscreenCheckBox").button_pressed = true
	_settings_node(ui, "VSyncCheckBox").button_pressed = false
	ui.get_node("Content/BackButton").emit_signal("pressed")
	if not _expect_int(ui.last_requested_window_mode(), DisplayServer.WINDOW_MODE_FULLSCREEN, "fullscreen mode request"):
		return
	if not _expect_int(ui.last_requested_vsync_mode(), DisplayServer.VSYNC_DISABLED, "disabled vsync request"):
		return

	ui.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	_settings_node(ui, "FullscreenCheckBox").button_pressed = false
	_settings_node(ui, "VSyncCheckBox").button_pressed = true
	ui.get_node("Content/BackButton").emit_signal("pressed")
	if not _expect_int(ui.last_requested_window_mode(), DisplayServer.WINDOW_MODE_WINDOWED, "windowed mode request"):
		return
	if not _expect_int(ui.last_requested_vsync_mode(), DisplayServer.VSYNC_ENABLED, "enabled vsync request"):
		return

	ui.free()
	quit(0)


func _settings_node(ui: Node, node_name: String) -> Variant:
	return ui.get_node("Content").find_child(node_name, true, false)


func _remove_settings_file(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _expect_int(actual: int, expected: int, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true


func _expect_bool(actual: bool, expected: bool, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true


func _expect_string(actual: String, expected: String, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true
