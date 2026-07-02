extends SceneTree

func _init() -> void:
	var resampler_script := _load_resampler_script()
	if resampler_script == null:
		return
	if not _test_java_hidpi_resample_downscales_physical_framebuffer(resampler_script):
		return
	if not _test_java_hidpi_resample_blurs_logical_edges(resampler_script):
		return
	if not _test_scale_one_keeps_pixels(resampler_script):
		return
	quit(0)


func _load_resampler_script() -> Script:
	var script: Variant = load("res://scripts/java_capture_resampler.gd")
	if not script is Script or not script.can_instantiate():
		push_error("Expected Java capture resampler script to load.")
		quit(1)
		return null
	return script


func _test_java_hidpi_resample_downscales_physical_framebuffer(resampler_script: Script) -> bool:
	var image := Image.create(4, 2, false, Image.FORMAT_RGBA8)
	var values := [
		0,
		64,
		192,
		255,
		32,
		96,
		160,
		224,
	]
	var index := 0
	for y in range(2):
		for x in range(4):
			var channel := float(values[index]) / 255.0
			image.set_pixel(x, y, Color(channel, channel, channel, 1.0))
			index += 1

	var resampler = resampler_script.new()
	var resampled: Image = resampler.resample_for_logical_capture(image, 2, Vector2i(2, 1))
	if not _expect_int(resampled.get_width(), 2, "physical framebuffer downscale width"):
		return false
	if not _expect_int(resampled.get_height(), 1, "physical framebuffer downscale height"):
		return false
	if not _expect_channel(resampled.get_pixel(0, 0).r, 48, "physical framebuffer left Java2D pixel"):
		return false
	if not _expect_channel(resampled.get_pixel(1, 0).r, 208, "physical framebuffer right Java2D pixel"):
		return false
	return true


func _test_java_hidpi_resample_blurs_logical_edges(resampler_script: Script) -> bool:
	var image := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color.BLACK)
	image.set_pixel(1, 0, Color.WHITE)

	var resampler = resampler_script.new()
	var resampled: Image = resampler.resample_for_logical_capture(image, 2)
	if not _expect_int(resampled.get_width(), 2, "resampled width"):
		return false
	if not _expect_int(resampled.get_height(), 1, "resampled height"):
		return false

	var left := resampled.get_pixel(0, 0).r
	var right := resampled.get_pixel(1, 0).r
	if not _expect_bool(left > 0.0 and left < 0.25, true, "left edge is bilinear blurred"):
		return false
	if not _expect_bool(right < 1.0 and right > 0.75, true, "right edge is bilinear blurred"):
		return false
	return true


func _test_scale_one_keeps_pixels(resampler_script: Script) -> bool:
	var image := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color.BLACK)
	image.set_pixel(1, 0, Color.WHITE)

	var resampler = resampler_script.new()
	var resampled: Image = resampler.resample_for_logical_capture(image, 1)
	if not _expect_int(resampled.get_width(), 2, "scale one width"):
		return false
	if not _expect_int(resampled.get_height(), 1, "scale one height"):
		return false
	if not _expect_color(resampled.get_pixel(0, 0), Color.BLACK, "scale one left pixel"):
		return false
	if not _expect_color(resampled.get_pixel(1, 0), Color.WHITE, "scale one right pixel"):
		return false
	return true


func _expect_int(actual: int, expected: int, label: String) -> bool:
	if actual != expected:
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


func _expect_color(actual: Color, expected: Color, label: String) -> bool:
	if not actual.is_equal_approx(expected):
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true


func _expect_channel(actual: float, expected_byte: int, label: String) -> bool:
	var actual_byte := int(round(actual * 255.0))
	if actual_byte != expected_byte:
		push_error("Expected %s '%d', got '%d'." % [label, expected_byte, actual_byte])
		quit(1)
		return false
	return true
