extends SceneTree

const GameplayView = preload("res://scripts/gameplay_view.gd")
const GameplayLoader = preload("res://scripts/gameplay_loader.gd")
const RenderEntityModel = preload("res://scripts/render_entity_model.gd")


func _init() -> void:
	var model = RenderEntityModel.new()
	var metadata: Dictionary = model.load_from_file("res://test/fixtures/render-metadata.json")
	if metadata.is_empty():
		push_error("Expected render metadata fixture to load.")
		quit(1)
		return

	if not _expect_float(metadata.get("baseWidth", 0.0), 800.0, "base width"):
		return
	if not _expect_float(metadata.get("baseHeight", 0.0), 600.0, "base height"):
		return
	if not _expect_float(metadata.get("measureSize", 0.0), 385.0, "measure size"):
		return
	if not _expect_int(metadata.get("judgmentLine", 0), 480, "judgment line"):
		return

	var entities: Array = metadata.get("entities", [])
	if not _expect_int(entities.size(), 4, "entity count"):
		return
	if not _expect_string(entities[0].get("id", ""), "BGA", "first entity id"):
		return
	if not _expect_string(entities[1].get("id", ""), "LONG_NOTE_1", "long note entity id"):
		return

	var lane: Dictionary = model.lane_for_channel(metadata, "NOTE_1")
	if lane.is_empty():
		push_error("Expected NOTE_1 lane.")
		quit(1)
		return
	if not _expect_int(lane.get("lane", -1), 0, "lane index"):
		return
	if not _expect_float(lane.get("x", 0.0), 5.0, "lane x"):
		return
	if not _expect_float(lane.get("width", 0.0), 28.0, "lane width"):
		return

	var view = GameplayView.new()
	if not _expect_bool(view.load_metadata(metadata), true, "view metadata load"):
		return
	if not _expect_int(view.get_child_count(), 2, "static entity node count"):
		return
	if not _expect_bool(view.has_node("Entity_BGA"), true, "bga node"):
		return
	if not _expect_bool(view.has_node("Entity_NOTE_1"), false, "note template is not static"):
		return

	var gameplay_loader = GameplayLoader.new()
	var chart: Dictionary = gameplay_loader.load_from_file("res://test/fixtures/gameplay.json")
	if chart.is_empty():
		push_error("Expected gameplay fixture to load.")
		quit(1)
		return
	if not _expect_bool(view.load_chart(chart), true, "view chart load"):
		return
	if not _expect_bool(view.has_node("Note_000"), true, "dynamic note node"):
		return

	var note_node: ColorRect = view.get_node("Note_000")
	if not _expect_float(note_node.position.x, 5.0, "dynamic note node x"):
		return
	if not _expect_float(note_node.position.y, 280.5, "dynamic note node y at zero"):
		return
	if not _expect_float(note_node.size.x, 28.0, "dynamic note node width"):
		return
	if not _expect_float(note_node.size.y, 7.0, "dynamic note node height"):
		return

	view.update_time(1000.0)
	if not _expect_float(note_node.position.y, 473.0, "dynamic note node y at judgment"):
		return

	view.free()
	quit(0)


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
