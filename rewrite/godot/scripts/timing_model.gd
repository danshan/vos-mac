extends RefCounted

var _pending_changes: Array[Dictionary] = []
var _changes: Array[Dictionary] = []


func add_change(time_ms: float, bpm: float) -> void:
	_pending_changes.append({
		"time": time_ms,
		"bpm": bpm,
		"beat": 0.0,
	})


func finish() -> void:
	_changes = _pending_changes.duplicate(true)
	if _changes.is_empty():
		return

	_changes[0]["beat"] = 0.0
	for i in range(1, _changes.size()):
		var previous: Dictionary = _changes[i - 1]
		_changes[i]["beat"] = _calculate_beat(previous, float(_changes[i].get("time", 0.0)))


func get_beat(time_ms: float) -> float:
	if _changes.is_empty():
		return 0.0

	var left := 0
	var right := _changes.size() - 1
	while left <= right:
		var mid := int((left + right) / 2)
		var after_mid := float(_changes[mid].get("time", 0.0)) <= time_ms
		var before_next := mid + 1 >= _changes.size() or time_ms < float(_changes[mid + 1].get("time", 0.0))

		if after_mid and before_next:
			return _calculate_beat(_changes[mid], time_ms)
		if after_mid:
			left = mid + 1
		else:
			right = mid - 1

	return _calculate_beat(_changes[0], time_ms)


func _calculate_beat(change: Dictionary, target_ms: float) -> float:
	return float(change.get("beat", 0.0)) + (target_ms - float(change.get("time", 0.0))) * float(change.get("bpm", 0.0)) / 60000.0
