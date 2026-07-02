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

	chart["notes"] = _repeated_notes(chart)

	var view = GameplayView.new()
	view.name = "GameplayView"
	get_root().add_child(view)

	if not _expect_bool(view.load_metadata(metadata), true, "metadata load"):
		return
	if not _expect_bool(view.load_chart(chart), true, "chart load"):
		return
	if not _expect_repeated_notes_share_texture(view, chart["notes"].size()):
		return

	view.free()
	quit(0)


func _repeated_notes(chart: Dictionary) -> Array:
	var raw_notes: Variant = chart.get("notes", [])
	if not raw_notes is Array or raw_notes.is_empty() or not raw_notes[0] is Dictionary:
		return []
	var base_note: Dictionary = raw_notes[0]
	var notes: Array = []
	for index in range(24):
		var note := base_note.duplicate(true)
		note["startMs"] = 1000.0 + float(index * 100)
		notes.append(note)
	return notes


func _expect_repeated_notes_share_texture(view: Node, note_count: int) -> bool:
	var first_texture := _note_texture(view, 0)
	if first_texture == null:
		_fail("Expected first note texture.")
		return false
	var first_texture_id := first_texture.get_instance_id()
	for index in range(1, note_count):
		var texture := _note_texture(view, index)
		if texture == null:
			_fail("Expected note %d texture." % index)
			return false
		if texture.get_instance_id() != first_texture_id:
			_fail("Expected repeated note textures to be shared, got note 0 texture %d and note %d texture %d." % [
				first_texture_id,
				index,
				texture.get_instance_id(),
			])
			return false
	return true


func _note_texture(view: Node, index: int) -> Texture2D:
	var node := view.get_node_or_null("Note_%03d" % index)
	if not node is TextureRect:
		return null
	return node.texture


func _expect_bool(actual: bool, expected: bool, label: String) -> bool:
	if actual != expected:
		_fail("Expected %s '%s', got '%s'." % [label, expected, actual])
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
