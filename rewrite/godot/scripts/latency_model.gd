extends RefCounted

const JAVA_AUTOSYNC_HISTORY_SIZE: int = 64

var _starting_latency_ms: float = 0.0
var _latency_ms: float = 0.0
var _history: Array[float] = []


func _init(initial_latency_ms: float = 0.0) -> void:
	reset(initial_latency_ms)


func reset(initial_latency_ms: float) -> void:
	_starting_latency_ms = initial_latency_ms
	_latency_ms = initial_latency_ms
	_history.clear()


func latency_ms() -> float:
	return _latency_ms


func autosync(hit_ms: float) -> float:
	_history.append(_latency_ms - hit_ms)

	var sum := 0.0
	var count := 0
	for lag: float in _history:
		sum += lag
		count += 1

	while count < JAVA_AUTOSYNC_HISTORY_SIZE:
		sum += _starting_latency_ms
		count += 1

	_latency_ms = sum / float(count)
	return _latency_ms
