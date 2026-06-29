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
	if not _test_java_speed_status_preserves_multiplier_text(chart, audio_manifest):
		return
	if not _test_java_volume_misc_hotkeys(chart, audio_manifest):
		return
	if not _test_custom_misc_key_bindings(chart, audio_manifest):
		return
	if not _test_java_initial_volume_options(chart, audio_manifest):
		return
	if not _test_java_haste_mode_pitch_sync(audio_manifest):
		return
	if not _test_java_bga_events_follow_game_time(audio_manifest):
		return
	if not _test_java_bga_events_consume_one_per_frame(audio_manifest):
		return
	if not _test_java_manual_start_gates_game_time(audio_manifest):
		return
	if not _test_java_latency_splits_judgment_display_and_autosound(audio_manifest):
		return
	if not _test_java_buffered_visual_entities_match_render_window(audio_manifest):
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


func _test_java_speed_status_preserves_multiplier_text(chart: Dictionary, audio_manifest: Dictionary) -> bool:
	var speed_chart := chart.duplicate(true)
	speed_chart["speedMultiplier"] = 1.25
	var runtime = GameplayRuntime.new()
	get_root().add_child(runtime)
	if not _expect_bool(runtime.start(speed_chart, audio_manifest), true, "speed text runtime start"):
		return false

	var state: Dictionary = runtime.hud_state()
	var status_texts: Array = state.get("statusTexts", [])
	if not _expect_string(str(status_texts[0]), "HI-SPEED: x1.25", "speed multiplier Java text"):
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


func _test_custom_misc_key_bindings(chart: Dictionary, audio_manifest: Dictionary) -> bool:
	var runtime = GameplayRuntime.new()
	get_root().add_child(runtime)
	if not _expect_bool(runtime.has_method("set_misc_key_bindings"), true, "runtime misc key binding setter"):
		return false
	if not _expect_bool(runtime.set_misc_key_bindings({
			"speed_up": "PageUp",
			"main_volume_down": "Minus",
	}), true, "runtime set misc key bindings"):
		return false
	if not _expect_bool(runtime.start(chart, audio_manifest), true, "custom misc runtime start"):
		return false
	if not _expect_int(_keycode_for_action("speed_up"), OS.find_keycode_from_string("PageUp"), "runtime speed up keycode"):
		return false
	if not _expect_int(_keycode_for_action("main_volume_down"), OS.find_keycode_from_string("Minus"), "runtime main volume down keycode"):
		return false

	runtime.free()
	return true


func _test_java_initial_volume_options(chart: Dictionary, audio_manifest: Dictionary) -> bool:
	var volume_chart: Dictionary = chart.duplicate(true)
	volume_chart["masterVolume"] = 0.5
	volume_chart["keyVolume"] = 0.25
	volume_chart["bgmVolume"] = 0.75

	var runtime = GameplayRuntime.new()
	get_root().add_child(runtime)
	if not _expect_bool(runtime.start(volume_chart, audio_manifest), true, "initial volume runtime start"):
		return false

	var initial_state: Dictionary = runtime.hud_state()
	if not _expect_float(float(initial_state.get("masterVolume", -1.0)), 0.5, "configured master volume"):
		return false
	if not _expect_float(float(initial_state.get("keyVolume", -1.0)), 0.25, "configured key volume"):
		return false
	if not _expect_float(float(initial_state.get("bgmVolume", -1.0)), 0.75, "configured bgm volume"):
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
	var expected_hit_time := (9200.0 - (6001.0 + (9000.0 - 6001.0) * expected_pitch)) / expected_pitch
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


func _test_java_bga_events_consume_one_per_frame(audio_manifest: Dictionary) -> bool:
	var chart := {
		"schemaVersion": 1,
		"chartId": "vos:bga-event-queue",
		"format": "VOS",
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 3000,
		"notes": [],
		"autoPlayEvents": [],
		"bgaEvents": [
			{"startMs": 1000.0, "spriteId": 7},
			{"startMs": 1000.0, "spriteId": 8},
		],
	}
	var runtime = GameplayRuntime.new()
	get_root().add_child(runtime)
	if not _expect_bool(runtime.start(chart, audio_manifest), true, "bga queue runtime start"):
		return false

	runtime.advance_to(1000.0)
	var first_state: Dictionary = runtime.hud_state()
	var first_event: Dictionary = first_state.get("currentBgaEvent", {})
	if not _expect_int(first_event.get("spriteId", -1), 7, "first queued bga sprite id"):
		return false

	var repeated_state: Dictionary = runtime.hud_state()
	var repeated_event: Dictionary = repeated_state.get("currentBgaEvent", {})
	if not _expect_int(repeated_event.get("spriteId", -1), 7, "queued bga holds within same frame"):
		return false

	runtime.advance_to(1001.0)
	var second_state: Dictionary = runtime.hud_state()
	var second_event: Dictionary = second_state.get("currentBgaEvent", {})
	if not _expect_int(second_event.get("spriteId", -1), 8, "second queued bga sprite id"):
		return false

	runtime.free()
	return true


func _test_java_manual_start_gates_game_time(audio_manifest: Dictionary) -> bool:
	var chart := {
		"schemaVersion": 1,
		"chartId": "vos:manual-start",
		"format": "VOS",
		"manualStart": true,
		"judgmentType": "time",
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 3000,
		"notes": [
			{"id": 1, "lane": 0, "startMs": 0.0, "endMs": null, "sampleId": 1, "volume": 1.0, "pan": 0.0, "kind": "tap"},
		],
		"autoPlayEvents": [],
	}
	var runtime = GameplayRuntime.new()
	get_root().add_child(runtime)
	if not _expect_bool(runtime.start(chart, audio_manifest), true, "manual start runtime start"):
		return false

	runtime.advance_to(1000.0)
	var waiting_state: Dictionary = runtime.hud_state()
	if not _expect_int(waiting_state.get("elapsedMs", -1), 1000, "manual start elapsed advances"):
		return false
	if not _expect_int(waiting_state.get("gameTimeMs", -1), 0, "manual start game time waits"):
		return false
	if not _expect_bool(bool(waiting_state.get("gameStarted", true)), false, "manual start game started state waits"):
		return false
	var waiting_status: Array = waiting_state.get("statusTexts", [])
	if not _expect_string(str(waiting_status[3]), "Press any note button to start the game.", "manual start status"):
		return false

	var hit: Dictionary = runtime.press_action("vos_lane_1")
	if not _expect_bool(hit.get("accepted", false), true, "manual start first input accepted"):
		return false
	var started_state: Dictionary = runtime.hud_state()
	var started_status: Array = started_state.get("statusTexts", [])
	if not _expect_int(started_status.size(), 3, "manual start prompt clears"):
		return false
	if not _expect_bool(bool(started_state.get("gameStarted", false)), true, "manual start game started state begins"):
		return false
	if not _expect_int(started_state.get("gameTimeMs", -1), 0, "manual start input begins at zero"):
		return false

	runtime.advance_to(1500.0)
	var running_state: Dictionary = runtime.hud_state()
	if not _expect_int(running_state.get("gameTimeMs", -1), 500, "manual start game time after input"):
		return false

	runtime.free()
	return true


func _test_java_latency_splits_judgment_display_and_autosound(audio_manifest: Dictionary) -> bool:
	var chart := {
		"schemaVersion": 1,
		"chartId": "vos:latency-split",
		"format": "VOS",
		"autosound": true,
		"judgmentType": "time",
		"audioLatencyMs": 100.0,
		"displayLatencyMs": 250.0,
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 3000,
		"measures": [
			{"startMs": 1000.0},
		],
		"notes": [
			{"id": 1, "lane": 0, "startMs": 1000.0, "endMs": null, "sampleId": 1, "volume": 1.0, "pan": 0.0, "kind": "tap"},
		],
		"autoPlayEvents": [
			{"startMs": 1000.0, "sampleId": 1, "volume": 1.0, "pan": 0.0},
		],
		"bgaEvents": [
			{"startMs": 1000.0, "spriteId": 7},
		],
	}
	var runtime = GameplayRuntime.new()
	get_root().add_child(runtime)
	if not _expect_bool(runtime.start(chart, audio_manifest), true, "latency runtime start"):
		return false

	runtime.advance_to(1000.0)
	var delayed_state: Dictionary = runtime.hud_state()
	if not _expect_int(delayed_state.get("gameTimeMs", -1), 1000, "latency game time"):
		return false
	if not _expect_int(delayed_state.get("judgmentTimeMs", -1), 900, "latency judgment time"):
		return false
	if not _expect_int(delayed_state.get("displayTimeMs", -1), 1150, "latency display time"):
		return false
	if not _expect_int(runtime.audio_play_event_count(), 2, "latency autosound uses game time"):
		return false
	var delayed_status: Array = delayed_state.get("statusTexts", [])
	if not _expect_string(str(delayed_status[1]), "Current Measure: 1", "latency measure status uses game time"):
		return false
	var delayed_hidden_measures: Array = delayed_state.get("hiddenMeasures", [])
	if not _expect_int(delayed_hidden_measures.size(), 1, "latency hidden measure count"):
		return false
	if not _expect_int(int(delayed_hidden_measures[0]), 0, "latency hidden measure index"):
		return false
	if not _expect_bool(delayed_state.has("currentBgaEvent"), false, "latency bga waits for judgment time"):
		return false

	var hit: Dictionary = runtime.press_action("vos_lane_1")
	if not _expect_float(float(hit.get("hitTime", -1.0)), 100.0, "latency input uses judgment time"):
		return false
	if not _expect_int(runtime.audio_play_event_count(), 2, "latency autosound avoids duplicate note keysound"):
		return false

	runtime.advance_to(1100.0)
	var caught_up_state: Dictionary = runtime.hud_state()
	var caught_up_status: Array = caught_up_state.get("statusTexts", [])
	if not _expect_int(caught_up_state.get("judgmentTimeMs", -1), 1000, "latency caught up judgment time"):
		return false
	if not _expect_string(str(caught_up_status[1]), "Current Measure: 1", "latency caught up measure"):
		return false
	var caught_up_bga: Dictionary = caught_up_state.get("currentBgaEvent", {})
	if not _expect_int(caught_up_bga.get("spriteId", -1), 7, "latency caught up bga"):
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


func _test_java_buffered_visual_entities_match_render_window(audio_manifest: Dictionary) -> bool:
	var note_chart := {
		"schemaVersion": 1,
		"chartId": "vos:buffered-visual-notes",
		"format": "VOS",
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 8000,
		"notes": [
			{"id": 1, "lane": 0, "startMs": 1000.0, "endMs": null, "sampleId": 1, "volume": 1.0, "pan": 0.0, "kind": "tap"},
			{"id": 2, "lane": 1, "startMs": 3000.0, "endMs": null, "sampleId": 1, "volume": 1.0, "pan": 0.0, "kind": "tap"},
			{"id": 3, "lane": 2, "startMs": 6000.0, "endMs": null, "sampleId": 1, "volume": 1.0, "pan": 0.0, "kind": "tap"},
		],
		"autoPlayEvents": [],
	}
	var note_runtime = GameplayRuntime.new()
	get_root().add_child(note_runtime)
	if not _expect_bool(note_runtime.start(note_chart, audio_manifest), true, "buffered notes runtime start"):
		return false
	var initial_note_state: Dictionary = note_runtime.hud_state()
	var initial_hidden_notes: Array = initial_note_state.get("hiddenNotes", [])
	if not _expect_int(initial_hidden_notes.size(), 1, "initial unbuffered note count"):
		return false
	if not _expect_int(int(initial_hidden_notes[0]), 2, "initial unbuffered note index"):
		return false
	var far_press: Dictionary = note_runtime.press_action("vos_lane_3", 0.0)
	if not _expect_bool(far_press.get("accepted", true), false, "unbuffered note input rejected"):
		return false
	if not _expect_string(str(far_press.get("reason", "")), "no_note", "unbuffered note input reason"):
		return false
	note_runtime.release_action("vos_lane_3", 0.0)
	note_runtime.advance_to(500.0)
	var buffered_note_state: Dictionary = note_runtime.hud_state()
	if not _expect_int(buffered_note_state.get("hiddenNotes", []).size(), 0, "notes enter Java buffer window"):
		return false
	note_runtime.free()

	var measure_chart := {
		"schemaVersion": 1,
		"chartId": "vos:buffered-visual-measures",
		"format": "VOS",
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 8000,
		"notes": [],
		"measures": [
			{"startMs": 1000.0},
			{"startMs": 3000.0},
			{"startMs": 6000.0},
		],
		"autoPlayEvents": [],
	}
	var measure_runtime = GameplayRuntime.new()
	get_root().add_child(measure_runtime)
	if not _expect_bool(measure_runtime.start(measure_chart, audio_manifest), true, "buffered measures runtime start"):
		return false
	var initial_measure_state: Dictionary = measure_runtime.hud_state()
	var initial_hidden_measures: Array = initial_measure_state.get("hiddenMeasures", [])
	if not _expect_int(initial_hidden_measures.size(), 1, "initial unbuffered measure count"):
		return false
	if not _expect_int(int(initial_hidden_measures[0]), 2, "initial unbuffered measure index"):
		return false
	measure_runtime.advance_to(500.0)
	var buffered_measure_state: Dictionary = measure_runtime.hud_state()
	if not _expect_int(buffered_measure_state.get("hiddenMeasures", []).size(), 0, "measures enter Java buffer window"):
		return false

	measure_runtime.free()
	return true


func _send_input_action(runtime: GameplayRuntime, action: String, pressed: bool) -> void:
	var input_event := InputEventAction.new()
	input_event.action = action
	input_event.pressed = pressed
	runtime._unhandled_input(input_event)


func _keycode_for_action(action: String) -> int:
	var events := InputMap.action_get_events(action)
	if events.is_empty() or not events[0] is InputEventKey:
		return 0
	return events[0].keycode


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
