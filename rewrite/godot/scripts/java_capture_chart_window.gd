extends RefCounted

const NOTE_PAST_WINDOW_MS: float = 2000.0
const NOTE_FUTURE_WINDOW_MS: float = 11000.0
const MEASURE_PAST_WINDOW_MS: float = 4000.0
const MEASURE_FUTURE_WINDOW_MS: float = 7000.0


func chart_for_capture(chart: Dictionary, capture_time_ms: float) -> Dictionary:
	var capture_chart := chart.duplicate(true)
	capture_chart["notes"] = _windowed_dictionaries(chart.get("notes", []), capture_time_ms,
			NOTE_PAST_WINDOW_MS, NOTE_FUTURE_WINDOW_MS, true)
	capture_chart["measures"] = _windowed_dictionaries(chart.get("measures", []), capture_time_ms,
			MEASURE_PAST_WINDOW_MS, MEASURE_FUTURE_WINDOW_MS, false)
	capture_chart["autoPlayEvents"] = _windowed_dictionaries(chart.get("autoPlayEvents", []), capture_time_ms,
			NOTE_PAST_WINDOW_MS, NOTE_FUTURE_WINDOW_MS, false)
	capture_chart["bgaEvents"] = _windowed_dictionaries(chart.get("bgaEvents", []), capture_time_ms,
			NOTE_PAST_WINDOW_MS, NOTE_FUTURE_WINDOW_MS, false)
	return capture_chart


func _windowed_dictionaries(value: Variant, capture_time_ms: float, past_window_ms: float,
		future_window_ms: float, include_end_time: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	var min_time := capture_time_ms - past_window_ms
	var max_time := capture_time_ms + future_window_ms
	for item: Variant in value:
		if not item is Dictionary:
			continue
		var entry: Dictionary = item
		if _entry_overlaps_window(entry, min_time, max_time, include_end_time):
			result.append(entry.duplicate(true))
	return result


func _entry_overlaps_window(entry: Dictionary, min_time: float, max_time: float, include_end_time: bool) -> bool:
	var start_ms := float(entry.get("startMs", entry.get("timeMs", 0.0)))
	var end_ms := start_ms
	if include_end_time and (entry.has("endMs") or entry.has("endTimeMs")):
		end_ms = float(entry.get("endMs", entry.get("endTimeMs", start_ms)))
	return end_ms >= min_time and start_ms <= max_time
