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
	store.set_autoplay_enabled(true)
	store.set_autosound_enabled(true)
	store.set_channel_modifier("Mirror")
	store.set_speed_type("RegulSpeed")
	store.set_speed_multiplier(2.0)
	store.set_visibility_modifier("Hidden")
	store.set_judgment_type("time")
	if not _expect_bool(store.has_method("set_audio_latency_ms"), true, "audio latency setter"):
		return
	if not _expect_bool(store.has_method("set_display_latency_ms"), true, "display latency setter"):
		return
	store.set_audio_latency_ms(120.0)
	store.set_display_latency_ms(45.0)
	if not _expect_bool(store.has_method("set_master_volume"), true, "master volume setter"):
		return
	if not _expect_bool(store.has_method("set_key_volume"), true, "key volume setter"):
		return
	if not _expect_bool(store.has_method("set_bgm_volume"), true, "bgm volume setter"):
		return
	store.set_master_volume(1.5)
	store.set_key_volume(-0.5)
	store.set_bgm_volume(0.75)

	if not _expect_array(store.song_directories(), ["/tmp/vos"], "song directories"):
		return
	if not _expect_bool(store.fullscreen_enabled(), true, "fullscreen enabled"):
		return
	if not _expect_array(store.key_bindings(), ["A", "S", "D", "Space", "J", "K", "L"], "key bindings"):
		return
	if not _expect_bool(store.autoplay_enabled(), true, "autoplay enabled"):
		return
	if not _expect_bool(store.autosound_enabled(), true, "autosound enabled"):
		return
	if not _expect_string(store.channel_modifier(), "Mirror", "channel modifier"):
		return
	if not _expect_string(store.speed_type(), "RegulSpeed", "speed type"):
		return
	if not _expect_float(store.speed_multiplier(), 2.0, "speed multiplier"):
		return
	if not _expect_string(store.visibility_modifier(), "Hidden", "visibility modifier"):
		return
	if not _expect_string(store.judgment_type(), "time", "judgment type"):
		return
	if not _expect_float(store.audio_latency_ms(), 120.0, "audio latency"):
		return
	if not _expect_float(store.display_latency_ms(), 45.0, "display latency"):
		return
	if not _expect_float(store.master_volume(), 1.0, "master volume clamp"):
		return
	if not _expect_float(store.key_volume(), 0.0, "key volume clamp"):
		return
	if not _expect_float(store.bgm_volume(), 0.75, "bgm volume"):
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


func _expect_float(actual: float, expected: float, label: String) -> bool:
	if absf(actual - expected) > 0.0001:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true
