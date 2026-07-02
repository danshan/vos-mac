extends SceneTree

const AppState = preload("res://scripts/app_state.gd")
const MainUi = preload("res://scripts/main_ui.gd")

const FULLSCREEN_SIZE: Vector2 = Vector2(2560.0, 1440.0)
const EXPECTED_CONTENT_MARGIN: float = 115.2
const EXPECTED_VERTICAL_MARGIN: float = 100.8
const EXPECTED_BUTTON_WIDTH: float = 358.4
const EXPECTED_BUTTON_HEIGHT: float = 96.0


func _init() -> void:
	var settings_path := "user://fullscreen-layout-test.cfg"
	var absolute_settings_path := ProjectSettings.globalize_path(settings_path)
	if FileAccess.file_exists(absolute_settings_path):
		DirAccess.remove_absolute(absolute_settings_path)

	var ui = MainUi.new()
	ui.set_settings_path(settings_path)
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

	ui.apply_layout_for_size(FULLSCREEN_SIZE)
	if not _expect_string(ui.current_state(), AppState.MAIN_MENU, "main menu state"):
		return
	if not _expect_framed_content_layout(ui, "main menu content"):
		return
	if not _expect_button_size(ui.get_node("Content/Menu/StartButton"), "main menu start"):
		return
	if not _expect_button_size(ui.get_node("Content/Menu/SettingsButton"), "main menu settings"):
		return

	ui.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	ui.apply_layout_for_size(FULLSCREEN_SIZE)
	if not _expect_string(ui.current_state(), AppState.SETTINGS, "settings state"):
		return
	if not _expect_framed_content_layout(ui, "settings content"):
		return
	if not _expect_bool(ui.get_node("Content/SettingsScroll") is ScrollContainer, true, "settings scroll"):
		return
	if not _expect_int(ui.get_node("Content/SettingsScroll").size_flags_vertical, Control.SIZE_EXPAND_FILL, "settings scroll fills vertical space"):
		return
	if not _expect_button_size(ui.get_node("Content/BackButton"), "settings back"):
		return

	ui.get_node("Content/BackButton").emit_signal("pressed")
	ui.get_node("Content/Menu/StartButton").emit_signal("pressed")
	ui.apply_layout_for_size(FULLSCREEN_SIZE)
	if not _expect_string(ui.current_state(), AppState.SONG_SELECT, "song select state"):
		return
	if not _expect_framed_content_layout(ui, "song select content"):
		return
	if not _expect_button_size(ui.get_node("Content/SongSelectScroll/SongList/Song_vos_fixture"), "song select song"):
		return
	if not _expect_button_size(ui.get_node("Content/BackButton"), "song select back"):
		return

	ui.get_node("Content/SongSelectScroll/SongList/Song_vos_fixture").emit_signal("pressed")
	ui.apply_layout_for_size(FULLSCREEN_SIZE)
	if not _expect_string(ui.current_state(), AppState.LOADING, "loading state"):
		return
	if not _expect_full_bleed_loading_layout(ui):
		return
	ui._process(0.3)
	ui.apply_layout_for_size(FULLSCREEN_SIZE)
	if not _expect_string(ui.current_state(), AppState.GAMEPLAY, "gameplay state"):
		return
	if not _expect_full_bleed_gameplay_layout(ui):
		return

	ui.complete_game({
		"score": 200,
		"maxCombo": 12,
		"judgments": {"perfect": 0, "cool": 2, "good": 1, "bad": 0, "miss": 1},
	})
	ui.apply_layout_for_size(FULLSCREEN_SIZE)
	if not _expect_string(ui.current_state(), AppState.RESULT, "result state"):
		return
	if not _expect_framed_content_layout(ui, "result content"):
		return
	if not _expect_bool(ui.has_node("Content/ResultSummary"), true, "result summary"):
		return
	if not _expect_button_size(ui.get_node("Content/RetryButton"), "result retry"):
		return
	if not _expect_button_size(ui.get_node("Content/SongSelectButton"), "result song select"):
		return

	ui.free()
	quit(0)


func _expect_framed_content_layout(ui: Node, label: String) -> bool:
	var content: Control = ui.get_node("Content")
	if not _expect_float(content.offset_left, EXPECTED_CONTENT_MARGIN, "%s left" % label):
		return false
	if not _expect_float(content.offset_top, EXPECTED_VERTICAL_MARGIN, "%s top" % label):
		return false
	if not _expect_float(content.offset_right, -EXPECTED_CONTENT_MARGIN, "%s right" % label):
		return false
	if not _expect_float(content.offset_bottom, -EXPECTED_VERTICAL_MARGIN, "%s bottom" % label):
		return false
	return true


func _expect_full_bleed_loading_layout(ui: Node) -> bool:
	var content: Control = ui.get_node("Content")
	if not _expect_float(content.offset_left, 0.0, "loading content left"):
		return false
	if not _expect_float(content.offset_top, 0.0, "loading content top"):
		return false
	if not _expect_float(content.offset_right, 0.0, "loading content right"):
		return false
	if not _expect_float(content.offset_bottom, 0.0, "loading content bottom"):
		return false
	var loading_image: Control = ui.get_node("Content/LoadingLayer/LoadingImage")
	if not _expect_int(loading_image.size_flags_horizontal, Control.SIZE_EXPAND_FILL, "loading image horizontal fill"):
		return false
	if not _expect_int(loading_image.size_flags_vertical, Control.SIZE_EXPAND_FILL, "loading image vertical fill"):
		return false
	return true


func _expect_full_bleed_gameplay_layout(ui: Node) -> bool:
	var content: Control = ui.get_node("Content")
	if not _expect_float(content.offset_left, 0.0, "gameplay content left"):
		return false
	if not _expect_float(content.offset_top, 0.0, "gameplay content top"):
		return false
	if not _expect_float(content.offset_right, 0.0, "gameplay content right"):
		return false
	if not _expect_float(content.offset_bottom, 0.0, "gameplay content bottom"):
		return false
	var gameplay_area: Control = ui.get_node("Content/GameplayArea")
	if not _expect_float(gameplay_area.custom_minimum_size.x, 2560.0, "gameplay area width"):
		return false
	if not _expect_float(gameplay_area.custom_minimum_size.y, 1440.0, "gameplay area height"):
		return false
	var gameplay_view: Control = ui.get_node("Content/GameplayArea/GameplayView")
	if not _expect_float(gameplay_view.scale.x, 2.4, "gameplay view scale x"):
		return false
	if not _expect_float(gameplay_view.scale.y, 2.4, "gameplay view scale y"):
		return false
	if not _expect_float(gameplay_view.position.x, 320.0, "gameplay view letterbox x"):
		return false
	if not _expect_float(gameplay_view.position.y, 0.0, "gameplay view letterbox y"):
		return false
	return true


func _expect_button_size(button: Button, label: String) -> bool:
	if not _expect_float(button.custom_minimum_size.x, EXPECTED_BUTTON_WIDTH, "%s width" % label):
		return false
	if not _expect_float(button.custom_minimum_size.y, EXPECTED_BUTTON_HEIGHT, "%s height" % label):
		return false
	return true


func _expect_bool(actual: bool, expected: bool, label: String) -> bool:
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


func _expect_string(actual: String, expected: String, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true
