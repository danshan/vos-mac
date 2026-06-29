extends SceneTree

const SettingsStore = preload("res://scripts/settings_store.gd")

func _init() -> void:
	var store = SettingsStore.new()
	var input_directories: Array[String] = ["/tmp/vos"]

	store.set_song_directories(input_directories)
	input_directories.append("/tmp/input-mutated")
	store.set_fullscreen_enabled(true)

	if not _expect_array(store.song_directories(), ["/tmp/vos"], "song directories"):
		return
	if not _expect_bool(store.fullscreen_enabled(), true, "fullscreen enabled"):
		return

	var directories: Array[String] = store.song_directories()
	directories.append("/tmp/other")
	if not _expect_array(store.song_directories(), ["/tmp/vos"], "defensive copy"):
		return

	quit(0)


func _expect_array(actual: Array[String], expected: Array[String], label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true


func _expect_bool(actual: bool, expected: bool, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true
