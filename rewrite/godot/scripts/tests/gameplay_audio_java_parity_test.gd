extends SceneTree

const GameplayController = preload("res://scripts/gameplay_controller.gd")


func _init() -> void:
	var controller = GameplayController.new()
	if not _expect_bool(controller.load_chart(_chart()), true, "controller load chart"):
		return
	if not _expect_int(controller.drain_audio_commands().size(), 0, "initial audio commands"):
		return

	controller.advance_to(0.0)
	var auto_commands: Array[Dictionary] = controller.drain_audio_commands()
	if not _expect_int(auto_commands.size(), 1, "auto play command count"):
		return
	if not _expect_command(auto_commands[0], "playSample", 9, "autoPlay", "autosound"):
		return

	controller.advance_to(999.0)
	if not _expect_int(controller.drain_audio_commands().size(), 0, "auto play only once"):
		return

	var first_hit: Dictionary = controller.press_action("vos_lane_1", 1000.0)
	if not _expect_bool(first_hit.get("accepted", false), true, "first hit accepted"):
		return
	if not _expect_result_command(first_hit, "playSample", 1, "note", "keysound", "first hit command"):
		return
	if not _expect_int(controller.drain_audio_commands().size(), 1, "first hit drained command"):
		return

	var too_early: Dictionary = controller.press_action("vos_lane_2", 1600.0)
	if not _expect_bool(too_early.get("accepted", true), false, "too early rejected"):
		return
	if not _expect_bool(too_early.get("rejectedKeysound", true), false, "too early rejected keysound"):
		return
	if not _expect_result_command_count(too_early, 0, "too early command count"):
		return
	if not _expect_int(controller.drain_audio_commands().size(), 0, "too early drained command"):
		return

	controller.release_action("vos_lane_2", 1601.0)
	var rejected_close: Dictionary = controller.press_action("vos_lane_2", 1820.0)
	if not _expect_bool(rejected_close.get("accepted", true), false, "close rejected"):
		return
	if not _expect_bool(rejected_close.get("rejectedKeysound", false), true, "close rejected keysound"):
		return
	if not _expect_result_command(rejected_close, "playSample", 2, "note", "extrasound", "close rejected command"):
		return
	if not _expect_int(controller.drain_audio_commands().size(), 1, "close rejected drained command"):
		return

	controller.release_action("vos_lane_2", 1830.0)
	var second_hit: Dictionary = controller.press_action("vos_lane_2", 2000.0)
	if not _expect_bool(second_hit.get("accepted", false), true, "second hit accepted"):
		return
	if not _expect_result_command(second_hit, "playSample", 2, "note", "keysound", "second hit command"):
		return
	controller.drain_audio_commands()

	var hold_head: Dictionary = controller.press_action("vos_lane_3", 3000.0)
	if not _expect_bool(hold_head.get("accepted", false), true, "hold head accepted"):
		return
	if not _expect_result_command(hold_head, "playSample", 3, "note", "keysound", "hold head command"):
		return
	controller.drain_audio_commands()

	controller.advance_to(3474.0)
	var tail_miss_commands: Array[Dictionary] = controller.drain_audio_commands()
	if not _expect_int(tail_miss_commands.size(), 1, "tail miss stop command count"):
		return
	if not _expect_command(tail_miss_commands[0], "stopSample", 3, "note", "missed"):
		return

	controller.advance_to(4174.0)
	var tap_miss_commands: Array[Dictionary] = controller.drain_audio_commands()
	if not _expect_int(tap_miss_commands.size(), 0, "unplayed tap miss has no stop command"):
		return

	quit(0)


func _chart() -> Dictionary:
	return {
		"schemaVersion": 1,
		"chartId": "vos:audio",
		"format": "VOS",
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 5000,
		"notes": [
			{"id": 1, "lane": 0, "startMs": 1000.0, "endMs": null, "sampleId": 1, "volume": 0.8, "pan": -0.2, "kind": "tap"},
			{"id": 2, "lane": 1, "startMs": 2000.0, "endMs": null, "sampleId": 2, "volume": 0.9, "pan": 0.1, "kind": "tap"},
			{"id": 3, "lane": 2, "startMs": 3000.0, "endMs": 3300.0, "sampleId": 3, "volume": 1.0, "pan": 0.0, "kind": "holdStart"},
			{"id": 4, "lane": 3, "startMs": 4000.0, "endMs": null, "sampleId": 4, "volume": 1.0, "pan": 0.0, "kind": "tap"},
		],
		"autoPlayEvents": [
			{"startMs": 0.0, "sampleId": 9, "volume": 1.0, "pan": 0.0},
		],
	}


func _expect_result_command(
		result: Dictionary,
		action: String,
		sample_id: int,
		source: String,
		trigger: String,
		label: String) -> bool:
	var commands: Array = result.get("audioCommands", [])
	if not _expect_int(commands.size(), 1, label):
		return false
	if not commands[0] is Dictionary:
		push_error("Expected %s command dictionary." % label)
		quit(1)
		return false
	return _expect_command(commands[0], action, sample_id, source, trigger)


func _expect_result_command_count(result: Dictionary, expected: int, label: String) -> bool:
	var commands: Array = result.get("audioCommands", [])
	return _expect_int(commands.size(), expected, label)


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
