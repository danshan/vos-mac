extends Control

const RenderEntityModel = preload("res://scripts/render_entity_model.gd")

var _model = RenderEntityModel.new()
var _metadata: Dictionary = {}


func load_metadata(metadata: Dictionary) -> bool:
	var normalized := _model.normalize(metadata)
	if normalized.is_empty():
		return false

	_metadata = normalized
	custom_minimum_size = Vector2(
			float(_metadata.get("baseWidth", 800.0)),
			float(_metadata.get("baseHeight", 600.0)))
	_rebuild_entities()
	return true


func _rebuild_entities() -> void:
	for child in get_children():
		remove_child(child)
		child.free()

	var index := 0
	for entity: Dictionary in _model.entities_by_layer(_metadata):
		var node := ColorRect.new()
		node.name = _node_name(entity, index)
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.position = Vector2(float(entity.get("x", 0.0)), float(entity.get("y", 0.0)))
		node.size = Vector2(max(float(entity.get("width", 0.0)), 1.0), max(float(entity.get("height", 0.0)), 1.0))
		node.color = _color_for_type(str(entity.get("type", "")))
		add_child(node)
		index += 1


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
