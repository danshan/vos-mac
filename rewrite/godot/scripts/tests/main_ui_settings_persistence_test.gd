extends SceneTree

const AppState = preload("res://scripts/app_state.gd")
const MainUi = preload("res://scripts/main_ui.gd")
const SettingsI18n = preload("res://scripts/settings_i18n.gd")


func _init() -> void:
	if not _test_song_directory_selection_persists_immediately():
		return
	if not _test_autosync_result_persists_latency_and_disables_mode():
		return
	if not _test_settings_language_switch_affects_settings_only():
		return

	var settings_path := "user://main-ui-settings-persistence.cfg"
	_remove_settings_file(settings_path)
	var first = MainUi.new()
	if not _expect_bool(first.has_method("set_settings_path"), true, "settings path method"):
		return
	first.set_settings_path(settings_path)
	get_root().add_child(first)
	first.build()
	first.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	if not _expect_string(first.current_state(), AppState.SETTINGS, "first settings state"):
		return
	if not _expect_bool(first.has_node("Content/SettingsScroll/SettingsForm"), true, "settings form"):
		return
	if not _expect_string(_settings_label_text(first, "AudioLatencySpinBoxDescription"),
			"Global audio and judgment offset in milliseconds. Positive values judge notes later; negative values judge earlier.", "audio latency description"):
		return
	if not _expect_string(_settings_label_text(first, "VSyncCheckBoxDescription"),
			"Synchronizes frame presentation with the display refresh, matching Java's launch-time VSync option.", "vsync description"):
		return
	if not _expect_bool(_has_settings_node(first, "LocalMatchingServerInput"), false, "local matching server input removed"):
		return
	if not _expect_bool(_has_settings_node(first, "CreatePartytimeServerButton"), false, "create partytime server button removed"):
		return

	if not _expect_bool(_has_settings_node(first, "SongDirectoryDisplay"), true, "song directory display"):
		return
	if not _expect_bool(_settings_node(first, "SongDirectoryDisplay") is LineEdit, true, "song directory display type"):
		return
	if not _expect_bool(_settings_node(first, "SongDirectoryDisplay").editable, false, "song directory display read only"):
		return
	if not _expect_bool(_has_settings_node(first, "SongDirectoryBrowseButton"), true, "song directory browse button"):
		return
	if not _expect_bool(_has_settings_node(first, "SongDirectoryDialog"), true, "song directory dialog"):
		return
	if not _expect_int(_settings_node(first, "SongDirectoryDialog").file_mode, FileDialog.FILE_MODE_OPEN_DIR, "song directory dialog mode"):
		return
	_settings_node(first, "SongDirectoryBrowseButton").emit_signal("pressed")
	if not _expect_bool(_settings_node(first, "SongDirectoryDialog").visible, true, "song directory dialog opens"):
		return
	_settings_node(first, "SongDirectoryDialog").emit_signal("dir_selected", "res://test/fixtures")
	if not _expect_string(_settings_node(first, "SongDirectoryDisplay").text, "res://test/fixtures", "selected song directory display"):
		return
	_settings_node(first, "FullscreenCheckBox").button_pressed = false
	_settings_node(first, "VSyncCheckBox").button_pressed = false
	_settings_node(first, "AutoplayCheckBox").button_pressed = true
	_settings_node(first, "AudioLatencySpinBox").value = 88.0
	_settings_node(first, "DisplayLatencySpinBox").value = 44.0
	if not _expect_bool(_has_settings_node(first, "AutosyncModeOption"), true, "first autosync mode option"):
		return
	_settings_node(first, "AutosyncModeOption").select(1)
	_settings_node(first, "MasterVolumeSpinBox").value = 0.55
	if not _expect_bool(_settings_node(first, "KeyBinding1") is Button, true, "key binding capture button"):
		return
	_capture_key(_settings_node(first, "KeyBinding1"), KEY_C)
	_capture_key(_settings_node(first, "KeyBinding7"), KEY_SEMICOLON)
	if not _expect_string(_settings_node(first, "KeyBinding1").text, "C", "captured key binding"):
		return
	if not _expect_string(_settings_node(first, "KeyBinding7").text, ";", "captured semicolon key binding"):
		return
	if not _expect_bool(_has_settings_node(first, "MiscKey_speed_up"), true, "first misc speed up key binding"):
		return
	_settings_node(first, "MiscKey_speed_up").text = "PageUp"
	first.get_node("Content/BackButton").emit_signal("pressed")
	first.free()

	var second = MainUi.new()
	second.set_settings_path(settings_path)
	get_root().add_child(second)
	second.build()
	second.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	if not _expect_string(_settings_node(second, "SongDirectoryDisplay").text, "res://test/fixtures", "loaded song directory"):
		return
	if not _expect_bool(_settings_node(second, "AutoplayCheckBox").button_pressed, true, "loaded autoplay"):
		return
	if not _expect_bool(_settings_node(second, "VSyncCheckBox").button_pressed, false, "loaded vsync"):
		return
	if not _expect_float(_settings_node(second, "AudioLatencySpinBox").value, 88.0, "loaded audio latency"):
		return
	if not _expect_float(_settings_node(second, "DisplayLatencySpinBox").value, 44.0, "loaded display latency"):
		return
	if not _expect_bool(_has_settings_node(second, "LocalMatchingServerInput"), false, "loaded local matching server removed"):
		return
	if not _expect_string(_settings_node(second, "AutosyncModeOption").get_item_text(
			_settings_node(second, "AutosyncModeOption").selected), "Display", "loaded autosync mode"):
		return
	if not _expect_float(_settings_node(second, "MasterVolumeSpinBox").value, 0.55, "loaded master volume"):
		return
	if not _expect_string(_settings_node(second, "KeyBinding1").text, "C", "loaded key binding"):
		return
	if not _expect_string(_settings_node(second, "KeyBinding7").text, ";", "loaded semicolon key binding"):
		return
	if not _expect_bool(_has_settings_node(second, "MiscKey_speed_up"), true, "loaded misc speed up key binding"):
		return
	if not _expect_string(_settings_node(second, "MiscKey_speed_up").text, "PageUp", "loaded misc key binding"):
		return

	second.free()
	quit(0)


func _test_settings_language_switch_affects_settings_only() -> bool:
	var settings_path := "user://main-ui-language-switch.cfg"
	_remove_settings_file(settings_path)
	if not _expect_string(SettingsI18n.text("zh", "settings.title"), "设置", "settings i18n key"):
		return false
	if not _expect_string(SettingsI18n.text("zh", "settings.option.channel.none"), "无", "settings option i18n key"):
		return false
	if not _expect_string(SettingsI18n.text("fr", "settings.title"), "Settings", "settings i18n default fallback"):
		return false
	if not _expect_string(SettingsI18n.key_for_english("Settings"), "settings.title", "settings i18n english key lookup"):
		return false

	var first = MainUi.new()
	first.set_settings_path(settings_path)
	get_root().add_child(first)
	first.build()
	first.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	if not _expect_string(first.get_node("Content/Title").text, "Settings", "default settings language title"):
		return false
	if not _expect_bool(_has_settings_node(first, "SettingsLanguageOption"), true, "settings language option"):
		return false
	var language_option: OptionButton = _settings_node(first, "SettingsLanguageOption")
	language_option.select(1)
	language_option.emit_signal("item_selected", 1)
	if not _expect_string(first.get_node("Content/Title").text, "设置", "chinese settings title"):
		return false
	if not _expect_string(_settings_label_text(first, "SettingsHelp"),
			"游戏设置, 音频, 显示和键位.",
			"chinese settings help"):
		return false
	var autosync_option: OptionButton = _settings_node(first, "AutosyncModeOption")
	if not _expect_string(autosync_option.get_item_text(0), "关闭", "chinese autosync off option"):
		return false
	autosync_option.select(2)
	autosync_option.emit_signal("item_selected", 2)
	if not _expect_string(_settings_label_text(first, "AutosyncModeOptionValueDescription"),
			"音频: 使用 Java autosync 规则, 根据 tap 命中偏移更新音频延迟.",
			"chinese autosync selected value description"):
		return false
	var channel_option: OptionButton = _settings_node(first, "ChannelModifierOption")
	if not _expect_string(channel_option.get_item_text(0), "无", "chinese channel none option"):
		return false
	channel_option.select(1)
	channel_option.emit_signal("item_selected", 1)
	if not _expect_string(_settings_label_text(first, "ChannelModifierOptionValueDescription"),
			"镜像: 反转轨道顺序, 轨道 1 变为轨道 7.",
			"chinese channel selected value description"):
		return false
	var speed_option: OptionButton = _settings_node(first, "SpeedTypeOption")
	if not _expect_string(_settings_label_text(first, "SpeedTypeOptionValueDescription"),
			"HiSpeed: 跟随谱面 BPM, 因此 BPM 变化会影响音符移动距离.",
			"chinese speed value description"):
		return false
	var visibility_option: OptionButton = _settings_node(first, "VisibilityModifierOption")
	if not _expect_string(visibility_option.get_item_text(1), "隐藏", "chinese visibility hidden option"):
		return false
	var judgment_option: OptionButton = _settings_node(first, "JudgmentTypeOption")
	if not _expect_string(judgment_option.get_item_text(0), "节拍", "chinese judgment beat option"):
		return false
	first.get_node("Content/BackButton").emit_signal("pressed")
	var config := ConfigFile.new()
	if not _expect_int(config.load(settings_path), OK, "language settings file loads"):
		return false
	if not _expect_string(str(config.get_value("gameplay", "autosync_mode", "")), "audio", "translated autosync stores stable value"):
		return false
	if not _expect_string(str(config.get_value("gameplay", "channel_modifier", "")), "Mirror", "translated channel stores stable value"):
		return false
	if not _expect_string(first.get_node("Content/Menu/StartButton").text, "Start", "main menu start remains english"):
		return false
	if not _expect_string(first.get_node("Content/Menu/SettingsButton").text, "Settings", "main menu settings remains english"):
		return false
	first.free()

	var second = MainUi.new()
	second.set_settings_path(settings_path)
	get_root().add_child(second)
	second.build()
	second.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	var persisted := _expect_string(second.get_node("Content/Title").text, "设置", "persisted chinese settings title")
	second.free()
	return persisted


func _test_autosync_result_persists_latency_and_disables_mode() -> bool:
	var settings_path := "user://main-ui-autosync-result.cfg"
	_remove_settings_file(settings_path)

	var first = MainUi.new()
	first.set_settings_path(settings_path)
	get_root().add_child(first)
	first.build()
	first.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	_settings_node(first, "AudioLatencySpinBox").value = 88.0
	_settings_node(first, "DisplayLatencySpinBox").value = 44.0
	_settings_node(first, "AutosyncModeOption").select(2)
	first.get_node("Content/BackButton").emit_signal("pressed")
	first.complete_game({
		"score": 0,
		"judgments": {},
		"autosyncMode": "audio",
		"audioLatencyMs": 87.5,
		"displayLatencyMs": 44.0,
	})
	first.free()

	var second = MainUi.new()
	second.set_settings_path(settings_path)
	get_root().add_child(second)
	second.build()
	second.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	if not _expect_float(_settings_node(second, "AudioLatencySpinBox").value, 87.5, "autosync saved audio latency"):
		return false
	if not _expect_float(_settings_node(second, "DisplayLatencySpinBox").value, 44.0, "autosync leaves display latency"):
		return false
	if not _expect_string(_settings_node(second, "AutosyncModeOption").get_item_text(
			_settings_node(second, "AutosyncModeOption").selected), "Off", "autosync disables mode after save"):
		return false
	second.free()
	return true


func _test_song_directory_selection_persists_immediately() -> bool:
	var settings_path := "user://main-ui-directory-immediate-save.cfg"
	_remove_settings_file(settings_path)

	var first = MainUi.new()
	first.set_settings_path(settings_path)
	get_root().add_child(first)
	first.build()
	first.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	_settings_node(first, "SongDirectoryDialog").emit_signal("dir_selected", "/Users/honghao.shan/Music/demo")
	first.free()

	var second = MainUi.new()
	second.set_settings_path(settings_path)
	get_root().add_child(second)
	second.build()
	second.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	var result := _expect_string(_settings_node(second, "SongDirectoryDisplay").text,
			"/Users/honghao.shan/Music/demo", "immediately persisted song directory")
	second.free()
	return result


func _remove_settings_file(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _settings_node(ui: Node, node_name: String) -> Variant:
	return ui.get_node("Content").find_child(node_name, true, false)


func _has_settings_node(ui: Node, node_name: String) -> bool:
	return _settings_node(ui, node_name) != null


func _settings_label_text(ui: Node, node_name: String) -> String:
	var label: Variant = _settings_node(ui, node_name)
	if label is Label:
		return label.text
	return ""


func _capture_key(control: Variant, keycode: int) -> void:
	if not (control is Button):
		return
	control.emit_signal("pressed")
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	control.emit_signal("gui_input", event)


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


func _expect_int(actual: int, expected: int, label: String) -> bool:
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
