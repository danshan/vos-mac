extends SceneTree

const SettingsStore = preload("res://scripts/settings_store.gd")

func _init() -> void:
	var store = SettingsStore.new()
	var input_directories: Array[String] = ["/tmp/vos"]

	store.set_song_directories(input_directories)
	input_directories.append("/tmp/input-mutated")
	store.set_fullscreen_enabled(true)
	var input_bindings: Array[String] = ["A", "S", "D", "Space", "J", "K", "L"]
	store.set_key_bindings(input_bindings)
	input_bindings[0] = "Mutated"
	store.set_channel_modifier("Mirror")

	if not _expect_array(store.song_directories(), ["/tmp/vos"], "song directories"):
		return
	if not _expect_bool(store.fullscreen_enabled(), true, "fullscreen enabled"):
		return
	if not _expect_array(store.key_bindings(), ["A", "S", "D", "Space", "J", "K", "L"], "key bindings"):
		return
	if not _expect_string(store.channel_modifier(), "Mirror", "channel modifier"):
		return

	var directories: Array[String] = store.song_directories()
	directories.append("/tmp/other")
	if not _expect_array(store.song_directories(), ["/tmp/vos"], "defensive copy"):
		return

	var bindings: Array[String] = store.key_bindings()
	bindings[1] = "Other"
	if not _expect_array(store.key_bindings(), ["A", "S", "D", "Space", "J", "K", "L"], "key binding defensive copy"):
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


func _expect_string(actual: String, expected: String, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true
