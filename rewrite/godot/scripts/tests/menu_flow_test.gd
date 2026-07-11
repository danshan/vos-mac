extends SceneTree

const AppState = preload("res://scripts/app_state.gd")
const MainUi = preload("res://scripts/main_ui.gd")

class MenuFlowExporter:
	extends RefCounted

	var catalog_calls: Array[Dictionary] = []

	func export_catalog(source_path: String, output_path: String) -> Dictionary:
		catalog_calls.append({
			"sourcePath": source_path,
			"outputPath": output_path,
		})
		var parent := output_path.get_base_dir()
		DirAccess.make_dir_recursive_absolute(parent)
		var file := FileAccess.open(output_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({
				"schemaVersion": 1,
				"entries": [
					_catalog_entry("vos:fixture", "Canon in D", "Pachelbel", 7),
					_catalog_entry("vos:nocturne", "Nocturne", "Jay Chou", 5),
				],
			}))
		return {"ok": true, "exit_code": 0}

	func _catalog_entry(id: String, title: String, artist: String, level: int) -> Dictionary:
		return {
			"id": id,
			"format": "VOS",
			"sourcePath": "/tmp/%s.vos" % id.replace(":", "_"),
			"title": title,
			"artist": artist,
			"noter": "Menu Flow",
			"genre": "Test",
			"keys": 7,
			"level": level,
			"levelKnown": true,
			"bpm": 120.0,
			"durationMs": 123000,
			"noteCount": 2,
			"coverAsset": "",
			"exportStatus": "ready",
			"gameplayPath": "res://test/fixtures/gameplay.json",
			"audioManifestPath": "res://test/fixtures/audio-manifest.json",
			"renderMetadataPath": "res://test/fixtures/render-metadata.json",
		}


func _init() -> void:
	var settings_path := "user://menu-flow-test.cfg"
	_remove_settings_file(settings_path)
	var exporter = MenuFlowExporter.new()
	var ui = MainUi.new()
	ui.set_settings_path(settings_path)
	ui.set_exporter_client(exporter)
	get_root().add_child(ui)
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
		{
			"id": "vos:nocturne",
			"title": "Nocturne",
			"artist": "Jay Chou",
			"level": 5,
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
	if not _expect_bool(ui.has_node("Content/Menu/ExitButton"), true, "exit button"):
		return
	if not _expect_string(ui.get_node("Content/Menu/ExitButton").text, "Exit", "exit button text"):
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
	if not _expect_string(_settings_label_text(ui, "SettingsHelp"),
			"Game setup, audio, display, and controls.",
			"settings help"):
		return
	if not _expect_settings_descriptions(ui, _expected_settings_sections()):
		return
	if not _expect_settings_description_noise_removed(ui):
		return
	if not _expect_string(_settings_label_text(ui, "SongDirectorySelectorLabel"), "Song directory", "song directory label"):
		return
	if not _expect_settings_descriptions(ui, _expected_settings_descriptions()):
		return
	if not _expect_settings_control_copy(ui):
		return
	if not _expect_settings_tooltips(ui, _expected_settings_descriptions()):
		return
	if not _expect_current_option_value_descriptions(ui):
		return
	_settings_node(ui, "ChannelModifierOption").select(3)
	_settings_node(ui, "ChannelModifierOption").emit_signal("item_selected", 3)
	if not _expect_string(_settings_label_text(ui, "ChannelModifierOptionValueDescription"),
			"Random: remaps lanes again for each measure while keeping held long notes on their active remapped lane.",
			"channel modifier selected value description"):
		return
	_settings_node(ui, "SpeedTypeOption").select(3)
	_settings_node(ui, "SpeedTypeOption").emit_signal("item_selected", 3)
	if not _expect_string(_settings_label_text(ui, "SpeedTypeOptionValueDescription"),
			"RegulSpeed: uses a fixed 150 BPM baseline so scroll distance does not follow chart BPM changes.",
			"speed type selected value description"):
		return
	if not _expect_bool(_has_settings_node(ui, "SongDirectoryInput"), false, "song directory manual input removed"):
		return
	if not _expect_bool(_has_settings_node(ui, "SongDirectoryDisplay"), true, "song directory display"):
		return
	if not _expect_bool(_settings_node(ui, "SongDirectoryDisplay") is LineEdit, true, "song directory display type"):
		return
	if not _expect_bool(_settings_node(ui, "SongDirectoryDisplay").editable, false, "song directory display read only"):
		return
	if not _expect_bool(_has_settings_node(ui, "SongDirectoryBrowseButton"), true, "song directory browse button"):
		return
	if not _expect_bool(_has_settings_node(ui, "SongDirectoryDialog"), true, "song directory dialog"):
		return
	if not _expect_int(_settings_node(ui, "SongDirectoryDialog").file_mode, FileDialog.FILE_MODE_OPEN_DIR, "song directory dialog mode"):
		return
	_settings_node(ui, "SongDirectoryBrowseButton").emit_signal("pressed")
	if not _expect_bool(_settings_node(ui, "SongDirectoryDialog").visible, true, "song directory dialog opens"):
		return
	_settings_node(ui, "SongDirectoryDialog").emit_signal("dir_selected", "res://test/fixtures")
	if not _expect_string(_settings_node(ui, "SongDirectoryDisplay").text, "res://test/fixtures", "selected song directory display"):
		return
	if not _expect_bool(_has_settings_node(ui, "FullscreenCheckBox"), true, "fullscreen checkbox"):
		return
	if not _expect_bool(_has_settings_node(ui, "VSyncCheckBox"), true, "vsync checkbox"):
		return
	if not _expect_bool(_has_settings_node(ui, "AutoplayCheckBox"), true, "autoplay checkbox"):
		return
	if not _expect_bool(_has_settings_node(ui, "AutoSoundCheckBox"), true, "autosound checkbox"):
		return
	if not _expect_bool(_has_settings_node(ui, "AudioLatencySpinBox"), true, "audio latency spinbox"):
		return
	if not _expect_bool(_has_settings_node(ui, "DisplayLatencySpinBox"), true, "display latency spinbox"):
		return
	if not _expect_bool(_has_settings_node(ui, "AutosyncModeOption"), true, "autosync mode option"):
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
	if not _expect_bool(_has_settings_node(ui, "LocalMatchingServerInput"), false, "local matching server input removed"):
		return
	if not _expect_bool(_has_settings_node(ui, "CreatePartytimeServerButton"), false, "create partytime server button removed"):
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

	_settings_node(ui, "FullscreenCheckBox").button_pressed = true
	_settings_node(ui, "VSyncCheckBox").button_pressed = false
	_settings_node(ui, "AutoplayCheckBox").button_pressed = true
	_settings_node(ui, "AutoSoundCheckBox").button_pressed = true
	_settings_node(ui, "AudioLatencySpinBox").value = 120.0
	_settings_node(ui, "DisplayLatencySpinBox").value = 45.0
	_settings_node(ui, "AutosyncModeOption").select(2)
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
	if not _expect_string(_settings_node(ui, "SongDirectoryDisplay").text, "res://test/fixtures", "persisted song directory"):
		return
	if not _expect_bool(_settings_node(ui, "FullscreenCheckBox").button_pressed, true, "persisted fullscreen"):
		return
	if not _expect_bool(_settings_node(ui, "VSyncCheckBox").button_pressed, false, "persisted vsync"):
		return
	if not _expect_bool(_settings_node(ui, "AutoplayCheckBox").button_pressed, true, "persisted autoplay"):
		return
	if not _expect_bool(_settings_node(ui, "AutoSoundCheckBox").button_pressed, true, "persisted autosound"):
		return
	if not _expect_float(_settings_node(ui, "AudioLatencySpinBox").value, 120.0, "persisted audio latency"):
		return
	if not _expect_float(_settings_node(ui, "DisplayLatencySpinBox").value, 45.0, "persisted display latency"):
		return
	if not _expect_string(_settings_node(ui, "AutosyncModeOption").get_item_text(
			_settings_node(ui, "AutosyncModeOption").selected), "Audio", "persisted autosync mode"):
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
	if not _expect_string(str(option_overrides.get("autosyncMode", "missing")), "audio", "autosync gameplay override"):
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
	if not _expect_bool(option_overrides.has("localMatchingServer"), false, "local matching server gameplay override removed"):
		return
	if not _expect_bool(option_overrides.has("partytimeServerObject"), false, "partytime server gameplay override removed"):
		return
	_settings_node(ui, "AutoplayCheckBox").button_pressed = false
	ui.get_node("Content/BackButton").emit_signal("pressed")

	ui.get_node("Content/Menu/StartButton").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.SONG_SELECT, "song select state"):
		return
	if not _expect_bool(ui.has_node("Content/SongFilterInput"), true, "song filter input"):
		return
	if not _expect_bool(ui.has_node("Content/SongSelectScroll/SongList"), true, "song select scroll list"):
		return
	if not _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/Song_vos_fixture"), true, "fixture song button"):
		return
	if not _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/Song_vos_nocturne"), true, "unfiltered second song button"):
		return
	ui.get_node("Content/SongFilterInput").text = "Canon"
	ui.get_node("Content/SongFilterInput").emit_signal("text_changed", "Canon")
	if not _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/Song_vos_fixture"), true, "filtered fixture song button"):
		return
	if not _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/Song_vos_nocturne"), false, "filtered second song hidden"):
		return

	var invalid_key_bindings: Array[String] = ["A"]
	ui._settings_store.set_key_bindings(invalid_key_bindings)
	ui.get_node("Content/SongSelectScroll/SongList/Song_vos_fixture").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.LOADING, "invalid key binding loading state"):
		return
	if not _expect_bool(ui.has_node("Content/LoadingLayer/LoadingImage"), true, "java loading image"):
		return
	ui._process(0.299)
	if not _expect_string(ui.current_state(), AppState.LOADING, "java loading minimum duration"):
		return
	ui._process(0.001)
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

	ui.get_node("Content/SongSelectScroll/SongList/Song_vos_fixture").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.LOADING, "gameplay loading state"):
		return
	if not _expect_bool(ui.has_node("Content/LoadingLayer/LoadingImage"), true, "gameplay loading image"):
		return
	var gameplay_loading_image: TextureRect = ui.get_node("Content/LoadingLayer/LoadingImage")
	if not _expect_bool(gameplay_loading_image.texture != null, true, "gameplay loading uses Java texture"):
		return
	ui._process(0.299)
	if not _expect_string(ui.current_state(), AppState.LOADING, "gameplay loading minimum duration holds"):
		return
	if not _expect_bool(ui.has_node("Content/LoadingLayer/LoadingImage"), true, "gameplay loading image still visible"):
		return
	ui._process(0.001)
	if not _expect_string(ui.current_state(), AppState.GAMEPLAY, "gameplay state"):
		return
	if not _expect_string(ui.last_requested_window_title(), "Pachelbel - Canon in D", "gameplay Java window title"):
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
	if not _expect_bool(ui.has_node("Content/GameplayArea/GameplayView/Visibility_Hidden_000"), false,
			"gameplay hidden visibility removed by Java composite lifecycle"):
		return
	if not _expect_bool(ui.has_node("GameplayRuntime"), true, "gameplay runtime"):
		return
	var runtime: Node = ui.get_node("GameplayRuntime")
	var initial_runtime_state: Dictionary = runtime.hud_state()
	if not _expect_bool(bool(initial_runtime_state.get("gameStarted", true)), false, "settings start paused reaches runtime"):
		return
	if not _expect_float(float(initial_runtime_state.get("judgmentTimeMs", -1.0)), -120.0, "settings audio latency reaches runtime"):
		return
	if not _expect_float(float(initial_runtime_state.get("displayTimeMs", -1.0)), -75.0, "settings display latency reaches runtime"):
		return
	if not _expect_float(float(initial_runtime_state.get("masterVolume", -1.0)), 0.6, "settings master volume reaches runtime"):
		return
	if not _expect_float(float(initial_runtime_state.get("keyVolume", -1.0)), 0.7, "settings key volume reaches runtime"):
		return
	if not _expect_float(float(initial_runtime_state.get("bgmVolume", -1.0)), 0.8, "settings bgm volume reaches runtime"):
		return
	var initial_status_texts: Array = initial_runtime_state.get("statusTexts", [])
	if not _expect_string(str(initial_status_texts[0]), "REGUL-SPEED: x2.0", "settings speed type reaches runtime"):
		return
	var gameplay_view_before_layout: Control = ui.get_node("Content/GameplayArea/GameplayView")
	if not _expect_float(gameplay_view_before_layout._target_speed, 2.0, "settings speed multiplier reaches view"):
		return
	if not _expect_string(gameplay_view_before_layout._speed_type, "RegulSpeed", "settings speed type reaches view"):
		return
	if not _expect_string(gameplay_view_before_layout._chart.get("visibilityModifier", ""), "Hidden", "settings visibility reaches view"):
		return
	if not _expect_bool(ui.has_node("Content/GameplayArea/GameplayView/Hud_SCORE_COUNTER"), true, "gameplay score hud"):
		return

	ui.get_node("GameplayRuntime").advance_to(500.0)
	var pause_time_before := float(ui.get_node("GameplayRuntime").elapsed_ms())
	_send_escape(ui)
	if not _expect_bool(ui.has_node("PauseMenu"), true, "gameplay menu layer"):
		return
	if not _expect_bool(ui.has_node("Content/PauseMenu"), false, "gameplay menu is not inside content"):
		return
	if not _expect_bool(ui.get_node("PauseMenu") is CanvasLayer, true, "gameplay menu canvas layer"):
		return
	if not _expect_int(ui.get_node("PauseMenu").layer, 100, "gameplay menu top layer"):
		return
	if not _expect_bool(ui.has_node("PauseMenu/Overlay/Scrim"), true, "gameplay menu scrim"):
		return
	if not _expect_bool(ui.has_node("PauseMenu/Overlay/Center/Panel/PauseActions/ResumeButton"), false, "gameplay menu has no resume button"):
		return
	if not _expect_bool(ui.has_node("PauseMenu/Overlay/Center/Panel/PauseActions/RetryButton"), true, "pause retry button"):
		return
	if not _expect_bool(ui.has_node("PauseMenu/Overlay/Center/Panel/PauseActions/SettingsButton"), true, "pause settings button"):
		return
	if not _expect_bool(ui.has_node("PauseMenu/Overlay/Center/Panel/PauseActions/SongSelectButton"), true, "pause song select button"):
		return
	ui._process(1.0)
	if not _expect_float(ui.get_node("GameplayRuntime").elapsed_ms(), pause_time_before, "pause stops runtime time"):
		return
	_send_escape(ui)
	if not _expect_bool(ui.has_node("PauseMenu"), false, "second escape hides gameplay menu"):
		return
	ui._process(0.5)
	if not _expect_float(ui.get_node("GameplayRuntime").elapsed_ms(), pause_time_before + 500.0, "closing menu resumes runtime time"):
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
	if not _expect_float(gameplay_view.scale.x, 1.5, "gameplay view uniform scale x"):
		return
	if not _expect_float(gameplay_view.scale.y, 1.5, "gameplay view uniform scale y"):
		return
	if not _expect_float(gameplay_view.position.x, 200.0, "gameplay view letterbox x"):
		return
	if not _expect_float(gameplay_view.position.y, 0.0, "gameplay view letterbox y"):
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

	ui._process(2.0)
	if not _expect_string(ui.current_state(), AppState.GAMEPLAY, "runtime finish waits for Java delay"):
		return
	ui._process(10.001)
	if not _expect_string(ui.current_state(), AppState.RESULT, "runtime completed signal result state"):
		return
	if not _expect_string(ui.last_requested_window_title(), "Open2Jam Rewrite", "result restores default window title"):
		return
	if not _expect_bool(ui.has_node("GameplayRuntime"), false, "runtime removed after automatic result"):
		return
	if not _expect_string(ui.get_node("Content/Status").text, "Score 200", "automatic result score text"):
		return
	if not _expect_bool(ui.has_node("Content/ResultSummary"), true, "result summary"):
		return
	if not _expect_string(ui.get_node("Content/ResultSummary").text,
			"Accuracy 100.00%\nMax Combo 0\nPerfect 0\nCool 1\nGood 0\nBad 0\nMiss 0", "automatic result summary text"):
		return
	if not _expect_bool(ui.has_node("Content/RetryButton"), true, "retry button"):
		return
	if not _expect_bool(ui.has_node("Content/SongSelectButton"), true, "song select button"):
		return

	ui.get_node("Content/RetryButton").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.LOADING, "retry loading state"):
		return
	if not _expect_bool(ui.has_node("Content/LoadingLayer/LoadingImage"), true, "retry loading image"):
		return
	var retry_loading_image: TextureRect = ui.get_node("Content/LoadingLayer/LoadingImage")
	if not _expect_bool(retry_loading_image.texture != null, true, "retry loading uses Java texture"):
		return
	ui._process(0.299)
	if not _expect_string(ui.current_state(), AppState.LOADING, "retry loading minimum duration holds"):
		return
	if not _expect_bool(ui.has_node("Content/LoadingLayer/LoadingImage"), true, "retry loading image still visible"):
		return
	ui._process(0.001)
	if not _expect_string(ui.current_state(), AppState.GAMEPLAY, "retry gameplay state"):
		return
	if not _expect_bool(ui.has_node("GameplayRuntime"), true, "retry gameplay runtime"):
		return
	if not _expect_float(ui.get_node("GameplayRuntime").game_time_ms(), 0.0, "retry runtime game time reset"):
		return
	if not _expect_int(ui.get_node("GameplayRuntime").result().get("score", -1), 0, "retry runtime score reset"):
		return
	if not _expect_string(ui.get_node("Content/GameplayArea/GameplayView/Hud_SCORE_COUNTER").text, "0", "retry hud score reset"):
		return
	if not _expect_int(ui.get_node("GameplayRuntime").audio_play_event_count(), 0, "retry audio event count reset"):
		return

	ui.complete_game({"score": 200, "maxCombo": 0})
	ui.get_node("Content/SongSelectButton").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.SONG_SELECT, "result back to song select"):
		return
	if not _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/Song_vos_fixture"), true, "result back keeps song button"):
		return
	if not _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/SongSelected_vos_fixture"), true, "result back selected song marker"):
		return
	if not _expect_string(ui.get_node("Content/SongSelectScroll/SongList/SongSelected_vos_fixture").text, "Selected", "result back selected song marker text"):
		return
	ui.get_node("Content/BackButton").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.MAIN_MENU, "song select back to main menu after result"):
		return
	ui.get_node("Content/Menu/StartButton").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.SONG_SELECT, "main menu start keeps catalog"):
		return
	if not _expect_string(ui.get_node("Content/SongFilterInput").text, "Canon", "main menu start keeps song filter"):
		return
	if not _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/Song_vos_fixture"), true, "main menu start keeps song button"):
		return
	if not _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/Song_vos_nocturne"), false, "main menu start keeps filtered song hidden"):
		return
	if not _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/SongSelected_vos_fixture"), true, "main menu start keeps selected song marker"):
		return

	if not _test_gameplay_menu_settings_transition():
		return

	ui.free()
	quit(0)


func _test_gameplay_menu_settings_transition() -> bool:
	var settings_path := "user://menu-flow-gameplay-menu-settings.cfg"
	_remove_settings_file(settings_path)
	var ui = MainUi.new()
	ui.set_settings_path(settings_path)
	get_root().add_child(ui)
	ui.build()
	ui.set_song_entries([
		{
			"id": "vos:settings",
			"title": "Settings Path",
			"artist": "Menu Flow",
			"level": 7,
			"keys": 7,
			"gameplayPath": "res://test/fixtures/gameplay.json",
			"audioManifestPath": "res://test/fixtures/audio-manifest.json",
			"renderMetadataPath": "res://test/fixtures/render-metadata.json",
		},
	])
	ui.get_node("Content/Menu/StartButton").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.SONG_SELECT, "menu settings helper song select"):
		return false
	ui.get_node("Content/SongSelectScroll/SongList/Song_vos_settings").emit_signal("pressed")
	ui._process(0.3)
	if not _expect_string(ui.current_state(), AppState.GAMEPLAY, "menu settings helper gameplay"):
		return false
	_send_escape(ui)
	if not _expect_bool(ui.has_node("PauseMenu/Overlay/Center/Panel/PauseActions/SettingsButton"), true, "menu settings helper settings button"):
		return false
	ui.get_node("PauseMenu/Overlay/Center/Panel/PauseActions/SettingsButton").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.SETTINGS, "gameplay menu settings state"):
		return false
	if not _expect_bool(ui.has_node("Content/SettingsScroll"), true, "gameplay menu opens settings page"):
		return false
	if not _expect_bool(ui.has_node("PauseMenu"), false, "gameplay menu cleared before settings"):
		return false
	if not _expect_bool(ui.has_node("GameplayRuntime"), false, "gameplay runtime stopped before settings"):
		return false
	ui.free()
	return true


func _settings_node(ui: Node, node_name: String) -> Variant:
	return ui.get_node("Content").find_child(node_name, true, false)


func _send_escape(ui: Node) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	ui._unhandled_input(event)


func _remove_settings_file(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _has_settings_node(ui: Node, node_name: String) -> bool:
	return _settings_node(ui, node_name) != null


func _settings_label_text(ui: Node, node_name: String) -> String:
	var label: Variant = _settings_node(ui, node_name)
	if label is Label:
		return label.text
	return ""


func _expected_settings_descriptions() -> Dictionary:
	var expected := {
		"SongDirectorySelectorDescription": "Folder scanned when Start is pressed. Choose a directory with the browser so the path is stored exactly as selected.",
		"FullscreenCheckBoxDescription": "When enabled, returning from Settings requests fullscreen mode for the game window.",
		"VSyncCheckBoxDescription": "Synchronizes frame presentation with the display refresh, matching Java's launch-time VSync option.",
		"AutoplayCheckBoxDescription": "Automatically judges lane notes as hits. Use this for visual or audio checks, not normal play.",
		"AutoSoundCheckBoxDescription": "Plays note keysounds at chart timing even without key presses. Disable it for manual keysound-only play.",
		"AudioLatencySpinBoxDescription": "Global audio and judgment offset in milliseconds. Positive values judge notes later; negative values judge earlier.",
		"DisplayLatencySpinBoxDescription": "Visual offset in milliseconds applied after audio latency. Positive values draw notes later; negative values draw earlier.",
		"AutosyncModeOptionDescription": "Optional Java autosync mode. It updates one latency value from normal tap judgments while a chart is running.",
		"MasterVolumeSpinBoxDescription": "Master gain from 0.00 to 1.00 applied to every audio channel.",
		"KeyVolumeSpinBoxDescription": "Keysound gain from 0.00 to 1.00 applied to note samples.",
		"BgmVolumeSpinBoxDescription": "Background music gain from 0.00 to 1.00 applied to BGM samples.",
		"HasteModeCheckBoxDescription": "Enables Java-style haste: chart speed and audio pitch change over time.",
		"HasteNormalizeSpeedCheckBoxDescription": "Keeps note travel distance stable while haste changes pitch. Disable it to let scroll speed change with haste.",
		"StartPausedCheckBoxDescription": "Keeps chart time at zero until the first lane key is pressed.",
		"ChannelModifierOptionDescription": "Lane remap before play: None keeps lanes, Mirror reverses lanes, Shuffle picks one chart-wide map, Random changes by measure while preserving held lanes.",
		"SpeedTypeOptionDescription": "Scroll math mode: HiSpeed follows BPM, xRSpeed varies each lane, WSpeed waves over time, RegulSpeed uses a fixed 150 BPM baseline.",
		"SpeedMultiplierSpinBoxDescription": "Base scroll multiplier from 0.5 to 10.0. Higher values move notes faster toward the judgment line.",
		"VisibilityModifierOptionDescription": "Lane mask mode: Hidden covers lower lanes, Sudden covers upper lanes, Dark masks both ends, None leaves lanes visible.",
		"JudgmentTypeOptionDescription": "Judgment window mode: beat scales with BPM; time uses fixed millisecond windows.",
		"KeyBindingsDescription": "Seven lane inputs, left to right. Focus a key button, press Enter, then press one keyboard key to bind it.",
		"MiscKeyBindingsDescription": "In-game adjustment hotkeys for speed and volume. Focus a key button, press Enter, then press one keyboard key to bind it.",
	}
	return expected


func _expected_settings_sections() -> Dictionary:
	return {}


func _expected_settings_control_texts() -> Dictionary:
	return {
		"SongDirectoryBrowseButton": "Browse...",
		"FullscreenCheckBox": "Use fullscreen mode",
		"VSyncCheckBox": "Use VSync",
		"AutoplayCheckBox": "Auto-hit lane notes",
		"AutoSoundCheckBox": "Play keysounds automatically",
		"StartPausedCheckBox": "Wait for first lane key",
		"HasteModeCheckBox": "Enable haste speed changes",
		"HasteNormalizeSpeedCheckBox": "Keep scroll distance stable",
	}


func _expected_settings_placeholders() -> Dictionary:
	return {
		"SongDirectoryDisplay": "No folder selected",
	}


func _option_value_descriptions_by_control() -> Dictionary:
	return {
		"ChannelModifierOption": {
			"None": "None: keeps the chart's exported lane order.",
			"Mirror": "Mirror: reverses lane order, so lane 1 becomes lane 7.",
			"Shuffle": "Shuffle: picks one randomized lane map and keeps it for the whole chart.",
			"Random": "Random: remaps lanes again for each measure while keeping held long notes on their active remapped lane.",
		},
		"SpeedTypeOption": {
			"HiSpeed": "HiSpeed: follows chart BPM, so BPM changes affect note travel distance.",
			"xRSpeed": "xRSpeed: applies Java xRSpeed lane variation on top of the base speed multiplier.",
			"WSpeed": "WSpeed: waves scroll distance over time using the Java WSpeed rule.",
			"RegulSpeed": "RegulSpeed: uses a fixed 150 BPM baseline so scroll distance does not follow chart BPM changes.",
		},
		"AutosyncModeOption": {
			"Off": "Off: keeps audio and display latency fixed during play.",
			"Display": "Display: updates display latency from tap hit offsets using the Java autosync rule.",
			"Audio": "Audio: updates audio latency from tap hit offsets using the Java autosync rule.",
		},
		"VisibilityModifierOption": {
			"None": "None: leaves the playfield lanes fully visible.",
			"Hidden": "Hidden: covers the lower part of the lanes so notes disappear before the judgment line.",
			"Sudden": "Sudden: covers the upper part of the lanes so notes appear later.",
			"Dark": "Dark: covers both upper and lower lane areas.",
		},
		"JudgmentTypeOption": {
			"beat": "beat: scales judgment windows with BPM, matching the Java beat-based mode.",
			"time": "time: uses fixed millisecond judgment windows regardless of BPM.",
		},
	}


func _expect_current_option_value_descriptions(ui: Node) -> bool:
	var descriptions_by_control := _option_value_descriptions_by_control()
	for control_name: Variant in descriptions_by_control.keys():
		var option: Variant = _settings_node(ui, str(control_name))
		if not (option is OptionButton):
			return _expect_bool(false, true, "%s option exists" % control_name)
		var option_button: OptionButton = option
		var selected_text: String = option_button.get_item_text(option_button.selected)
		var descriptions: Dictionary = descriptions_by_control[control_name]
		var expected := str(descriptions.get(selected_text, ""))
		if not _expect_string(_settings_label_text(ui, "%sValueDescription" % control_name), expected, "%s value description" % control_name):
			return false
	return true


func _expect_all_option_value_descriptions(ui: Node) -> bool:
	var descriptions_by_control := _option_value_descriptions_by_control()
	for control_name: Variant in descriptions_by_control.keys():
		var option: Variant = _settings_node(ui, str(control_name))
		if not (option is OptionButton):
			return _expect_bool(false, true, "%s option exists" % control_name)
		var option_button: OptionButton = option
		var expected_lines: Array[String] = []
		var descriptions: Dictionary = descriptions_by_control[control_name]
		for index in range(option_button.get_item_count()):
			var option_text := option_button.get_item_text(index)
			expected_lines.append(str(descriptions.get(option_text, option_text)))
		if not _expect_string(_settings_label_text(ui, "%sValueDescriptions" % control_name),
				"\n".join(expected_lines), "%s all value descriptions" % control_name):
			return false
	return true


func _expect_settings_description_noise_removed(ui: Node) -> bool:
	for node_name in [
		"SettingsSectionSongsDescription",
		"SettingsSectionDisplayDescription",
		"SettingsSectionPlaybackDescription",
		"SettingsSectionTimingDescription",
		"SettingsSectionAudioDescription",
		"SettingsSectionModifiersDescription",
		"SettingsSectionInputDescription",
		"KeyBinding1Description",
		"KeyBinding7Description",
		"MiscKey_speed_upDescription",
		"MiscKey_bgm_volume_downDescription",
		"ChannelModifierOptionValueDescriptionsTitle",
		"ChannelModifierOptionValueDescriptions",
		"SpeedTypeOptionValueDescriptionsTitle",
		"SpeedTypeOptionValueDescriptions",
	]:
		if not _expect_bool(_has_settings_node(ui, node_name), false, "%s removed" % node_name):
			return false
	return true


func _expect_settings_descriptions(ui: Node, expected: Dictionary) -> bool:
	for node_name: Variant in expected.keys():
		if not _expect_string(_settings_label_text(ui, str(node_name)), str(expected[node_name]), "%s text" % node_name):
			return false
	return true


func _expect_settings_control_copy(ui: Node) -> bool:
	for node_name: Variant in _expected_settings_control_texts().keys():
		var control: Variant = _settings_node(ui, str(node_name))
		if not (control is Button):
			return _expect_bool(false, true, "%s button exists" % node_name)
		if not _expect_string(control.text, str(_expected_settings_control_texts()[node_name]), "%s text" % node_name):
			return false
	for node_name: Variant in _expected_settings_placeholders().keys():
		var control: Variant = _settings_node(ui, str(node_name))
		if not (control is LineEdit):
			return _expect_bool(false, true, "%s line edit exists" % node_name)
		if not _expect_string(control.placeholder_text, str(_expected_settings_placeholders()[node_name]), "%s placeholder" % node_name):
			return false
	return true


func _expect_settings_tooltips(ui: Node, expected: Dictionary) -> bool:
	for node_name: Variant in expected.keys():
		var description_name := str(node_name)
		var control_name := description_name.substr(0, description_name.length() - "Description".length())
		var control: Variant = _settings_node(ui, control_name)
		if not (control is Control):
			continue
		if not _expect_string(control.tooltip_text, str(expected[node_name]), "%s tooltip" % control_name):
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


func _expect_int(actual: int, expected: int, label: String) -> bool:
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
