extends RefCounted

const REQUIRED_NOTE_FIELDS: Array[String] = [
	"lane",
	"startMs",
	"measure",
	"sampleId",
	"volume",
	"pan",
	"kind",
]

const VALID_NOTE_KINDS := ["tap", "holdStart"]
const VALID_FORMATS := ["VOS", "OSU", "OJN"]
const CHANNEL_MOD_NONE: String = "None"
const CHANNEL_MOD_MIRROR: String = "Mirror"
const CHANNEL_MOD_SHUFFLE: String = "Shuffle"
const CHANNEL_MOD_RANDOM: String = "Random"
const VALID_SPEED_TYPES := ["HiSpeed", "xRSpeed", "WSpeed", "RegulSpeed"]
const VALID_VISIBILITY_MODIFIERS := ["None", "Hidden", "Sudden", "Dark"]
const VALID_JUDGMENT_TYPES := ["beat", "time"]


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


func load_native_chart_with_overrides(chart: Dictionary, overrides: Dictionary) -> Dictionary:
	var configured := chart.duplicate(true)
	configured.merge(overrides, true)
	return _normalized_chart(configured, true)


func _normalized_chart(chart: Dictionary, native_values: bool = false) -> Dictionary:
	if chart.get("schemaVersion") != 1:
		return {}
	if not VALID_FORMATS.has(chart.get("format")):
		return {}
	var chart_format := str(chart.get("format"))
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
		var normalized_note: Dictionary = _normalized_note(note, int(keys), chart_format, native_values)
		if normalized_note.is_empty():
			return {}
		normalized_notes.append(normalized_note)

	var visual_timing: Array[Dictionary] = _normalized_timing(chart.get("visualTiming"), native_values)
	if visual_timing.is_empty():
		return {}
	var judgment_timing: Array[Dictionary] = _normalized_timing(chart.get("judgmentTiming"), native_values)
	if judgment_timing.is_empty():
		return {}

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

	var bga_events: Variant = chart.get("bgaEvents", [])
	if not bga_events is Array:
		return {}
	var normalized_bga_events: Array[Dictionary] = []
	for event: Variant in bga_events:
		if not event is Dictionary:
			return {}
		var normalized_bga_event: Dictionary = _normalized_bga_event(event)
		if normalized_bga_event.is_empty():
			return {}
		normalized_bga_events.append(normalized_bga_event)

	var bga_sprites: Variant = chart.get("bgaSprites", [])
	if not bga_sprites is Array:
		return {}
	var normalized_bga_sprites: Array[Dictionary] = []
	for sprite: Variant in bga_sprites:
		if not sprite is Dictionary:
			return {}
		var normalized_bga_sprite: Dictionary = _normalized_bga_sprite(sprite)
		if normalized_bga_sprite.is_empty():
			return {}
		normalized_bga_sprites.append(normalized_bga_sprite)

	var normalized_chart: Dictionary = chart.duplicate(true)
	if normalized_chart.has("bgaVideoPath"):
		var bga_video_path: Variant = normalized_chart.get("bgaVideoPath")
		if not bga_video_path is String or str(bga_video_path).strip_edges().is_empty():
			return {}
		normalized_chart["bgaVideoPath"] = str(bga_video_path)
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
	if not _normalize_optional_string_enum(normalized_chart, "speedType", VALID_SPEED_TYPES):
		return {}
	if not _normalize_optional_string_enum(normalized_chart, "visibilityModifier", VALID_VISIBILITY_MODIFIERS):
		return {}
	if not _normalize_optional_string_enum(normalized_chart, "judgmentType", VALID_JUDGMENT_TYPES):
		return {}
	var channel_notes: Array[Dictionary] = _notes_with_channel_modifier(
			normalized_notes,
			int(keys),
			channel_modifier,
			channel_map,
			normalized_chart.get("channelMapsByMeasure", []))
	if channel_modifier == CHANNEL_MOD_RANDOM and normalized_notes.size() > 0 and channel_notes.is_empty():
		return {}
	normalized_chart["notes"] = channel_notes
	normalized_chart["visualTiming"] = visual_timing
	normalized_chart["judgmentTiming"] = judgment_timing
	normalized_chart["autoPlayEvents"] = normalized_events
	normalized_chart["bgaEvents"] = normalized_bga_events
	normalized_chart["bgaSprites"] = normalized_bga_sprites
	return normalized_chart


func _normalized_note(note: Dictionary, keys: int, chart_format: String, allow_sampleless: bool = false) -> Dictionary:
	if not _has_fields(note, REQUIRED_NOTE_FIELDS):
		return {}
	if note.has("id"):
		return {}

	var lane: Variant = note.get("lane")
	if not _is_integer_like(lane):
		return {}
	if int(lane) < 0 or int(lane) >= keys:
		return {}

	var start_ms: Variant = note.get("startMs")
	if not _is_non_negative_number(start_ms):
		return {}

	var measure: Variant = note.get("measure")
	if not _is_integer_like(measure) or int(measure) < 0:
		return {}

	var sample_id: Variant = note.get("sampleId")
	if chart_format == "OSU" or allow_sampleless:
		if not _is_integer_like(sample_id) or int(sample_id) < 0:
			return {}
	else:
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
	if str(kind) == "tap" and (note.has("endMs") or note.has("endMeasure")):
		return {}

	var normalized_note: Dictionary = note.duplicate(true)
	normalized_note["lane"] = int(lane)
	normalized_note["startMs"] = float(start_ms)
	normalized_note["measure"] = int(measure)
	normalized_note["sampleId"] = int(sample_id)
	if not _normalize_optional_integer(normalized_note, "eventOrder"):
		return {}
	if not _normalize_optional_integer(normalized_note, "releaseEventOrder"):
		return {}
	if str(kind) == "holdStart" and not _normalize_hold_note(normalized_note, float(start_ms)):
		return {}
	return normalized_note


func _normalize_hold_note(note: Dictionary, start_ms: float) -> bool:
	if not note.has("endMs") or not note.has("endMeasure"):
		return false

	var end_ms: Variant = note.get("endMs")
	if not _is_non_negative_number(end_ms):
		return false
	if float(end_ms) < start_ms:
		return false

	var end_measure: Variant = note.get("endMeasure")
	if not _is_integer_like(end_measure) or int(end_measure) < 0:
		return false

	note["endMs"] = float(end_ms)
	note["endMeasure"] = int(end_measure)
	return true


func _normalized_timing(raw_timing: Variant, allow_stops: bool = false) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	if not raw_timing is Array or raw_timing.is_empty():
		return normalized
	for raw_change: Variant in raw_timing:
		if not raw_change is Dictionary:
			return []
		if not _is_non_negative_number(raw_change.get("timeMs")):
			return []
		if not (_is_non_negative_number(raw_change.get("bpm")) if allow_stops else _is_positive_number(raw_change.get("bpm"))):
			return []
		var change: Dictionary = raw_change.duplicate(true)
		change["timeMs"] = float(raw_change.get("timeMs"))
		change["bpm"] = float(raw_change.get("bpm"))
		normalized.append(change)
	return normalized


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


func _normalized_bga_event(event: Dictionary) -> Dictionary:
	var start_ms: Variant = null
	if event.has("startMs"):
		start_ms = event.get("startMs")
	elif event.has("timeMs"):
		start_ms = event.get("timeMs")
	else:
		return {}

	if not _is_non_negative_number(start_ms):
		return {}

	var sprite_id: Variant = event.get("spriteId")
	if not _is_positive_integer_like(sprite_id):
		return {}

	var normalized_event: Dictionary = event.duplicate(true)
	normalized_event.erase("timeMs")
	normalized_event["startMs"] = float(start_ms)
	normalized_event["spriteId"] = int(sprite_id)
	return normalized_event


func _normalized_bga_sprite(sprite: Dictionary) -> Dictionary:
	if not _has_fields(sprite, ["spriteId", "texturePath"]):
		return {}

	var sprite_id: Variant = sprite.get("spriteId")
	if not _is_positive_integer_like(sprite_id):
		return {}

	var texture_path: Variant = sprite.get("texturePath")
	if not texture_path is String or str(texture_path).strip_edges().is_empty():
		return {}

	var normalized_sprite: Dictionary = sprite.duplicate(true)
	normalized_sprite["spriteId"] = int(sprite_id)
	normalized_sprite["texturePath"] = str(texture_path)

	if not _normalize_optional_non_negative_number(normalized_sprite, "textureX"):
		return {}
	if not _normalize_optional_non_negative_number(normalized_sprite, "textureY"):
		return {}
	if not _normalize_optional_positive_number(normalized_sprite, "textureWidth"):
		return {}
	if not _normalize_optional_positive_number(normalized_sprite, "textureHeight"):
		return {}

	return normalized_sprite


func _normalize_optional_non_negative_number(entry: Dictionary, field: String) -> bool:
	if not entry.has(field):
		return true
	var value: Variant = entry.get(field)
	if not _is_non_negative_number(value):
		return false
	entry[field] = float(value)
	return true


func _normalize_optional_positive_number(entry: Dictionary, field: String) -> bool:
	if not entry.has(field):
		return true
	var value: Variant = entry.get(field)
	if not _is_positive_number(value):
		return false
	entry[field] = float(value)
	return true


func _normalize_optional_integer(entry: Dictionary, field: String) -> bool:
	if not entry.has(field):
		return true
	var value: Variant = entry.get(field)
	if not _is_integer_like(value):
		return false
	entry[field] = int(value)
	return true


func _normalize_optional_string_enum(entry: Dictionary, field: String, valid_values: Array) -> bool:
	if not entry.has(field):
		return true
	var value: Variant = entry.get(field)
	if not value is String:
		return false
	var text := str(value)
	if not valid_values.has(text):
		return false
	entry[field] = text
	return true


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
		current_measure = _release_past_random_longs(
				active_long_notes,
				float(note.get("startMs", 0.0)),
				current_measure)
		if note_measure > current_measure:
			if active_long_notes.is_empty():
				current_map = _random_channel_map_for_measure(keys, raw_maps_by_measure, note_measure)
				if current_map.is_empty():
					return []
			current_measure = note_measure
		_release_ordered_random_longs(active_long_notes, note)

		var source_lane := int(note.get("lane", -1))
		var target_lane := int(current_map[source_lane])
		var kind := str(note.get("kind", ""))
		if kind == "holdStart":
			active_long_notes[source_lane] = {
				"targetLane": target_lane,
				"endMs": float(note.get("endMs", note.get("startMs", 0.0))),
				"endMeasure": int(note.get("endMeasure", note_measure)),
				"releaseEventOrder": int(note.get("releaseEventOrder", -1)),
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


func _release_past_random_longs(active_long_notes: Dictionary, now_ms: float, current_measure: int) -> int:
	var next_measure := current_measure
	for raw_source_lane: Variant in active_long_notes.keys():
		var long_note: Dictionary = active_long_notes.get(raw_source_lane, {})
		if float(long_note.get("endMs", 0.0)) < now_ms:
			var release_measure := int(long_note.get("endMeasure", next_measure))
			if release_measure > next_measure:
				next_measure = release_measure
			active_long_notes.erase(raw_source_lane)
	return next_measure


func _release_ordered_random_longs(active_long_notes: Dictionary, note: Dictionary) -> void:
	if not note.has("eventOrder"):
		return
	var now_ms := float(note.get("startMs", 0.0))
	var event_order := int(note.get("eventOrder", -1))
	for raw_source_lane: Variant in active_long_notes.keys():
		var long_note: Dictionary = active_long_notes.get(raw_source_lane, {})
		if not long_note.has("releaseEventOrder"):
			continue
		if not is_equal_approx(float(long_note.get("endMs", 0.0)), now_ms):
			continue
		var release_order := int(long_note.get("releaseEventOrder", -1))
		if release_order >= 0 and release_order < event_order:
			active_long_notes.erase(raw_source_lane)


func _random_target_lane_is_active(active_long_notes: Dictionary, target_lane: int) -> bool:
	for raw_long_note: Variant in active_long_notes.values():
		var long_note: Dictionary = raw_long_note if raw_long_note is Dictionary else {}
		if int(long_note.get("targetLane", -1)) == target_lane:
			return true
	return false
