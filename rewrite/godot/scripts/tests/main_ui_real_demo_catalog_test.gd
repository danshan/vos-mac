extends SceneTree

const AppState = preload("res://scripts/app_state.gd")
const MainUi = preload("res://scripts/main_ui.gd")

const DEMO_DIRECTORY := "/Users/honghao.shan/Music/demo"


func _init() -> void:
	if not DirAccess.dir_exists_absolute(DEMO_DIRECTORY):
		print("Skipping real demo catalog test; demo directory is not available.")
		quit(0)
		return

	var settings_path := "user://main-ui-real-demo-catalog-test.cfg"
	_remove_settings_file(settings_path)

	var ui = MainUi.new()
	ui.set_settings_path(settings_path)
	get_root().add_child(ui)
	ui.build()

	ui.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	_settings_node(ui, "SongDirectoryDialog").emit_signal("dir_selected", DEMO_DIRECTORY)
	ui.get_node("Content/BackButton").emit_signal("pressed")
	ui.get_node("Content/Menu/StartButton").emit_signal("pressed")

	if not _expect_string(ui.current_state(), AppState.SONG_SELECT, "song select state"):
		return
	if not _expect_bool(_has_song_text_containing(ui, "Age of empire"), true, "real demo VOS song"):
		return
	if not _expect_bool(_has_song_text_containing(ui, "Nocturne.osz"), true, "real demo OSU song"):
		return
	if not _expect_bool(_has_song_text_containing(ui, "Bach Alive"), true, "real demo OJN song"):
		return
	if not _expect_bool(_has_song_text_containing(ui, "Hunch"), true, "second real demo OJN song"):
		return

	ui.free()
	quit(0)


func _settings_node(ui: Node, node_name: String) -> Variant:
	return ui.get_node("Content").find_child(node_name, true, false)


func _has_song_text_containing(ui: Node, text: String) -> bool:
	var song_list: Node = ui.get_node("Content/SongSelectScroll/SongList")
	for child: Node in song_list.get_children():
		if (child is Button or child is Label) and str(child.get("text")).contains(text):
			return true
	return false


func _remove_settings_file(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


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
