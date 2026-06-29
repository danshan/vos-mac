extends RefCounted

const REQUIRED_NOTE_FIELDS: Array[String] = [
	"lane",
	"startMs",
	"sampleId",
	"volume",
	"pan",
	"kind",
]

const VALID_NOTE_KINDS := ["tap", "holdStart", "holdEnd"]
const CHANNEL_MOD_NONE: String = "None"
const CHANNEL_MOD_MIRROR: String = "Mirror"
const CHANNEL_MOD_SHUFFLE: String = "Shuffle"
const CHANNEL_MOD_RANDOM: String = "Random"


func load_from_file(path: String) -> Dictionary:
	return load_from_file_with_overrides(path, {})


func load_from_file_with_overrides(path: String, overrides: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var content: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(content)
	if not parsed is Dictionary:
		return {}

	var chart: Dictionary = parsed
	for key: Variant in overrides.keys():
		chart[key] = overrides[key]
	var normalized_chart: Dictionary = _normalized_chart(chart)
	if normalized_chart.is_empty():
		return {}

	return normalized_chart


func _normalized_chart(chart: Dictionary) -> Dictionary:
	if chart.get("schemaVersion") != 1:
		return {}
	if chart.get("format") != "VOS":
		return {}
	if not chart.has("keys"):
		return {}

	var keys: Variant = chart.get("keys")
	if not (keys is int or keys is float):
		return {}
	if not _is_integer_like(keys) or int(keys) <= 0:
		return {}

	var notes: Variant = chart.get("notes")
	if not notes is Array:
		return {}
	var normalized_notes: Array[Dictionary] = []
	for note: Variant in notes:
		if not note is Dictionary:
			return {}
		var normalized_note: Dictionary = _normalized_note(note, int(keys))
		if normalized_note.is_empty():
			return {}
		normalized_notes.append(normalized_note)

	var auto_play_events: Variant = chart.get("autoPlayEvents")
	if not auto_play_events is Array:
		return {}
	var normalized_events: Array[Dictionary] = []
	for event: Variant in auto_play_events:
		if not event is Dictionary:
			return {}
		var normalized_event: Dictionary = _normalized_auto_play_event(event)
		if normalized_event.is_empty():
			return {}
		normalized_events.append(normalized_event)

	var normalized_chart: Dictionary = chart.duplicate(true)
	normalized_chart["keys"] = int(keys)
	var channel_modifier := _normalized_channel_modifier(normalized_chart.get("channelModifier", CHANNEL_MOD_NONE))
	if channel_modifier.is_empty():
		return {}
	normalized_chart["channelModifier"] = channel_modifier
	var channel_map: Array[int] = _channel_map_for_modifier(int(keys), channel_modifier, normalized_chart.get("channelMap", []))
	if channel_modifier == CHANNEL_MOD_SHUFFLE:
		if channel_map.is_empty():
			return {}
		normalized_chart["channelMap"] = channel_map
	if normalized_chart.has("rank"):
		var rank: Variant = normalized_chart.get("rank")
		if not _is_integer_like(rank) or int(rank) < 0:
			return {}
		normalized_chart["rank"] = int(rank)
	if normalized_chart.has("speedMultiplier"):
		var speed_multiplier: Variant = normalized_chart.get("speedMultiplier")
		if not _is_positive_number(speed_multiplier):
			return {}
		normalized_chart["speedMultiplier"] = float(speed_multiplier)
	if normalized_chart.has("speedType"):
		var speed_type: Variant = normalized_chart.get("speedType")
		if not speed_type is String or str(speed_type).is_empty():
			return {}
		normalized_chart["speedType"] = str(speed_type)
	var channel_notes: Array[Dictionary] = _notes_with_channel_modifier(
			normalized_notes,
			int(keys),
			channel_modifier,
			channel_map,
			normalized_chart.get("channelMapsByMeasure", []))
	if channel_modifier == CHANNEL_MOD_RANDOM and normalized_notes.size() > 0 and channel_notes.is_empty():
		return {}
	normalized_chart["notes"] = channel_notes
	normalized_chart["autoPlayEvents"] = normalized_events
	return normalized_chart


func _normalized_note(note: Dictionary, keys: int) -> Dictionary:
	if not _has_fields(note, REQUIRED_NOTE_FIELDS):
		return {}

	var lane: Variant = note.get("lane")
	if not _is_integer_like(lane):
		return {}
	if int(lane) < 0 or int(lane) >= keys:
		return {}

	var start_ms: Variant = note.get("startMs")
	if not _is_non_negative_number(start_ms):
		return {}

	var sample_id: Variant = note.get("sampleId")
	if not _is_positive_integer_like(sample_id):
		return {}

	if not note.get("volume") is int and not note.get("volume") is float:
		return {}
	if not note.get("pan") is int and not note.get("pan") is float:
		return {}

	var kind: Variant = note.get("kind")
	if not kind is String:
		return {}
	if not VALID_NOTE_KINDS.has(kind):
		return {}

	var normalized_note: Dictionary = note.duplicate(true)
	normalized_note["lane"] = int(lane)
	normalized_note["startMs"] = float(start_ms)
	normalized_note["sampleId"] = int(sample_id)
	return normalized_note


func _normalized_auto_play_event(event: Dictionary) -> Dictionary:
	var start_ms: Variant = null
	if event.has("startMs"):
		start_ms = event.get("startMs")
	elif event.has("timeMs"):
		start_ms = event.get("timeMs")
	else:
		return {}

	if not _is_non_negative_number(start_ms):
		return {}

	var sample_id: Variant = event.get("sampleId")
	if not _is_positive_integer_like(sample_id):
		return {}

	if not event.get("volume") is int and not event.get("volume") is float:
		return {}
	if not event.get("pan") is int and not event.get("pan") is float:
		return {}

	var normalized_event: Dictionary = event.duplicate(true)
	normalized_event.erase("timeMs")
	normalized_event["startMs"] = float(start_ms)
	normalized_event["sampleId"] = int(sample_id)
	return normalized_event


func _is_non_negative_number(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	return float(value) >= 0.0


func _is_positive_integer_like(value: Variant) -> bool:
	if not _is_integer_like(value):
		return false
	return int(value) > 0


func _is_positive_number(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	return float(value) > 0.0


func _is_integer_like(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return value == floor(value)
	return false


func _has_fields(entry: Dictionary, fields: Array[String]) -> bool:
	for field: String in fields:
		if not entry.has(field):
			return false
	return true


func _normalized_channel_modifier(value: Variant) -> String:
	if not value is String:
		return ""
	var modifier := str(value)
	if modifier == CHANNEL_MOD_NONE:
		return CHANNEL_MOD_NONE
	if modifier == CHANNEL_MOD_MIRROR:
		return CHANNEL_MOD_MIRROR
	if modifier == CHANNEL_MOD_SHUFFLE:
		return CHANNEL_MOD_SHUFFLE
	if modifier == CHANNEL_MOD_RANDOM:
		return CHANNEL_MOD_RANDOM
	return ""


func _channel_map_for_modifier(keys: int, modifier: String, raw_map: Variant) -> Array[int]:
	var channel_map: Array[int] = []
	if modifier != CHANNEL_MOD_SHUFFLE:
		return channel_map
	return _channel_map_from(raw_map, keys)


func _channel_map_from(raw_map: Variant, keys: int) -> Array[int]:
	var channel_map: Array[int] = []
	if raw_map is Array and not raw_map.is_empty():
		if raw_map.size() != keys:
			return []
		var used := {}
		for raw_lane: Variant in raw_map:
			if not _is_integer_like(raw_lane):
				return []
			var lane := int(raw_lane)
			if lane < 0 or lane >= keys or used.has(lane):
				return []
			channel_map.append(lane)
			used[lane] = true
		return channel_map
	for lane in range(keys):
		channel_map.append(lane)
	channel_map.shuffle()
	return channel_map


func _notes_with_channel_modifier(
		notes: Array[Dictionary],
		keys: int,
		modifier: String,
		channel_map: Array[int],
		raw_maps_by_measure: Variant) -> Array[Dictionary]:
	if modifier == CHANNEL_MOD_RANDOM:
		return _notes_with_random_channel_modifier(notes, keys, raw_maps_by_measure)

	var remapped: Array[Dictionary] = []
	for note: Dictionary in notes:
		var mapped_note: Dictionary = note.duplicate(true)
		if modifier == CHANNEL_MOD_MIRROR:
			mapped_note["lane"] = keys - 1 - int(mapped_note.get("lane", -1))
		elif modifier == CHANNEL_MOD_SHUFFLE:
			mapped_note["lane"] = channel_map[int(mapped_note.get("lane", -1))]
		remapped.append(mapped_note)
	return remapped


func _notes_with_random_channel_modifier(
		notes: Array[Dictionary],
		keys: int,
		raw_maps_by_measure: Variant) -> Array[Dictionary]:
	var remapped: Array[Dictionary] = []
	var active_long_notes := {}
	var current_measure: int = -1
	var current_map: Array[int] = []

	for note: Dictionary in notes:
		var note_measure := _note_measure(note)
		_release_finished_random_longs(active_long_notes, float(note.get("startMs", 0.0)))
		if note_measure > current_measure:
			if active_long_notes.is_empty():
				current_map = _random_channel_map_for_measure(keys, raw_maps_by_measure, note_measure)
				if current_map.is_empty():
					return []
			current_measure = note_measure

		var source_lane := int(note.get("lane", -1))
		var target_lane := int(current_map[source_lane])
		var kind := str(note.get("kind", ""))
		if kind == "holdStart":
			active_long_notes[source_lane] = {
				"targetLane": target_lane,
				"endMs": float(note.get("endMs", note.get("startMs", 0.0))),
			}
		elif _random_target_lane_is_active(active_long_notes, target_lane):
			continue

		var mapped_note: Dictionary = note.duplicate(true)
		mapped_note["lane"] = target_lane
		remapped.append(mapped_note)
	return remapped


func _random_channel_map_for_measure(keys: int, raw_maps_by_measure: Variant, measure: int) -> Array[int]:
	if raw_maps_by_measure is Array and measure >= 0 and measure < raw_maps_by_measure.size():
		return _channel_map_from(raw_maps_by_measure[measure], keys)
	return _channel_map_from([], keys)


func _note_measure(note: Dictionary) -> int:
	var measure: Variant = note.get("measure", 0)
	if _is_integer_like(measure):
		return int(measure)
	return 0


func _release_finished_random_longs(active_long_notes: Dictionary, now_ms: float) -> void:
	for raw_source_lane: Variant in active_long_notes.keys():
		var long_note: Dictionary = active_long_notes.get(raw_source_lane, {})
		if float(long_note.get("endMs", 0.0)) <= now_ms:
			active_long_notes.erase(raw_source_lane)


func _random_target_lane_is_active(active_long_notes: Dictionary, target_lane: int) -> bool:
	for raw_long_note: Variant in active_long_notes.values():
		var long_note: Dictionary = raw_long_note if raw_long_note is Dictionary else {}
		if int(long_note.get("targetLane", -1)) == target_lane:
			return true
	return false
