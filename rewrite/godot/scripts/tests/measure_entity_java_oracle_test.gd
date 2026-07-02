extends SceneTree

const GameplayView = preload("res://scripts/gameplay_view.gd")


func _init() -> void:
	var oracle := _load_oracle()
	if oracle.is_empty():
		return

	var scenarios: Variant = oracle.get("scenarios")
	if not scenarios is Array:
		push_error("Expected measure entity oracle scenarios.")
		quit(1)
		return

	for raw_scenario: Variant in scenarios:
		if not raw_scenario is Dictionary:
			push_error("Expected measure entity oracle scenario object.")
			quit(1)
			return
		if not _verify_scenario(raw_scenario, oracle):
			return

	quit(0)


func _load_oracle() -> Dictionary:
	var path := "res://test/fixtures/measure-entity-oracle.json"
	if not FileAccess.file_exists(path):
		push_error("Missing measure entity oracle fixture: %s" % path)
		quit(1)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Expected measure entity oracle root object.")
		quit(1)
		return {}
	var root: Dictionary = parsed
	if int(root.get("schemaVersion", 0)) != 1:
		push_error("Expected measure entity oracle schema version 1.")
		quit(1)
		return {}
	if str(root.get("source", "")) != "MeasureEntity":
		push_error("Expected measure entity oracle source MeasureEntity.")
		quit(1)
		return {}
	return root


func _verify_scenario(scenario: Dictionary, oracle: Dictionary) -> bool:
	var elapsed_ms := float(scenario.get("elapsedMs", 0.0))
	var view = GameplayView.new()
	if not _expect_bool(view.load_metadata(_metadata_for_oracle(oracle)), true,
			"%s metadata load" % scenario.get("name", "")):
		return false
	if not _expect_bool(view.load_chart(_chart_for_elapsed(elapsed_ms)), true,
			"%s chart load" % scenario.get("name", "")):
		return false

	view.update_time(elapsed_ms)
	view.update_hud_state({
		"elapsedMs": elapsed_ms,
		"hiddenMeasures": [0] if bool(scenario.get("judgedBeforeDraw", false)) else [],
	})

	if not _expect_bool(view.has_node("Measure_000"), true, "%s measure node" % scenario.get("name", "")):
		return false
	var node: TextureRect = view.get_node("Measure_000")
	var draws: Variant = scenario.get("draws")
	if not draws is Array:
		push_error("Expected measure entity oracle draws array.")
		quit(1)
		return false

	if draws.is_empty():
		var hidden_result := _expect_bool(node.visible, false,
				"%s hidden after Java dead state" % scenario.get("name", ""))
		view.free()
		return hidden_result

	var draw: Dictionary = draws[0]
	if not _expect_bool(node.visible, true, "%s visible" % scenario.get("name", "")):
		return false
	if not _expect_float(node.position.x, float(draw.get("x", 0.0)), "%s x" % scenario.get("name", "")):
		return false
	if not _expect_float(node.position.y, float(draw.get("y", 0.0)), "%s y" % scenario.get("name", "")):
		return false
	if not _expect_float(node.scale.x, float(draw.get("scaleX", 0.0)), "%s scale x" % scenario.get("name", "")):
		return false
	if not _expect_float(node.scale.y, float(draw.get("scaleY", 0.0)), "%s scale y" % scenario.get("name", "")):
		return false
	if not _expect_float(node.size.x, float(oracle.get("width", 0.0)), "%s width" % scenario.get("name", "")):
		return false
	if not _expect_float(node.size.y, float(oracle.get("height", 0.0)), "%s height" % scenario.get("name", "")):
		return false

	if not node.texture is AtlasTexture:
		push_error("Expected measure texture to be an AtlasTexture.")
		quit(1)
		return false
	var texture: AtlasTexture = node.texture
	if not _expect_float(texture.region.position.y, float(draw.get("frame", 0)),
			"%s frame texture y" % scenario.get("name", "")):
		return false

	view.free()
	return true


func _metadata_for_oracle(oracle: Dictionary) -> Dictionary:
	var width := float(oracle.get("width", 1.0))
	var height := float(oracle.get("height", 1.0))
	var texture_path := "%s/main.png" % ProjectSettings.globalize_path("res://../../src/resources")
	return {
		"schemaVersion": 1,
		"format": "VOS_RENDER_METADATA",
		"baseWidth": 800.0,
		"baseHeight": 600.0,
		"judgmentLine": float(oracle.get("baseY", 0.0)) + 1.0,
		"measureSize": 385.0,
		"entities": [{
			"id": "MEASURE_MARK",
			"type": "measure",
			"layer": 0,
			"x": float(oracle.get("baseX", 0.0)),
			"y": 0.0,
			"width": width,
			"height": height,
			"named": true,
			"texturePath": texture_path,
			"textureX": 0.0,
			"textureY": 0.0,
			"textureWidth": width,
			"textureHeight": height,
			"frameSpeed": float(oracle.get("frameSpeed", 0.0)),
			"sprites": [],
			"spriteFrames": [
				{
					"id": "measure_0",
					"texturePath": texture_path,
					"textureX": 0.0,
					"textureY": 0.0,
					"textureWidth": width,
					"textureHeight": height,
				},
				{
					"id": "measure_1",
					"texturePath": texture_path,
					"textureX": 0.0,
					"textureY": 1.0,
					"textureWidth": width,
					"textureHeight": height,
				},
			],
		}],
		"lanes": [],
	}


func _chart_for_elapsed(elapsed_ms: float) -> Dictionary:
	return {
		"schemaVersion": 1,
		"format": "VOS",
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 3000.0,
		"notes": [],
		"measures": [{
			"startMs": elapsed_ms,
		}],
		"visualTiming": [{
			"timeMs": 0.0,
			"bpm": 120.0,
		}],
	}


func _expect_bool(actual: bool, expected: bool, label: String) -> bool:
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
