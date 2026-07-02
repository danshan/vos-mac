extends SceneTree

const GameplayView = preload("res://scripts/gameplay_view.gd")


func _init() -> void:
	var probe_path := "%s/open2jam_java_texture_probe.png" % OS.get_temp_dir()
	var probe := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	probe.set_pixel(0, 0, Color(1.0, 1.0, 1.0, 0.0))
	probe.set_pixel(1, 0, Color(1.0, 0.0, 0.0, 1.0))
	if probe.save_png(probe_path) != OK:
		push_error("Failed to write Java texture probe image.")
		quit(1)
		return

	var view := GameplayView.new()
	var texture: Texture2D = view._image_texture_for_path(probe_path)
	if texture == null:
		push_error("Expected Java texture probe to load.")
		quit(1)
		return
	var image := texture.get_image()
	var transparent_pixel := image.get_pixel(0, 0)
	if not _expect_color(transparent_pixel, Color(0.0, 0.0, 0.0, 0.0), "transparent Java texture pixel"):
		return

	var opaque_pixel := image.get_pixel(1, 0)
	if not _expect_color(opaque_pixel, Color(1.0, 0.0, 0.0, 1.0), "opaque Java texture pixel"):
		return

	var resource_root := ProjectSettings.globalize_path("res://../../src/resources")
	var font_node := TextureRect.new()
	view._configure_java_texture_node(font_node, {
		"texturePath": "%s/font1.png" % resource_root,
	})
	if not _expect_int(font_node.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR, "Java font texture filter"):
		return
	if not _expect_bool(font_node.material is CanvasItemMaterial, true, "Java font texture material"):
		return
	var material: CanvasItemMaterial = font_node.material
	if not _expect_int(material.blend_mode, CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA,
			"Java font texture blend mode"):
		return

	var judgment_node := TextureRect.new()
	view._configure_java_texture_node(judgment_node, {
		"id": "JUDGMENT_LINE",
		"texturePath": "%s/main.png" % resource_root,
	})
	if not _expect_int(judgment_node.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR, "Java judgment texture filter"):
		return
	if not _expect_bool(judgment_node.material is CanvasItemMaterial, true, "Java judgment texture material"):
		return
	var judgment_material: CanvasItemMaterial = judgment_node.material
	if not _expect_int(judgment_material.blend_mode, CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA,
			"Java judgment texture blend mode"):
		return

	var note_bg_node := TextureRect.new()
	view._configure_java_texture_node(note_bg_node, {
		"texturePath": "%s/Note_BG.png" % resource_root,
	})
	if not _expect_bool(note_bg_node.material is CanvasItemMaterial, true, "Java note background texture material"):
		return
	var note_bg_material: CanvasItemMaterial = note_bg_node.material
	if not _expect_int(note_bg_material.blend_mode, CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA,
			"Java note background texture blend mode"):
		return

	var static_keyboard_node := TextureRect.new()
	view._configure_java_texture_node(static_keyboard_node, {
		"texturePath": "%s/main.png" % resource_root,
		"sprites": ["static_keyboard"],
	})
	if not _expect_bool(static_keyboard_node.material is CanvasItemMaterial, true,
			"Java static keyboard texture material"):
		return
	var static_keyboard_material: CanvasItemMaterial = static_keyboard_node.material
	if not _expect_int(static_keyboard_material.blend_mode, CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA,
			"Java static keyboard texture blend mode"):
		return

	var main_node := TextureRect.new()
	view._configure_java_texture_node(main_node, {
		"texturePath": "%s/main.png" % resource_root,
	})
	if not _expect_int(main_node.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR, "Java main texture filter"):
		return
	if not _expect_bool(main_node.material is CanvasItemMaterial, true, "Java main texture material"):
		return
	var main_material: CanvasItemMaterial = main_node.material
	if not _expect_int(main_material.blend_mode, CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA,
			"Java main texture blend mode"):
		return

	DirAccess.remove_absolute(probe_path)
	font_node.free()
	judgment_node.free()
	note_bg_node.free()
	static_keyboard_node.free()
	main_node.free()
	view.free()
	quit(0)


func _expect_color(actual: Color, expected: Color, label: String) -> bool:
	if not is_equal_approx(actual.r, expected.r) \
			or not is_equal_approx(actual.g, expected.g) \
			or not is_equal_approx(actual.b, expected.b) \
			or not is_equal_approx(actual.a, expected.a):
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
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
