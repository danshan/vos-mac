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
	if not _expect_bool(ui.has_node("Content/SongDirectoryInput"), true, "song directory input"):
		return
	if not _expect_bool(ui.has_node("Content/FullscreenCheckBox"), true, "fullscreen checkbox"):
		return
	if not _expect_bool(ui.has_node("Content/AutoplayCheckBox"), true, "autoplay checkbox"):
		return
	if not _expect_bool(ui.has_node("Content/AutoSoundCheckBox"), true, "autosound checkbox"):
		return
	if not _expect_bool(ui.has_node("Content/AudioLatencySpinBox"), true, "audio latency spinbox"):
		return
	if not _expect_bool(ui.has_node("Content/DisplayLatencySpinBox"), true, "display latency spinbox"):
		return
	if not _expect_bool(ui.has_node("Content/MasterVolumeSpinBox"), true, "master volume spinbox"):
		return
	if not _expect_bool(ui.has_node("Content/KeyVolumeSpinBox"), true, "key volume spinbox"):
		return
	if not _expect_bool(ui.has_node("Content/BgmVolumeSpinBox"), true, "bgm volume spinbox"):
		return
	if not _expect_bool(ui.has_node("Content/HasteModeCheckBox"), true, "haste mode checkbox"):
		return
	if not _expect_bool(ui.has_node("Content/HasteNormalizeSpeedCheckBox"), true, "haste normalize speed checkbox"):
		return
	if not _expect_bool(ui.has_node("Content/StartPausedCheckBox"), true, "start paused checkbox"):
		return
	if not _expect_bool(ui.has_node("Content/ChannelModifierOption"), true, "channel modifier option"):
		return
	if not _expect_bool(ui.has_node("Content/SpeedTypeOption"), true, "speed type option"):
		return
	if not _expect_bool(ui.has_node("Content/SpeedMultiplierSpinBox"), true, "speed multiplier spinbox"):
		return
	if not _expect_bool(ui.has_node("Content/VisibilityModifierOption"), true, "visibility modifier option"):
		return
	if not _expect_bool(ui.has_node("Content/JudgmentTypeOption"), true, "judgment type option"):
		return
	if not _expect_bool(ui.has_node("Content/KeyBindings/KeyBinding1"), true, "first key binding"):
		return

	ui.get_node("Content/SongDirectoryInput").text = "res://test/fixtures"
	ui.get_node("Content/FullscreenCheckBox").button_pressed = true
	ui.get_node("Content/AutoplayCheckBox").button_pressed = true
	ui.get_node("Content/AutoSoundCheckBox").button_pressed = true
	ui.get_node("Content/AudioLatencySpinBox").value = 120.0
	ui.get_node("Content/DisplayLatencySpinBox").value = 45.0
	ui.get_node("Content/MasterVolumeSpinBox").value = 0.6
	ui.get_node("Content/KeyVolumeSpinBox").value = 0.7
	ui.get_node("Content/BgmVolumeSpinBox").value = 0.8
	ui.get_node("Content/HasteModeCheckBox").button_pressed = true
	ui.get_node("Content/HasteNormalizeSpeedCheckBox").button_pressed = false
	ui.get_node("Content/StartPausedCheckBox").button_pressed = true
	ui.get_node("Content/ChannelModifierOption").select(1)
	ui.get_node("Content/SpeedTypeOption").select(3)
	ui.get_node("Content/SpeedMultiplierSpinBox").value = 2.0
	ui.get_node("Content/VisibilityModifierOption").select(1)
	ui.get_node("Content/JudgmentTypeOption").select(1)
	ui.get_node("Content/KeyBindings/KeyBinding1").text = "A"
	ui.get_node("Content/BackButton").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.MAIN_MENU, "back to menu from settings"):
		return
	ui.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	if not _expect_string(ui.get_node("Content/SongDirectoryInput").text, "res://test/fixtures", "persisted song directory"):
		return
	if not _expect_bool(ui.get_node("Content/FullscreenCheckBox").button_pressed, true, "persisted fullscreen"):
		return
	if not _expect_bool(ui.get_node("Content/AutoplayCheckBox").button_pressed, true, "persisted autoplay"):
		return
	if not _expect_bool(ui.get_node("Content/AutoSoundCheckBox").button_pressed, true, "persisted autosound"):
		return
	if not _expect_float(ui.get_node("Content/AudioLatencySpinBox").value, 120.0, "persisted audio latency"):
		return
	if not _expect_float(ui.get_node("Content/DisplayLatencySpinBox").value, 45.0, "persisted display latency"):
		return
	if not _expect_float(ui.get_node("Content/MasterVolumeSpinBox").value, 0.6, "persisted master volume"):
		return
	if not _expect_float(ui.get_node("Content/KeyVolumeSpinBox").value, 0.7, "persisted key volume"):
		return
	if not _expect_float(ui.get_node("Content/BgmVolumeSpinBox").value, 0.8, "persisted bgm volume"):
		return
	if not _expect_bool(ui.get_node("Content/HasteModeCheckBox").button_pressed, true, "persisted haste mode"):
		return
	if not _expect_bool(ui.get_node("Content/HasteNormalizeSpeedCheckBox").button_pressed, false, "persisted haste normalize speed"):
		return
	if not _expect_bool(ui.get_node("Content/StartPausedCheckBox").button_pressed, true, "persisted start paused"):
		return
	if not _expect_string(ui.get_node("Content/ChannelModifierOption").get_item_text(
			ui.get_node("Content/ChannelModifierOption").selected), "Mirror", "persisted channel modifier"):
		return
	if not _expect_string(ui.get_node("Content/SpeedTypeOption").get_item_text(
			ui.get_node("Content/SpeedTypeOption").selected), "RegulSpeed", "persisted speed type"):
		return
	if not _expect_float(ui.get_node("Content/SpeedMultiplierSpinBox").value, 2.0, "persisted speed multiplier"):
		return
	if not _expect_string(ui.get_node("Content/VisibilityModifierOption").get_item_text(
			ui.get_node("Content/VisibilityModifierOption").selected), "Hidden", "persisted visibility modifier"):
		return
	if not _expect_string(ui.get_node("Content/JudgmentTypeOption").get_item_text(
			ui.get_node("Content/JudgmentTypeOption").selected), "time", "persisted judgment type"):
		return
	if not _expect_string(ui.get_node("Content/KeyBindings/KeyBinding1").text, "A", "persisted key binding"):
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
	ui.get_node("Content/AutoplayCheckBox").button_pressed = false
	ui.get_node("Content/AutoSoundCheckBox").button_pressed = false
	ui.get_node("Content/BackButton").emit_signal("pressed")

	ui.get_node("Content/Menu/StartButton").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.SONG_SELECT, "song select state"):
		return
	if not _expect_bool(ui.has_node("Content/SongList/Song_vos_fixture"), true, "fixture song button"):
		return

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
			"Max Combo 12\nPerfect 0\nCool 2\nGood 1\nBad 0\nMiss 1", "result summary text"):
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
