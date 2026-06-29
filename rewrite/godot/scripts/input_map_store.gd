extends RefCounted

const LANE_COUNT: int = 7
const DEFAULT_KEY_BINDINGS: Array[String] = ["S", "D", "F", "Space", "J", "K", "L"]

var _key_bindings: Array[String] = DEFAULT_KEY_BINDINGS.duplicate()


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
