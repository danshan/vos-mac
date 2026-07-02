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
	if not _expect_string(InputMapStore.normalized_key_name("<SPACE>"), "Space", "normalized bracketed space"):
		return
	if not _expect_bool(store.set_key_bindings(["A", "S", "C", "<SPACE>", "M", "L", ";"]), true, "set punctuation bindings"):
		return
	if not _expect_array(store.key_bindings(), ["A", "S", "C", "Space", "M", "L", ";"], "normalized punctuation bindings"):
		return
	if not _expect_bool(store.has_method("set_misc_key_bindings"), true, "misc key binding setter"):
		return
	if not _expect_bool(store.has_method("misc_key_bindings"), true, "misc key binding getter"):
		return
	if not _expect_dictionary(store.misc_key_bindings(), {
			"speed_up": "Up",
			"speed_down": "Down",
			"main_volume_up": "2",
			"main_volume_down": "1",
			"key_volume_up": "4",
			"key_volume_down": "3",
			"bgm_volume_up": "6",
			"bgm_volume_down": "5",
	}, "default misc bindings"):
		return
	if not _expect_bool(store.set_misc_key_bindings({
			"speed_up": "PageUp",
			"main_volume_down": "Minus",
	}), true, "set custom misc bindings"):
		return
	if not _expect_bool(store.set_misc_key_bindings({
			"missing_action": "A",
	}), false, "reject unknown misc binding"):
		return
	var misc_bindings: Dictionary = store.misc_key_bindings()
	if not _expect_string(str(misc_bindings.get("speed_up", "")), "PageUp", "custom speed up binding"):
		return
	if not _expect_string(str(misc_bindings.get("main_volume_down", "")), "Minus", "custom main volume down binding"):
		return
	if not _expect_string(str(misc_bindings.get("speed_down", "")), "Down", "default speed down binding remains"):
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
	if not _expect_int(_keycode_for_action("vos_lane_7"), KEY_SEMICOLON, "semicolon lane keycode"):
		return
	if not _expect_int(InputMap.action_get_events("speed_up").size(), 1, "speed up input action event count"):
		return
	if not _expect_int(_keycode_for_action("speed_up"), OS.find_keycode_from_string("PageUp"), "custom speed up keycode"):
		return
	if not _expect_int(InputMap.action_get_events("speed_down").size(), 1, "speed down input action event count"):
		return
	if not _expect_int(InputMap.action_get_events("main_volume_up").size(), 1, "main volume up input action event count"):
		return
	if not _expect_int(InputMap.action_get_events("main_volume_down").size(), 1, "main volume down input action event count"):
		return
	if not _expect_int(_keycode_for_action("main_volume_down"), OS.find_keycode_from_string("Minus"), "custom main volume down keycode"):
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


func _expect_dictionary(actual: Dictionary, expected: Dictionary, label: String) -> bool:
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


func _keycode_for_action(action: String) -> int:
	var events := InputMap.action_get_events(action)
	if events.is_empty() or not events[0] is InputEventKey:
		return 0
	return events[0].keycode
