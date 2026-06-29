extends SceneTree

const AppState = preload("res://scripts/app_state.gd")
const MainUi = preload("res://scripts/main_ui.gd")


func _init() -> void:
	var settings_path := "user://main-ui-settings-persistence.cfg"
	var first = MainUi.new()
	if not _expect_bool(first.has_method("set_settings_path"), true, "settings path method"):
		return
	first.set_settings_path(settings_path)
	first.build()
	first.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	if not _expect_string(first.current_state(), AppState.SETTINGS, "first settings state"):
		return

	first.get_node("Content/SongDirectoryInput").text = "res://test/fixtures"
	first.get_node("Content/FullscreenCheckBox").button_pressed = false
	first.get_node("Content/AutoplayCheckBox").button_pressed = true
	first.get_node("Content/AudioLatencySpinBox").value = 88.0
	first.get_node("Content/DisplayLatencySpinBox").value = 44.0
	first.get_node("Content/MasterVolumeSpinBox").value = 0.55
	first.get_node("Content/KeyBindings/KeyBinding1").text = "A"
	if not _expect_bool(first.has_node("Content/MiscKeyBindings/MiscKey_speed_up"), true, "first misc speed up key binding"):
		return
	first.get_node("Content/MiscKeyBindings/MiscKey_speed_up").text = "PageUp"
	first.get_node("Content/BackButton").emit_signal("pressed")
	first.free()

	var second = MainUi.new()
	second.set_settings_path(settings_path)
	second.build()
	second.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	if not _expect_string(second.get_node("Content/SongDirectoryInput").text, "res://test/fixtures", "loaded song directory"):
		return
	if not _expect_bool(second.get_node("Content/AutoplayCheckBox").button_pressed, true, "loaded autoplay"):
		return
	if not _expect_float(second.get_node("Content/AudioLatencySpinBox").value, 88.0, "loaded audio latency"):
		return
	if not _expect_float(second.get_node("Content/DisplayLatencySpinBox").value, 44.0, "loaded display latency"):
		return
	if not _expect_float(second.get_node("Content/MasterVolumeSpinBox").value, 0.55, "loaded master volume"):
		return
	if not _expect_string(second.get_node("Content/KeyBindings/KeyBinding1").text, "A", "loaded key binding"):
		return
	if not _expect_bool(second.has_node("Content/MiscKeyBindings/MiscKey_speed_up"), true, "loaded misc speed up key binding"):
		return
	if not _expect_string(second.get_node("Content/MiscKeyBindings/MiscKey_speed_up").text, "PageUp", "loaded misc key binding"):
		return

	second.free()
	quit(0)


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


func _expect_float(actual: float, expected: float, label: String) -> bool:
	if absf(actual - expected) > 0.0001:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true
