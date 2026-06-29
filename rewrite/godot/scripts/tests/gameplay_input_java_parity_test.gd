extends SceneTree

const GameplayController = preload("res://scripts/gameplay_controller.gd")


func _init() -> void:
	if not _test_default_beat_judgment():
		return
	if not _test_explicit_time_judgment():
		return
	if not _test_ranked_chart_life_model():
		return
	if not _test_autoplay_tap_note():
		return
	if not _test_autoplay_long_note():
		return
	if not _test_autoplay_ignores_manual_input():
		return

	var controller = GameplayController.new()
	if not _expect_bool(controller.load_chart(_chart()), true, "controller load chart"):
		return

	var first_hit: Dictionary = controller.press_action("vos_lane_1", 1000.0)
	if not _expect_bool(first_hit.get("accepted", false), true, "first hit accepted"):
		return
	if not _expect_string(first_hit.get("result", ""), "cool", "first hit result"):
		return
	if not _expect_int(controller.result().get("score", 0), 200, "first hit score"):
		return
	var hidden_after_first: Array = controller.render_state(1000.0).get("hiddenNotes", [])
	if not _expect_int(hidden_after_first.size(), 2, "first hit hidden note count"):
		return
	if not _expect_int(int(hidden_after_first[0]), 0, "first hit hidden note index"):
		return
	if not _expect_int(int(hidden_after_first[1]), 3, "first hit unbuffered note index"):
		return

	var early_press: Dictionary = controller.press_action("vos_lane_2", 1820.0)
	if not _expect_bool(early_press.get("accepted", true), false, "early press rejected"):
		return
	if not _expect_bool(early_press.get("rejectedKeysound", false), true, "early rejected keysound"):
		return
	if not _expect_int(controller.result().get("score", 0), 200, "early press score unchanged"):
		return

	var early_release: Dictionary = controller.release_action("vos_lane_2", 1830.0)
	if not _expect_bool(early_release.get("released", false), true, "early release tracked"):
		return

	var second_hit: Dictionary = controller.press_action("vos_lane_2", 2000.0)
	if not _expect_bool(second_hit.get("accepted", false), true, "second hit accepted"):
		return
	if not _expect_string(second_hit.get("result", ""), "cool", "second hit result"):
		return

	var hold_head: Dictionary = controller.press_action("vos_lane_3", 3000.0)
	if not _expect_bool(hold_head.get("accepted", false), true, "hold head accepted"):
		return
	if not _expect_string(hold_head.get("result", ""), "cool", "hold head result"):
		return
	if not _expect_int(controller.held_note_count(), 1, "held note count"):
		return
	var hold_render_state: Dictionary = controller.render_state(3000.0)
	var long_flares: Array = hold_render_state.get("longFlares", [])
	if not _expect_int(long_flares.size(), 1, "long flare active after hold head"):
		return
	if not _expect_int(long_flares[0].get("lane", -1), 2, "long flare lane"):
		return
	if not _expect_int(long_flares[0].get("startMs", -1), 3000, "long flare start time"):
		return
	if not _expect_int(long_flares[0].get("noteIndex", -1), 2, "long flare note index"):
		return
	var hidden_after_hold_head: Array = hold_render_state.get("hiddenNotes", [])
	if not _expect_int(hidden_after_hold_head.size(), 3, "hold head keeps long note visible"):
		return

	var hold_tail: Dictionary = controller.release_action("vos_lane_3", 3300.0)
	if not _expect_bool(hold_tail.get("accepted", false), true, "hold tail accepted"):
		return
	if not _expect_string(hold_tail.get("result", ""), "cool", "hold tail result"):
		return
	if not _expect_int(controller.held_note_count(), 0, "held note released"):
		return
	if not _expect_int(controller.render_state(3300.0).get("longFlares", []).size(), 0, "long flare cleared after release"):
		return
	var hidden_after_hold_tail: Array = controller.render_state(3300.0).get("hiddenNotes", [])
	if not _expect_int(hidden_after_hold_tail.size(), 3, "hold tail keeps long note visible"):
		return

	controller.advance_to(4174.0)
	var hidden_after_miss: Array = controller.render_state(4174.0).get("hiddenNotes", [])
	if not _expect_int(hidden_after_miss.size(), 3, "long note cleaned before tap miss leaves screen"):
		return
	controller.advance_to(5000.0)
	var hidden_after_cleanup: Array = controller.render_state(5000.0).get("hiddenNotes", [])
	if not _expect_int(hidden_after_cleanup.size(), 4, "miss cleaned after leaving screen"):
		return
	var result: Dictionary = controller.result()
	var judgments: Dictionary = result.get("judgments", {})
	if not _expect_int(result.get("score", 0), 790, "final Java score"):
		return
	if not _expect_int(result.get("maxCombo", 0), 4, "final Java max combo"):
		return
	if not _expect_int(judgments.get("cool", 0), 4, "cool count"):
		return
	if not _expect_int(judgments.get("miss", 0), 1, "miss count"):
		return

	quit(0)


func _test_default_beat_judgment() -> bool:
	var controller = GameplayController.new()
	if not _expect_bool(controller.load_chart(_single_note_chart({})), true, "beat chart load"):
		return false
	var beat_hit: Dictionary = controller.press_action("vos_lane_1", 780.0)
	if not _expect_bool(beat_hit.get("accepted", false), true, "beat accepts wide early hit"):
		return false
	if not _expect_string(beat_hit.get("result", ""), "bad", "beat wide early result"):
		return false
	return true


func _test_explicit_time_judgment() -> bool:
	var controller = GameplayController.new()
	if not _expect_bool(controller.load_chart(_single_note_chart({"judgmentType": "time"})), true, "time chart load"):
		return false
	var time_hit: Dictionary = controller.press_action("vos_lane_1", 780.0)
	if not _expect_bool(time_hit.get("accepted", true), false, "time rejects wide early hit"):
		return false
	return true


func _test_ranked_chart_life_model() -> bool:
	var controller = GameplayController.new()
	if not _expect_bool(controller.load_chart(_single_note_chart({"rank": 2})), true, "ranked chart load"):
		return false
	var result: Dictionary = controller.result()
	if not _expect_int(result.get("lifeLimit", 0), 48000, "ranked chart life limit"):
		return false
	if not _expect_int(result.get("life", 0), 48000, "ranked chart life"):
		return false
	return true


func _test_autoplay_tap_note() -> bool:
	var controller = GameplayController.new()
	if not _expect_bool(controller.load_chart(_autoplay_tap_chart()), true, "autoplay tap chart load"):
		return false

	if not _expect_int(controller.advance_to(999.0), 0, "autoplay tap before target"):
		return false
	if not _expect_int(controller.drain_audio_commands().size(), 0, "autoplay tap before target audio"):
		return false
	if not _expect_int(controller.result().get("score", 0), 0, "autoplay tap before target score"):
		return false

	if not _expect_int(controller.advance_to(1000.0), 1, "autoplay tap judged at target"):
		return false
	var commands: Array[Dictionary] = controller.drain_audio_commands()
	if not _expect_int(commands.size(), 1, "autoplay tap keysound count"):
		return false
	if not _expect_command(commands[0], "playSample", 1, "note", "keysound"):
		return false
	if not _expect_int(controller.result().get("score", 0), 200, "autoplay tap score"):
		return false
	var hidden: Array = controller.render_state(1000.0).get("hiddenNotes", [])
	if not _expect_int(hidden.size(), 1, "autoplay tap hidden count"):
		return false
	if not _expect_int(int(hidden[0]), 0, "autoplay tap hidden index"):
		return false
	return true


func _test_autoplay_long_note() -> bool:
	var controller = GameplayController.new()
	if not _expect_bool(controller.load_chart(_autoplay_long_note_chart()), true, "autoplay long chart load"):
		return false

	if not _expect_int(controller.advance_to(2999.0), 0, "autoplay long before head"):
		return false
	if not _expect_int(controller.advance_to(3000.0), 1, "autoplay long head judged"):
		return false
	var head_commands: Array[Dictionary] = controller.drain_audio_commands()
	if not _expect_int(head_commands.size(), 1, "autoplay long head keysound count"):
		return false
	if not _expect_command(head_commands[0], "playSample", 3, "note", "keysound"):
		return false
	if not _expect_int(controller.result().get("score", 0), 200, "autoplay long head score"):
		return false
	if not _expect_int(controller.held_note_count(), 1, "autoplay long held count"):
		return false
	var pressed_lanes: Array[int] = controller.pressed_lanes()
	if not _expect_int(pressed_lanes.size(), 1, "autoplay long pressed lane count"):
		return false
	if not _expect_int(pressed_lanes[0], 2, "autoplay long pressed lane"):
		return false
	var long_flares: Array = controller.render_state(3000.0).get("longFlares", [])
	if not _expect_int(long_flares.size(), 1, "autoplay long flare count"):
		return false
	if not _expect_int(long_flares[0].get("lane", -1), 2, "autoplay long flare lane"):
		return false
	if not _expect_int(long_flares[0].get("noteIndex", -1), 0, "autoplay long flare note index"):
		return false

	if not _expect_int(controller.advance_to(3300.0), 1, "autoplay long tail judged"):
		return false
	if not _expect_int(controller.drain_audio_commands().size(), 0, "autoplay long tail audio count"):
		return false
	if not _expect_int(controller.result().get("score", 0), 400, "autoplay long tail score"):
		return false
	if not _expect_int(controller.held_note_count(), 0, "autoplay long released count"):
		return false
	if not _expect_int(controller.pressed_lanes().size(), 0, "autoplay long pressed lane cleared"):
		return false
	if not _expect_int(controller.render_state(3300.0).get("longFlares", []).size(), 0, "autoplay long flare cleared"):
		return false
	return true


func _test_autoplay_ignores_manual_input() -> bool:
	var controller = GameplayController.new()
	if not _expect_bool(controller.load_chart(_autoplay_tap_chart()), true, "autoplay manual chart load"):
		return false

	var manual_hit: Dictionary = controller.press_action("vos_lane_1", 1000.0)
	if not _expect_bool(manual_hit.get("accepted", true), false, "autoplay manual input ignored"):
		return false
	if not _expect_string(manual_hit.get("reason", ""), "autoplay_lane", "autoplay manual input reason"):
		return false
	if not _expect_int(controller.result().get("score", 0), 0, "autoplay manual input score"):
		return false
	if not _expect_int(controller.drain_audio_commands().size(), 0, "autoplay manual input audio"):
		return false

	if not _expect_int(controller.advance_to(1000.0), 1, "autoplay still judges after manual input"):
		return false
	if not _expect_int(controller.result().get("score", 0), 200, "autoplay score after ignored manual input"):
		return false
	return true


func _single_note_chart(extra_fields: Dictionary) -> Dictionary:
	var chart := {
		"schemaVersion": 1,
		"chartId": "vos:single-note",
		"format": "VOS",
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 3000,
		"notes": [
			{"id": 1, "lane": 0, "startMs": 1000.0, "endMs": null, "sampleId": 1, "volume": 1.0, "pan": 0.0, "kind": "tap"},
		],
		"visualTiming": [
			{"timeMs": 0.0, "bpm": 120.0},
		],
		"autoPlayEvents": [],
	}
	for key: Variant in extra_fields.keys():
		chart[key] = extra_fields[key]
	return chart


func _autoplay_tap_chart() -> Dictionary:
	return {
		"schemaVersion": 1,
		"chartId": "vos:autoplay-tap",
		"format": "VOS",
		"autoplay": true,
		"judgmentType": "time",
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 3000,
		"notes": [
			{"id": 1, "lane": 0, "startMs": 1000.0, "endMs": null, "sampleId": 1, "volume": 1.0, "pan": 0.0, "kind": "tap"},
		],
		"autoPlayEvents": [],
	}


func _autoplay_long_note_chart() -> Dictionary:
	return {
		"schemaVersion": 1,
		"chartId": "vos:autoplay-long",
		"format": "VOS",
		"autoplay": true,
		"judgmentType": "time",
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 5000,
		"notes": [
			{"id": 3, "lane": 2, "startMs": 3000.0, "endMs": 3300.0, "sampleId": 3, "volume": 1.0, "pan": 0.0, "kind": "holdStart"},
		],
		"autoPlayEvents": [],
	}


func _chart() -> Dictionary:
	return {
		"schemaVersion": 1,
		"chartId": "vos:input",
		"format": "VOS",
		"judgmentType": "time",
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 5000,
		"notes": [
			{"id": 1, "lane": 0, "startMs": 1000.0, "endMs": null, "sampleId": 1, "volume": 1.0, "pan": 0.0, "kind": "tap"},
			{"id": 2, "lane": 1, "startMs": 2000.0, "endMs": null, "sampleId": 2, "volume": 1.0, "pan": 0.0, "kind": "tap"},
			{"id": 3, "lane": 2, "startMs": 3000.0, "endMs": 3300.0, "sampleId": 3, "volume": 1.0, "pan": 0.0, "kind": "holdStart"},
			{"id": 4, "lane": 3, "startMs": 4000.0, "endMs": null, "sampleId": 4, "volume": 1.0, "pan": 0.0, "kind": "tap"},
		],
		"autoPlayEvents": [],
	}


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


func _expect_command(command: Dictionary, action: String, sample_id: int, source: String, trigger: String) -> bool:
	if not _expect_string(command.get("action", ""), action, "audio action"):
		return false
	if not _expect_int(command.get("sampleId", -1), sample_id, "audio sample id"):
		return false
	if not _expect_string(command.get("source", ""), source, "audio source"):
		return false
	if not _expect_string(command.get("trigger", ""), trigger, "audio trigger"):
		return false
	return true
