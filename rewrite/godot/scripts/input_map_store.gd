extends RefCounted

const LANE_COUNT: int = 7
const DEFAULT_KEY_BINDINGS: Array[String] = ["S", "D", "F", "Space", "J", "K", "L"]
const ACTION_SPEED_UP: String = "speed_up"
const ACTION_SPEED_DOWN: String = "speed_down"
const ACTION_MAIN_VOLUME_UP: String = "main_volume_up"
const ACTION_MAIN_VOLUME_DOWN: String = "main_volume_down"
const ACTION_KEY_VOLUME_UP: String = "key_volume_up"
const ACTION_KEY_VOLUME_DOWN: String = "key_volume_down"
const ACTION_BGM_VOLUME_UP: String = "bgm_volume_up"
const ACTION_BGM_VOLUME_DOWN: String = "bgm_volume_down"
const DEFAULT_MISC_KEY_BINDINGS: Dictionary = {
	ACTION_SPEED_UP: "Up",
	ACTION_SPEED_DOWN: "Down",
	ACTION_MAIN_VOLUME_UP: "2",
	ACTION_MAIN_VOLUME_DOWN: "1",
	ACTION_KEY_VOLUME_UP: "4",
	ACTION_KEY_VOLUME_DOWN: "3",
	ACTION_BGM_VOLUME_UP: "6",
	ACTION_BGM_VOLUME_DOWN: "5",
}

var _key_bindings: Array[String] = DEFAULT_KEY_BINDINGS.duplicate()
var _misc_key_bindings: Dictionary = DEFAULT_MISC_KEY_BINDINGS.duplicate(true)


func set_key_bindings(bindings: Array) -> bool:
	if bindings.size() != LANE_COUNT:
		return false

	var next_bindings: Array[String] = []
	for binding: Variant in bindings:
		if not binding is String:
			return false
		var key := str(binding).strip_edges()
		if key.is_empty():
			return false
		next_bindings.append(key)

	_key_bindings = next_bindings
	return true


func key_bindings() -> Array[String]:
	return _key_bindings.duplicate()


func set_misc_key_bindings(bindings: Dictionary) -> bool:
	var next_bindings := _misc_key_bindings.duplicate(true)
	for action: Variant in bindings.keys():
		if not action is String:
			return false
		var action_name := str(action)
		if not DEFAULT_MISC_KEY_BINDINGS.has(action_name):
			return false
		var binding: Variant = bindings[action]
		if not binding is String:
			return false
		var key := str(binding).strip_edges()
		if key.is_empty():
			return false
		next_bindings[action_name] = key

	_misc_key_bindings = next_bindings
	return true


func misc_key_bindings() -> Dictionary:
	return _misc_key_bindings.duplicate(true)


func action_for_lane(lane: int) -> String:
	if lane < 0 or lane >= LANE_COUNT:
		return ""
	return "vos_lane_%d" % (lane + 1)


func key_for_lane(lane: int) -> String:
	if lane < 0 or lane >= _key_bindings.size():
		return ""
	return _key_bindings[lane]


func lane_for_action(action: String) -> int:
	for lane in range(LANE_COUNT):
		if action_for_lane(lane) == action:
			return lane
	return -1


func misc_actions() -> Array[String]:
	return [
		ACTION_SPEED_UP,
		ACTION_SPEED_DOWN,
		ACTION_MAIN_VOLUME_UP,
		ACTION_MAIN_VOLUME_DOWN,
		ACTION_KEY_VOLUME_UP,
		ACTION_KEY_VOLUME_DOWN,
		ACTION_BGM_VOLUME_UP,
		ACTION_BGM_VOLUME_DOWN,
	]


func apply_to_godot_input_map() -> bool:
	for lane in range(LANE_COUNT):
		var action := action_for_lane(lane)
		var key := key_for_lane(lane)
		if not _apply_key_action(action, key):
			return false

	for action: String in misc_actions():
		if not _apply_key_action(action, str(_misc_key_bindings.get(action, DEFAULT_MISC_KEY_BINDINGS.get(action, "")))):
			return false
	return true


func _apply_key_action(action: String, key: String) -> bool:
	var keycode := OS.find_keycode_from_string(key)
	if keycode == 0:
		return false

	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)

	var event := InputEventKey.new()
	event.keycode = keycode
	InputMap.action_add_event(action, event)
	return true
