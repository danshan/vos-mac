extends RefCounted

const DEFAULT_MEASURE_SIZE: float = 385.0
const W_SPEED_FACTOR: float = 0.0005
const W_SPEED_MIN: float = 0.5
const W_SPEED_MAX: float = 10.0

var timing_model = null
var measure_size: float = DEFAULT_MEASURE_SIZE
var speed_factor: float = 1.0
var w_speed: float = W_SPEED_MIN
var w_time_ms: float = 0.0
var w_positive: bool = true


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


func update_w_speed(delta_ms: float, target_speed: float) -> void:
	var cycle_speed: float = max(target_speed, 0.001)
	w_time_ms += delta_ms
	if w_time_ms < 3000.0 * cycle_speed:
		var direction: float = 1.0 if w_positive else -1.0
		w_speed += direction * W_SPEED_FACTOR * delta_ms
		w_speed = clampf(w_speed, W_SPEED_MIN, W_SPEED_MAX)
	else:
		w_time_ms = 0.0
		w_positive = not w_positive


func calculate_w_speed(now_ms: float, target_ms: float) -> float:
	return calculate_hi_speed(now_ms, target_ms, 1.0) * w_speed
