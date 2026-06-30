extends SceneTree

const AppState = preload("res://scripts/app_state.gd")
const MainUi = preload("res://scripts/main_ui.gd")


func _init() -> void:
	var ui = MainUi.new()
	ui.build()
	ui.set_song_entries([
		{
			"id": "vos:fixture",
			"title": "Canon in D",
			"artist": "Pachelbel",
			"level": 7,
			"gameplayPath": "res://test/fixtures/gameplay.json",
			"audioManifestPath": "res://test/fixtures/audio-manifest.json",
			"renderMetadataPath": "res://test/fixtures/render-metadata.json",
		},
	])

	if not _expect_string(ui.current_state(), AppState.MAIN_MENU, "initial state"):
		return
	if not _expect_bool(ui.has_node("Content/Menu/StartButton"), true, "start button"):
		return
	if not _expect_bool(ui.has_node("Content/Menu/SettingsButton"), true, "settings button"):
		return

	ui.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.SETTINGS, "settings state"):
		return
	if not _expect_bool(ui.has_node("Content/SettingsScroll"), true, "settings scroll container"):
		return
	if not _expect_bool(ui.get_node("Content/SettingsScroll") is ScrollContainer, true, "settings scroll type"):
		return
	if not _expect_bool(ui.has_node("Content/SettingsScroll/SettingsForm"), true, "settings form"):
		return
	if not _expect_string(_settings_label_text(ui, "SongDirectoryInputLabel"), "Song directories", "song directory label"):
		return
	if not _expect_settings_descriptions(ui, _expected_settings_descriptions()):
		return
	if not _expect_bool(_has_settings_node(ui, "SongDirectoryInput"), true, "song directory input"):
		return
	if not _expect_bool(_has_settings_node(ui, "FullscreenCheckBox"), true, "fullscreen checkbox"):
		return
	if not _expect_bool(_has_settings_node(ui, "AutoplayCheckBox"), true, "autoplay checkbox"):
		return
	if not _expect_bool(_has_settings_node(ui, "AutoSoundCheckBox"), true, "autosound checkbox"):
		return
	if not _expect_bool(_has_settings_node(ui, "AudioLatencySpinBox"), true, "audio latency spinbox"):
		return
	if not _expect_bool(_has_settings_node(ui, "DisplayLatencySpinBox"), true, "display latency spinbox"):
		return
	if not _expect_bool(_has_settings_node(ui, "MasterVolumeSpinBox"), true, "master volume spinbox"):
		return
	if not _expect_bool(_has_settings_node(ui, "KeyVolumeSpinBox"), true, "key volume spinbox"):
		return
	if not _expect_bool(_has_settings_node(ui, "BgmVolumeSpinBox"), true, "bgm volume spinbox"):
		return
	if not _expect_bool(_has_settings_node(ui, "HasteModeCheckBox"), true, "haste mode checkbox"):
		return
	if not _expect_bool(_has_settings_node(ui, "HasteNormalizeSpeedCheckBox"), true, "haste normalize speed checkbox"):
		return
	if not _expect_bool(_has_settings_node(ui, "StartPausedCheckBox"), true, "start paused checkbox"):
		return
	if not _expect_bool(_has_settings_node(ui, "ChannelModifierOption"), true, "channel modifier option"):
		return
	if not _expect_bool(_has_settings_node(ui, "SpeedTypeOption"), true, "speed type option"):
		return
	if not _expect_bool(_has_settings_node(ui, "SpeedMultiplierSpinBox"), true, "speed multiplier spinbox"):
		return
	if not _expect_bool(_has_settings_node(ui, "VisibilityModifierOption"), true, "visibility modifier option"):
		return
	if not _expect_bool(_has_settings_node(ui, "JudgmentTypeOption"), true, "judgment type option"):
		return
	if not _expect_bool(_has_settings_node(ui, "KeyBinding1"), true, "first key binding"):
		return
	if not _expect_bool(_has_settings_node(ui, "MiscKey_speed_up"), true, "speed up misc key binding"):
		return
	if not _expect_bool(_has_settings_node(ui, "MiscKey_main_volume_down"), true, "main volume down misc key binding"):
		return

	_settings_node(ui, "SongDirectoryInput").text = "res://test/fixtures"
	_settings_node(ui, "FullscreenCheckBox").button_pressed = true
	_settings_node(ui, "AutoplayCheckBox").button_pressed = true
	_settings_node(ui, "AutoSoundCheckBox").button_pressed = true
	_settings_node(ui, "AudioLatencySpinBox").value = 120.0
	_settings_node(ui, "DisplayLatencySpinBox").value = 45.0
	_settings_node(ui, "MasterVolumeSpinBox").value = 0.6
	_settings_node(ui, "KeyVolumeSpinBox").value = 0.7
	_settings_node(ui, "BgmVolumeSpinBox").value = 0.8
	_settings_node(ui, "HasteModeCheckBox").button_pressed = true
	_settings_node(ui, "HasteNormalizeSpeedCheckBox").button_pressed = false
	_settings_node(ui, "StartPausedCheckBox").button_pressed = true
	_settings_node(ui, "ChannelModifierOption").select(1)
	_settings_node(ui, "SpeedTypeOption").select(3)
	_settings_node(ui, "SpeedMultiplierSpinBox").value = 2.0
	_settings_node(ui, "VisibilityModifierOption").select(1)
	_settings_node(ui, "JudgmentTypeOption").select(1)
	_settings_node(ui, "KeyBinding1").text = "A"
	_settings_node(ui, "MiscKey_speed_up").text = "PageUp"
	_settings_node(ui, "MiscKey_main_volume_down").text = "Minus"
	ui.get_node("Content/BackButton").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.MAIN_MENU, "back to menu from settings"):
		return
	ui.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	if not _expect_string(_settings_node(ui, "SongDirectoryInput").text, "res://test/fixtures", "persisted song directory"):
		return
	if not _expect_bool(_settings_node(ui, "FullscreenCheckBox").button_pressed, true, "persisted fullscreen"):
		return
	if not _expect_bool(_settings_node(ui, "AutoplayCheckBox").button_pressed, true, "persisted autoplay"):
		return
	if not _expect_bool(_settings_node(ui, "AutoSoundCheckBox").button_pressed, true, "persisted autosound"):
		return
	if not _expect_float(_settings_node(ui, "AudioLatencySpinBox").value, 120.0, "persisted audio latency"):
		return
	if not _expect_float(_settings_node(ui, "DisplayLatencySpinBox").value, 45.0, "persisted display latency"):
		return
	if not _expect_float(_settings_node(ui, "MasterVolumeSpinBox").value, 0.6, "persisted master volume"):
		return
	if not _expect_float(_settings_node(ui, "KeyVolumeSpinBox").value, 0.7, "persisted key volume"):
		return
	if not _expect_float(_settings_node(ui, "BgmVolumeSpinBox").value, 0.8, "persisted bgm volume"):
		return
	if not _expect_bool(_settings_node(ui, "HasteModeCheckBox").button_pressed, true, "persisted haste mode"):
		return
	if not _expect_bool(_settings_node(ui, "HasteNormalizeSpeedCheckBox").button_pressed, false, "persisted haste normalize speed"):
		return
	if not _expect_bool(_settings_node(ui, "StartPausedCheckBox").button_pressed, true, "persisted start paused"):
		return
	if not _expect_string(_settings_node(ui, "ChannelModifierOption").get_item_text(
			_settings_node(ui, "ChannelModifierOption").selected), "Mirror", "persisted channel modifier"):
		return
	if not _expect_string(_settings_node(ui, "SpeedTypeOption").get_item_text(
			_settings_node(ui, "SpeedTypeOption").selected), "RegulSpeed", "persisted speed type"):
		return
	if not _expect_float(_settings_node(ui, "SpeedMultiplierSpinBox").value, 2.0, "persisted speed multiplier"):
		return
	if not _expect_string(_settings_node(ui, "VisibilityModifierOption").get_item_text(
			_settings_node(ui, "VisibilityModifierOption").selected), "Hidden", "persisted visibility modifier"):
		return
	if not _expect_string(_settings_node(ui, "JudgmentTypeOption").get_item_text(
			_settings_node(ui, "JudgmentTypeOption").selected), "time", "persisted judgment type"):
		return
	if not _expect_string(_settings_node(ui, "KeyBinding1").text, "A", "persisted key binding"):
		return
	if not _expect_string(_settings_node(ui, "MiscKey_speed_up").text, "PageUp", "persisted speed up misc key binding"):
		return
	if not _expect_string(_settings_node(ui, "MiscKey_main_volume_down").text, "Minus", "persisted main volume down misc key binding"):
		return
	var option_overrides: Dictionary = ui._gameplay_option_overrides()
	if not _expect_bool(option_overrides.get("autoplay", false), true, "autoplay gameplay override"):
		return
	if not _expect_bool(option_overrides.get("autosound", false), true, "autosound gameplay override"):
		return
	if not _expect_float(float(option_overrides.get("audioLatencyMs", -1.0)), 120.0, "audio latency gameplay override"):
		return
	if not _expect_float(float(option_overrides.get("displayLatencyMs", -1.0)), 45.0, "display latency gameplay override"):
		return
	if not _expect_float(float(option_overrides.get("masterVolume", -1.0)), 0.6, "master volume gameplay override"):
		return
	if not _expect_float(float(option_overrides.get("keyVolume", -1.0)), 0.7, "key volume gameplay override"):
		return
	if not _expect_float(float(option_overrides.get("bgmVolume", -1.0)), 0.8, "bgm volume gameplay override"):
		return
	if not _expect_bool(option_overrides.get("hasteMode", false), true, "haste mode gameplay override"):
		return
	if not _expect_bool(option_overrides.get("hasteModeNormalizeSpeed", true), false, "haste normalize gameplay override"):
		return
	if not _expect_bool(option_overrides.get("manualStart", false), true, "start paused gameplay override"):
		return
	_settings_node(ui, "AutoplayCheckBox").button_pressed = false
	_settings_node(ui, "AutoSoundCheckBox").button_pressed = false
	ui.get_node("Content/BackButton").emit_signal("pressed")

	ui.get_node("Content/Menu/StartButton").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.SONG_SELECT, "song select state"):
		return
	if not _expect_bool(ui.has_node("Content/SongList/Song_vos_fixture"), true, "fixture song button"):
		return

	var invalid_key_bindings: Array[String] = ["A"]
	ui._settings_store.set_key_bindings(invalid_key_bindings)
	ui.get_node("Content/SongList/Song_vos_fixture").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.GAMEPLAY, "invalid key binding gameplay state"):
		return
	if not _expect_string(ui.get_node("Content/Status").text, "Unable to apply key bindings", "invalid key binding error"):
		return
	if not _expect_bool(ui.has_node("Content/BackButton"), true, "invalid key binding back button"):
		return
	ui.get_node("Content/BackButton").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.SONG_SELECT, "invalid key binding back to song select"):
		return
	var default_key_bindings: Array[String] = []
	ui._settings_store.set_key_bindings(default_key_bindings)

	ui.get_node("Content/SongList/Song_vos_fixture").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.GAMEPLAY, "gameplay state"):
		return
	if not _expect_bool(ui.has_node("Content/Title"), false, "gameplay omits menu title"):
		return
	if not _expect_bool(ui.has_node("Content/Status"), false, "gameplay omits menu status"):
		return
	if not _expect_bool(ui.has_node("Content/GameplayArea/GameplayView"), true, "gameplay view"):
		return
	if not _expect_bool(ui.has_node("Content/GameplayArea/GameplayView/Note_000"), true, "gameplay note node"):
		return
	if not _expect_float(ui.get_node("Content/GameplayArea/GameplayView/Note_000").position.x, 165.0, "gameplay mirrored note x"):
		return
	if not _expect_float(ui.get_node("Content/GameplayArea/GameplayView/Note_000").position.y, -8.25, "gameplay regul speed note y"):
		return
	if not _expect_bool(ui.has_node("Content/GameplayArea/GameplayView/Visibility_Hidden_000"), true, "gameplay hidden visibility"):
		return
	if not _expect_bool(ui.has_node("GameplayRuntime"), true, "gameplay runtime"):
		return
	if not _expect_bool(ui.has_node("Content/GameplayArea/GameplayView/Hud_SCORE_COUNTER"), true, "gameplay score hud"):
		return

	ui.get_node("GameplayRuntime").press_action("vos_lane_7", 780.0)
	ui._process(0.0)
	if not _expect_string(ui.get_node("Content/GameplayArea/GameplayView/Hud_SCORE_COUNTER").text, "0", "time judgment rejects wide early hit"):
		return
	ui.get_node("GameplayRuntime").release_action("vos_lane_7", 780.0)
	ui._process(0.0)

	ui.apply_layout_for_size(Vector2(1600.0, 900.0))
	var content: VBoxContainer = ui.get_node("Content")
	if not _expect_float(content.offset_left, 0.0, "gameplay content left"):
		return
	if not _expect_float(content.offset_top, 0.0, "gameplay content top"):
		return
	var gameplay_area: Control = ui.get_node("Content/GameplayArea")
	if not _expect_float(gameplay_area.custom_minimum_size.x, 1600.0, "gameplay area width"):
		return
	if not _expect_float(gameplay_area.custom_minimum_size.y, 900.0, "gameplay area height"):
		return
	var gameplay_view: Control = ui.get_node("Content/GameplayArea/GameplayView")
	if not _expect_float(gameplay_view.scale.x, 2.0, "gameplay view scale x"):
		return
	if not _expect_float(gameplay_view.scale.y, 1.5, "gameplay view scale y"):
		return

	ui.get_node("GameplayRuntime").press_action("vos_lane_7", 1000.0)
	ui._process(0.0)
	if not _expect_string(ui.get_node("Content/GameplayArea/GameplayView/Hud_SCORE_COUNTER").text, "200", "gameplay score hud update"):
		return
	if not _expect_bool(ui.has_node("Content/GameplayArea/GameplayView/Pressed_PRESSED_NOTE_7_000"), true, "gameplay pressed lane"):
		return
	if not _expect_bool(ui.has_node("Content/GameplayArea/GameplayView/Judgment_EFFECT_JUDGMENT_COOL"), true, "gameplay cool judgment"):
		return
	if not _expect_bool(ui.has_node("Content/GameplayArea/GameplayView/Click_EFFECT_CLICK_002"), true, "gameplay cool click"):
		return

	ui.get_node("GameplayRuntime").release_action("vos_lane_7", 1000.0)
	ui._process(0.0)
	if not _expect_bool(ui.has_node("Content/GameplayArea/GameplayView/Pressed_PRESSED_NOTE_7_000"), false, "gameplay released lane"):
		return

	ui.complete_game({
		"score": 200,
		"maxCombo": 12,
		"judgments": {"perfect": 0, "cool": 2, "good": 1, "bad": 0, "miss": 1},
	})
	if not _expect_string(ui.current_state(), AppState.RESULT, "result state"):
		return
	if not _expect_bool(ui.has_node("Content/ResultSummary"), true, "result summary"):
		return
	if not _expect_string(ui.get_node("Content/ResultSummary").text,
			"Accuracy 62.50%\nMax Combo 12\nPerfect 0\nCool 2\nGood 1\nBad 0\nMiss 1", "result summary text"):
		return
	if not _expect_bool(ui.has_node("Content/RetryButton"), true, "retry button"):
		return
	if not _expect_bool(ui.has_node("Content/SongSelectButton"), true, "song select button"):
		return

	ui.get_node("Content/RetryButton").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.GAMEPLAY, "retry gameplay state"):
		return

	ui.complete_game({"score": 200, "maxCombo": 0})
	ui.get_node("Content/SongSelectButton").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.SONG_SELECT, "result back to song select"):
		return

	ui.free()
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


func _expected_settings_descriptions() -> Dictionary:
	var expected := {
		"SongDirectoryInputDescription": "One or more folders to scan for VOS songs. Separate multiple paths with semicolons.",
		"FullscreenCheckBoxDescription": "Switch the game window to fullscreen when enabled.",
		"AutoplayCheckBoxDescription": "Automatically hits note lanes for playback, testing, and visual checks.",
		"AutoSoundCheckBoxDescription": "Plays note keysounds at chart timing without requiring key presses.",
		"AudioLatencySpinBoxDescription": "Audio timing offset in milliseconds. Positive values delay judgment and autosound timing.",
		"DisplayLatencySpinBoxDescription": "Visual timing offset in milliseconds applied after audio latency. Positive values draw notes later in chart time.",
		"MasterVolumeSpinBoxDescription": "Volume multiplier from 0.0 to 1.0 applied to all audio.",
		"KeyVolumeSpinBoxDescription": "Volume multiplier from 0.0 to 1.0 applied to note keysounds.",
		"BgmVolumeSpinBoxDescription": "Volume multiplier from 0.0 to 1.0 applied to background music.",
		"HasteModeCheckBoxDescription": "Gradually changes game speed and audio pitch using Java haste rules.",
		"HasteNormalizeSpeedCheckBoxDescription": "Keeps note scroll distance stable while haste changes audio pitch.",
		"StartPausedCheckBoxDescription": "Waits for the first lane key before game time starts.",
		"ChannelModifierOptionDescription": "None keeps original lanes. Mirror reverses lanes. Shuffle remaps once per chart. Random remaps by measure while preserving active long notes.",
		"SpeedTypeOptionDescription": "HiSpeed follows BPM beat distance. xRSpeed adds per-lane distance variation. WSpeed waves distance over time. RegulSpeed uses fixed 150 BPM distance.",
		"SpeedMultiplierSpinBoxDescription": "Base note scroll speed multiplier. 1.0 matches exported Java speed; larger values scroll faster.",
		"VisibilityModifierOptionDescription": "None leaves lanes uncovered. Hidden covers lower lanes. Sudden covers upper lanes. Dark masks top and bottom lanes.",
		"JudgmentTypeOptionDescription": "Beat uses BPM-relative windows. Time uses millisecond windows.",
		"KeyBindingsDescription": "Assign one key per VOS 7K lane from left to right.",
		"MiscKeyBindingsDescription": "Assign gameplay hotkeys for speed and master, keysound, and BGM volume changes.",
	}
	for lane in range(7):
		expected["KeyBinding%dDescription" % (lane + 1)] = "Triggers lane %d of the VOS 7K layout from left to right." % (lane + 1)
	expected["MiscKey_speed_upDescription"] = "Raises note scroll speed by 0.5 during gameplay."
	expected["MiscKey_speed_downDescription"] = "Lowers note scroll speed by 0.5 during gameplay."
	expected["MiscKey_main_volume_upDescription"] = "Raises master volume by 0.05 during gameplay."
	expected["MiscKey_main_volume_downDescription"] = "Lowers master volume by 0.05 during gameplay."
	expected["MiscKey_key_volume_upDescription"] = "Raises keysound volume by 0.05 during gameplay."
	expected["MiscKey_key_volume_downDescription"] = "Lowers keysound volume by 0.05 during gameplay."
	expected["MiscKey_bgm_volume_upDescription"] = "Raises background music volume by 0.05 during gameplay."
	expected["MiscKey_bgm_volume_downDescription"] = "Lowers background music volume by 0.05 during gameplay."
	return expected


func _expect_settings_descriptions(ui: Node, expected: Dictionary) -> bool:
	for node_name: Variant in expected.keys():
		if not _expect_string(_settings_label_text(ui, str(node_name)), str(expected[node_name]), "%s text" % node_name):
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


func _expect_float(actual: float, expected: float, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true
