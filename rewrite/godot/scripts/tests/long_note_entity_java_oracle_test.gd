extends SceneTree

const GameplayView = preload("res://scripts/gameplay_view.gd")

const BPM: float = 150.0
const MEASURE_SIZE: float = 160.0


func _init() -> void:
	var oracle := _load_oracle()
	if oracle.is_empty():
		return

	var scenarios: Variant = oracle.get("scenarios")
	if not scenarios is Array:
		push_error("Expected long note entity oracle scenarios.")
		quit(1)
		return

	for raw_scenario: Variant in scenarios:
		if not raw_scenario is Dictionary:
			push_error("Expected long note entity oracle scenario object.")
			quit(1)
			return
		if not _verify_scenario(raw_scenario, oracle):
			return

	quit(0)


func _load_oracle() -> Dictionary:
	var path := "res://test/fixtures/long-note-entity-oracle.json"
	if not FileAccess.file_exists(path):
		push_error("Missing long note entity oracle fixture: %s" % path)
		quit(1)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Expected long note entity oracle root object.")
		quit(1)
		return {}
	var root: Dictionary = parsed
	if int(root.get("schemaVersion", 0)) != 1:
		push_error("Expected long note entity oracle schema version 1.")
		quit(1)
		return {}
	if str(root.get("source", "")) != "LongNoteEntity.draw":
		push_error("Expected long note entity oracle source LongNoteEntity.draw.")
		quit(1)
		return {}
	return root


func _verify_scenario(scenario: Dictionary, oracle: Dictionary) -> bool:
	var elapsed_ms := float(scenario.get("elapsedMs", 0.0))
	var view = GameplayView.new()
	if not _expect_bool(view.load_metadata(_metadata_for_oracle(oracle)), true,
			"%s metadata load" % scenario.get("name", "")):
		return false
	if not _expect_bool(view.load_chart(_chart_for_scenario(scenario, oracle)), true,
			"%s chart load" % scenario.get("name", "")):
		return false

	view.update_time(elapsed_ms)

	if not _expect_bool(view.has_node("Note_000"), true, "%s long note node" % scenario.get("name", "")):
		return false
	var note_node: Control = view.get_node("Note_000")
	var draws: Variant = scenario.get("draws")
	if not draws is Array:
		push_error("Expected long note entity oracle draws array.")
		quit(1)
		return false
	if not _expect_int(draws.size(), 3, "%s draw count" % scenario.get("name", "")):
		return false

	var part_order := ["Body", "Tail", "Head"]
	for i in range(part_order.size()):
		var draw: Dictionary = draws[i]
		var child_name: String = part_order[i]
		if not _expect_string(str(draw.get("part", "")).to_lower(), child_name.to_lower(),
				"%s draw part %d" % [scenario.get("name", ""), i]):
			return false
		if not _expect_part(note_node, child_name, draw, "%s %s" % [scenario.get("name", ""), child_name]):
			return false

	view.free()
	return true


func _metadata_for_oracle(oracle: Dictionary) -> Dictionary:
	var texture_path := "%s/main.png" % ProjectSettings.globalize_path("res://../../src/resources")
	var width := float(oracle.get("width", 1.0))
	var head_height := float(oracle.get("headHeight", 1.0))
	var body_height := float(oracle.get("bodyHeight", 1.0))
	var tail_height := float(oracle.get("tailHeight", 1.0))
	var frame_speed := float(oracle.get("frameSpeed", 0.0))
	return {
		"schemaVersion": 1,
		"format": "VOS_RENDER_METADATA",
		"baseWidth": 800.0,
		"baseHeight": 600.0,
		"judgmentLine": float(oracle.get("baseY", 0.0)),
		"measureSize": MEASURE_SIZE,
		"entities": [_long_note_entity(texture_path, oracle, width, head_height, body_height, tail_height, frame_speed)],
		"lanes": [{
			"channel": "NOTE_1",
			"lane": 0,
			"x": float(oracle.get("baseX", 0.0)),
			"width": width,
		}],
	}


func _long_note_entity(
		texture_path: String,
		oracle: Dictionary,
		width: float,
		head_height: float,
		body_height: float,
		tail_height: float,
		frame_speed: float) -> Dictionary:
	return {
		"id": "LONG_NOTE_1",
		"type": "longNote",
		"layer": 0,
		"channel": "NOTE_1",
		"x": float(oracle.get("baseX", 0.0)),
		"y": 0.0,
		"width": width,
		"height": head_height,
		"normalHeight": float(oracle.get("normalHeight", head_height)),
		"named": true,
		"texturePath": texture_path,
		"textureX": 0.0,
		"textureY": 0.0,
		"textureWidth": width,
		"textureHeight": head_height,
		"frameSpeed": frame_speed,
		"spriteFrames": _sprite_frames(texture_path, "head", width, head_height),
		"bodyTexturePath": texture_path,
		"bodyTextureX": 0.0,
		"bodyTextureY": 0.0,
		"bodyTextureWidth": width,
		"bodyTextureHeight": body_height,
		"bodyFrameSpeed": frame_speed,
		"bodySpriteFrames": _sprite_frames(texture_path, "body", width, body_height),
		"tailTexturePath": texture_path,
		"tailTextureX": 0.0,
		"tailTextureY": 0.0,
		"tailTextureWidth": width,
		"tailTextureHeight": tail_height,
		"tailFrameSpeed": frame_speed,
		"tailSpriteFrames": _sprite_frames(texture_path, "tail", width, tail_height),
	}


func _sprite_frames(texture_path: String, prefix: String, width: float, height: float) -> Array[Dictionary]:
	var frames: Array[Dictionary] = []
	for i in range(3):
		frames.append({
			"id": "%s_%d" % [prefix, i],
			"texturePath": texture_path,
			"textureX": 0.0,
			"textureY": float(i),
			"textureWidth": width,
			"textureHeight": height,
		})
	return frames


func _chart_for_scenario(scenario: Dictionary, oracle: Dictionary) -> Dictionary:
	var elapsed_ms := float(scenario.get("elapsedMs", 0.0))
	return {
		"schemaVersion": 1,
		"format": "VOS",
		"keys": 7,
		"bpm": BPM,
		"durationMs": elapsed_ms + 3000.0,
		"speedMultiplier": 1.0,
		"speedType": "HiSpeed",
		"notes": [{
			"lane": 0,
			"startMs": elapsed_ms,
			"endMs": _end_ms_for_scenario(scenario, oracle),
			"measure": 0,
			"endMeasure": 0,
			"sampleId": 1,
			"volume": 1.0,
			"pan": 0.0,
			"kind": "holdStart",
		}],
		"measures": [],
		"visualTiming": [{
			"timeMs": 0.0,
			"bpm": BPM,
		}],
	}


func _end_ms_for_scenario(scenario: Dictionary, oracle: Dictionary) -> float:
	return float(scenario.get("elapsedMs", 0.0)) + float(oracle.get("endDistance", 0.0)) / _pixels_per_ms()


func _pixels_per_ms() -> float:
	return BPM / 60000.0 * MEASURE_SIZE / 4.0


func _expect_part(note_node: Control, child_name: String, draw: Dictionary, label: String) -> bool:
	if not _expect_bool(note_node.has_node(child_name), true, "%s exists" % label):
		return false
	var child: TextureRect = note_node.get_node(child_name)
	if not child.texture is AtlasTexture:
		push_error("Expected %s texture to be an AtlasTexture." % label)
		quit(1)
		return false
	var texture: AtlasTexture = child.texture
	var top_left := note_node.position + child.position
	var screen_width := child.size.x * child.scale.x
	var screen_height := child.size.y * child.scale.y
	var rendered_scale_x := screen_width / texture.region.size.x
	var rendered_scale_y := screen_height / texture.region.size.y
	if not _expect_float(top_left.x, float(draw.get("x", 0.0)), "%s x" % label):
		return false
	if not _expect_float(top_left.y, float(draw.get("y", 0.0)), "%s y" % label):
		return false
	if not _expect_float(screen_width, float(draw.get("screenWidth", 0.0)), "%s screen width" % label):
		return false
	if not _expect_float(screen_height, float(draw.get("screenHeight", 0.0)), "%s screen height" % label):
		return false
	if not _expect_float(rendered_scale_x, float(draw.get("scaleX", 0.0)), "%s rendered scale x" % label):
		return false
	if not _expect_float(rendered_scale_y, float(draw.get("scaleY", 0.0)), "%s rendered scale y" % label):
		return false
	if not _expect_float(texture.region.position.y, float(draw.get("frame", 0)),
			"%s frame texture y" % label):
		return false
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
	if absf(actual - expected) > 0.0001:
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
