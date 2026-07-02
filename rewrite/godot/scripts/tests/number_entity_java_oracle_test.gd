extends SceneTree

const GameplayView = preload("res://scripts/gameplay_view.gd")


func _init() -> void:
	var oracle := _load_oracle()
	if oracle.is_empty():
		return

	var scenarios: Variant = oracle.get("scenarios")
	if not scenarios is Array:
		push_error("Expected number entity oracle scenarios.")
		quit(1)
		return

	for raw_scenario: Variant in scenarios:
		if not raw_scenario is Dictionary:
			push_error("Expected number entity oracle scenario object.")
			quit(1)
			return
		if not _verify_scenario(raw_scenario, oracle):
			return

	quit(0)


func _load_oracle() -> Dictionary:
	var path := "res://test/fixtures/number-entity-oracle.json"
	if not FileAccess.file_exists(path):
		push_error("Missing number entity oracle fixture: %s" % path)
		quit(1)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Expected number entity oracle root object.")
		quit(1)
		return {}
	var root: Dictionary = parsed
	if int(root.get("schemaVersion", 0)) != 1:
		push_error("Expected number entity oracle schema version 1.")
		quit(1)
		return {}
	if str(root.get("source", "")) != "NumberEntity.draw":
		push_error("Expected number entity oracle source NumberEntity.draw.")
		quit(1)
		return {}
	return root


func _verify_scenario(scenario: Dictionary, oracle: Dictionary) -> bool:
	var view = GameplayView.new()
	if not _expect_bool(view.load_metadata(_metadata_for_scenario(scenario, oracle)), true,
			"%s metadata load" % scenario.get("name", "")):
		return false

	view.update_hud_state({
		"score": int(scenario.get("number", 0)),
	})

	var container: Control = view.get_node("HudSprite_SCORE_COUNTER")
	var digits: Variant = scenario.get("digits")
	if not digits is Array:
		push_error("Expected number entity oracle digits array.")
		quit(1)
		return false
	if not _expect_int(container.get_child_count(), digits.size(),
			"%s digit child count" % scenario.get("name", "")):
		return false

	for i in range(digits.size()):
		var expected_digit: Dictionary = digits[i]
		var digit: TextureRect = container.get_node("Digit_%03d" % i)
		if not _expect_float(digit.position.x, float(expected_digit.get("x", 0.0)),
				"%s digit %d x" % [scenario.get("name", ""), i]):
			return false
		if not _expect_float(digit.position.y, float(expected_digit.get("y", 0.0)),
				"%s digit %d y" % [scenario.get("name", ""), i]):
			return false
		if not digit.texture is AtlasTexture:
			push_error("Expected %s digit %d texture to be an AtlasTexture." % [scenario.get("name", ""), i])
			quit(1)
			return false
		var atlas: AtlasTexture = digit.texture
		var digit_value := float(str(expected_digit.get("digit", "0")))
		if not _expect_float(atlas.region.position.x, digit_value,
				"%s digit %d texture x" % [scenario.get("name", ""), i]):
			return false
		if not _expect_float(atlas.region.size.x, _digit_width(oracle, str(expected_digit.get("digit", "0"))),
				"%s digit %d texture width" % [scenario.get("name", ""), i]):
			return false

	view.free()
	return true


func _metadata_for_scenario(scenario: Dictionary, oracle: Dictionary) -> Dictionary:
	return {
		"schemaVersion": 1,
		"format": "VOS_RENDER_METADATA",
		"baseWidth": 800.0,
		"baseHeight": 600.0,
		"judgmentLine": 480,
		"measureSize": 385.0,
		"entities": [_number_entity(scenario, oracle)],
		"lanes": [],
	}


func _number_entity(scenario: Dictionary, oracle: Dictionary) -> Dictionary:
	var digit_widths: Dictionary = oracle.get("digitWidths", {})
	var frames: Array[Dictionary] = []
	var resource_root := ProjectSettings.globalize_path("res://../../src/resources")
	for i in range(10):
		var digit := str(i)
		frames.append({
			"id": "number_%s" % digit,
			"texturePath": "%s/main.png" % resource_root,
			"textureX": float(i),
			"textureY": 0.0,
			"textureWidth": float(digit_widths.get(digit, 1.0)),
			"textureHeight": 24.0,
		})
	return {
		"id": "SCORE_COUNTER",
		"type": "numberCounter",
		"layer": 0,
		"x": float(oracle.get("baseX", 0.0)),
		"y": float(oracle.get("baseY", 0.0)),
		"width": _digit_width(oracle, "0"),
		"height": 24.0,
		"named": true,
		"showDigits": int(scenario.get("showDigits", 1)),
		"texturePath": "%s/main.png" % resource_root,
		"textureX": 0.0,
		"textureY": 0.0,
		"textureWidth": _digit_width(oracle, "0"),
		"textureHeight": 24.0,
		"spriteFrames": frames,
		"sprites": [],
	}


func _digit_width(oracle: Dictionary, digit: String) -> float:
	var digit_widths: Dictionary = oracle.get("digitWidths", {})
	return float(digit_widths.get(digit, 1.0))


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
