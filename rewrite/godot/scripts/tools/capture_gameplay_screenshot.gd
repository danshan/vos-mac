extends SceneTree

const GameplayLoader = preload("res://scripts/gameplay_loader.gd")
const GameplayView = preload("res://scripts/gameplay_view.gd")
const JavaCaptureChartWindow = preload("res://scripts/java_capture_chart_window.gd")
const JavaCaptureResampler = preload("res://scripts/java_capture_resampler.gd")
const JavaCaptureStateModel = preload("res://scripts/java_capture_state_model.gd")
const JavaCaptureViewportConfig = preload("res://scripts/java_capture_viewport_config.gd")
const RenderEntityModel = preload("res://scripts/render_entity_model.gd")

const CAPTURE_SIZE := Vector2i(800, 600)
const DEFAULT_OUTPUT_PATH := "target/godot-captures/godot-gameplay-fixture.png"


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var metadata_loader = RenderEntityModel.new()
	var metadata: Dictionary = metadata_loader.load_from_file(_resource_path("OPEN2JAM_CAPTURE_RENDER_METADATA",
			"res://test/fixtures/render-metadata.json"))
	if metadata.is_empty():
		_fail("Expected render metadata to load.")
		return

	var gameplay_loader = GameplayLoader.new()
	var chart: Dictionary = gameplay_loader.load_from_file(_resource_path("OPEN2JAM_CAPTURE_GAMEPLAY",
			"res://test/fixtures/gameplay.json"))
	if chart.is_empty():
		_fail("Expected gameplay chart to load.")
		return

	var capture_time_ms := _capture_time_ms()
	var view_chart := _view_chart_for_capture(chart, capture_time_ms)
	var hidpi_scale := _java_capture_hidpi_scale()
	var capture_viewport: SubViewport = null
	var scaled_root: Node2D = null
	var view = GameplayView.new()
	view.name = "GameplayView"
	view.position = Vector2.ZERO
	view.size = Vector2(CAPTURE_SIZE)
	if _uses_physical_java_capture(hidpi_scale):
		capture_viewport = _java_capture_viewport(hidpi_scale)
		get_root().add_child(capture_viewport)
		scaled_root = Node2D.new()
		scaled_root.name = "JavaPhysicalCaptureRoot"
		scaled_root.scale = Vector2(float(hidpi_scale), float(hidpi_scale))
		capture_viewport.add_child(scaled_root)
		scaled_root.add_child(view)
	else:
		get_root().add_child(view)

	if not view.load_metadata(metadata):
		_fail("Unable to load render metadata.")
		return
	if not view.load_chart(view_chart):
		_fail("Unable to load gameplay chart.")
		return

	view.update_frame(capture_time_ms, _capture_state(chart, capture_time_ms))
	if not _validate_key_textures(view):
		return
	if OS.get_environment("OPEN2JAM_CAPTURE_JAVA_REFERENCE_STATE") == "1" and not _validate_java_reference_state(view):
		return

	if OS.get_environment("OPEN2JAM_CAPTURE_VALIDATE_ONLY") == "1":
		view.free()
		quit(0)
		return

	await process_frame
	await process_frame
	await process_frame

	var image: Image = _capture_source_image(capture_viewport)
	if image == null:
		_fail("Cannot capture viewport image. Run this script without --headless so Godot uses a real renderer.")
		return
	if image.get_width() < CAPTURE_SIZE.x or image.get_height() < CAPTURE_SIZE.y:
		_fail("Viewport image is smaller than the Java skin base size.")
		return

	var capture_size := CAPTURE_SIZE * hidpi_scale if capture_viewport != null else CAPTURE_SIZE
	var capture := _output_capture_image(image.get_region(Rect2i(Vector2i.ZERO, capture_size)), hidpi_scale)
	if not _expect_nonblank_image(capture, "captured gameplay image"):
		return

	var output_path := _output_path()
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
	var err := capture.save_png(output_path)
	if err != OK:
		_fail("Unable to save screenshot to %s: %d." % [output_path, err])
		return

	print("Saved Godot gameplay screenshot: %s" % output_path)
	if capture_viewport != null:
		capture_viewport.free()
	else:
		view.free()
	quit(0)


func _capture_source_image(capture_viewport: SubViewport) -> Image:
	if capture_viewport != null:
		return capture_viewport.get_texture().get_image()
	return get_root().get_texture().get_image()


func _output_capture_image(image: Image, hidpi_scale: int) -> Image:
	if hidpi_scale <= 1:
		return image
	var resampler = JavaCaptureResampler.new()
	return resampler.resample_for_logical_capture(image, hidpi_scale, CAPTURE_SIZE)


func _uses_physical_java_capture(hidpi_scale: int) -> bool:
	return hidpi_scale > 1 and OS.get_environment("OPEN2JAM_CAPTURE_JAVA_REFERENCE_STATE") == "1"


func _java_capture_viewport(hidpi_scale: int) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = "JavaPhysicalCaptureViewport"
	var config = JavaCaptureViewportConfig.new()
	config.configure_java_reference_viewport(viewport, CAPTURE_SIZE, hidpi_scale)
	return viewport


func _java_capture_hidpi_scale() -> int:
	var value := OS.get_environment("OPEN2JAM_CAPTURE_JAVA_HIDPI_SCALE").strip_edges()
	if not value.is_empty():
		if value.is_valid_int():
			return maxi(value.to_int(), 1)
		return 1
	if OS.get_environment("OPEN2JAM_CAPTURE_JAVA_REFERENCE_STATE") == "1":
		return 2
	return 1


func _capture_state(chart: Dictionary, capture_time_ms: float) -> Dictionary:
	if OS.get_environment("OPEN2JAM_CAPTURE_JAVA_REFERENCE_STATE") == "1":
		return _java_reference_state(chart, capture_time_ms)
	return {
		"score": 12345,
		"combo": 12,
		"maxCombo": 34,
		"jamCombo": 2,
		"jamBar": 25,
		"jamBarLimit": 50,
		"life": 12000,
		"lifeLimit": 24000,
		"elapsedMs": 83000.0,
		"gameTimeMs": 500.0,
		"durationMs": 1000.0,
		"fps": 144,
		"minute": 2,
		"second": 5,
		"judgments": {
			"cool": 7,
			"good": 3,
			"bad": 1,
			"miss": 2,
		},
		"statusTexts": [
			"HI-SPEED: x1.0",
			"Current Measure: 2",
			"Game Speed: +0",
		],
	}


func _view_chart_for_capture(chart: Dictionary, capture_time_ms: float) -> Dictionary:
	if OS.get_environment("OPEN2JAM_CAPTURE_JAVA_REFERENCE_STATE") != "1":
		return chart
	var window = JavaCaptureChartWindow.new()
	return window.chart_for_capture(chart, capture_time_ms)


func _java_reference_state(chart: Dictionary, capture_time_ms: float) -> Dictionary:
	var model = JavaCaptureStateModel.new()
	return model.state_for_chart(chart, capture_time_ms, _capture_animation_time_ms(capture_time_ms))


func _capture_time_ms() -> float:
	var value := OS.get_environment("OPEN2JAM_CAPTURE_TIME_MS").strip_edges()
	if value.is_empty():
		return 1000.0
	if not value.is_valid_float():
		return 1000.0
	return max(value.to_float(), 0.0)


func _capture_animation_time_ms(default_time_ms: float) -> float:
	var value := OS.get_environment("OPEN2JAM_CAPTURE_ANIMATION_TIME_MS").strip_edges()
	if value.is_empty():
		return default_time_ms
	if not value.is_valid_float():
		return default_time_ms
	return max(value.to_float(), 0.0)


func _validate_key_textures(view: Node) -> bool:
	if not _expect_texture_node_nonblank(view.get_node("Entity_BGA"), "Java BGA skin texture"):
		return false
	if not _expect_texture_node_nonblank(view.get_node("Entity_001"), "Java left gameplay skin texture"):
		return false
	if not _expect_texture_node_nonblank(view.get_node("Entity_002"), "Java bottom menu skin texture"):
		return false
	if not _expect_texture_node_nonblank(view.get_node("HudSprite_SCORE_COUNTER").get_child(0), "Java score digit texture"):
		return false
	if not _expect_texture_node_nonblank(view.get_node("Note_000"), "Java note texture"):
		return false
	if not _expect_texture_node_nonblank(view.get_node("Measure_000"), "Java measure texture"):
		return false
	return _expect_texture_node_nonblank(_timebar_decoration_node(view), "Java static timebar texture")


func _timebar_decoration_node(view: Node) -> TextureRect:
	for child: Node in view.get_children():
		if not child is TextureRect:
			continue
		var node: TextureRect = child
		if is_equal_approx(node.position.x, 226.0) \
				and is_equal_approx(node.position.y, 515.0) \
				and is_equal_approx(node.size.x, 226.0) \
				and is_equal_approx(node.size.y, 72.0):
			return node
	return null


func _validate_java_reference_state(view: Node) -> bool:
	for id in ["COMBO_COUNTER", "JAM_COUNTER"]:
		var path := "HudSprite_%s" % id
		if not view.has_node(path):
			_fail("Expected %s node for Java reference state." % path)
			return false
		var container := view.get_node(path)
		if container.get_child_count() != 0:
			_fail("Expected %s to be hidden in Java reference state." % id)
			return false
	return true


func _expect_texture_node_nonblank(node: Node, label: String) -> bool:
	var texture_node := _texture_node_for_validation(node)
	if texture_node == null:
		_fail("Expected %s to be a TextureRect." % label)
		return false
	if texture_node.texture == null:
		_fail("Expected %s to have a texture." % label)
		return false
	var image: Image = texture_node.texture.get_image()
	if image == null:
		_fail("Expected %s texture image." % label)
		return false
	return _expect_nonblank_image(image, label)


func _texture_node_for_validation(node: Node) -> TextureRect:
	if node is TextureRect:
		return node
	if node == null:
		return null
	for child: Node in node.get_children():
		var texture_node := _texture_node_for_validation(child)
		if texture_node != null:
			return texture_node
	return null


func _expect_nonblank_image(image: Image, label: String) -> bool:
	var visible_pixels := 0
	var bright_pixels := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a > 0.01:
				visible_pixels += 1
			if color.a > 0.01 and (color.r + color.g + color.b) > 0.05:
				bright_pixels += 1
	if visible_pixels <= 0 or bright_pixels <= 0:
		_fail("Expected nonblank %s, got visible=%d bright=%d." % [label, visible_pixels, bright_pixels])
		return false
	return true


func _resource_path(env_name: String, default_path: String) -> String:
	var env_path := OS.get_environment(env_name).strip_edges()
	if env_path.is_empty():
		return default_path
	return env_path


func _output_path() -> String:
	var output_path := OS.get_environment("OPEN2JAM_CAPTURE_OUTPUT").strip_edges()
	if output_path.is_empty():
		output_path = _repo_root().path_join(DEFAULT_OUTPUT_PATH)
	if output_path.begins_with("user://") or output_path.begins_with("res://"):
		return ProjectSettings.globalize_path(output_path)
	return output_path


func _repo_root() -> String:
	return ProjectSettings.globalize_path("res://../..")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
