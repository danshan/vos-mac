extends RefCounted

const DEFAULT_MEASURE_SIZE: float = 385.0
const W_SPEED_FACTOR: float = 0.0005
const W_SPEED_MIN: float = 0.5
const W_SPEED_MAX: float = 10.0
const XR_SPEED_LANE_COUNT: int = 7

var timing_model = null
var measure_size: float = DEFAULT_MEASURE_SIZE
var speed_factor: float = 1.0
var w_speed: float = W_SPEED_MIN
var w_time_ms: float = 0.0
var w_positive: bool = true
var xr_speed_factors: Array[float] = []


func _init(initial_timing_model = null, initial_measure_size: float = DEFAULT_MEASURE_SIZE) -> void:
	timing_model = initial_timing_model
	measure_size = initial_measure_size
	_randomize_xr_speed_factors()


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


func set_xr_speed_factors(raw_factors: Variant) -> void:
	if not raw_factors is Array:
		_randomize_xr_speed_factors()
		return

	xr_speed_factors.clear()
	for i in range(XR_SPEED_LANE_COUNT):
		var factor: float = 0.0
		if i < raw_factors.size():
			var raw_factor: Variant = raw_factors[i]
			if raw_factor is int or raw_factor is float:
				factor = clampf(float(raw_factor), 0.0, 1.0)
		xr_speed_factors.append(factor)


func calculate_xr_speed(now_ms: float, target_ms: float, speed: float, lane: int = -1) -> float:
	var factor: float = 1.0
	if lane >= 0 and lane < xr_speed_factors.size():
		factor += xr_speed_factors[lane]
	return calculate_hi_speed(now_ms, target_ms, speed) * factor


func _randomize_xr_speed_factors() -> void:
	xr_speed_factors.clear()
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.randomize()
	for i in range(XR_SPEED_LANE_COUNT):
		xr_speed_factors.append(random.randf())
