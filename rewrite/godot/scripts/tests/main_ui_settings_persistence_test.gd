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
	if not _expect_bool(first.has_node("Content/SettingsScroll/SettingsForm"), true, "settings form"):
		return
	if not _expect_string(_settings_label_text(first, "AudioLatencySpinBoxDescription"),
			"Offset audio and autosound timing in milliseconds.", "audio latency description"):
		return

	_settings_node(first, "SongDirectoryInput").text = "res://test/fixtures"
	_settings_node(first, "FullscreenCheckBox").button_pressed = false
	_settings_node(first, "AutoplayCheckBox").button_pressed = true
	_settings_node(first, "AudioLatencySpinBox").value = 88.0
	_settings_node(first, "DisplayLatencySpinBox").value = 44.0
	_settings_node(first, "MasterVolumeSpinBox").value = 0.55
	_settings_node(first, "KeyBinding1").text = "A"
	if not _expect_bool(_has_settings_node(first, "MiscKey_speed_up"), true, "first misc speed up key binding"):
		return
	_settings_node(first, "MiscKey_speed_up").text = "PageUp"
	first.get_node("Content/BackButton").emit_signal("pressed")
	first.free()

	var second = MainUi.new()
	second.set_settings_path(settings_path)
	second.build()
	second.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	if not _expect_string(_settings_node(second, "SongDirectoryInput").text, "res://test/fixtures", "loaded song directory"):
		return
	if not _expect_bool(_settings_node(second, "AutoplayCheckBox").button_pressed, true, "loaded autoplay"):
		return
	if not _expect_float(_settings_node(second, "AudioLatencySpinBox").value, 88.0, "loaded audio latency"):
		return
	if not _expect_float(_settings_node(second, "DisplayLatencySpinBox").value, 44.0, "loaded display latency"):
		return
	if not _expect_float(_settings_node(second, "MasterVolumeSpinBox").value, 0.55, "loaded master volume"):
		return
	if not _expect_string(_settings_node(second, "KeyBinding1").text, "A", "loaded key binding"):
		return
	if not _expect_bool(_has_settings_node(second, "MiscKey_speed_up"), true, "loaded misc speed up key binding"):
		return
	if not _expect_string(_settings_node(second, "MiscKey_speed_up").text, "PageUp", "loaded misc key binding"):
		return

	second.free()
	quit(0)


func _settings_node(ui: Node, node_name: String) -> Variant:
	return ui.get_node("Content").find_child(node_name, true, false)


func _has_settings_node(ui: Node, node_name: String) -> bool:
	return _settings_node(ui, node_name) != null


func _settings_label_text(ui: Node, node_name: String) -> String:
	var label: Variant = _settings_node(ui, node_name)
	if label is Label:
		return label.text
	return ""


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
