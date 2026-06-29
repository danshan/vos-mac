extends RefCounted

const REQUIRED_ENTRY_FIELDS: Array[String] = [
	"id",
	"format",
	"sourcePath",
	"title",
	"artist",
	"keys",
	"level",
	"levelKnown",
	"bpm",
	"durationMs",
	"noteCount",
	"exportStatus",
]

var _entries: Array[Dictionary] = []


func load_from_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false

	var content: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(content)
	if not parsed is Dictionary:
		return false

	var root: Dictionary = parsed
	if root.get("schemaVersion") != 1:
		return false

	var raw_entries: Variant = root.get("entries")
	if not raw_entries is Array:
		return false

	var next_entries: Array[Dictionary] = []
	for raw_entry: Variant in raw_entries:
		if not raw_entry is Dictionary:
			return false

		var entry: Dictionary = raw_entry
		if not _is_valid_entry(entry):
			return false

		next_entries.append(entry)

	_entries = next_entries
	return true


func count() -> int:
	return _entries.size()


func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in _entries:
		result.append(entry.duplicate(true))
	return result


func filter(text: String) -> Array[Dictionary]:
	var query: String = text.to_lower()
	var results: Array[Dictionary] = []

	for entry: Dictionary in _entries:
		var title: String = str(entry.get("title", "")).to_lower()
		var artist: String = str(entry.get("artist", "")).to_lower()
		if title.contains(query) or artist.contains(query):
			results.append(entry)

	return results


func _is_valid_entry(entry: Dictionary) -> bool:
	for field: String in REQUIRED_ENTRY_FIELDS:
		if not entry.has(field):
			return false
	return true
