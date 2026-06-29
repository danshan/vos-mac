extends SceneTree

const GameplayLoader = preload("res://scripts/gameplay_loader.gd")

func _init() -> void:
	var loader = GameplayLoader.new()
	var chart: Dictionary = loader.load_from_file("res://test/fixtures/gameplay.json")

	if not _expect_string(chart.get("chartId", ""), "vos:fixture", "chart id"):
		return
	if not _expect_string(chart.get("format", ""), "VOS", "format"):
		return

	var notes: Array = chart.get("notes", [])
	if not _expect_int(notes.size(), 1, "note count"):
		return

	var note: Dictionary = notes[0]
	if not _expect_int(note.get("lane", -1), 0, "note lane"):
		return
	if not _expect_float(note.get("startMs", -1.0), 1000.0, "note start"):
		return
	if not _expect_string(note.get("kind", ""), "tap", "note kind"):
		return

	var auto_play_events: Array = chart.get("autoPlayEvents", [])
	if not _expect_int(auto_play_events.size(), 1, "auto play event count"):
		return

	var time_ms_chart: Dictionary = _valid_chart()
	time_ms_chart["autoPlayEvents"] = [{"timeMs": 25.0, "sampleId": 1, "volume": 1.0, "pan": 0.0}]
	var time_ms_path := _chart_path("time_ms")
	if not _write_chart(time_ms_path, time_ms_chart):
		return

	var normalized_chart: Dictionary = loader.load_from_file(time_ms_path)
	if not _expect_bool(normalized_chart.is_empty(), false, "timeMs chart load"):
		return
	var normalized_events: Array = normalized_chart.get("autoPlayEvents", [])
	if not _expect_float(normalized_events[0].get("startMs", -1.0), 25.0, "normalized event start"):
		return
	if not _expect_bool(normalized_events[0].has("timeMs"), false, "normalized event timeMs removed"):
		return

	var bga_time_ms_chart: Dictionary = _valid_chart()
	bga_time_ms_chart["bgaEvents"] = [{"timeMs": 75.0, "spriteId": 3}]
	var bga_time_ms_path := _chart_path("bga_time_ms")
	if not _write_chart(bga_time_ms_path, bga_time_ms_chart):
		return

	var normalized_bga_chart: Dictionary = loader.load_from_file(bga_time_ms_path)
	if not _expect_bool(normalized_bga_chart.is_empty(), false, "bga timeMs chart load"):
		return
	var normalized_bga_events: Array = normalized_bga_chart.get("bgaEvents", [])
	if not _expect_int(normalized_bga_events.size(), 1, "normalized bga event count"):
		return
	if not _expect_float(normalized_bga_events[0].get("startMs", -1.0), 75.0, "normalized bga event start"):
		return
	if not _expect_int(normalized_bga_events[0].get("spriteId", -1), 3, "normalized bga sprite id"):
		return
	if not _expect_bool(normalized_bga_events[0].has("timeMs"), false, "normalized bga timeMs removed"):
		return

	var bga_sprite_chart: Dictionary = _valid_chart()
	bga_sprite_chart["bgaSprites"] = [{
		"spriteId": 3.0,
		"texturePath": "res://test/fixtures/bga.png",
		"textureX": 1,
		"textureY": 2,
		"textureWidth": 64,
		"textureHeight": 32,
	}]
	var bga_sprite_path := _chart_path("bga_sprite")
	if not _write_chart(bga_sprite_path, bga_sprite_chart):
		return

	var normalized_bga_sprite_chart: Dictionary = loader.load_from_file(bga_sprite_path)
	if not _expect_bool(normalized_bga_sprite_chart.is_empty(), false, "bga sprite chart load"):
		return
	var normalized_bga_sprites: Array = normalized_bga_sprite_chart.get("bgaSprites", [])
	if not _expect_int(normalized_bga_sprites.size(), 1, "normalized bga sprite count"):
		return
	if not _expect_int(typeof(normalized_bga_sprites[0].get("spriteId")), TYPE_INT, "normalized bga sprite id type"):
		return
	if not _expect_int(normalized_bga_sprites[0].get("spriteId", -1), 3, "normalized bga sprite id"):
		return
	if not _expect_string(normalized_bga_sprites[0].get("texturePath", ""), "res://test/fixtures/bga.png", "normalized bga sprite texture path"):
		return
	if not _expect_float(normalized_bga_sprites[0].get("textureX", -1.0), 1.0, "normalized bga sprite texture x"):
		return
	if not _expect_float(normalized_bga_sprites[0].get("textureY", -1.0), 2.0, "normalized bga sprite texture y"):
		return
	if not _expect_float(normalized_bga_sprites[0].get("textureWidth", -1.0), 64.0, "normalized bga sprite texture width"):
		return
	if not _expect_float(normalized_bga_sprites[0].get("textureHeight", -1.0), 32.0, "normalized bga sprite texture height"):
		return

	var bga_video_chart: Dictionary = _valid_chart()
	bga_video_chart["bgaVideoPath"] = "res://test/fixtures/intro.ogv"
	var bga_video_path := _chart_path("bga_video")
	if not _write_chart(bga_video_path, bga_video_chart):
		return

	var normalized_bga_video_chart: Dictionary = loader.load_from_file(bga_video_path)
	if not _expect_bool(normalized_bga_video_chart.is_empty(), false, "bga video chart load"):
		return
	if not _expect_string(normalized_bga_video_chart.get("bgaVideoPath", ""), "res://test/fixtures/intro.ogv", "normalized bga video path"):
		return

	var mirror_chart: Dictionary = _valid_chart()
	mirror_chart["channelModifier"] = "Mirror"
	mirror_chart["notes"] = [
		{"id": 1, "lane": 0, "startMs": 1000.0, "endMs": null, "sampleId": 2, "volume": 1.0, "pan": 0.0, "kind": "tap"},
		{"id": 2, "lane": 3, "startMs": 1100.0, "endMs": null, "sampleId": 3, "volume": 1.0, "pan": 0.0, "kind": "tap"},
		{"id": 3, "lane": 6, "startMs": 1200.0, "endMs": null, "sampleId": 4, "volume": 1.0, "pan": 0.0, "kind": "tap"},
	]
	var mirror_path := _chart_path("mirror_modifier")
	if not _write_chart(mirror_path, mirror_chart):
		return
	var mirrored_chart: Dictionary = loader.load_from_file(mirror_path)
	if not _expect_bool(mirrored_chart.is_empty(), false, "mirror chart load"):
		return
	var mirrored_notes: Array = mirrored_chart.get("notes", [])
	if not _expect_int(int(mirrored_notes[0].get("lane", -1)), 6, "mirror lane one to seven"):
		return
	if not _expect_int(int(mirrored_notes[1].get("lane", -1)), 3, "mirror middle lane unchanged"):
		return
	if not _expect_int(int(mirrored_notes[2].get("lane", -1)), 0, "mirror lane seven to one"):
		return

	var shuffle_chart: Dictionary = _valid_chart()
	shuffle_chart["channelModifier"] = "Shuffle"
	shuffle_chart["channelMap"] = [6, 4, 2, 3, 1, 5, 0]
	shuffle_chart["notes"] = [
		{"id": 1, "lane": 0, "startMs": 1000.0, "endMs": null, "sampleId": 2, "volume": 1.0, "pan": 0.0, "kind": "tap"},
		{"id": 2, "lane": 1, "startMs": 1100.0, "endMs": null, "sampleId": 3, "volume": 1.0, "pan": 0.0, "kind": "tap"},
		{"id": 3, "lane": 6, "startMs": 1200.0, "endMs": null, "sampleId": 4, "volume": 1.0, "pan": 0.0, "kind": "tap"},
	]
	var shuffle_path := _chart_path("shuffle_modifier")
	if not _write_chart(shuffle_path, shuffle_chart):
		return
	var shuffled_chart: Dictionary = loader.load_from_file(shuffle_path)
	if not _expect_bool(shuffled_chart.is_empty(), false, "shuffle chart load"):
		return
	var shuffled_notes: Array = shuffled_chart.get("notes", [])
	if not _expect_int(int(shuffled_notes[0].get("lane", -1)), 6, "shuffle lane one"):
		return
	if not _expect_int(int(shuffled_notes[1].get("lane", -1)), 4, "shuffle lane two"):
		return
	if not _expect_int(int(shuffled_notes[2].get("lane", -1)), 0, "shuffle lane seven"):
		return

	var random_chart: Dictionary = _valid_chart()
	random_chart["channelModifier"] = "Random"
	random_chart["channelMapsByMeasure"] = [
		[6, 5, 4, 3, 2, 1, 0],
		[0, 1, 2, 3, 4, 5, 6],
	]
	random_chart["notes"] = [
		{"id": 1, "lane": 0, "startMs": 1000.0, "measure": 0, "endMs": null, "sampleId": 2, "volume": 1.0, "pan": 0.0, "kind": "tap"},
		{"id": 2, "lane": 0, "startMs": 2000.0, "measure": 1, "endMs": null, "sampleId": 3, "volume": 1.0, "pan": 0.0, "kind": "tap"},
	]
	var random_path := _chart_path("random_modifier")
	if not _write_chart(random_path, random_chart):
		return
	var randomized_chart: Dictionary = loader.load_from_file(random_path)
	if not _expect_bool(randomized_chart.is_empty(), false, "random chart load"):
		return
	var randomized_notes: Array = randomized_chart.get("notes", [])
	if not _expect_int(int(randomized_notes[0].get("lane", -1)), 6, "random measure zero lane"):
		return
	if not _expect_int(int(randomized_notes[1].get("lane", -1)), 0, "random measure one lane"):
		return

	var random_hold_chart: Dictionary = _valid_chart()
	random_hold_chart["channelModifier"] = "Random"
	random_hold_chart["channelMapsByMeasure"] = [
		[6, 5, 4, 3, 2, 1, 0],
		[0, 1, 2, 3, 4, 5, 6],
	]
	random_hold_chart["notes"] = [
		{"id": 1, "lane": 0, "startMs": 1000.0, "measure": 0, "endMs": 2500.0, "endMeasure": 1, "sampleId": 2, "volume": 1.0, "pan": 0.0, "kind": "holdStart"},
		{"id": 2, "lane": 1, "startMs": 2000.0, "measure": 1, "endMs": null, "sampleId": 3, "volume": 1.0, "pan": 0.0, "kind": "tap"},
	]
	var random_hold_path := _chart_path("random_hold_modifier")
	if not _write_chart(random_hold_path, random_hold_chart):
		return
	var randomized_hold_chart: Dictionary = loader.load_from_file(random_hold_path)
	if not _expect_bool(randomized_hold_chart.is_empty(), false, "random hold chart load"):
		return
	var randomized_hold_notes: Array = randomized_hold_chart.get("notes", [])
	if not _expect_int(int(randomized_hold_notes[0].get("lane", -1)), 6, "random hold lane"):
		return
	if not _expect_int(int(randomized_hold_notes[1].get("lane", -1)), 5, "random keeps map while long note crosses measure"):
		return

	if not _expect_rejected(loader, _chart_with("schemaVersion", 2), "bad schema"):
		return
	if not _expect_rejected(loader, _chart_with("keys", "7"), "string keys"):
		return
	if not _expect_rejected(loader, _chart_with("keys", 0), "zero keys"):
		return
	if not _expect_rejected(loader, _chart_without_note_field("kind"), "missing note kind"):
		return
	if not _expect_rejected(loader, _chart_with_note("lane", "0"), "string note lane"):
		return
	if not _expect_rejected(loader, _chart_with_note("startMs", -1.0), "negative note start"):
		return
	if not _expect_rejected(loader, _chart_with_note("kind", "scratch"), "invalid note kind"):
		return
	if not _expect_rejected(loader, _chart_with_note("sampleId", "2"), "string note sample id"):
		return
	if not _expect_rejected(loader, _chart_with_note("sampleId", 0), "zero note sample id"):
		return
	if not _expect_rejected(loader, _chart_with_note("lane", 7), "note lane outside keys"):
		return
	if not _expect_rejected(loader, _chart_without_event_timestamp(), "missing event timestamp"):
		return
	if not _expect_rejected(loader, _chart_with_event("startMs", "0"), "string event timestamp"):
		return
	if not _expect_rejected(loader, _chart_with_event("startMs", -1.0), "negative event timestamp"):
		return
	if not _expect_rejected(loader, _chart_with_event("sampleId", "1"), "string event sample id"):
		return
	if not _expect_rejected(loader, _chart_with_event("sampleId", 0), "zero event sample id"):
		return
	if not _expect_rejected(loader, _chart_with_event("volume", "1.0"), "string event volume"):
		return
	if not _expect_rejected(loader, _chart_with_event("pan", "0.0"), "string event pan"):
		return
	if not _expect_rejected(loader, _chart_without_bga_timestamp(), "missing bga timestamp"):
		return
	if not _expect_rejected(loader, _chart_with_bga_event("startMs", "0"), "string bga timestamp"):
		return
	if not _expect_rejected(loader, _chart_with_bga_event("startMs", -1.0), "negative bga timestamp"):
		return
	if not _expect_rejected(loader, _chart_with_bga_event("spriteId", "1"), "string bga sprite id"):
		return
	if not _expect_rejected(loader, _chart_with_bga_event("spriteId", 0), "zero bga sprite id"):
		return
	if not _expect_rejected(loader, _chart_with_bga_sprite("spriteId", "1"), "string bga sprite resource id"):
		return
	if not _expect_rejected(loader, _chart_with_bga_sprite("spriteId", 0), "zero bga sprite resource id"):
		return
	if not _expect_rejected(loader, _chart_with_bga_sprite("texturePath", ""), "empty bga sprite texture path"):
		return
	if not _expect_rejected(loader, _chart_with_bga_sprite("textureX", "0"), "string bga sprite texture x"):
		return
	if not _expect_rejected(loader, _chart_with_bga_sprite("textureY", "0"), "string bga sprite texture y"):
		return
	if not _expect_rejected(loader, _chart_with_bga_sprite("textureWidth", 0), "zero bga sprite texture width"):
		return
	if not _expect_rejected(loader, _chart_with_bga_sprite("textureHeight", 0), "zero bga sprite texture height"):
		return
	if not _expect_rejected(loader, _chart_with("bgaVideoPath", ""), "empty bga video path"):
		return
	if not _expect_rejected(loader, _chart_with("bgaVideoPath", 7), "numeric bga video path"):
		return

	var missing_chart: Dictionary = loader.load_from_file("res://test/fixtures/missing_gameplay.json")
	if not _expect_bool(missing_chart.is_empty(), true, "missing file result"):
		return

	quit(0)


func _valid_chart() -> Dictionary:
	return {
		"schemaVersion": 1,
		"chartId": "vos:fixture",
		"format": "VOS",
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 3000,
		"notes": [{"id": 1, "lane": 0, "startMs": 1000.0, "endMs": null, "sampleId": 2, "volume": 1.0, "pan": 0.0, "kind": "tap"}],
		"autoPlayEvents": [{"startMs": 0.0, "sampleId": 1, "volume": 1.0, "pan": 0.0}],
		"bgaEvents": [{"startMs": 50.0, "spriteId": 7}],
		"bgaSprites": [{"spriteId": 7, "texturePath": "res://test/fixtures/bga.png"}],
	}


func _chart_with(field: String, value: Variant) -> Dictionary:
	var chart: Dictionary = _valid_chart()
	chart[field] = value
	return chart


func _chart_with_note(field: String, value: Variant) -> Dictionary:
	var chart: Dictionary = _valid_chart()
	chart["notes"][0][field] = value
	return chart


func _chart_without_note_field(field: String) -> Dictionary:
	var chart: Dictionary = _valid_chart()
	chart["notes"][0].erase(field)
	return chart


func _chart_with_event(field: String, value: Variant) -> Dictionary:
	var chart: Dictionary = _valid_chart()
	chart["autoPlayEvents"][0][field] = value
	return chart


func _chart_without_event_timestamp() -> Dictionary:
	var chart: Dictionary = _valid_chart()
	chart["autoPlayEvents"][0].erase("startMs")
	chart["autoPlayEvents"][0].erase("timeMs")
	return chart


func _chart_with_bga_event(field: String, value: Variant) -> Dictionary:
	var chart: Dictionary = _valid_chart()
	chart["bgaEvents"][0][field] = value
	return chart


func _chart_without_bga_timestamp() -> Dictionary:
	var chart: Dictionary = _valid_chart()
	chart["bgaEvents"][0].erase("startMs")
	chart["bgaEvents"][0].erase("timeMs")
	return chart


func _chart_with_bga_sprite(field: String, value: Variant) -> Dictionary:
	var chart: Dictionary = _valid_chart()
	chart["bgaSprites"][0][field] = value
	return chart


func _expect_rejected(loader: RefCounted, chart: Dictionary, label: String) -> bool:
	var path: String = _chart_path(label)
	if not _write_chart(path, chart):
		return false

	var loaded: Dictionary = loader.load_from_file(path)
	return _expect_bool(loaded.is_empty(), true, label)


func _chart_path(label: String) -> String:
	return "%s/open2jam_%s_gameplay.json" % [OS.get_temp_dir(), label.replace(" ", "_")]


func _write_chart(path: String, chart: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write chart fixture '%s'." % path)
		quit(1)
		return false

	file.store_string(JSON.stringify(chart))
	return true


func _expect_bool(actual: bool, expected: bool, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true


func _expect_int(actual: int, expected: int, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true


func _expect_float(actual: float, expected: float, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true


func _expect_string(actual: String, expected: String, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true
