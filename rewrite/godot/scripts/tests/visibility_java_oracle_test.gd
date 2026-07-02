extends SceneTree

const GameplayView = preload("res://scripts/gameplay_view.gd")
const RenderEntityModel = preload("res://scripts/render_entity_model.gd")


func _init() -> void:
	var oracle := _load_oracle()
	if oracle.is_empty():
		return

	var model = RenderEntityModel.new()
	var metadata: Dictionary = model.load_from_file("res://test/fixtures/render-metadata.json")
	if metadata.is_empty():
		push_error("Expected render metadata fixture to load.")
		quit(1)
		return
	metadata["visibilityLayer"] = int(oracle.get("visibilityLayer", 0))
	metadata["visibilityMasks"] = _masks_for_oracle(oracle)

	var scenarios: Variant = oracle.get("scenarios")
	if not scenarios is Array:
		push_error("Expected visibility oracle scenarios array.")
		quit(1)
		return

	for raw_scenario: Variant in scenarios:
		if not raw_scenario is Dictionary:
			push_error("Expected visibility oracle scenario object.")
			quit(1)
			return
		if not _verify_scenario(metadata, raw_scenario, oracle):
			return

	quit(0)


func _load_oracle() -> Dictionary:
	var path := "res://test/fixtures/visibility-oracle.json"
	if not FileAccess.file_exists(path):
		push_error("Missing visibility oracle fixture: %s" % path)
		quit(1)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Expected visibility oracle root object.")
		quit(1)
		return {}

	var root: Dictionary = parsed
	if int(root.get("schemaVersion", 0)) != 1:
		push_error("Expected visibility oracle schema version 1.")
		quit(1)
		return {}
	if str(root.get("source", "")) != "VosRenderMetadataExporter visibilityMasks with Render.visibility layer rules":
		push_error("Expected visibility oracle source VosRenderMetadataExporter visibilityMasks with Render.visibility layer rules.")
		quit(1)
		return {}
	return root


func _masks_for_oracle(oracle: Dictionary) -> Dictionary:
	var result := {}
	var masks: Variant = oracle.get("masks", [])
	if not masks is Array:
		return result
	for raw_mask: Variant in masks:
		if not raw_mask is Dictionary:
			continue
		var modifier := str(raw_mask.get("modifier", ""))
		if modifier.is_empty():
			continue
		var points: Array = []
		var raw_points: Variant = raw_mask.get("points", [])
		if raw_points is Array:
			for raw_point: Variant in raw_points:
				if raw_point is Dictionary:
					points.append({
						"at": float(raw_point.get("at", 0.0)),
						"alpha": float(raw_point.get("alpha", 0.0)),
					})
		result[modifier] = points
	return result


func _verify_scenario(metadata: Dictionary, scenario: Dictionary, oracle: Dictionary) -> bool:
	var modifier := str(scenario.get("modifier", ""))
	var view = GameplayView.new()
	if not _expect_bool(view.load_metadata(metadata), true, "%s metadata load" % modifier):
		return false
	if not _expect_bool(view.load_chart(_chart_for_modifier(modifier)), true, "%s chart load" % modifier):
		return false

	if not _verify_overlay_layout(view, scenario, oracle):
		return false
	if not _verify_layers(view, scenario):
		return false
	if not _verify_alpha_samples(view, modifier, oracle):
		return false

	view.free()
	return true


func _verify_overlay_layout(view: Node, scenario: Dictionary, oracle: Dictionary) -> bool:
	var modifier := str(scenario.get("modifier", ""))
	if not _expect_int(_count_children_with_prefix(view, "Visibility_%s_" % modifier),
			0, "%s overlay count follows Java CompositeEntity lifecycle" % modifier):
		return false

	var node_path := "Visibility_%s_000" % modifier
	if not _expect_bool(view.has_node(node_path), false, "%s first overlay node absent" % modifier):
		return false
	return true


func _verify_layers(view: Node, scenario: Dictionary) -> bool:
	var modifier := str(scenario.get("modifier", ""))
	if not _expect_int(_canvas_layer(view, "Note_000"), int(scenario.get("noteLayer", 0)),
			"%s note layer" % modifier):
		return false
	if not _expect_int(_canvas_layer(view, "Entity_JUDGMENT_LINE"), int(scenario.get("judgmentLineLayer", 0)),
			"%s judgment line layer" % modifier):
		return false
	if not _expect_int(_canvas_layer(view, "Measure_000"), int(scenario.get("measureLayer", 0)),
			"%s measure layer" % modifier):
		return false
	if not _expect_int(_canvas_layer(view, "Entity_JAM_BAR"), int(scenario.get("jamBarLayer", 0)),
			"%s jam bar layer" % modifier):
		return false
	return true


func _verify_alpha_samples(view: Node, modifier: String, oracle: Dictionary) -> bool:
	var tolerance := float(oracle.get("alphaTolerance", 0.005))
	for mask: Dictionary in oracle.get("masks", []):
		if str(mask.get("modifier", "")) != modifier:
			continue
		var samples: Variant = mask.get("samples", [])
		if not samples is Array:
			push_error("Expected %s visibility samples array." % modifier)
			quit(1)
			return false
		for raw_sample: Variant in samples:
			if not raw_sample is Dictionary:
				push_error("Expected %s visibility sample object." % modifier)
				quit(1)
				return false
			var sample: Dictionary = raw_sample
			var y := float(sample.get("y", 0.0))
			if not _expect_float(view._visibility_alpha(modifier, y, float(oracle.get("overlayHeight", 0.0))),
					float(sample.get("alpha", 0.0)),
					"%s metadata alpha at %.2f" % [modifier, float(sample.get("at", 0.0))], tolerance):
				return false
		return true
	push_error("Missing %s visibility mask samples." % modifier)
	quit(1)
	return false


func _chart_for_modifier(modifier: String) -> Dictionary:
	return {
		"schemaVersion": 1,
		"chartId": "oracle:visibility:%s" % modifier,
		"format": "VOS",
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 3000,
		"visibilityModifier": modifier,
		"notes": [
			{"lane": 0, "startMs": 1000.0, "measure": 0, "sampleId": 1, "volume": 1.0, "pan": 0.0, "kind": "tap"},
		],
		"measures": [
			{"startMs": 1000.0},
		],
		"autoPlayEvents": [],
	}


func _canvas_layer(view: Node, node_path: String) -> int:
	if not view.has_node(node_path):
		push_error("Missing node for layer check: %s" % node_path)
		quit(1)
		return 0
	var node: Variant = view.get_node(node_path)
	if node is CanvasItem:
		return node.z_index
	push_error("Expected CanvasItem node for layer check: %s" % node_path)
	quit(1)
	return 0


func _texture_alpha_at(node: TextureRect, x: int, y: int) -> float:
	if node.texture == null:
		push_error("Expected visibility texture.")
		quit(1)
		return 0.0
	var image: Image = node.texture.get_image()
	if image.is_empty():
		push_error("Expected visibility texture image.")
		quit(1)
		return 0.0
	var px: int = min(max(x, 0), image.get_width() - 1)
	var py: int = min(max(y, 0), image.get_height() - 1)
	return image.get_pixel(px, py).a


func _count_children_with_prefix(node: Node, prefix: String) -> int:
	var count := 0
	for child: Node in node.get_children():
		if child.name.begins_with(prefix):
			count += 1
	return count


func _expect_bool(actual: bool, expected: bool, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true


func _expect_float(actual: float, expected: float, label: String, tolerance: float = 0.0001) -> bool:
	if absf(actual - expected) > tolerance:
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
