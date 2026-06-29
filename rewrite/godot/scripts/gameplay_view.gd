extends Control

const NoteDistanceCalculator = preload("res://scripts/note_distance_calculator.gd")
const RenderEntityModel = preload("res://scripts/render_entity_model.gd")
const TimingModel = preload("res://scripts/timing_model.gd")

var _model = RenderEntityModel.new()
var _metadata: Dictionary = {}
var _chart: Dictionary = {}
var _note_entries: Array[Dictionary] = []
var _distance = null
var _speed: float = 1.0


func load_metadata(metadata: Dictionary) -> bool:
	var normalized := _model.normalize(metadata)
	if normalized.is_empty():
		return false

	_metadata = normalized
	custom_minimum_size = Vector2(
			float(_metadata.get("baseWidth", 800.0)),
			float(_metadata.get("baseHeight", 600.0)))
	_rebuild_entities()
	if not _chart.is_empty():
		_rebuild_note_nodes()
	return true


func load_chart(chart: Dictionary) -> bool:
	if chart.is_empty():
		return false
	_chart = chart.duplicate(true)
	_configure_distance()
	_rebuild_note_nodes()
	update_time(0.0)
	return true


func update_time(now_ms: float) -> void:
	if _metadata.is_empty() or _distance == null:
		return

	var judgment_line := float(_metadata.get("judgmentLine", 0.0))
	for i in range(_note_entries.size()):
		var entry := _note_entries[i]
		var note: Dictionary = entry.get("note", {})
		var node: Variant = entry.get("node")
		if not node is ColorRect:
			continue

		var note_height: float = float(entry.get("height", 1.0))
		var start_y: float = judgment_line - _distance.calculate_hi_speed(
				now_ms,
				float(note.get("startMs", 0.0)),
				_speed)
		var end_ms: Variant = note.get("endMs", null)
		if end_ms is int or end_ms is float:
			var end_y: float = judgment_line - _distance.calculate_hi_speed(now_ms, float(end_ms), _speed)
			node.position.y = min(start_y, end_y) - note_height
			node.size.y = max(absf(start_y - end_y) + note_height, note_height)
		else:
			node.position.y = start_y - note_height
			node.size.y = note_height


func _rebuild_entities() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_note_entries.clear()

	var index := 0
	for entity: Dictionary in _model.entities_by_layer(_metadata):
		if _is_note_template(entity):
			continue
		var node := ColorRect.new()
		node.name = _node_name(entity, index)
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.position = Vector2(float(entity.get("x", 0.0)), float(entity.get("y", 0.0)))
		node.size = Vector2(max(float(entity.get("width", 0.0)), 1.0), max(float(entity.get("height", 0.0)), 1.0))
		node.color = _color_for_type(str(entity.get("type", "")))
		add_child(node)
		index += 1


func _rebuild_note_nodes() -> void:
	for entry: Dictionary in _note_entries:
		var node: Variant = entry.get("node")
		if node is Node:
			remove_child(node)
			node.free()
	_note_entries.clear()

	if _metadata.is_empty() or _chart.is_empty():
		return

	var notes: Variant = _chart.get("notes", [])
	if not notes is Array:
		return

	var index := 0
	for raw_note: Variant in notes:
		if not raw_note is Dictionary:
			continue
		var note: Dictionary = raw_note.duplicate(true)
		var lane := _lane_for_index(int(note.get("lane", -1)))
		if lane.is_empty():
			continue
		var template := _note_template_for(lane, str(note.get("kind", "")))
		if template.is_empty():
			continue

		var node := ColorRect.new()
		node.name = "Note_%03d" % index
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.position.x = float(lane.get("x", template.get("x", 0.0)))
		node.size.x = float(lane.get("width", template.get("width", 1.0)))
		node.size.y = max(float(template.get("height", 1.0)), 1.0)
		node.color = _color_for_type(str(template.get("type", "")))
		add_child(node)
		_note_entries.append({
			"note": note,
			"node": node,
			"height": node.size.y,
		})
		index += 1


func _configure_distance() -> void:
	var timing = TimingModel.new()
	timing.add_change(0.0, float(_chart.get("bpm", 120.0)))
	timing.finish()
	_distance = NoteDistanceCalculator.new(timing, float(_metadata.get("measureSize", 385.0)))


func _lane_for_index(lane_index: int) -> Dictionary:
	for lane: Dictionary in _metadata.get("lanes", []):
		if int(lane.get("lane", -1)) == lane_index:
			return lane.duplicate(true)
	return {}


func _note_template_for(lane: Dictionary, kind: String) -> Dictionary:
	var expected_type := "longNote" if kind == "holdStart" else "note"
	var channel := str(lane.get("channel", ""))
	for entity: Dictionary in _metadata.get("entities", []):
		if str(entity.get("type", "")) == expected_type and str(entity.get("channel", "")) == channel:
			return entity.duplicate(true)
	return {}


func _is_note_template(entity: Dictionary) -> bool:
	var type := str(entity.get("type", ""))
	return type == "note" or type == "longNote"


func _node_name(entity: Dictionary, index: int) -> String:
	var id := str(entity.get("id", ""))
	if id.is_empty():
		return "Entity_%03d" % index
	var base := "Entity_%s" % id.replace(" ", "_")
	if not has_node(base):
		return base
	return "%s_%03d" % [base, index]


func _color_for_type(type: String) -> Color:
	match type:
		"note", "longNote":
			return Color(0.25, 0.72, 1.0, 0.65)
		"bar":
			return Color(0.5, 1.0, 0.4, 0.65)
		"bga":
			return Color(0.12, 0.12, 0.16, 1.0)
		"judgmentEffect":
			return Color(1.0, 0.85, 0.2, 0.65)
		_:
			return Color(0.8, 0.8, 0.86, 0.35)
