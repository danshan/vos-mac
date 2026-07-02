extends RefCounted

const DEFAULT_SPEED_TYPE := "HiSpeed"
const DEFAULT_SPEED_MULTIPLIER := 1.0


func state_for_chart(chart: Dictionary, capture_time_ms: float, animation_time_ms: float) -> Dictionary:
	var duration_ms := float(chart.get("durationMs", max(capture_time_ms, 1.0)))
	return {
		"score": 0,
		"combo": 0,
		"maxCombo": 0,
		"jamCombo": 0,
		"jamBar": 0,
		"jamBarLimit": 50,
		"life": 24000,
		"lifeLimit": 24000,
		"elapsedMs": capture_time_ms,
		"animationTimeMs": animation_time_ms,
		"gameTimeMs": 0.0,
		"durationMs": duration_ms,
		"fps": 0,
		"minute": 0,
		"second": 0,
		"judgments": {
			"cool": 0,
			"good": 0,
			"bad": 0,
			"miss": 0,
		},
		"statusTexts": [
			"%s: x%s" % [_java_speed_type_name(str(chart.get("speedType", DEFAULT_SPEED_TYPE))),
					_java_double_text(_speed_multiplier(chart))],
			"Current Measure: %d" % _current_measure(chart, capture_time_ms),
			"Game Speed: +0",
		],
	}


func _current_measure(chart: Dictionary, capture_time_ms: float) -> int:
	var measures: Variant = chart.get("measures", [])
	if not measures is Array:
		return 0
	var count := 0
	for raw_measure: Variant in measures:
		if not raw_measure is Dictionary:
			continue
		if float(raw_measure.get("startMs", raw_measure.get("timeMs", 0.0))) <= capture_time_ms:
			count += 1
	return count


func _speed_multiplier(chart: Dictionary) -> float:
	var value: Variant = chart.get("speedMultiplier", DEFAULT_SPEED_MULTIPLIER)
	if value is int or value is float:
		return max(float(value), 0.001)
	return DEFAULT_SPEED_MULTIPLIER


func _java_speed_type_name(speed_type: String) -> String:
	if speed_type == "xRSpeed":
		return "xR-SPEED"
	if speed_type == "RegulSpeed":
		return "REGUL-SPEED"
	if speed_type == "WSpeed":
		return "W-SPEED"
	return "HI-SPEED"


func _java_double_text(value: float) -> String:
	var text := "%.12f" % value
	while text.ends_with("0") and not text.ends_with(".0"):
		text = text.substr(0, text.length() - 1)
	return text
