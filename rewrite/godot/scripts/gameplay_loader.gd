extends RefCounted

const REQUIRED_NOTE_FIELDS: Array[String] = [
	"lane",
	"startMs",
	"sampleId",
	"volume",
	"pan",
	"kind",
]

const REQUIRED_AUTO_PLAY_FIELDS: Array[String] = [
	"startMs",
	"sampleId",
	"volume",
	"pan",
]


func load_from_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var content: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(content)
	if not parsed is Dictionary:
		return {}

	var chart: Dictionary = parsed
	if not _is_valid_chart(chart):
		return {}

	return chart


func _is_valid_chart(chart: Dictionary) -> bool:
	if chart.get("schemaVersion") != 1:
		return false
	if chart.get("format") != "VOS":
		return false
	if not chart.has("keys"):
		return false

	var keys: Variant = chart.get("keys")
	if not (keys is int or keys is float):
		return false
	if float(keys) <= 0.0:
		return false

	var notes: Variant = chart.get("notes")
	if not notes is Array:
		return false
	for note: Variant in notes:
		if not note is Dictionary:
			return false
		if not _has_fields(note, REQUIRED_NOTE_FIELDS):
			return false

	var auto_play_events: Variant = chart.get("autoPlayEvents")
	if not auto_play_events is Array:
		return false
	for event: Variant in auto_play_events:
		if not event is Dictionary:
			return false
		if not _has_fields(event, REQUIRED_AUTO_PLAY_FIELDS):
			return false

	return true


func _has_fields(entry: Dictionary, fields: Array[String]) -> bool:
	for field: String in fields:
		if not entry.has(field):
			return false
	return true
