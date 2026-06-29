extends Control

const NoteDistanceCalculator = preload("res://scripts/note_distance_calculator.gd")
const RenderEntityModel = preload("res://scripts/render_entity_model.gd")
const TimingModel = preload("res://scripts/timing_model.gd")

const JAVA_INITIAL_ENTITY_IDS: Dictionary = {
	"BGA": true,
	"FPS_COUNTER": true,
	"SCORE_COUNTER": true,
	"JAM_COUNTER": true,
	"JAM_BAR": true,
	"LIFE_BAR": true,
	"COMBO_COUNTER": true,
	"MAXCOMBO_COUNTER": true,
	"MINUTE_COUNTER": true,
	"SECOND_COUNTER": true,
	"JUDGMENT_LINE": true,
	"COUNTER_JUDGMENT_PERFECT": true,
	"COUNTER_JUDGMENT_COOL": true,
	"COUNTER_JUDGMENT_GOOD": true,
	"COUNTER_JUDGMENT_BAD": true,
	"COUNTER_JUDGMENT_MISS": true,
}

var _model = RenderEntityModel.new()
var _metadata: Dictionary = {}
var _chart: Dictionary = {}
var _note_entries: Array[Dictionary] = []
var _distance = null
var _speed: float = 1.0
var _hud_labels: Dictionary = {}
var _bar_nodes: Dictionary = {}
var _bar_rects: Dictionary = {}
var _pressed_nodes: Array[Node] = []
var _judgment_node: Node = null
var _click_nodes: Array[Node] = []
var _pill_nodes: Array[Node] = []


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


func update_hud_state(state: Dictionary) -> void:
	_set_hud_text("SCORE_COUNTER", _int_text(state.get("score", 0)))
	_set_combo_text("COMBO_COUNTER", int(state.get("combo", 0)), 2)
	_set_combo_text("JAM_COUNTER", int(state.get("jamCombo", 0)), 1)
	_set_hud_text("MAXCOMBO_COUNTER", _int_text(state.get("maxCombo", 0)))

	var elapsed_seconds := int(floor(max(float(state.get("elapsedMs", 0.0)), 0.0) / 1000.0))
	_set_hud_text("MINUTE_COUNTER", _int_text(elapsed_seconds / 60))
	_set_hud_text("SECOND_COUNTER", "%02d" % (elapsed_seconds % 60))

	var judgments: Dictionary = state.get("judgments", {})
	_set_hud_text("COUNTER_JUDGMENT_PERFECT", _int_text(judgments.get("perfect", 0)))
	_set_hud_text("COUNTER_JUDGMENT_COOL", _int_text(judgments.get("cool", 0)))
	_set_hud_text("COUNTER_JUDGMENT_GOOD", _int_text(judgments.get("good", 0)))
	_set_hud_text("COUNTER_JUDGMENT_BAD", _int_text(judgments.get("bad", 0)))
	_set_hud_text("COUNTER_JUDGMENT_MISS", _int_text(judgments.get("miss", 0)))

	_set_bar_fill("LIFE_BAR", float(state.get("life", 0.0)), float(state.get("lifeLimit", 0.0)))
	_set_bar_fill("JAM_BAR", float(state.get("jamBar", 0.0)), float(state.get("jamBarLimit", 0.0)))
	_sync_pressed_lanes(state.get("pressedLanes", []))
	_sync_judgment_event(state.get("judgmentEvent", {}))
	_sync_click_events(state.get("clickEvents", []))
	_sync_pills(int(state.get("pills", 0)))


func _rebuild_entities() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_note_entries.clear()
	_hud_labels.clear()
	_bar_nodes.clear()
	_bar_rects.clear()
	_clear_pressed_nodes()
	_clear_judgment_node()
	_clear_nodes(_click_nodes)
	_clear_nodes(_pill_nodes)

	var index := 0
	for entity: Dictionary in _model.entities_by_layer(_metadata):
		if not _is_java_initial_entity(entity):
			continue
		var node := _entity_rect(entity, _node_name(entity, index))
		add_child(node)
		_register_bar_node(entity, node)
		_register_hud_label(entity)
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


func _is_java_initial_entity(entity: Dictionary) -> bool:
	var id := str(entity.get("id", ""))
	if id.is_empty():
		return true
	return JAVA_INITIAL_ENTITY_IDS.has(id)


func _entity_rect(entity: Dictionary, node_name: String) -> ColorRect:
	var node := ColorRect.new()
	node.name = node_name
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = Vector2(float(entity.get("x", 0.0)), float(entity.get("y", 0.0)))
	node.size = Vector2(max(float(entity.get("width", 0.0)), 1.0), max(float(entity.get("height", 0.0)), 1.0))
	node.color = _color_for_type(str(entity.get("type", "")))
	return node


func _sync_pressed_lanes(raw_lanes: Variant) -> void:
	_clear_pressed_nodes()
	if not raw_lanes is Array:
		return

	for raw_lane: Variant in raw_lanes:
		var lane := int(raw_lane)
		if lane < 0:
			continue
		var id := "PRESSED_NOTE_%d" % (lane + 1)
		var piece_index := 0
		for entity: Dictionary in _entities_by_id(id):
			var node := _entity_rect(entity, "Pressed_%s_%03d" % [_safe_node_id(id), piece_index])
			add_child(node)
			_pressed_nodes.append(node)
			piece_index += 1


func _sync_judgment_event(raw_event: Variant) -> void:
	_clear_judgment_node()
	if not raw_event is Dictionary or raw_event.is_empty():
		return

	var result := str(raw_event.get("result", "")).to_upper()
	if result.is_empty():
		return
	var entity := _first_entity_by_id("EFFECT_JUDGMENT_%s" % result)
	if entity.is_empty():
		return
	_judgment_node = _entity_rect(entity, "Judgment_EFFECT_JUDGMENT_%s" % result)
	add_child(_judgment_node)


func _sync_click_events(raw_events: Variant) -> void:
	_clear_nodes(_click_nodes)
	if not raw_events is Array:
		return

	var entity := _first_entity_by_id("EFFECT_CLICK")
	if entity.is_empty():
		return
	for raw_event: Variant in raw_events:
		if not raw_event is Dictionary:
			continue
		var sequence := int(raw_event.get("sequence", 0))
		var node := _entity_rect(entity, "Click_EFFECT_CLICK_%03d" % sequence)
		_position_click_node(node, entity, int(raw_event.get("lane", -1)))
		add_child(node)
		_click_nodes.append(node)


func _sync_pills(count: int) -> void:
	_clear_nodes(_pill_nodes)
	for i in range(clamp(count, 0, 5)):
		var id := "PILL_%d" % (i + 1)
		var entity := _first_entity_by_id(id)
		if entity.is_empty():
			continue
		var node := _entity_rect(entity, "Pill_%s" % _safe_node_id(id))
		add_child(node)
		_pill_nodes.append(node)


func _position_click_node(node: ColorRect, entity: Dictionary, lane_index: int) -> void:
	var lane := _lane_for_index(lane_index)
	if lane.is_empty():
		return
	var width: float = max(float(entity.get("width", 0.0)), 1.0)
	var height: float = max(float(entity.get("height", 0.0)), 1.0)
	node.position.x = float(lane.get("x", 0.0)) + float(lane.get("width", 0.0)) * 0.5 - width * 0.5
	node.position.y = float(_metadata.get("judgmentLine", 0.0)) - height * 0.5


func _clear_pressed_nodes() -> void:
	_clear_nodes(_pressed_nodes)


func _clear_judgment_node() -> void:
	if _judgment_node == null or not is_instance_valid(_judgment_node):
		_judgment_node = null
		return
	if _judgment_node.get_parent() == self:
		remove_child(_judgment_node)
	_judgment_node.free()
	_judgment_node = null


func _clear_nodes(nodes: Array[Node]) -> void:
	for node: Node in nodes:
		if not is_instance_valid(node):
			continue
		if node.get_parent() == self:
			remove_child(node)
		node.free()
	nodes.clear()


func _entities_by_id(id: String) -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for entity: Dictionary in _metadata.get("entities", []):
		if str(entity.get("id", "")) == id:
			matches.append(entity.duplicate(true))
	return matches


func _first_entity_by_id(id: String) -> Dictionary:
	for entity: Dictionary in _metadata.get("entities", []):
		if str(entity.get("id", "")) == id:
			return entity.duplicate(true)
	return {}


func _register_bar_node(entity: Dictionary, node: ColorRect) -> void:
	if str(entity.get("type", "")) != "bar":
		return
	var id := str(entity.get("id", ""))
	if id.is_empty():
		return
	_bar_nodes[id] = node
	_bar_rects[id] = {
		"position": node.position,
		"size": node.size,
		"fillDirection": str(entity.get("fillDirection", "left_to_right")),
	}


func _register_hud_label(entity: Dictionary) -> void:
	if not _is_hud_counter(entity):
		return

	var id := str(entity.get("id", ""))
	var label := Label.new()
	label.name = "Hud_%s" % _safe_node_id(id)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.text = "0"

	var digit_width: float = max(float(entity.get("width", 0.0)), 1.0)
	var digit_height: float = max(float(entity.get("height", 0.0)), 1.0)
	var label_width: float = max(digit_width * 8.0, digit_width)
	if str(entity.get("type", "")) == "comboCounter":
		label_width = max(digit_width * 6.0, digit_width)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position.x = float(entity.get("x", 0.0)) - label_width * 0.5
	else:
		label.position.x = float(entity.get("x", 0.0)) - label_width
	label.position.y = float(entity.get("y", 0.0))
	label.size = Vector2(label_width, max(digit_height * 1.4, digit_height))
	label.add_theme_font_size_override("font_size", int(round(max(digit_height, 8.0))))

	_hud_labels[id] = label
	add_child(label)


func _is_hud_counter(entity: Dictionary) -> bool:
	var type := str(entity.get("type", ""))
	return (type == "numberCounter" or type == "comboCounter") and not str(entity.get("id", "")).is_empty()


func _set_hud_text(id: String, text: String) -> void:
	var label: Variant = _hud_labels.get(id)
	if label is Label:
		label.text = text


func _set_combo_text(id: String, value: int, threshold: int) -> void:
	if value < threshold:
		_set_hud_text(id, "")
		return
	_set_hud_text(id, _int_text(value - max(threshold - 1, 0)))


func _set_bar_fill(id: String, value: float, limit: float) -> void:
	var node: Variant = _bar_nodes.get(id)
	var rect: Dictionary = _bar_rects.get(id, {})
	if not node is ColorRect or rect.is_empty():
		return

	var base_position: Vector2 = rect.get("position", Vector2.ZERO)
	var base_size: Vector2 = rect.get("size", Vector2.ZERO)
	var ratio := 0.0
	if limit > 0.0:
		ratio = clamp(value / limit, 0.0, 1.0)

	node.position = base_position
	node.size = base_size

	match str(rect.get("fillDirection", "left_to_right")):
		"right_to_left":
			node.size.x = base_size.x * ratio
			node.position.x = base_position.x + base_size.x - node.size.x
		"up_to_down":
			node.size.y = base_size.y * ratio
			node.position.y = base_position.y + base_size.y - node.size.y
		"down_to_up":
			node.size.y = base_size.y * ratio
		_:
			node.size.x = base_size.x * ratio


func _int_text(value: Variant) -> String:
	if value is int or value is float:
		return "%d" % int(value)
	return "0"


func _safe_node_id(value: String) -> String:
	return value.replace(" ", "_")


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
