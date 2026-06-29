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


func load_from_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var content: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(content)
	if not parsed is Dictionary:
		return {}

	var chart: Dictionary = parsed
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
	if normalized_chart.has("rank"):
		var rank: Variant = normalized_chart.get("rank")
		if not _is_integer_like(rank) or int(rank) < 0:
			return {}
		normalized_chart["rank"] = int(rank)
	normalized_chart["notes"] = normalized_notes
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
