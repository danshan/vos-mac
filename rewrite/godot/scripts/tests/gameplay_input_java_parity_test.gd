extends SceneTree

const GameplayController = preload("res://scripts/gameplay_controller.gd")


func _init() -> void:
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

	var hold_tail: Dictionary = controller.release_action("vos_lane_3", 3300.0)
	if not _expect_bool(hold_tail.get("accepted", false), true, "hold tail accepted"):
		return
	if not _expect_string(hold_tail.get("result", ""), "cool", "hold tail result"):
		return
	if not _expect_int(controller.held_note_count(), 0, "held note released"):
		return
	if not _expect_int(controller.render_state(3300.0).get("longFlares", []).size(), 0, "long flare cleared after release"):
		return

	controller.advance_to(4174.0)
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


func _chart() -> Dictionary:
	return {
		"schemaVersion": 1,
		"chartId": "vos:input",
		"format": "VOS",
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
