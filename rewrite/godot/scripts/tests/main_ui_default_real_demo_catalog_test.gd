extends SceneTree

const AppState = preload("res://scripts/app_state.gd")
const MainUi = preload("res://scripts/main_ui.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const DEMO_DIRECTORY := "/Users/honghao.shan/Music/demo"
const DEFAULT_SETTINGS_PATH := "user://settings.cfg"


func _init() -> void:
	if not DirAccess.dir_exists_absolute(DEMO_DIRECTORY):
		print("Skipping default real demo catalog test; demo directory is not available.")
		quit(0)
		return

	var store = SettingsStore.new()
	if not store.load_from_file(DEFAULT_SETTINGS_PATH):
		print("Skipping default real demo catalog test; default settings are not available.")
		quit(0)
		return
	if not store.song_directories().has(DEMO_DIRECTORY):
		print("Skipping default real demo catalog test; default settings do not point at the demo directory.")
		quit(0)
		return

	var ui = MainUi.new()
	get_root().add_child(ui)
	ui.build()

	ui.get_node("Content/Menu/StartButton").emit_signal("pressed")

	if not _expect_string(ui.current_state(), AppState.SONG_SELECT, "song select state"):
		return
	if not _expect_bool(_has_song_text_containing(ui, "Age of empire"), true, "default demo VOS song"):
		return
	if not _expect_bool(_has_song_text_containing(ui, "Bach Alive"), true, "default demo OJN song"):
		return
	if not _expect_bool(_has_song_text_containing(ui, "Hunch"), true, "default second demo OJN song"):
		return

	ui.free()
	quit(0)


func _has_song_text_containing(ui: Node, text: String) -> bool:
	var song_list: Node = ui.get_node("Content/SongSelectScroll/SongList")
	for child: Node in song_list.get_children():
		if (child is Button or child is Label) and str(child.get("text")).contains(text):
			return true
	return false


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
