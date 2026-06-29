extends RefCounted

const DEFAULT_MEASURE_SIZE: float = 385.0

var timing_model = null
var measure_size: float = DEFAULT_MEASURE_SIZE
var speed_factor: float = 1.0


func _init(initial_timing_model = null, initial_measure_size: float = DEFAULT_MEASURE_SIZE) -> void:
	timing_model = initial_timing_model
	measure_size = initial_measure_size


func calculate_hi_speed(now_ms: float, target_ms: float, speed: float) -> float:
	if timing_model == null:
		return 0.0
	return speed_factor * speed * (timing_model.get_beat(target_ms) - timing_model.get_beat(now_ms)) * measure_size / 4.0


func calculate_regul_speed(now_ms: float, target_ms: float, speed: float) -> float:
	var delta := target_ms - now_ms
	var beats := delta * 150.0 / 60000.0
	return speed_factor * speed * beats * measure_size / 4.0
