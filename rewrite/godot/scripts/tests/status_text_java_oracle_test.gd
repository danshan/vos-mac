extends SceneTree

const GameplayView = preload("res://scripts/gameplay_view.gd")


func _init() -> void:
	var oracle := _load_oracle()
	if oracle.is_empty():
		return

	var view = GameplayView.new()
	if not _expect_bool(view.load_metadata(_metadata_for_oracle(oracle)), true, "status text metadata load"):
		return

	var draws: Variant = oracle.get("draws")
	if not draws is Array:
		push_error("Expected status text oracle draws array.")
		quit(1)
		return

	var status_texts: Array[String] = []
	for raw_draw: Variant in draws:
		if not raw_draw is Dictionary:
			push_error("Expected status text oracle draw object.")
			quit(1)
			return
		status_texts.append(str(raw_draw.get("text", "")))

	view.update_hud_state({"statusTexts": status_texts})
	for i in range(draws.size()):
		if not _verify_draw(view, draws[i], oracle, i):
			return
	if not _expect_bool(view.has_node("StatusText_%03d" % draws.size()), false, "invisible Java status item skipped"):
		return
	if not _verify_network_draws(view, oracle):
		return

	view.free()
	if not _verify_atlas_draws(oracle):
		return
	quit(0)


func _load_oracle() -> Dictionary:
	var path := "res://test/fixtures/status-text-oracle.json"
	if not FileAccess.file_exists(path):
		push_error("Missing status text oracle fixture: %s" % path)
		quit(1)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Expected status text oracle root object.")
		quit(1)
		return {}
	var root: Dictionary = parsed
	if int(root.get("schemaVersion", 0)) != 1:
		push_error("Expected status text oracle schema version 1.")
		quit(1)
		return {}
	if str(root.get("source", "")) != "Render statusList draw loop":
		push_error("Expected status text oracle source Render statusList draw loop.")
		quit(1)
		return {}
	return root


func _metadata_for_oracle(oracle: Dictionary) -> Dictionary:
	return {
		"schemaVersion": 1,
		"format": "VOS_RENDER_METADATA",
		"baseWidth": 800.0,
		"baseHeight": 600.0,
		"judgmentLine": 480.0,
		"measureSize": 385.0,
		"statusTextLayout": oracle.get("layout", {}).duplicate(true),
		"networkStatusTextLayout": oracle.get("networkLayout", {}).duplicate(true),
		"entities": [],
		"lanes": [],
	}


func _status_font_metadata() -> Dictionary:
	var path := "res://test/fixtures/render-metadata.json"
	if not FileAccess.file_exists(path):
		push_error("Missing render metadata fixture: %s" % path)
		quit(1)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Expected render metadata root object.")
		quit(1)
		return {}
	var font: Variant = parsed.get("statusFont", {})
	if not font is Dictionary:
		push_error("Expected render metadata statusFont object.")
		quit(1)
		return {}
	return font.duplicate(true)


func _verify_draw(view: Node, draw: Dictionary, oracle: Dictionary, index: int) -> bool:
	var layout: Dictionary = oracle.get("layout", {})
	var node_path := "StatusText_%03d" % index
	if not _expect_bool(view.has_node(node_path), true, "%s label node" % node_path):
		return false
	var label: Label = view.get_node(node_path)
	var label_width := float(layout.get("labelWidth", 0.0))
	var line_height := float(layout.get("lineHeight", 0.0))

	if not _expect_string(label.text, str(draw.get("text", "")), "%s text" % node_path):
		return false
	if not _expect_float(label.position.x + label.size.x, float(draw.get("x", 0.0)), "%s Java right x" % node_path):
		return false
	if not _expect_float(label.position.y, _expected_label_y(draw, layout), "%s Java y" % node_path):
		return false
	if not _expect_bool(label.size.x >= label_width, true, "%s Java label minimum width" % node_path):
		return false
	if not _expect_bool(label.size.y >= line_height, true, "%s Java line height" % node_path):
		return false
	if not _expect_int(label.horizontal_alignment, _alignment_constant(str(draw.get("alignment", ""))),
			"%s Java alignment" % node_path):
		return false
	if not _expect_int(label.vertical_alignment, VERTICAL_ALIGNMENT_TOP, "%s Java vertical alignment" % node_path):
		return false
	if not _expect_int(label.get_theme_font_size("font_size"), int(layout.get("fontSize", 0)),
			"%s Java font size" % node_path):
		return false
	if not _expect_float(float(layout.get("glyphHeight", 0.0)), 20.0, "%s Java glyph height" % node_path):
		return false
	if not _expect_bool(bool(label.get_meta("statusTextBold", false)), bool(layout.get("bold", false)),
			"%s Java bold" % node_path):
		return false
	if not _expect_bool(bool(label.get_meta("statusTextAntiAlias", true)), bool(layout.get("antiAlias", true)),
			"%s Java antialias" % node_path):
		return false
	if not _expect_string(str(label.get_meta("statusTextFontFamily", "")), str(layout.get("fontFamily", "")),
			"%s Java font family" % node_path):
		return false
	var expected_weight := 700 if bool(layout.get("bold", false)) else 400
	if not _expect_int(int(label.get_meta("statusTextFontWeight", 0)), expected_weight,
			"%s Java font weight" % node_path):
		return false
	if not _expect_color(label.get_theme_color("font_color"), Color.html(str(layout.get("fontColor", "#ffffffff"))),
			"%s Java font color" % node_path):
		return false
	var family := str(layout.get("fontFamily", ""))
	if not OS.get_system_font_path(family, expected_weight, 100, false).is_empty():
		if not _expect_bool(label.has_theme_font_override("font"), true, "%s Java font override" % node_path):
			return false
	return true


func _verify_network_draws(view: Node, oracle: Dictionary) -> bool:
	var network_draws: Variant = oracle.get("networkDraws")
	if not network_draws is Array:
		push_error("Expected status text oracle networkDraws array.")
		quit(1)
		return false

	var network_texts: Array[String] = []
	for raw_draw: Variant in network_draws:
		if not raw_draw is Dictionary:
			push_error("Expected status text oracle network draw object.")
			quit(1)
			return false
		network_texts.append(str(raw_draw.get("text", "")))

	view.update_hud_state({
		"statusTexts": [],
		"networkStatusTexts": network_texts,
	})
	for i in range(network_draws.size()):
		if not _verify_network_draw(view, network_draws[i], oracle, i):
			return false
	if not _expect_bool(view.has_node("NetworkStatusText_%03d" % network_draws.size()), false,
			"invisible Java network status item skipped"):
		return false
	return true


func _verify_network_draw(view: Node, draw: Dictionary, oracle: Dictionary, index: int) -> bool:
	var layout: Dictionary = oracle.get("networkLayout", {})
	var node_path := "NetworkStatusText_%03d" % index
	if not _expect_bool(view.has_node(node_path), true, "%s label node" % node_path):
		return false
	var label: Label = view.get_node(node_path)
	var label_width := float(layout.get("labelWidth", 0.0))
	var line_height := float(layout.get("serverLineHeight", 0.0)) if index == 0 else float(layout.get("connectionLineHeight", 0.0))

	if not _expect_string(label.text, str(draw.get("text", "")), "%s text" % node_path):
		return false
	if not _expect_float(label.position.x + label.size.x, float(draw.get("x", 0.0)), "%s Java right x" % node_path):
		return false
	if not _expect_float(label.position.y, _expected_label_y(draw, layout), "%s Java y" % node_path):
		return false
	if not _expect_bool(label.size.x >= label_width, true, "%s Java label minimum width" % node_path):
		return false
	if not _expect_bool(label.size.y >= line_height, true, "%s Java line height" % node_path):
		return false
	if not _expect_int(label.horizontal_alignment, _alignment_constant(str(draw.get("alignment", ""))),
			"%s Java alignment" % node_path):
		return false
	if not _expect_int(label.vertical_alignment, VERTICAL_ALIGNMENT_TOP, "%s Java vertical alignment" % node_path):
		return false
	if not _expect_int(label.get_theme_font_size("font_size"), int(layout.get("fontSize", 0)),
			"%s Java font size" % node_path):
		return false
	if not _expect_float(float(layout.get("glyphHeight", 0.0)), 20.0, "%s Java glyph height" % node_path):
		return false
	return true


func _verify_atlas_draws(oracle: Dictionary) -> bool:
	var view = GameplayView.new()
	var font := _status_font_metadata()
	var metadata := _metadata_for_oracle(oracle)
	metadata["statusFont"] = font
	if not _expect_bool(view.load_metadata(metadata), true, "status text atlas metadata load"):
		return false

	var draws: Variant = oracle.get("draws")
	if not draws is Array:
		push_error("Expected status text oracle draws array.")
		quit(1)
		return false
	var status_texts: Array[String] = []
	for raw_draw: Variant in draws:
		if not raw_draw is Dictionary:
			push_error("Expected status text oracle draw object.")
			quit(1)
			return false
		status_texts.append(str(raw_draw.get("text", "")))

	view.update_hud_state({"statusTexts": status_texts})
	for i in range(draws.size()):
		if not _verify_atlas_draw(view, "StatusText_%03d" % i, draws[i], oracle.get("layout", {}), font):
			return false
	if not _expect_bool(view.has_node("StatusText_%03d" % draws.size()), false,
			"invisible Java atlas status item skipped"):
		return false
	if not _verify_network_atlas_draws(view, oracle, font):
		return false

	view.free()
	return true


func _verify_network_atlas_draws(view: Node, oracle: Dictionary, font: Dictionary) -> bool:
	var network_draws: Variant = oracle.get("networkDraws")
	if not network_draws is Array:
		push_error("Expected status text oracle networkDraws array.")
		quit(1)
		return false

	var network_texts: Array[String] = []
	for raw_draw: Variant in network_draws:
		if not raw_draw is Dictionary:
			push_error("Expected status text oracle network draw object.")
			quit(1)
			return false
		network_texts.append(str(raw_draw.get("text", "")))

	view.update_hud_state({
		"statusTexts": [],
		"networkStatusTexts": network_texts,
	})
	for i in range(network_draws.size()):
		if not _verify_atlas_draw(view, "NetworkStatusText_%03d" % i, network_draws[i],
				oracle.get("networkLayout", {}), font):
			return false
	if not _expect_bool(view.has_node("NetworkStatusText_%03d" % network_draws.size()), false,
			"invisible Java atlas network status item skipped"):
		return false
	return true


func _verify_atlas_draw(view: Node, node_path: String, draw: Dictionary, layout: Dictionary, font: Dictionary) -> bool:
	if not _expect_bool(view.has_node(node_path), true, "%s atlas container" % node_path):
		return false
	var container: Control = view.get_node(node_path)
	var glyphs := _expected_java_glyphs(draw, layout, font)
	if glyphs.is_empty():
		push_error("Expected %s atlas glyphs." % node_path)
		quit(1)
		return false

	var bounds := _bounds_for_glyphs(glyphs)
	if not _expect_string(str(container.get_meta("statusText", "")), str(draw.get("text", "")),
			"%s atlas text" % node_path):
		return false
	if not _expect_string(str(container.get_meta("statusTextRenderer", "")), "TrueTypeFont",
			"%s atlas renderer" % node_path):
		return false
	if not _expect_float(float(container.get_meta("statusTextRightX", 0.0)), float(draw.get("x", 0.0)),
			"%s atlas Java right x" % node_path):
		return false
	if not _expect_float(float(container.get_meta("statusTextDrawY", 0.0)), float(draw.get("y", 0.0)),
			"%s atlas Java y" % node_path):
		return false
	if not _expect_float(container.position.x, float(bounds.get("left", 0.0)), "%s atlas left" % node_path):
		return false
	if not _expect_float(container.position.y, float(bounds.get("top", 0.0)), "%s atlas top" % node_path):
		return false
	if not _expect_float(container.size.x, float(bounds.get("right", 0.0)) - float(bounds.get("left", 0.0)),
			"%s atlas width" % node_path):
		return false
	if not _expect_float(container.size.y, float(bounds.get("bottom", 0.0)) - float(bounds.get("top", 0.0)),
			"%s atlas height" % node_path):
		return false
	if not _expect_int(container.get_child_count(), glyphs.size(), "%s atlas glyph count" % node_path):
		return false

	for glyph_index in range(glyphs.size()):
		var expected: Dictionary = glyphs[glyph_index]
		var child := container.get_child(glyph_index)
		if not child is TextureRect:
			push_error("Expected %s atlas child %d to be TextureRect." % [node_path, glyph_index])
			quit(1)
			return false
		var glyph_node: TextureRect = child
		var code := int(expected.get("code", 0))
		if not _expect_string(glyph_node.name, "Glyph_%03d_%03d" % [glyph_index, code],
				"%s glyph name %d" % [node_path, glyph_index]):
			return false
		if not _expect_float(glyph_node.position.x, float(expected.get("left", 0.0)) - container.position.x,
				"%s glyph x %d" % [node_path, glyph_index]):
			return false
		if not _expect_float(glyph_node.position.y, float(expected.get("top", 0.0)) - container.position.y,
				"%s glyph y %d" % [node_path, glyph_index]):
			return false
		if not _expect_float(glyph_node.size.x, float(expected.get("width", 0.0)),
				"%s glyph width %d" % [node_path, glyph_index]):
			return false
		if not _expect_float(glyph_node.size.y, float(expected.get("height", 0.0)),
				"%s glyph height %d" % [node_path, glyph_index]):
			return false
		if not _verify_atlas_region(glyph_node, expected, "%s glyph region %d" % [node_path, glyph_index]):
			return false
		if not _expect_int(glyph_node.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR,
				"%s glyph texture filter %d" % [node_path, glyph_index]):
			return false
		if not _expect_int(glyph_node.stretch_mode, TextureRect.STRETCH_SCALE,
				"%s glyph stretch mode %d" % [node_path, glyph_index]):
			return false
		if not _expect_bool(glyph_node.material is CanvasItemMaterial, true,
				"%s glyph premultiplied material %d" % [node_path, glyph_index]):
			return false
		var material: CanvasItemMaterial = glyph_node.material
		if not _expect_int(material.blend_mode, CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA,
				"%s glyph blend mode %d" % [node_path, glyph_index]):
			return false
	return true


func _verify_atlas_region(node: TextureRect, expected: Dictionary, label: String) -> bool:
	if not node.texture is AtlasTexture:
		push_error("Expected %s AtlasTexture." % label)
		quit(1)
		return false
	var texture: AtlasTexture = node.texture
	var glyph: Dictionary = expected.get("glyph", {})
	if not _expect_float(texture.region.position.x, float(glyph.get("x", 0.0)), "%s x" % label):
		return false
	if not _expect_float(texture.region.position.y, float(glyph.get("y", 0.0)), "%s y" % label):
		return false
	if not _expect_float(texture.region.size.x, float(glyph.get("width", 0.0)), "%s width" % label):
		return false
	if not _expect_float(texture.region.size.y, float(glyph.get("height", 0.0)), "%s height" % label):
		return false
	return true


func _expected_java_glyphs(draw: Dictionary, layout: Dictionary, font: Dictionary) -> Array[Dictionary]:
	var text := str(draw.get("text", ""))
	var glyph_map := _glyph_map(font)
	var scale_x := float(draw.get("scaleX", layout.get("scaleX", 1.0)))
	var scale_y := float(draw.get("scaleY", layout.get("scaleY", 1.0)))
	var x := float(draw.get("x", 0.0))
	var y := float(draw.get("y", 0.0))
	var alignment := str(draw.get("alignment", layout.get("horizontalAlignment", "right")))
	var font_height := float(font.get("fontHeight", layout.get("glyphHeight", 20.0)))
	var direction := 1
	var correction := float(font.get("correctL", 0.0))
	var index := 0
	var total_width := 0.0
	var start_y := 0.0

	if alignment == "right":
		direction = -1
		correction = float(font.get("correctR", 0.0))
		index = text.length() - 1
		var scan := 0
		while scan < text.length() - 1:
			if text.substr(scan, 1) == "\n":
				start_y -= font_height
			scan += 1
	elif alignment == "center":
		total_width = _line_width(text, glyph_map, float(font.get("correctL", 0.0))) / -2.0
		correction = float(font.get("correctL", 0.0))

	var out: Array[Dictionary] = []
	while index >= 0 and index < text.length():
		var code := text.unicode_at(index)
		var glyph: Dictionary = glyph_map.get(code, {})
		if glyph.is_empty():
			index += direction
			continue
		if direction < 0:
			total_width += (float(glyph.get("width", 0.0)) - correction) * direction

		if code == 10:
			start_y -= font_height * direction
			total_width = 0.0
			if alignment == "center":
				total_width = _line_width(text.substr(index + 1), glyph_map,
						float(font.get("correctL", 0.0))) / -2.0
		else:
			var draw_x: float = (total_width + float(glyph.get("width", 0.0))) * scale_x + x
			var draw_x2: float = total_width * scale_x + x
			var draw_y: float = start_y * scale_y + y
			var draw_y2: float = (start_y + float(glyph.get("height", 0.0))) * scale_y + y
			out.append({
				"code": code,
				"left": min(draw_x, draw_x2),
				"top": min(draw_y, draw_y2),
				"width": absf(draw_x2 - draw_x),
				"height": absf(draw_y2 - draw_y),
				"glyph": glyph,
			})

		if direction > 0:
			total_width += (float(glyph.get("width", 0.0)) - correction) * direction
		index += direction
	return out


func _glyph_map(font: Dictionary) -> Dictionary:
	var out := {}
	var glyphs: Variant = font.get("glyphs", [])
	if not glyphs is Array:
		return out
	for raw_glyph: Variant in glyphs:
		if raw_glyph is Dictionary:
			var glyph: Dictionary = raw_glyph
			out[int(glyph.get("code", -1))] = glyph.duplicate(true)
	return out


func _line_width(text: String, glyphs: Dictionary, correction: float) -> float:
	var total := 0.0
	for i in range(text.length()):
		var code := text.unicode_at(i)
		if code == 10:
			break
		var glyph: Dictionary = glyphs.get(code, {})
		if glyph.is_empty():
			continue
		total += float(glyph.get("width", 0.0)) - correction
	return total


func _bounds_for_glyphs(glyphs: Array[Dictionary]) -> Dictionary:
	var left := INF
	var top := INF
	var right := -INF
	var bottom := -INF
	for glyph: Dictionary in glyphs:
		left = min(left, float(glyph.get("left", 0.0)))
		top = min(top, float(glyph.get("top", 0.0)))
		right = max(right, float(glyph.get("left", 0.0)) + float(glyph.get("width", 0.0)))
		bottom = max(bottom, float(glyph.get("top", 0.0)) + float(glyph.get("height", 0.0)))
	return {
		"left": left,
		"top": top,
		"right": right,
		"bottom": bottom,
	}


func _alignment_constant(value: String) -> HorizontalAlignment:
	match value:
		"left":
			return HORIZONTAL_ALIGNMENT_LEFT
		"center":
			return HORIZONTAL_ALIGNMENT_CENTER
		_:
			return HORIZONTAL_ALIGNMENT_RIGHT


func _expected_label_y(draw: Dictionary, layout: Dictionary) -> float:
	var y := float(draw.get("y", 0.0))
	if float(layout.get("scaleY", 1.0)) < 0.0:
		return y - float(layout.get("glyphHeight", 20.0))
	return y


func _expect_bool(actual: bool, expected: bool, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true


func _expect_color(actual: Color, expected: Color, label: String) -> bool:
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


func _expect_int(actual: int, expected: int, label: String) -> bool:
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
