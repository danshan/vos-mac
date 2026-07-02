extends SceneTree

const GameplayLoader = preload("res://scripts/gameplay_loader.gd")
const GameplayView = preload("res://scripts/gameplay_view.gd")
const RenderEntityModel = preload("res://scripts/render_entity_model.gd")

func _init() -> void:
	var metadata_loader = RenderEntityModel.new()
	var metadata: Dictionary = metadata_loader.load_from_file("res://test/fixtures/render-metadata.json")
	if metadata.is_empty():
		_fail("Expected render metadata fixture to load.")
		return

	var gameplay_loader = GameplayLoader.new()
	var chart: Dictionary = gameplay_loader.load_from_file("res://test/fixtures/gameplay.json")
	if chart.is_empty():
		_fail("Expected gameplay fixture to load.")
		return

	var view = GameplayView.new()
	view.name = "GameplayView"
	get_root().add_child(view)

	if not _expect_bool(view.load_metadata(metadata), true, "metadata load"):
		return
	if not _expect_bool(view.load_chart(chart), true, "chart load"):
		return

	view.update_frame(1000.0, {
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
	})

	if not _expect_texture_node_nonblank(view.get_node("Entity_BGA"), "Java BGA skin texture"):
		return
	if not _expect_texture_node_nonblank(view.get_node("Entity_001"), "Java left gameplay skin texture"):
		return
	if not _expect_texture_node_nonblank(view.get_node("Entity_002"), "Java bottom menu skin texture"):
		return
	if not _expect_texture_node_nonblank(view.get_node("HudSprite_SCORE_COUNTER").get_child(0), "Java score digit texture"):
		return
	if not _expect_texture_node_nonblank(view.get_node("Note_000"), "Java note texture"):
		return
	if not _expect_texture_node_nonblank(view.get_node("Measure_000"), "Java measure texture"):
		return
	if not _expect_texture_node_nonblank(_timebar_decoration_node(view), "Java static timebar texture"):
		return

	view.free()
	quit(0)


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


func _expect_texture_node_nonblank(node: Node, label: String) -> bool:
	if not node is TextureRect:
		_fail("Expected %s to be a TextureRect." % label)
		return false
	var texture_node: TextureRect = node
	if texture_node.texture == null:
		_fail("Expected %s to have a texture." % label)
		return false
	var image: Image = texture_node.texture.get_image()
	if image == null:
		_fail("Expected %s texture image." % label)
		return false
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


func _expect_bool(actual: bool, expected: bool, label: String) -> bool:
	if actual != expected:
		_fail("Expected %s '%s', got '%s'." % [label, expected, actual])
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
