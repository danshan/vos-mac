extends SceneTree

const SettingsStore = preload("res://scripts/settings_store.gd")

func _init() -> void:
	var store = SettingsStore.new()
	var input_directories: Array[String] = ["/tmp/vos"]

	store.set_song_directories(input_directories)
	input_directories.append("/tmp/input-mutated")
	store.set_fullscreen_enabled(true)
	if not _expect_bool(store.has_method("set_vsync_enabled"), true, "vsync setter"):
		return
	if not _expect_bool(store.has_method("vsync_enabled"), true, "vsync getter"):
		return
	store.set_vsync_enabled(false)
	var input_bindings: Array[String] = ["A", "S", "D", "Space", "J", "K", "L"]
	store.set_key_bindings(input_bindings)
	input_bindings[0] = "Mutated"
	if not _expect_bool(store.has_method("set_misc_key_bindings"), true, "misc key binding setter"):
		return
	if not _expect_bool(store.has_method("misc_key_bindings"), true, "misc key binding getter"):
		return
	var input_misc_bindings := {
		"speed_up": "PageUp",
		"main_volume_down": "Minus",
	}
	if not _expect_bool(store.set_misc_key_bindings(input_misc_bindings), true, "set misc key bindings"):
		return
	input_misc_bindings["speed_up"] = "Mutated"
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
	if not _expect_bool(store.has_method("set_autosync_mode"), true, "autosync mode setter"):
		return
	if not _expect_bool(store.has_method("autosync_mode"), true, "autosync mode getter"):
		return
	store.set_audio_latency_ms(120.0)
	store.set_display_latency_ms(45.0)
	store.set_autosync_mode("audio")
	if not _expect_bool(store.has_method("set_master_volume"), true, "master volume setter"):
		return
	if not _expect_bool(store.has_method("set_key_volume"), true, "key volume setter"):
		return
	if not _expect_bool(store.has_method("set_bgm_volume"), true, "bgm volume setter"):
		return
	store.set_master_volume(1.5)
	store.set_key_volume(-0.5)
	store.set_bgm_volume(0.75)
	if not _expect_bool(store.has_method("set_haste_mode_enabled"), true, "haste mode setter"):
		return
	if not _expect_bool(store.has_method("set_haste_mode_normalize_speed"), true, "haste normalize setter"):
		return
	store.set_haste_mode_enabled(true)
	store.set_haste_mode_normalize_speed(false)
	if not _expect_bool(store.has_method("set_start_paused_enabled"), true, "start paused setter"):
		return
	store.set_start_paused_enabled(true)
	if not _expect_bool(store.has_method("set_local_matching_server"), true, "local matching server setter"):
		return
	if not _expect_bool(store.has_method("local_matching_server"), true, "local matching server getter"):
		return
	store.set_local_matching_server(" localhost:1234 ")
	if not _expect_bool(store.has_method("set_settings_language"), true, "settings language setter"):
		return
	if not _expect_bool(store.has_method("settings_language"), true, "settings language getter"):
		return
	store.set_settings_language("zh")

	if not _expect_array(store.song_directories(), ["/tmp/vos"], "song directories"):
		return
	if not _expect_bool(store.fullscreen_enabled(), true, "fullscreen enabled"):
		return
	if not _expect_bool(store.vsync_enabled(), false, "vsync enabled"):
		return
	if not _expect_array(store.key_bindings(), ["A", "S", "D", "Space", "J", "K", "L"], "key bindings"):
		return
	if not _expect_dictionary(store.misc_key_bindings(), {
			"speed_up": "PageUp",
			"speed_down": "Down",
			"main_volume_up": "2",
			"main_volume_down": "Minus",
			"key_volume_up": "4",
			"key_volume_down": "3",
			"bgm_volume_up": "6",
			"bgm_volume_down": "5",
	}, "misc key bindings"):
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
	if not _expect_string(store.autosync_mode(), "audio", "autosync mode"):
		return
	store.set_autosync_mode("invalid")
	if not _expect_string(store.autosync_mode(), "", "invalid autosync mode falls back"):
		return
	store.set_autosync_mode("audio")
	if not _expect_float(store.master_volume(), 1.0, "master volume clamp"):
		return
	if not _expect_float(store.key_volume(), 0.0, "key volume clamp"):
		return
	if not _expect_float(store.bgm_volume(), 0.75, "bgm volume"):
		return
	if not _expect_bool(store.haste_mode_enabled(), true, "haste mode enabled"):
		return
	if not _expect_bool(store.haste_mode_normalize_speed(), false, "haste normalize speed"):
		return
	if not _expect_bool(store.start_paused_enabled(), true, "start paused enabled"):
		return
	if not _expect_string(store.local_matching_server(), "localhost:1234", "local matching server"):
		return
	if not _expect_string(store.settings_language(), "zh", "settings language"):
		return
	store.set_settings_language("invalid")
	if not _expect_string(store.settings_language(), "en", "invalid settings language falls back"):
		return
	store.set_settings_language("zh")

	var directories: Array[String] = store.song_directories()
	directories.append("/tmp/other")
	if not _expect_array(store.song_directories(), ["/tmp/vos"], "defensive copy"):
		return

	var bindings: Array[String] = store.key_bindings()
	bindings[1] = "Other"
	if not _expect_array(store.key_bindings(), ["A", "S", "D", "Space", "J", "K", "L"], "key binding defensive copy"):
		return
	var misc_bindings: Dictionary = store.misc_key_bindings()
	misc_bindings["speed_up"] = "Other"
	if not _expect_string(str(store.misc_key_bindings().get("speed_up", "")), "PageUp", "misc key binding defensive copy"):
		return

	if not _expect_bool(store.has_method("save_to_file"), true, "settings save method"):
		return
	if not _expect_bool(store.has_method("load_from_file"), true, "settings load method"):
		return
	var save_path := "user://settings-store-roundtrip.cfg"
	if not _expect_bool(store.save_to_file(save_path), true, "settings save result"):
		return
	var loaded_store = SettingsStore.new()
	if not _expect_bool(loaded_store.load_from_file(save_path), true, "settings load result"):
		return
	if not _expect_array(loaded_store.song_directories(), ["/tmp/vos"], "loaded song directories"):
		return
	if not _expect_bool(loaded_store.fullscreen_enabled(), true, "loaded fullscreen enabled"):
		return
	if not _expect_bool(loaded_store.vsync_enabled(), false, "loaded vsync enabled"):
		return
	if not _expect_array(loaded_store.key_bindings(), ["A", "S", "D", "Space", "J", "K", "L"], "loaded key bindings"):
		return
	if not _expect_dictionary(loaded_store.misc_key_bindings(), {
			"speed_up": "PageUp",
			"speed_down": "Down",
			"main_volume_up": "2",
			"main_volume_down": "Minus",
			"key_volume_up": "4",
			"key_volume_down": "3",
			"bgm_volume_up": "6",
			"bgm_volume_down": "5",
	}, "loaded misc key bindings"):
		return
	if not _expect_bool(loaded_store.autoplay_enabled(), true, "loaded autoplay enabled"):
		return
	if not _expect_bool(loaded_store.autosound_enabled(), true, "loaded autosound enabled"):
		return
	if not _expect_float(loaded_store.audio_latency_ms(), 120.0, "loaded audio latency"):
		return
	if not _expect_float(loaded_store.display_latency_ms(), 45.0, "loaded display latency"):
		return
	if not _expect_string(loaded_store.autosync_mode(), "audio", "loaded autosync mode"):
		return
	if not _expect_float(loaded_store.master_volume(), 1.0, "loaded master volume"):
		return
	if not _expect_float(loaded_store.key_volume(), 0.0, "loaded key volume"):
		return
	if not _expect_float(loaded_store.bgm_volume(), 0.75, "loaded bgm volume"):
		return
	if not _expect_bool(loaded_store.haste_mode_enabled(), true, "loaded haste mode enabled"):
		return
	if not _expect_bool(loaded_store.haste_mode_normalize_speed(), false, "loaded haste normalize speed"):
		return
	if not _expect_bool(loaded_store.start_paused_enabled(), true, "loaded start paused enabled"):
		return
	if not _expect_string(loaded_store.local_matching_server(), "localhost:1234", "loaded local matching server"):
		return
	if not _expect_string(loaded_store.channel_modifier(), "Mirror", "loaded channel modifier"):
		return
	if not _expect_string(loaded_store.speed_type(), "RegulSpeed", "loaded speed type"):
		return
	if not _expect_float(loaded_store.speed_multiplier(), 2.0, "loaded speed multiplier"):
		return
	if not _expect_string(loaded_store.visibility_modifier(), "Hidden", "loaded visibility modifier"):
		return
	if not _expect_string(loaded_store.judgment_type(), "time", "loaded judgment type"):
		return
	if not _expect_string(loaded_store.settings_language(), "zh", "loaded settings language"):
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


func _expect_dictionary(actual: Dictionary, expected: Dictionary, label: String) -> bool:
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
