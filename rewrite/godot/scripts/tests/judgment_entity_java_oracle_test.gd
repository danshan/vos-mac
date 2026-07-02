extends SceneTree

const GameplayView = preload("res://scripts/gameplay_view.gd")


func _init() -> void:
	var oracle := _load_oracle()
	if oracle.is_empty():
		return

	var scenarios: Variant = oracle.get("scenarios")
	if not scenarios is Array:
		push_error("Expected judgment entity oracle scenarios.")
		quit(1)
		return

	for raw_scenario: Variant in scenarios:
		if not raw_scenario is Dictionary:
			push_error("Expected judgment entity oracle scenario object.")
			quit(1)
			return
		if not _verify_scenario(raw_scenario, oracle):
			return

	quit(0)


func _load_oracle() -> Dictionary:
	var path := "res://test/fixtures/judgment-entity-oracle.json"
	if not FileAccess.file_exists(path):
		push_error("Missing judgment entity oracle fixture: %s" % path)
		quit(1)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Expected judgment entity oracle root object.")
		quit(1)
		return {}
	var root: Dictionary = parsed
	if int(root.get("schemaVersion", 0)) != 1:
		push_error("Expected judgment entity oracle schema version 1.")
		quit(1)
		return {}
	if str(root.get("source", "")) != "JudgmentEntity.draw":
		push_error("Expected judgment entity oracle source JudgmentEntity.draw.")
		quit(1)
		return {}
	return root


func _verify_scenario(scenario: Dictionary, oracle: Dictionary) -> bool:
	var view = GameplayView.new()
	if not _expect_bool(view.load_metadata(_metadata_for_scenario(scenario, oracle)), true,
			"%s metadata load" % scenario.get("name", "")):
		return false

	var elapsed_ms := float(scenario.get("elapsedMs", 0.0))
	view.update_hud_state({
		"elapsedMs": 1000.0 + elapsed_ms,
		"judgmentEvent": {
			"sequence": 1,
			"result": "cool",
			"lane": 0,
			"startMs": 1000.0,
		},
	})

	var draws: Variant = scenario.get("draws")
	if not draws is Array:
		push_error("Expected judgment entity oracle draws array.")
		quit(1)
		return false

	var node_path := "Judgment_EFFECT_JUDGMENT_COOL"
	if draws.is_empty():
		var result := _expect_bool(view.has_node(node_path), false,
				"%s no judgment node after Java dead state" % scenario.get("name", ""))
		view.free()
		return result

	if not _expect_bool(view.has_node(node_path), true, "%s judgment node" % scenario.get("name", "")):
		return false
	var node: TextureRect = view.get_node(node_path)
	var draw: Dictionary = draws[0]
	var rendered_position := _rendered_top_left(node)

	if not _expect_float(node.position.x, float(scenario.get("entityX", 0.0)),
			"%s Java entity x" % scenario.get("name", "")):
		return false
	if not _expect_float(node.position.y, float(scenario.get("entityY", 0.0)),
			"%s Java entity y" % scenario.get("name", "")):
		return false
	if not _expect_float(node.pivot_offset.x, node.size.x * 0.5,
			"%s Java center pivot x" % scenario.get("name", "")):
		return false
	if not _expect_float(node.pivot_offset.y, node.size.y * 0.5,
			"%s Java center pivot y" % scenario.get("name", "")):
		return false
	if not _expect_float(node.scale.x, float(draw.get("scaleX", 0.0)),
			"%s Java scale x" % scenario.get("name", "")):
		return false
	if not _expect_float(node.scale.y, float(draw.get("scaleY", 0.0)),
			"%s Java scale y" % scenario.get("name", "")):
		return false
	if not _expect_float(rendered_position.x, float(draw.get("x", 0.0)),
			"%s Java draw x" % scenario.get("name", "")):
		return false
	if not _expect_float(rendered_position.y, float(draw.get("y", 0.0)),
			"%s Java draw y" % scenario.get("name", "")):
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
		"entities": [_judgment_entity(scenario, oracle)],
		"lanes": [],
	}


func _judgment_entity(scenario: Dictionary, oracle: Dictionary) -> Dictionary:
	return {
		"id": "EFFECT_JUDGMENT_COOL",
		"type": "judgmentEffect",
		"layer": 0,
		"x": float(scenario.get("entityX", 0.0)),
		"y": float(scenario.get("entityY", 0.0)),
		"width": float(oracle.get("width", 1.0)),
		"height": float(oracle.get("height", 1.0)),
		"named": true,
		"showTimeMs": float(oracle.get("showTimeMs", 3000.0)),
		"scaleRampMs": float(oracle.get("scaleRampMs", 100.0)),
		"initialScale": float(oracle.get("initialScale", 0.5)),
		"sprites": [],
		"spriteFrames": [{
			"id": "judgment_cool",
			"textureWidth": float(oracle.get("width", 1.0)),
			"textureHeight": float(oracle.get("height", 1.0)),
		}],
	}


func _rendered_top_left(node: Control) -> Vector2:
	return node.position + node.pivot_offset - node.pivot_offset * node.scale


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
