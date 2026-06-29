extends SceneTree

const AppState = preload("res://scripts/app_state.gd")
const MainUi = preload("res://scripts/main_ui.gd")


func _init() -> void:
	var ui = MainUi.new()
	ui.build()
	if not _expect_bool(ui.has_method("last_requested_window_mode"), true, "window mode request method"):
		return

	ui.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.SETTINGS, "settings state"):
		return
	ui.get_node("Content/FullscreenCheckBox").button_pressed = true
	ui.get_node("Content/BackButton").emit_signal("pressed")
	if not _expect_int(ui.last_requested_window_mode(), DisplayServer.WINDOW_MODE_FULLSCREEN, "fullscreen mode request"):
		return

	ui.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	ui.get_node("Content/FullscreenCheckBox").button_pressed = false
	ui.get_node("Content/BackButton").emit_signal("pressed")
	if not _expect_int(ui.last_requested_window_mode(), DisplayServer.WINDOW_MODE_WINDOWED, "windowed mode request"):
		return

	ui.free()
	quit(0)


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
