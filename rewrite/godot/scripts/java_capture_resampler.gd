extends RefCounted


func resample_for_logical_capture(image: Image, hidpi_scale: int, logical_size: Vector2i = Vector2i.ZERO) -> Image:
	var result := image.duplicate()
	if hidpi_scale <= 1:
		return result

	result.convert(Image.FORMAT_RGBA8)
	if logical_size.x > 0 and logical_size.y > 0:
		if result.get_width() == logical_size.x and result.get_height() == logical_size.y:
			return _apply_java_2x_downscale_kernel(result)
		if result.get_width() == logical_size.x * hidpi_scale and result.get_height() == logical_size.y * hidpi_scale:
			return _downscale_physical_framebuffer(result, logical_size, hidpi_scale)
	return _apply_java_2x_downscale_kernel(result)


func _downscale_physical_framebuffer(image: Image, logical_size: Vector2i, hidpi_scale: int) -> Image:
	if hidpi_scale != 2:
		var resized := image.duplicate()
		resized.resize(logical_size.x, logical_size.y, Image.INTERPOLATE_BILINEAR)
		resized.convert(Image.FORMAT_RGBA8)
		return resized

	var source: PackedByteArray = image.get_data()
	var output := PackedByteArray()
	output.resize(logical_size.x * logical_size.y * 4)
	var source_width := image.get_width()

	for y in range(logical_size.y):
		for x in range(logical_size.x):
			var output_index := (y * logical_size.x + x) * 4
			var source_x := x * 2
			var source_y := y * 2
			var top_left := (source_y * source_width + source_x) * 4
			var top_right := top_left + 4
			var bottom_left := ((source_y + 1) * source_width + source_x) * 4
			var bottom_right := bottom_left + 4
			for channel in range(4):
				output[output_index + channel] = int((
						source[top_left + channel]
						+ source[top_right + channel]
						+ source[bottom_left + channel]
						+ source[bottom_right + channel]
						+ 2) / 4)

	return Image.create_from_data(logical_size.x, logical_size.y, false, Image.FORMAT_RGBA8, output)


func _apply_java_2x_downscale_kernel(image: Image) -> Image:
	var width: int = image.get_width()
	var height: int = image.get_height()
	var source: PackedByteArray = image.get_data()
	var horizontal := PackedByteArray()
	var output := PackedByteArray()
	horizontal.resize(source.size())
	output.resize(source.size())

	for y in range(height):
		for x in range(width):
			var left_x: int = maxi(x - 1, 0)
			var right_x: int = mini(x + 1, width - 1)
			var left_index: int = (y * width + left_x) * 4
			var center_index: int = (y * width + x) * 4
			var right_index: int = (y * width + right_x) * 4
			for channel in range(4):
				horizontal[center_index + channel] = _weighted_channel(
						source[left_index + channel],
						source[center_index + channel],
						source[right_index + channel])

	for y in range(height):
		var top_y: int = maxi(y - 1, 0)
		var bottom_y: int = mini(y + 1, height - 1)
		for x in range(width):
			var top_index: int = (top_y * width + x) * 4
			var center_index: int = (y * width + x) * 4
			var bottom_index: int = (bottom_y * width + x) * 4
			for channel in range(4):
				output[center_index + channel] = _weighted_channel(
						horizontal[top_index + channel],
						horizontal[center_index + channel],
						horizontal[bottom_index + channel])

	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, output)


func _weighted_channel(before: int, center: int, after: int) -> int:
	return int((before + center * 6 + after + 4) / 8)
