extends SceneTree

const AudioManifestLoader = preload("res://scripts/audio_manifest_loader.gd")
const GameplayLoader = preload("res://scripts/gameplay_loader.gd")
const GameplayRuntime = preload("res://scripts/gameplay_runtime.gd")


func _init() -> void:
	var gameplay_loader = GameplayLoader.new()
	var chart: Dictionary = gameplay_loader.load_from_file("res://test/fixtures/gameplay.json")
	if not _expect_bool(chart.is_empty(), false, "gameplay fixture load"):
		return

	var audio_loader = AudioManifestLoader.new()
	var audio_manifest: Dictionary = audio_loader.load_from_file("res://test/fixtures/audio-manifest.json")
	if not _expect_bool(audio_manifest.is_empty(), false, "audio fixture load"):
		return

	if not _test_java_fps_timer(chart, audio_manifest):
		return
	if not _test_java_finish_waits_for_note_layer(audio_manifest):
		return
	if not _test_java_finish_ignores_chart_duration(audio_manifest):
		return
	if not _test_java_finish_uses_buffered_autoplay(audio_manifest):
		return
	if not _test_java_speed_misc_hotkeys(chart, audio_manifest):
		return
	if not _test_java_volume_misc_hotkeys(chart, audio_manifest):
		return
	if not _test_java_haste_mode_pitch_sync(audio_manifest):
		return
	if not _test_java_bga_events_follow_game_time(audio_manifest):
		return

	var runtime = GameplayRuntime.new()
	get_root().add_child(runtime)
	if not _expect_bool(runtime.start(chart, audio_manifest), true, "runtime start"):
		return
	if not _expect_bool(runtime.is_running(), true, "runtime running"):
		return

	runtime.advance_to(0.0)
	if not _expect_int(runtime.audio_play_event_count(), 1, "autoplay play event"):
		return

	var hit: Dictionary = runtime.press_action("vos_lane_1", 1000.0)
	if not _expect_bool(hit.get("accepted", false), true, "note hit accepted"):
		return
	if not _expect_int(runtime.audio_play_event_count(), 2, "note hit play event"):
		return
	if not _expect_bool(runtime.has_method("hud_state"), true, "runtime hud state method"):
		return
	var hud_state: Dictionary = runtime.hud_state()
	if not _expect_int(hud_state.get("score", 0), 200, "hud state score"):
		return
	if not _expect_int(hud_state.get("combo", 0), 1, "hud state combo"):
		return
	if not _expect_int(hud_state.get("jamBar", 0), 2, "hud state jam bar"):
		return
	if not _expect_int(hud_state.get("life", 0), 24000, "hud state life"):
		return
	if not _expect_int(hud_state.get("lifeLimit", 0), 24000, "hud state life limit"):
		return
	if not _expect_int(hud_state.get("elapsedMs", 0), 0, "hud state elapsed"):
		return
	var pressed_lanes: Array = hud_state.get("pressedLanes", [])
	if not _expect_int(pressed_lanes.size(), 1, "hud state pressed lane count"):
		return
	if not _expect_int(int(pressed_lanes[0]), 0, "hud state pressed lane"):
		return
	var judgment_event: Dictionary = hud_state.get("judgmentEvent", {})
	if not _expect_string(judgment_event.get("result", ""), "cool", "hud state judgment event result"):
		return
	if not _expect_int(judgment_event.get("lane", -1), 0, "hud state judgment event lane"):
		return
	var click_events: Array = hud_state.get("clickEvents", [])
	if not _expect_int(click_events.size(), 1, "hud state click event count"):
		return
	if not _expect_int(click_events[0].get("lane", -1), 0, "hud state click event lane"):
		return
	var status_texts: Array = hud_state.get("statusTexts", [])
	if not _expect_int(status_texts.size(), 3, "hud state status text count"):
		return
	if not _expect_string(str(status_texts[0]), "HI-SPEED: x1.0", "hud state speed status"):
		return
	if not _expect_string(str(status_texts[1]), "Current Measure: 1", "hud state measure status"):
		return
	if not _expect_string(str(status_texts[2]), "Game Speed: +0", "hud state game speed status"):
		return
	runtime.release_action("vos_lane_1", 1000.0)
	var released_state: Dictionary = runtime.hud_state()
	if not _expect_int(released_state.get("pressedLanes", []).size(), 0, "hud state released lane count"):
		return

	runtime.stop()
	if not _expect_bool(runtime.start(chart, audio_manifest), true, "runtime restart"):
		return
	runtime.advance_to(1000.0)
	var input_event := InputEventAction.new()
	input_event.action = "vos_lane_1"
	input_event.pressed = true
	runtime._unhandled_input(input_event)
	if not _expect_int(runtime.result().get("score", 0), 200, "input event hit score"):
		return
	if not _expect_int(runtime.audio_play_event_count(), 2, "input event audio count"):
		return

	runtime.advance_to(3000.0)
	if not _expect_bool(runtime.is_running(), true, "runtime keeps running at duration"):
		return
	runtime.advance_to(13000.0)
	if not _expect_bool(runtime.is_running(), true, "runtime keeps running at Java finish boundary"):
		return
	runtime.advance_to(13001.0)
	if not _expect_bool(runtime.is_running(), false, "runtime stops after Java finish delay"):
		return
	if not _expect_int(runtime.result().get("score", 0), 200, "runtime result score"):
		return

	runtime.free()
	quit(0)


func _test_java_fps_timer(chart: Dictionary, audio_manifest: Dictionary) -> bool:
	var long_chart := chart.duplicate(true)
	long_chart["durationMs"] = 65000
	long_chart["notes"] = [
		{"id": 1, "lane": 0, "startMs": 70000.0, "endMs": null, "sampleId": 1, "volume": 1.0, "pan": 0.0, "kind": "tap"},
	]
	var runtime = GameplayRuntime.new()
	get_root().add_child(runtime)
	if not _expect_bool(runtime.start(long_chart, audio_manifest), true, "fps timer runtime start"):
		return false

	var initial_state: Dictionary = runtime.hud_state()
	if not _expect_int(initial_state.get("fps", -1), 0, "initial fps counter"):
		return false
	if not _expect_int(initial_state.get("minute", -1), 0, "initial minute counter"):
		return false
	if not _expect_int(initial_state.get("second", -1), 0, "initial second counter"):
		return false

	for i in range(60):
		runtime.advance_to(float((i + 1) * 1000))

	var one_minute_state: Dictionary = runtime.hud_state()
	if not _expect_int(one_minute_state.get("fps", -1), 1, "java fps counter"):
		return false
	if not _expect_int(one_minute_state.get("minute", -1), 1, "java minute rollover"):
		return false
	if not _expect_int(one_minute_state.get("second", -1), 0, "java second rollover"):
		return false

	runtime.free()
	return true


func _test_java_speed_misc_hotkeys(chart: Dictionary, audio_manifest: Dictionary) -> bool:
	var runtime = GameplayRuntime.new()
	get_root().add_child(runtime)
	if not _expect_bool(runtime.start(chart, audio_manifest), true, "speed misc runtime start"):
		return false

	var initial_state: Dictionary = runtime.hud_state()
	var initial_status: Array = initial_state.get("statusTexts", [])
	if not _expect_string(str(initial_status[0]), "HI-SPEED: x1.0", "initial speed status"):
		return false
	if not _expect_float(float(initial_state.get("targetSpeed", -1.0)), 1.0, "initial target speed"):
		return false
	if not _expect_float(float(initial_state.get("renderSpeed", -1.0)), 1.0, "initial render speed"):
		return false

	var speed_up := InputEventAction.new()
	speed_up.action = "speed_up"
	speed_up.pressed = true
	runtime._unhandled_input(speed_up)
	var speed_up_state: Dictionary = runtime.hud_state()
	var speed_up_status: Array = speed_up_state.get("statusTexts", [])
	if not _expect_string(str(speed_up_status[0]), "HI-SPEED: x1.5", "speed up status"):
		return false
	if not _expect_float(float(speed_up_state.get("targetSpeed", -1.0)), 1.5, "speed up target speed"):
		return false
	if not _expect_float(float(speed_up_state.get("renderSpeed", -1.0)), 1.0, "speed up current speed waits for update"):
		return false

	runtime._unhandled_input(speed_up)
	var repeated_state: Dictionary = runtime.hud_state()
	if not _expect_float(float(repeated_state.get("targetSpeed", -1.0)), 1.5, "held speed up does not repeat"):
		return false

	runtime.advance_to(100.0)
	var smoothed_state: Dictionary = runtime.hud_state()
	if not _expect_float(float(smoothed_state.get("renderSpeed", -1.0)), 1.5, "speed up current speed reaches target"):
		return false

	var speed_up_release := InputEventAction.new()
	speed_up_release.action = "speed_up"
	speed_up_release.pressed = false
	runtime._unhandled_input(speed_up_release)
	runtime._unhandled_input(speed_up)
	var second_speed_up_state: Dictionary = runtime.hud_state()
	var second_speed_up_status: Array = second_speed_up_state.get("statusTexts", [])
	if not _expect_string(str(second_speed_up_status[0]), "HI-SPEED: x2.0", "second speed up status"):
		return false

	var speed_down := InputEventAction.new()
	speed_down.action = "speed_down"
	speed_down.pressed = true
	runtime._unhandled_input(speed_down)
	var speed_down_state: Dictionary = runtime.hud_state()
	var speed_down_status: Array = speed_down_state.get("statusTexts", [])
	if not _expect_string(str(speed_down_status[0]), "HI-SPEED: x1.5", "speed down status"):
		return false

	runtime.free()
	return true


func _test_java_volume_misc_hotkeys(chart: Dictionary, audio_manifest: Dictionary) -> bool:
	var runtime = GameplayRuntime.new()
	get_root().add_child(runtime)
	if not _expect_bool(runtime.start(chart, audio_manifest), true, "volume misc runtime start"):
		return false

	var initial_state: Dictionary = runtime.hud_state()
	if not _expect_float(float(initial_state.get("masterVolume", -1.0)), 1.0, "initial master volume"):
		return false
	if not _expect_float(float(initial_state.get("keyVolume", -1.0)), 1.0, "initial key volume"):
		return false
	if not _expect_float(float(initial_state.get("bgmVolume", -1.0)), 1.0, "initial bgm volume"):
		return false

	_send_input_action(runtime, "main_volume_down", true)
	var main_down_state: Dictionary = runtime.hud_state()
	if not _expect_float(float(main_down_state.get("masterVolume", -1.0)), 0.95, "main volume down"):
		return false

	_send_input_action(runtime, "main_volume_down", true)
	var repeated_main_down_state: Dictionary = runtime.hud_state()
	if not _expect_float(float(repeated_main_down_state.get("masterVolume", -1.0)), 0.95, "held main volume down does not repeat"):
		return false

	_send_input_action(runtime, "main_volume_down", false)
	_send_input_action(runtime, "main_volume_down", true)
	var second_main_down_state: Dictionary = runtime.hud_state()
	if not _expect_float(float(second_main_down_state.get("masterVolume", -1.0)), 0.9, "second main volume down"):
		return false

	_send_input_action(runtime, "main_volume_up", true)
	var main_up_state: Dictionary = runtime.hud_state()
	if not _expect_float(float(main_up_state.get("masterVolume", -1.0)), 0.95, "main volume up"):
		return false

	_send_input_action(runtime, "key_volume_down", true)
	var key_down_state: Dictionary = runtime.hud_state()
	if not _expect_float(float(key_down_state.get("keyVolume", -1.0)), 0.95, "key volume down"):
		return false

	_send_input_action(runtime, "bgm_volume_down", true)
	var bgm_down_state: Dictionary = runtime.hud_state()
	if not _expect_float(float(bgm_down_state.get("bgmVolume", -1.0)), 0.95, "bgm volume down"):
		return false

	runtime.free()
	return true


func _test_java_haste_mode_pitch_sync(audio_manifest: Dictionary) -> bool:
	var chart := {
		"schemaVersion": 1,
		"chartId": "vos:haste-mode",
		"format": "VOS",
		"judgmentType": "time",
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 8000,
		"hasteMode": true,
		"hasteModeNormalizeSpeed": true,
		"notes": [
			{"id": 1, "lane": 0, "startMs": 6100.0, "endMs": null, "sampleId": 1, "volume": 1.0, "pan": 0.0, "kind": "tap"},
			{"id": 2, "lane": 1, "startMs": 9200.0, "endMs": null, "sampleId": 1, "volume": 1.0, "pan": 0.0, "kind": "tap"},
		],
		"measures": [
			{"startMs": 0.0},
			{"startMs": 1000.0},
			{"startMs": 2000.0},
			{"startMs": 3000.0},
			{"startMs": 4000.0},
			{"startMs": 5000.0},
			{"startMs": 6000.0},
			{"startMs": 7000.0},
			{"startMs": 8000.0},
			{"startMs": 9000.0},
		],
		"autoPlayEvents": [],
	}
	var runtime = GameplayRuntime.new()
	get_root().add_child(runtime)
	if not _expect_bool(runtime.start(chart, audio_manifest), true, "haste runtime start"):
		return false

	var initial_state: Dictionary = runtime.hud_state()
	var initial_status: Array = initial_state.get("statusTexts", [])
	if not _expect_string(str(initial_status[2]), "Game Speed: +0", "initial haste status"):
		return false
	if not _expect_float(float(initial_state.get("audioPitchScale", -1.0)), 1.0, "initial haste pitch scale"):
		return false

	runtime.advance_to(6000.0)
	runtime.advance_to(6001.0)
	var haste_state: Dictionary = runtime.hud_state()
	var haste_status: Array = haste_state.get("statusTexts", [])
	if not _expect_string(str(haste_status[2]), "Game Speed: +1", "haste pitch status"):
		return false
	var expected_pitch := pow(2.0, 1.0 / 12.0)
	if not _expect_float(float(haste_state.get("audioPitchScale", -1.0)), expected_pitch, "haste audio pitch scale"):
		return false

	var hit: Dictionary = runtime.press_action("vos_lane_1", 6100.0)
	if not _expect_bool(hit.get("accepted", false), true, "haste note hit"):
		return false
	var events: Array[Dictionary] = runtime._audio_pool.play_events()
	if not _expect_int(events.size(), 1, "haste audio event count"):
		return false
	if not _expect_float(float(events[0].get("pitchScale", -1.0)), expected_pitch, "haste event pitch scale"):
		return false

	runtime.advance_to(9000.0)
	var accelerated_hit: Dictionary = runtime.press_action("vos_lane_2")
	if not _expect_bool(accelerated_hit.get("accepted", false), true, "haste game time hit accepted"):
		return false
	var expected_hit_time := 9200.0 - (6001.0 + (9000.0 - 6001.0) * expected_pitch)
	if not _expect_float(float(accelerated_hit.get("hitTime", 0.0)), expected_hit_time, "haste game time hit window"):
		return false

	runtime.free()
	return true


func _test_java_bga_events_follow_game_time(audio_manifest: Dictionary) -> bool:
	var chart := {
		"schemaVersion": 1,
		"chartId": "vos:bga-events",
		"format": "VOS",
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 3000,
		"notes": [],
		"autoPlayEvents": [],
		"bgaEvents": [
			{"startMs": 500.0, "spriteId": 7},
			{"startMs": 1000.0, "spriteId": 8},
			{"startMs": 12000.0, "spriteId": 9},
		],
	}
	var runtime = GameplayRuntime.new()
	get_root().add_child(runtime)
	if not _expect_bool(runtime.start(chart, audio_manifest), true, "bga runtime start"):
		return false

	var initial_state: Dictionary = runtime.hud_state()
	if not _expect_bool(initial_state.has("currentBgaEvent"), false, "initial bga event absent"):
		return false

	runtime.advance_to(500.0)
	var first_bga_state: Dictionary = runtime.hud_state()
	var first_bga_event: Dictionary = first_bga_state.get("currentBgaEvent", {})
	if not _expect_int(first_bga_event.get("spriteId", -1), 7, "first bga sprite id"):
		return false
	if not _expect_float(first_bga_event.get("startMs", -1.0), 500.0, "first bga start"):
		return false

	runtime.advance_to(999.0)
	var held_bga_state: Dictionary = runtime.hud_state()
	var held_bga_event: Dictionary = held_bga_state.get("currentBgaEvent", {})
	if not _expect_int(held_bga_event.get("spriteId", -1), 7, "held bga sprite id"):
		return false

	runtime.advance_to(1000.0)
	var second_bga_state: Dictionary = runtime.hud_state()
	var second_bga_event: Dictionary = second_bga_state.get("currentBgaEvent", {})
	if not _expect_int(second_bga_event.get("spriteId", -1), 8, "second bga sprite id"):
		return false

	runtime.advance_to(10001.0)
	if not _expect_bool(runtime.is_running(), true, "future bga keeps runtime running"):
		return false
	runtime.advance_to(12000.0)
	var future_bga_state: Dictionary = runtime.hud_state()
	var future_bga_event: Dictionary = future_bga_state.get("currentBgaEvent", {})
	if not _expect_int(future_bga_event.get("spriteId", -1), 9, "future bga sprite id"):
		return false

	runtime.free()
	return true


func _test_java_finish_uses_buffered_autoplay(audio_manifest: Dictionary) -> bool:
	var chart := {
		"schemaVersion": 1,
		"chartId": "vos:future-autoplay",
		"format": "VOS",
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 3000,
		"notes": [],
		"autoPlayEvents": [
			{"startMs": 12000.0, "sampleId": 1, "volume": 1.0, "pan": 0.0},
		],
	}
	var runtime = GameplayRuntime.new()
	get_root().add_child(runtime)
	if not _expect_bool(runtime.start(chart, audio_manifest), true, "future autoplay runtime start"):
		return false

	runtime.advance_to(0.0)
	runtime.advance_to(10001.0)
	if not _expect_bool(runtime.is_running(), false, "future autoplay is already buffered"):
		return false
	if not _expect_int(runtime.audio_play_event_count(), 0, "future autoplay not played early"):
		return false

	runtime.free()
	return true


func _test_java_finish_ignores_chart_duration(audio_manifest: Dictionary) -> bool:
	var chart := {
		"schemaVersion": 1,
		"chartId": "vos:long-duration-short-notes",
		"format": "VOS",
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 65000,
		"notes": [
			{"id": 1, "lane": 0, "startMs": 1000.0, "endMs": null, "sampleId": 1, "volume": 1.0, "pan": 0.0, "kind": "tap"},
		],
		"autoPlayEvents": [],
	}
	var runtime = GameplayRuntime.new()
	get_root().add_child(runtime)
	if not _expect_bool(runtime.start(chart, audio_manifest), true, "long duration runtime start"):
		return false

	var hit: Dictionary = runtime.press_action("vos_lane_1", 1000.0)
	if not _expect_bool(hit.get("accepted", false), true, "long duration note hit"):
		return false
	runtime.advance_to(1000.0)
	if not _expect_bool(runtime.is_running(), true, "long duration finish delay starts"):
		return false
	runtime.advance_to(11001.0)
	if not _expect_bool(runtime.is_running(), false, "long duration runtime ignores chart duration"):
		return false

	runtime.free()
	return true


func _test_java_finish_waits_for_note_layer(audio_manifest: Dictionary) -> bool:
	var chart := {
		"schemaVersion": 1,
		"chartId": "vos:late-note",
		"format": "VOS",
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 3000,
		"notes": [
			{"id": 1, "lane": 0, "startMs": 12000.0, "endMs": null, "sampleId": 1, "volume": 1.0, "pan": 0.0, "kind": "tap"},
		],
		"autoPlayEvents": [],
	}
	var runtime = GameplayRuntime.new()
	get_root().add_child(runtime)
	if not _expect_bool(runtime.start(chart, audio_manifest), true, "late note runtime start"):
		return false

	runtime.advance_to(3000.0)
	if not _expect_bool(runtime.is_running(), true, "late note runtime keeps running at duration"):
		return false
	runtime.advance_to(13001.0)
	if not _expect_bool(runtime.is_running(), true, "late note runtime waits for note layer"):
		return false
	runtime.advance_to(23002.0)
	if not _expect_bool(runtime.is_running(), false, "late note runtime stops after layer delay"):
		return false

	runtime.free()
	return true


func _send_input_action(runtime: GameplayRuntime, action: String, pressed: bool) -> void:
	var input_event := InputEventAction.new()
	input_event.action = action
	input_event.pressed = pressed
	runtime._unhandled_input(input_event)


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
