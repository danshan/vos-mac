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
	if not _expect_bool(ui.has_node("Content/ChannelModifierOption"), true, "channel modifier option"):
		return
	if not _expect_bool(ui.has_node("Content/KeyBindings/KeyBinding1"), true, "first key binding"):
		return

	ui.get_node("Content/SongDirectoryInput").text = "res://test/fixtures"
	ui.get_node("Content/FullscreenCheckBox").button_pressed = true
	ui.get_node("Content/ChannelModifierOption").select(1)
	ui.get_node("Content/KeyBindings/KeyBinding1").text = "A"
	ui.get_node("Content/BackButton").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.MAIN_MENU, "back to menu from settings"):
		return
	ui.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	if not _expect_string(ui.get_node("Content/SongDirectoryInput").text, "res://test/fixtures", "persisted song directory"):
		return
	if not _expect_bool(ui.get_node("Content/FullscreenCheckBox").button_pressed, true, "persisted fullscreen"):
		return
	if not _expect_string(ui.get_node("Content/ChannelModifierOption").get_item_text(
			ui.get_node("Content/ChannelModifierOption").selected), "Mirror", "persisted channel modifier"):
		return
	if not _expect_string(ui.get_node("Content/KeyBindings/KeyBinding1").text, "A", "persisted key binding"):
		return
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
	if not _expect_bool(ui.has_node("GameplayRuntime"), true, "gameplay runtime"):
		return
	if not _expect_bool(ui.has_node("Content/GameplayArea/GameplayView/Hud_SCORE_COUNTER"), true, "gameplay score hud"):
		return

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

	ui.complete_game({"score": 200, "maxCombo": 0})
	if not _expect_string(ui.current_state(), AppState.RESULT, "result state"):
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
