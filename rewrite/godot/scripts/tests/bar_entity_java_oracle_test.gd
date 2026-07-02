extends SceneTree

const RenderEntityModel = preload("res://scripts/render_entity_model.gd")
const GameplayLoader = preload("res://scripts/gameplay_loader.gd")
const GameplayView = preload("res://scripts/gameplay_view.gd")

const BASE_TEXTURE_X: float = 20.0
const BASE_TEXTURE_Y: float = 30.0


func _init() -> void:
	var oracle := _load_oracle()
	if oracle.is_empty():
		return

	var view = GameplayView.new()
	get_root().add_child(view)
	if not _expect_bool(view.load_metadata(_metadata_for_oracle(oracle)), true, "view metadata load"):
		return

	var scenarios: Variant = oracle.get("scenarios")
	if not scenarios is Array:
		push_error("Expected bar entity oracle scenarios.")
		quit(1)
		return

	for raw_scenario: Variant in scenarios:
		if not raw_scenario is Dictionary:
			push_error("Expected bar entity oracle scenario object.")
			quit(1)
			return
		if not _verify_scenario(view, raw_scenario, oracle):
			return

	if not _verify_real_jam_bar_empty_slice():
		return

	view.free()
	quit(0)


func _load_oracle() -> Dictionary:
	var path := "res://test/fixtures/bar-entity-oracle.json"
	if not FileAccess.file_exists(path):
		push_error("Missing bar entity oracle fixture: %s" % path)
		quit(1)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Expected bar entity oracle root object.")
		quit(1)
		return {}
	var root: Dictionary = parsed
	if int(root.get("schemaVersion", 0)) != 1:
		push_error("Expected bar entity oracle schema version 1.")
		quit(1)
		return {}
	if str(root.get("source", "")) != "BarEntity.draw":
		push_error("Expected bar entity oracle source BarEntity.draw.")
		quit(1)
		return {}
	return root


func _metadata_for_oracle(oracle: Dictionary) -> Dictionary:
	var resource_root := ProjectSettings.globalize_path("res://../../src/resources")
	var entities: Array[Dictionary] = []
	for direction: String in ["left_to_right", "right_to_left", "up_to_down", "down_to_up"]:
		entities.append(_bar_entity(_entity_id(direction), direction, oracle, resource_root))
	return {
		"schemaVersion": 1,
		"format": "VOS_RENDER_METADATA",
		"baseWidth": 800.0,
		"baseHeight": 600.0,
		"judgmentLine": 480,
		"measureSize": 385.0,
		"entities": entities,
		"lanes": [],
	}


func _bar_entity(id: String, fill_direction: String, oracle: Dictionary, resource_root: String) -> Dictionary:
	var width := float(oracle.get("width", 1.0))
	var height := float(oracle.get("height", 1.0))
	return {
		"id": id,
		"type": "bar",
		"layer": 0,
		"x": float(oracle.get("baseX", 0.0)),
		"y": float(oracle.get("baseY", 0.0)),
		"width": width,
		"height": height,
		"named": true,
		"fillDirection": fill_direction,
		"texturePath": "%s/main.png" % resource_root,
		"textureX": BASE_TEXTURE_X,
		"textureY": BASE_TEXTURE_Y,
		"textureWidth": width,
		"textureHeight": height,
		"sprites": [],
		"spriteFrames": [{
			"id": "%s_frame" % id,
			"texturePath": "%s/main.png" % resource_root,
			"textureX": BASE_TEXTURE_X,
			"textureY": BASE_TEXTURE_Y,
			"textureWidth": width,
			"textureHeight": height,
		}],
	}


func _verify_scenario(view: Node, scenario: Dictionary, oracle: Dictionary) -> bool:
	var id := _entity_id(str(scenario.get("fillDirection", "")))
	view._set_bar_fill(id, float(scenario.get("storedValue", 0.0)), float(scenario.get("limit", 0.0)))

	var node_path := "Entity_%s" % id
	if not _expect_bool(view.has_node(node_path), true, "%s bar node exists" % scenario.get("name", "")):
		return false
	var node: TextureRect = view.get_node(node_path)
	var expected := _expected_geometry(scenario, oracle)
	if not _expect_float(node.position.x, float(expected.get("x", 0.0)), "%s x" % scenario.get("name", "")):
		return false
	if not _expect_float(node.position.y, float(expected.get("y", 0.0)), "%s y" % scenario.get("name", "")):
		return false
	if not _expect_float(node.size.x, float(expected.get("width", 0.0)), "%s width" % scenario.get("name", "")):
		return false
	if not _expect_float(node.size.y, float(expected.get("height", 0.0)), "%s height" % scenario.get("name", "")):
		return false
	if not _expect_bool(node.visible, bool(expected.get("visible", true)), "%s visibility" % scenario.get("name", "")):
		return false

	if not node.texture is AtlasTexture:
		push_error("Expected %s texture to be an AtlasTexture." % scenario.get("name", ""))
		quit(1)
		return false
	var texture: AtlasTexture = node.texture
	var expected_region: Rect2 = expected.get("region", Rect2())
	if not _expect_float(texture.region.position.x, expected_region.position.x,
			"%s region x" % scenario.get("name", "")):
		return false
	if not _expect_float(texture.region.position.y, expected_region.position.y,
			"%s region y" % scenario.get("name", "")):
		return false
	if not _expect_float(texture.region.size.x, expected_region.size.x,
			"%s region width" % scenario.get("name", "")):
		return false
	if not _expect_float(texture.region.size.y, expected_region.size.y,
			"%s region height" % scenario.get("name", "")):
		return false
	return true


func _verify_real_jam_bar_empty_slice() -> bool:
	var metadata_loader = RenderEntityModel.new()
	var metadata: Dictionary = metadata_loader.load_from_file("res://test/fixtures/render-metadata.json")
	if metadata.is_empty():
		push_error("Expected render metadata fixture to load.")
		quit(1)
		return false
	var view = GameplayView.new()
	get_root().add_child(view)
	if not _expect_bool(view.load_metadata(metadata), true, "real metadata view load"):
		return false
	var chart_loader = GameplayLoader.new()
	var chart: Dictionary = chart_loader.load_from_file("res://test/fixtures/gameplay.json")
	if chart.is_empty():
		push_error("Expected gameplay fixture to load.")
		quit(1)
		return false
	if not _expect_bool(view.load_chart(chart), true, "real metadata chart load"):
		return false
	view.update_frame(1000.0, {
		"jamBar": 0.0,
		"jamBarLimit": 50.0,
		"life": 24000.0,
		"lifeLimit": 24000.0,
		"elapsedMs": 1000.0,
		"animationTimeMs": 500.0,
		"gameTimeMs": 0.0,
		"durationMs": float(chart.get("durationMs", 1000.0)),
	})
	var life_bar: TextureRect = view.get_node("Entity_LIFE_BAR")
	var life_texture: AtlasTexture = life_bar.texture
	if not _expect_float(life_texture.region.position.x, 154.0,
			"real life bar uses Java capture animation time"):
		return false
	var node: TextureRect = view.get_node("Entity_JAM_BAR")
	if not _expect_bool(node.visible, false, "real empty jam bar visibility"):
		return false
	if not _expect_float(node.size.x, 0.0, "real empty jam bar width"):
		return false
	var texture: AtlasTexture = node.texture
	if not _expect_float(texture.region.size.x, 0.0, "real empty jam bar texture width"):
		return false
	view.free()
	return true


func _expected_geometry(scenario: Dictionary, oracle: Dictionary) -> Dictionary:
	var width := float(oracle.get("width", 1.0))
	var height := float(oracle.get("height", 1.0))
	var slice_x := float(scenario.get("sliceX", 1.0))
	var slice_y := float(scenario.get("sliceY", 1.0))
	var draw_x := float(scenario.get("drawX", 0.0))
	var draw_y := float(scenario.get("drawY", 0.0))
	var screen_width := _java_slice_size(width, slice_x)
	var screen_height := _java_slice_size(height, slice_y)
	var x := draw_x - screen_width if slice_x < 0.0 else draw_x
	var y := draw_y - screen_height if slice_y < 0.0 else draw_y
	var region := Rect2(BASE_TEXTURE_X, BASE_TEXTURE_Y, width, height)
	if absf(slice_x) < 1.0:
		if slice_x < 0.0:
			region.position.x = BASE_TEXTURE_X + width - screen_width
		region.size.x = screen_width
	if absf(slice_y) < 1.0:
		if slice_y < 0.0:
			region.position.y = BASE_TEXTURE_Y + height - screen_height
		region.size.y = screen_height
	return {
		"x": x,
		"y": y,
		"width": screen_width,
		"height": screen_height,
		"visible": screen_width > 0.0 and screen_height > 0.0,
		"region": region,
	}


func _java_slice_size(base_size: float, ratio: float) -> float:
	return absf(float(floor(base_size * ratio + 0.5)))


func _entity_id(fill_direction: String) -> String:
	match fill_direction:
		"left_to_right":
			return "LIFE_BAR"
		"right_to_left":
			return "JAM_BAR"
		"up_to_down":
			return "SCORE_COUNTER"
		"down_to_up":
			return "FPS_COUNTER"
		_:
			return "UNKNOWN_BAR"


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
