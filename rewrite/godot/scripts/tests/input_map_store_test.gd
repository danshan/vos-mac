extends SceneTree

const InputMapStore = preload("res://scripts/input_map_store.gd")


func _init() -> void:
	var store = InputMapStore.new()

	if not _expect_array(store.key_bindings(), ["S", "D", "F", "Space", "J", "K", "L"], "default bindings"):
		return
	if not _expect_string(store.action_for_lane(0), "vos_lane_1", "first action"):
		return
	if not _expect_string(store.action_for_lane(6), "vos_lane_7", "last action"):
		return
	if not _expect_string(store.key_for_lane(3), "Space", "space key"):
		return
	if not _expect_int(store.lane_for_action("vos_lane_5"), 4, "lane for action"):
		return
	if not _expect_int(store.lane_for_action("missing"), -1, "missing action"):
		return

	if not _expect_bool(store.set_key_bindings(["A", "S", "D", "F", "J", "K", "L"]), true, "set custom bindings"):
		return
	if not _expect_array(store.key_bindings(), ["A", "S", "D", "F", "J", "K", "L"], "custom bindings"):
		return
	if not _expect_bool(store.set_key_bindings(["A"]), false, "reject short bindings"):
		return
	if not _expect_array(store.key_bindings(), ["A", "S", "D", "F", "J", "K", "L"], "unchanged bindings"):
		return
	if not _expect_bool(store.apply_to_godot_input_map(), true, "apply custom bindings"):
		return
	if not _expect_bool(InputMap.has_action("vos_lane_1"), true, "first input action exists"):
		return
	if not _expect_bool(InputMap.has_action("vos_lane_7"), true, "last input action exists"):
		return
	if not _expect_bool(InputMap.has_action("speed_up"), true, "speed up input action exists"):
		return
	if not _expect_bool(InputMap.has_action("speed_down"), true, "speed down input action exists"):
		return
	if not _expect_bool(InputMap.has_action("main_volume_up"), true, "main volume up input action exists"):
		return
	if not _expect_bool(InputMap.has_action("main_volume_down"), true, "main volume down input action exists"):
		return
	if not _expect_bool(InputMap.has_action("key_volume_up"), true, "key volume up input action exists"):
		return
	if not _expect_bool(InputMap.has_action("key_volume_down"), true, "key volume down input action exists"):
		return
	if not _expect_bool(InputMap.has_action("bgm_volume_up"), true, "bgm volume up input action exists"):
		return
	if not _expect_bool(InputMap.has_action("bgm_volume_down"), true, "bgm volume down input action exists"):
		return
	if not _expect_int(InputMap.action_get_events("vos_lane_1").size(), 1, "first input action event count"):
		return
	if not _expect_int(InputMap.action_get_events("speed_up").size(), 1, "speed up input action event count"):
		return
	if not _expect_int(InputMap.action_get_events("speed_down").size(), 1, "speed down input action event count"):
		return
	if not _expect_int(InputMap.action_get_events("main_volume_up").size(), 1, "main volume up input action event count"):
		return
	if not _expect_int(InputMap.action_get_events("main_volume_down").size(), 1, "main volume down input action event count"):
		return
	if not _expect_int(InputMap.action_get_events("key_volume_up").size(), 1, "key volume up input action event count"):
		return
	if not _expect_int(InputMap.action_get_events("key_volume_down").size(), 1, "key volume down input action event count"):
		return
	if not _expect_int(InputMap.action_get_events("bgm_volume_up").size(), 1, "bgm volume up input action event count"):
		return
	if not _expect_int(InputMap.action_get_events("bgm_volume_down").size(), 1, "bgm volume down input action event count"):
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
