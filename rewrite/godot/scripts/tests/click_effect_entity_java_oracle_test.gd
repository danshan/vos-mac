extends SceneTree

const GameplayView = preload("res://scripts/gameplay_view.gd")

const EVENT_START_MS: float = 1000.0


func _init() -> void:
	var oracle := _load_oracle()
	if oracle.is_empty():
		return

	var scenarios: Variant = oracle.get("scenarios")
	if not scenarios is Array:
		push_error("Expected click effect entity oracle scenarios.")
		quit(1)
		return

	for raw_scenario: Variant in scenarios:
		if not raw_scenario is Dictionary:
			push_error("Expected click effect entity oracle scenario object.")
			quit(1)
			return
		if not _verify_scenario(raw_scenario, oracle):
			return

	quit(0)


func _load_oracle() -> Dictionary:
	var path := "res://test/fixtures/click-effect-entity-oracle.json"
	if not FileAccess.file_exists(path):
		push_error("Missing click effect entity oracle fixture: %s" % path)
		quit(1)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Expected click effect entity oracle root object.")
		quit(1)
		return {}
	var root: Dictionary = parsed
	if int(root.get("schemaVersion", 0)) != 1:
		push_error("Expected click effect entity oracle schema version 1.")
		quit(1)
		return {}
	if str(root.get("source", "")) != "Render.setNoteJudgment EFFECT_CLICK with AnimatedEntity.move":
		push_error("Expected click effect entity oracle source Render.setNoteJudgment EFFECT_CLICK with AnimatedEntity.move.")
		quit(1)
		return {}
	return root


func _verify_scenario(scenario: Dictionary, oracle: Dictionary) -> bool:
	var view = GameplayView.new()
	if not _expect_bool(view.load_metadata(_metadata_for_oracle(oracle)), true,
			"%s metadata load" % scenario.get("name", "")):
		return false
	if not _expect_bool(view.load_chart(_empty_chart()), true,
			"%s chart load" % scenario.get("name", "")):
		return false

	if str(scenario.get("name", "")) == "loop_boundary_after_prior_frame":
		view.update_hud_state(_click_state(EVENT_START_MS + 399.0))
	view.update_hud_state(_click_state(EVENT_START_MS + float(scenario.get("elapsedMs", 0.0))))

	var draws: Variant = scenario.get("draws")
	if not draws is Array:
		push_error("Expected click effect entity oracle draws array.")
		quit(1)
		return false

	var node_path := "Click_EFFECT_CLICK_007"
	if draws.is_empty():
		var result := _expect_bool(view.has_node(node_path), false,
				"%s no click node after Java dead state" % scenario.get("name", ""))
		view.free()
		return result

	if not _expect_bool(view.has_node(node_path), true, "%s click node" % scenario.get("name", "")):
		return false
	var node: TextureRect = view.get_node(node_path)
	var draw: Dictionary = draws[0]

	if not _expect_float(node.position.x, float(draw.get("x", 0.0)), "%s x" % scenario.get("name", "")):
		return false
	if not _expect_float(node.position.y, float(draw.get("y", 0.0)), "%s y" % scenario.get("name", "")):
		return false
	if not _expect_float(node.size.x * node.scale.x, float(draw.get("screenWidth", 0.0)),
			"%s screen width" % scenario.get("name", "")):
		return false
	if not _expect_float(node.size.y * node.scale.y, float(draw.get("screenHeight", 0.0)),
			"%s screen height" % scenario.get("name", "")):
		return false
	if not _expect_float(node.scale.x, float(draw.get("scaleX", 0.0)),
			"%s scale x" % scenario.get("name", "")):
		return false
	if not _expect_float(node.scale.y, float(draw.get("scaleY", 0.0)),
			"%s scale y" % scenario.get("name", "")):
		return false
	if not node.texture is AtlasTexture:
		push_error("Expected %s texture to be an AtlasTexture." % scenario.get("name", ""))
		quit(1)
		return false
	var texture: AtlasTexture = node.texture
	if not _expect_float(texture.region.position.y, float(draw.get("frame", 0)),
			"%s frame texture y" % scenario.get("name", "")):
		return false

	view.free()
	return true


func _metadata_for_oracle(oracle: Dictionary) -> Dictionary:
	var texture_path := "%s/main.png" % ProjectSettings.globalize_path("res://../../src/resources")
	var width := float(oracle.get("width", 1.0))
	var height := float(oracle.get("height", 1.0))
	return {
		"schemaVersion": 1,
		"format": "VOS_RENDER_METADATA",
		"baseWidth": 800.0,
		"baseHeight": 600.0,
		"judgmentLine": float(oracle.get("viewport", 0.0)),
		"measureSize": 385.0,
		"entities": [{
			"id": "EFFECT_CLICK",
			"type": "entity",
			"layer": 0,
			"x": 0.0,
			"y": 0.0,
			"width": width,
			"height": height,
			"named": true,
			"frameSpeed": float(oracle.get("frameSpeed", 0.0)),
			"animationLoop": bool(oracle.get("animationLoops", true)),
			"texturePath": texture_path,
			"textureX": 0.0,
			"textureY": 0.0,
			"textureWidth": width,
			"textureHeight": height,
			"sprites": [],
			"spriteFrames": _sprite_frames(texture_path, width, height),
		}],
		"lanes": [{
			"channel": "NOTE_1",
			"lane": 0,
			"x": float(oracle.get("laneX", 0.0)),
			"width": float(oracle.get("laneWidth", 1.0)),
		}],
	}


func _sprite_frames(texture_path: String, width: float, height: float) -> Array[Dictionary]:
	var frames: Array[Dictionary] = []
	for i in range(2):
		frames.append({
			"id": "click_%d" % i,
			"texturePath": texture_path,
			"textureX": 0.0,
			"textureY": float(i),
			"textureWidth": width,
			"textureHeight": height,
		})
	return frames


func _empty_chart() -> Dictionary:
	return {
		"schemaVersion": 1,
		"format": "VOS",
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 3000.0,
		"notes": [],
		"measures": [],
	}


func _click_state(elapsed_ms: float) -> Dictionary:
	return {
		"elapsedMs": elapsed_ms,
		"clickEvents": [{
			"sequence": 7,
			"lane": 0,
			"startMs": EVENT_START_MS,
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
