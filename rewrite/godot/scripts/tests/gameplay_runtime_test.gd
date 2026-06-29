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
	if not _test_java_finish_waits_for_autoplay_buffer(audio_manifest):
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


func _test_java_finish_waits_for_autoplay_buffer(audio_manifest: Dictionary) -> bool:
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
	if not _expect_bool(runtime.is_running(), true, "future autoplay keeps runtime running"):
		return false
	if not _expect_int(runtime.audio_play_event_count(), 0, "future autoplay not played early"):
		return false

	runtime.advance_to(12000.0)
	if not _expect_int(runtime.audio_play_event_count(), 1, "future autoplay plays before finish"):
		return false
	runtime.advance_to(22001.0)
	if not _expect_bool(runtime.is_running(), false, "future autoplay finishes after buffer delay"):
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
