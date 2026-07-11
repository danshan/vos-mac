extends Control

const NoteDistanceCalculator = preload("res://scripts/note_distance_calculator.gd")
const RenderEntityModel = preload("res://scripts/render_entity_model.gd")
const TimingModel = preload("res://scripts/timing_model.gd")

const COMBO_WOBBLE_PIXELS: float = 10.0
const COMBO_WOBBLE_SPEED: float = 0.5
const COMBO_SHOW_TIME_MS: float = 4000.0
const JUDGMENT_SHOW_TIME_MS: float = 3000.0
const JUDGMENT_SCALE_RAMP_MS: float = 100.0
const JUDGMENT_INITIAL_SCALE: float = 0.5
const JAVA_RENDER_SPEED: float = 1.0
const SPEED_TYPE_HI_SPEED: String = "HiSpeed"
const SPEED_TYPE_XR_SPEED: String = "xRSpeed"
const SPEED_TYPE_REGUL_SPEED: String = "RegulSpeed"
const SPEED_TYPE_W_SPEED: String = "WSpeed"
const VISIBILITY_NONE: String = "None"
const VISIBILITY_HIDDEN: String = "Hidden"
const VISIBILITY_SUDDEN: String = "Sudden"
const VISIBILITY_DARK: String = "Dark"
const JAVA_STATUS_RIGHT_X: float = 780.0
const JAVA_STATUS_START_Y: float = 300.0
const JAVA_STATUS_LINE_HEIGHT: float = 30.0
const JAVA_STATUS_WIDTH: float = 260.0
const JAVA_STATUS_FONT_SIZE: int = 14
const JAVA_STATUS_GLYPH_HEIGHT: float = 20.0

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
var _measure_entries: Array[Dictionary] = []
var _distance = null
var _speed: float = 1.0
var _target_speed: float = 1.0
var _speed_type: String = SPEED_TYPE_HI_SPEED
var _last_distance_update_ms: float = 0.0
var _has_distance_update_ms: bool = false
var _hud_labels: Dictionary = {}
var _hud_counter_entities: Dictionary = {}
var _hud_digit_entities: Dictionary = {}
var _combo_counter_states: Dictionary = {}
var _bar_nodes: Dictionary = {}
var _bar_rects: Dictionary = {}
var _pressed_nodes: Array[Node] = []
var _pressed_lane_nodes: Dictionary = {}
var _judgment_node: Node = null
var _current_judgment_sequence: int = -1
var _click_nodes: Array[Node] = []
var _click_nodes_by_sequence: Dictionary = {}
var _pill_nodes: Array[Node] = []
var _pill_nodes_by_index: Dictionary = {}
var _longflare_nodes: Array[Node] = []
var _longflare_nodes_by_lane: Dictionary = {}
var _visibility_nodes: Array[Node] = []
var _status_nodes: Array[Node] = []
var _status_font_cache: Dictionary = {}
var _status_font_texture: Texture2D = null
var _status_font_glyphs: Dictionary = {}
var _bga_sprites: Dictionary = {}
var _current_bga_sprite_id: int = -1
var _last_update_time_ms: float = 0.0
var _java_texture_material: CanvasItemMaterial = null
var _source_textures_by_path: Dictionary = {}
var _region_textures_by_key: Dictionary = {}


func load_metadata(metadata: Dictionary) -> bool:
	var normalized := _model.normalize(metadata)
	if normalized.is_empty():
		return false

	_metadata = normalized
	_status_font_texture = null
	_status_font_glyphs.clear()
	_source_textures_by_path.clear()
	_region_textures_by_key.clear()
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
	_configure_bga_sprites()
	_configure_bga_node()
	_configure_distance()
	_rebuild_note_nodes()
	update_time(0.0)
	return true


func update_time(now_ms: float) -> void:
	_update_time(now_ms, now_ms)


func _update_time(now_ms: float, animation_time_ms: float) -> void:
	_last_update_time_ms = now_ms
	if _metadata.is_empty() or _distance == null:
		return

	_update_distance_state(now_ms)
	_update_animation_frames(animation_time_ms)
	var judgment_line := float(_metadata.get("judgmentLine", 0.0))
	for i in range(_note_entries.size()):
		var entry := _note_entries[i]
		var note: Dictionary = entry.get("note", {})
		var node: Variant = entry.get("node")
		if not node is Control:
			continue

		var note_height: float = float(entry.get("height", 1.0))
		var anchor_height: float = float(entry.get("anchorHeight", note_height))
		var lane_index: int = int(note.get("lane", -1))
		var start_y: float = judgment_line - _distance_for(
				now_ms,
				float(note.get("startMs", 0.0)),
				lane_index)
		var end_ms: Variant = note.get("endMs", null)
		if end_ms is int or end_ms is float:
			var end_y: float = judgment_line - _distance_for(now_ms, float(end_ms), lane_index)
			node.position.y = min(start_y, end_y) - anchor_height
			node.size.y = max(absf(start_y - end_y) + anchor_height, note_height)
			if bool(entry.get("longNote", false)):
				_position_long_note_parts(node)
		else:
			node.position.y = start_y - note_height
			node.size.y = note_height

	for entry: Dictionary in _measure_entries:
		var measure: Dictionary = entry.get("measure", {})
		var node: Variant = entry.get("node")
		if not node is Control:
			continue
		node.position.y = judgment_line - _distance_for(
				now_ms,
				float(measure.get("startMs", 0.0))) - 1.0


func update_frame(now_ms: float, state: Dictionary) -> void:
	if state.has("renderSpeed"):
		_speed = max(float(state.get("renderSpeed", _speed)), 0.001)
	if state.has("targetSpeed"):
		_target_speed = max(float(state.get("targetSpeed", _target_speed)), 0.001)
	_apply_distance_speed_factor(state)
	var animation_time_ms := float(state.get("animationTimeMs", now_ms))
	_update_time(now_ms, animation_time_ms)
	update_hud_state(state)


func update_hud_state(state: Dictionary) -> void:
	var hud_time_ms := float(state.get("elapsedMs", 0.0))
	_apply_distance_speed_factor(state)
	if state.has("renderSpeed"):
		_speed = max(float(state.get("renderSpeed", _speed)), 0.001)
	if state.has("targetSpeed"):
		_target_speed = max(float(state.get("targetSpeed", _target_speed)), 0.001)
	_set_hud_text("SCORE_COUNTER", _int_text(state.get("score", 0)))
	_set_hud_text("FPS_COUNTER", _int_text(state.get("fps", 0)))
	_set_combo_text("COMBO_COUNTER", int(state.get("combo", 0)), hud_time_ms)
	_set_combo_text("JAM_COUNTER", int(state.get("jamCombo", 0)), hud_time_ms)
	_set_hud_text("MAXCOMBO_COUNTER", _int_text(state.get("maxCombo", 0)))

	var elapsed_seconds := int(floor(max(hud_time_ms, 0.0) / 1000.0))
	_set_hud_text("MINUTE_COUNTER", _int_text(state.get("minute", elapsed_seconds / 60)))
	_set_hud_text("SECOND_COUNTER", _int_text(state.get("second", elapsed_seconds % 60)))

	var judgments: Dictionary = state.get("judgments", {})
	_set_hud_text("COUNTER_JUDGMENT_PERFECT", _int_text(judgments.get("perfect", 0)))
	_set_hud_text("COUNTER_JUDGMENT_COOL", _int_text(judgments.get("cool", 0)))
	_set_hud_text("COUNTER_JUDGMENT_GOOD", _int_text(judgments.get("good", 0)))
	_set_hud_text("COUNTER_JUDGMENT_BAD", _int_text(judgments.get("bad", 0)))
	_set_hud_text("COUNTER_JUDGMENT_MISS", _int_text(judgments.get("miss", 0)))

	_set_bar_fill("LIFE_BAR", float(state.get("life", 0.0)), float(state.get("lifeLimit", 0.0)))
	_set_bar_fill("JAM_BAR", float(state.get("jamBar", 0.0)), float(state.get("jamBarLimit", 0.0)))
	_sync_pressed_lanes(state.get("pressedLanes", []))
	_sync_judgment_event(state.get("judgmentEvent", {}), hud_time_ms)
	_sync_click_events(state.get("clickEvents", []), hud_time_ms)
	_sync_pills(int(state.get("pills", 0)))
	_sync_longflares(state.get("longFlares", []), hud_time_ms)
	_sync_note_visibility(state.get("hiddenNotes", []), _last_update_time_ms)
	_sync_measure_visibility(state.get("hiddenMeasures", []), _last_update_time_ms)
	_sync_status_texts(state.get("statusTexts", []))
	_sync_bga_event(state.get("currentBgaEvent", {}), bool(state.get("gameStarted", true)))


func _apply_distance_speed_factor(state: Dictionary) -> void:
	if _distance == null or not state.has("distanceSpeedFactor"):
		return
	_distance.speed_factor = max(float(state.get("distanceSpeedFactor", _distance.speed_factor)), 0.001)


func _rebuild_entities() -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	_note_entries.clear()
	_measure_entries.clear()
	_hud_labels.clear()
	_hud_counter_entities.clear()
	_hud_digit_entities.clear()
	_combo_counter_states.clear()
	_bar_nodes.clear()
	_bar_rects.clear()
	_clear_pressed_nodes()
	_clear_judgment_node()
	_clear_click_nodes()
	_clear_pill_nodes()
	_clear_longflare_nodes()
	_clear_nodes(_visibility_nodes)
	_clear_nodes(_status_nodes)

	var index := 0
	for entity: Dictionary in _model.entities_by_layer(_metadata):
		if not _is_java_initial_entity(entity):
			continue
		if _is_hud_counter(entity):
			_register_hud_label(entity)
			continue
		var node := _entity_rect(entity, _node_name(entity, index))
		add_child(node)
		_register_bar_node(entity, node)
		index += 1


func _rebuild_note_nodes() -> void:
	_clear_nodes(_visibility_nodes)
	for entry: Dictionary in _note_entries:
		var node: Variant = entry.get("node")
		if node is Node:
			remove_child(node)
			node.free()
	_note_entries.clear()
	for entry: Dictionary in _measure_entries:
		var node: Variant = entry.get("node")
		if node is Node:
			remove_child(node)
			node.free()
	_measure_entries.clear()

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

		var is_long_note := str(template.get("type", "")) == "longNote"
		var node := _long_note_node(template, "Note_%03d" % index) if is_long_note else _entity_rect(template, "Note_%03d" % index)
		node.position.x = float(lane.get("x", template.get("x", 0.0)))
		node.size.x = float(lane.get("width", template.get("width", 1.0)))
		node.size.y = max(float(template.get("height", 1.0)), 1.0)
		if is_long_note:
			_position_long_note_parts(node)
		add_child(node)
		_note_entries.append({
			"note": note,
			"node": node,
			"height": node.size.y,
			"anchorHeight": _long_note_normal_height(template) if is_long_note else node.size.y,
			"longNote": is_long_note,
		})
		index += 1

	var measure_template := _first_entity_by_id("MEASURE_MARK")
	if measure_template.is_empty():
		_rebuild_visibility_nodes()
		return
	var measures: Variant = _chart.get("measures", [])
	if not measures is Array:
		_rebuild_visibility_nodes()
		return

	index = 0
	for raw_measure: Variant in measures:
		if not raw_measure is Dictionary:
			continue
		var measure: Dictionary = raw_measure.duplicate(true)
		var node := _entity_rect(measure_template, "Measure_%03d" % index)
		add_child(node)
		_measure_entries.append({
			"measure": measure,
			"node": node,
		})
		index += 1
	_rebuild_visibility_nodes()


func _configure_distance() -> void:
	var timing = TimingModel.new()
	if not _load_visual_timing(timing):
		timing.add_change(0.0, float(_chart.get("bpm", 120.0)))
	timing.finish()
	_distance = NoteDistanceCalculator.new(timing, float(_metadata.get("measureSize", 385.0)))
	_speed = _normalized_speed_multiplier(_chart.get("speedMultiplier", JAVA_RENDER_SPEED))
	_target_speed = _speed
	_speed_type = _normalized_speed_type(_chart.get("speedType", SPEED_TYPE_HI_SPEED))
	if _speed_type == SPEED_TYPE_XR_SPEED:
		_distance.set_xr_speed_factors(_chart.get("xRSpeedFactors", []))
	_last_distance_update_ms = 0.0
	_has_distance_update_ms = false


func _configure_bga_sprites() -> void:
	_bga_sprites.clear()
	_current_bga_sprite_id = -1
	var raw_sprites: Variant = _chart.get("bgaSprites", [])
	if not raw_sprites is Array:
		return
	for raw_sprite: Variant in raw_sprites:
		if not raw_sprite is Dictionary:
			continue
		var sprite_id := int(raw_sprite.get("spriteId", 0))
		if sprite_id <= 0:
			continue
		_bga_sprites[sprite_id] = raw_sprite.duplicate(true)


func _configure_bga_node() -> void:
	if _metadata.is_empty():
		return
	var video_path := str(_chart.get("bgaVideoPath", "")).strip_edges()
	if video_path.is_empty():
		if has_node("Entity_BGA") and get_node("Entity_BGA") is VideoStreamPlayer:
			var template := _first_entity_by_id("BGA")
			if not template.is_empty():
				_replace_bga_node(_entity_rect(template, "Entity_BGA"))
		return

	var current_node: Variant = get_node_or_null("Entity_BGA")
	if not current_node is Control:
		var template := _first_entity_by_id("BGA")
		if template.is_empty():
			return
		current_node = _entity_rect(template, "Entity_BGA")
		add_child(current_node)

	var video_stream := _video_stream_for_path(video_path)
	if video_stream == null:
		return

	var video_node := VideoStreamPlayer.new()
	video_node.name = "Entity_BGA"
	video_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_node.position = current_node.position
	video_node.size = current_node.size
	video_node.z_index = current_node.z_index
	video_node.z_as_relative = current_node.z_as_relative
	video_node.expand = true
	video_node.autoplay = false
	video_node.volume = 0.0
	video_node.stream = video_stream
	video_node.set_meta("bgaVideoPath", video_path)
	video_node.set_meta("bgaVideoStarted", false)
	_replace_bga_node(video_node)


func _replace_bga_node(node: Control) -> void:
	var current_node := get_node_or_null("Entity_BGA")
	if current_node == node:
		return
	if current_node == null:
		add_child(node)
		return
	var index := current_node.get_index()
	remove_child(current_node)
	current_node.free()
	add_child(node)
	move_child(node, index)


func _video_stream_for_path(path: String) -> VideoStream:
	if not FileAccess.file_exists(path):
		return null
	var extension := path.get_extension().to_lower()
	var video_class_name := ""
	match extension:
		"ogv", "ogg", "ogm":
			video_class_name = "VideoStreamTheora"
		"mp4", "m4v":
			video_class_name = "VideoStreamMP4"
	if not video_class_name.is_empty() and ClassDB.class_exists(video_class_name) and ClassDB.can_instantiate(video_class_name):
		var stream: Variant = ClassDB.instantiate(video_class_name)
		if stream is VideoStream:
			stream.set("file", path)
			return stream
	var resource := ResourceLoader.load(path)
	if resource is VideoStream:
		return resource
	return null


func _load_visual_timing(timing: TimingModel) -> bool:
	var changes: Variant = _chart.get("visualTiming", [])
	if not changes is Array:
		return false

	var loaded := false
	for raw_change: Variant in changes:
		if not raw_change is Dictionary:
			continue
		timing.add_change(float(raw_change.get("timeMs", 0.0)), float(raw_change.get("bpm", 0.0)))
		loaded = true
	return loaded


func _normalized_speed_multiplier(value: Variant) -> float:
	if value is int or value is float:
		return max(float(value), 0.001)
	return JAVA_RENDER_SPEED


func _normalized_speed_type(value: Variant) -> String:
	if str(value) == SPEED_TYPE_XR_SPEED:
		return SPEED_TYPE_XR_SPEED
	if str(value) == SPEED_TYPE_REGUL_SPEED:
		return SPEED_TYPE_REGUL_SPEED
	if str(value) == SPEED_TYPE_W_SPEED:
		return SPEED_TYPE_W_SPEED
	return SPEED_TYPE_HI_SPEED


func _update_distance_state(now_ms: float) -> void:
	if _speed_type != SPEED_TYPE_W_SPEED:
		return
	var delta_ms: float = 0.0
	if _has_distance_update_ms:
		delta_ms = max(now_ms - _last_distance_update_ms, 0.0)
	_distance.update_w_speed(delta_ms, _target_speed)
	_last_distance_update_ms = now_ms
	_has_distance_update_ms = true


func _distance_for(now_ms: float, target_ms: float, lane: int = -1) -> float:
	if _speed_type == SPEED_TYPE_XR_SPEED:
		return _distance.calculate_xr_speed(now_ms, target_ms, _speed, lane)
	if _speed_type == SPEED_TYPE_REGUL_SPEED:
		return _distance.calculate_regul_speed(now_ms, target_ms, _speed)
	if _speed_type == SPEED_TYPE_W_SPEED:
		return _distance.calculate_w_speed(now_ms, target_ms)
	return _distance.calculate_hi_speed(now_ms, target_ms, _speed)


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


func _entity_rect(entity: Dictionary, node_name: String) -> Control:
	if _has_sprite_frames(entity):
		return _animated_entity_rect(entity, node_name)
	var texture := _texture_for_entity(entity)
	if texture != null:
		var texture_node := TextureRect.new()
		texture_node.name = node_name
		texture_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_node.position = Vector2(float(entity.get("x", 0.0)), float(entity.get("y", 0.0)))
		texture_node.size = Vector2(max(float(entity.get("width", 0.0)), 1.0), max(float(entity.get("height", 0.0)), 1.0))
		texture_node.texture = texture
		texture_node.stretch_mode = TextureRect.STRETCH_SCALE
		_configure_java_texture_node(texture_node, entity)
		_apply_entity_layer(texture_node, entity)
		return texture_node

	var node := ColorRect.new()
	node.name = node_name
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = Vector2(float(entity.get("x", 0.0)), float(entity.get("y", 0.0)))
	node.size = Vector2(max(float(entity.get("width", 0.0)), 1.0), max(float(entity.get("height", 0.0)), 1.0))
	node.color = _color_for_type(str(entity.get("type", "")))
	_apply_entity_layer(node, entity)
	return node


func _animated_entity_rect(entity: Dictionary, node_name: String) -> Control:
	var texture_node := TextureRect.new()
	texture_node.name = node_name
	texture_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_node.position = Vector2(float(entity.get("x", 0.0)), float(entity.get("y", 0.0)))
	texture_node.size = Vector2(max(float(entity.get("width", 0.0)), 1.0), max(float(entity.get("height", 0.0)), 1.0))
	texture_node.stretch_mode = TextureRect.STRETCH_SCALE
	_configure_java_texture_node(texture_node, entity)
	texture_node.set_meta("spriteFrames", _sprite_frames(entity))
	texture_node.set_meta("frameSpeed", float(entity.get("frameSpeed", 0.0)))
	texture_node.set_meta("animationStartMs", float(entity.get("animationStartMs", 0.0)))
	_apply_animation_frame(texture_node, 0.0)
	_apply_entity_layer(texture_node, entity)
	return texture_node


func _long_note_node(entity: Dictionary, node_name: String) -> Control:
	var node := Control.new()
	node.name = node_name
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = Vector2(float(entity.get("x", 0.0)), float(entity.get("y", 0.0)))
	node.size = Vector2(max(float(entity.get("width", 0.0)), 1.0), max(float(entity.get("height", 0.0)), 1.0))
	node.add_child(_entity_part_rect(entity, "Body", "body"))
	node.add_child(_entity_part_rect(entity, "Tail", "tail"))
	node.add_child(_entity_part_rect(entity, "Head", ""))
	_position_long_note_parts(node)
	_apply_entity_layer(node, entity)
	return node


func _entity_part_rect(entity: Dictionary, node_name: String, prefix: String) -> Control:
	var texture := _texture_for_entity_part(entity, prefix)
	if texture != null:
		var texture_node := TextureRect.new()
		texture_node.name = node_name
		texture_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_node.texture = texture
		texture_node.stretch_mode = TextureRect.STRETCH_SCALE
		_configure_java_texture_node(texture_node, entity)
		texture_node.size = Vector2(max(float(entity.get("width", 0.0)), 1.0), _texture_height_for_part(entity, prefix))
		var frames := _sprite_frames_for_part(entity, prefix)
		if not frames.is_empty():
			texture_node.set_meta("spriteFrames", frames)
			texture_node.set_meta("frameSpeed", _frame_speed_for_part(entity, prefix))
			texture_node.set_meta("animationStartMs", float(entity.get("animationStartMs", 0.0)))
			_apply_animation_frame(texture_node, 0.0)
		return texture_node

	var node := ColorRect.new()
	node.name = node_name
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size = Vector2(max(float(entity.get("width", 0.0)), 1.0), _texture_height_for_part(entity, prefix))
	node.color = _color_for_type(str(entity.get("type", "")))
	return node


func _position_long_note_parts(node: Control) -> void:
	if not node.has_node("Head") or not node.has_node("Body") or not node.has_node("Tail"):
		return
	var head: Control = node.get_node("Head")
	var body: Control = node.get_node("Body")
	var tail: Control = node.get_node("Tail")
	head.position = Vector2.ZERO
	head.size.x = node.size.x
	body.position = Vector2.ZERO
	body.size = node.size
	tail.position = Vector2(0.0, max(node.size.y - tail.size.y, 0.0))
	tail.size.x = node.size.x


func _long_note_normal_height(entity: Dictionary) -> float:
	return max(float(entity.get("normalHeight", entity.get("height", 1.0))), 1.0)


func _texture_for_entity(entity: Dictionary) -> Texture2D:
	return _texture_for_entity_part(entity, "")


func _texture_for_entity_part(entity: Dictionary, prefix: String) -> Texture2D:
	var path_key := "texturePath" if prefix.is_empty() else "%sTexturePath" % prefix
	var texture_path := str(entity.get("texturePath", "")).strip_edges()
	if not prefix.is_empty():
		texture_path = str(entity.get(path_key, "")).strip_edges()
	if texture_path.is_empty():
		return null
	var extension := texture_path.get_extension().to_lower()
	if ["png", "jpg", "jpeg", "webp", "bmp", "tga"].has(extension):
		var image_texture := _image_texture_for_path(texture_path)
		return _texture_with_region(entity, image_texture, prefix, texture_path)
	var resource := _resource_texture_for_path(texture_path)
	if resource is Texture2D:
		return _texture_with_region(entity, resource, prefix, texture_path)
	return null


func _image_texture_for_path(texture_path: String) -> Texture2D:
	var cached: Variant = _source_textures_by_path.get(texture_path, null)
	if cached is Texture2D:
		return cached
	var image := Image.new()
	if image.load(texture_path) == OK:
		_prepare_java_texture_image(image)
		var texture := ImageTexture.create_from_image(image)
		_source_textures_by_path[texture_path] = texture
		return texture
	return null


func _resource_texture_for_path(texture_path: String) -> Texture2D:
	var cached: Variant = _source_textures_by_path.get(texture_path, null)
	if cached is Texture2D:
		return cached
	var resource := ResourceLoader.load(texture_path)
	if resource is Texture2D:
		_source_textures_by_path[texture_path] = resource
		return resource
	return null


func _prepare_java_texture_image(image: Image) -> void:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if is_zero_approx(pixel.a):
				image.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))


func _texture_with_region(entity: Dictionary, texture: Texture2D, prefix: String = "",
		texture_path: String = "") -> Texture2D:
	if texture == null:
		return null
	var x_key := "textureX" if prefix.is_empty() else "%sTextureX" % prefix
	var y_key := "textureY" if prefix.is_empty() else "%sTextureY" % prefix
	var width_key := "textureWidth" if prefix.is_empty() else "%sTextureWidth" % prefix
	var height_key := "textureHeight" if prefix.is_empty() else "%sTextureHeight" % prefix
	if not entity.has(x_key) or not entity.has(y_key) or not entity.has(width_key) or not entity.has(height_key):
		return texture
	var region := Rect2(
			float(entity.get(x_key, 0.0)),
			float(entity.get(y_key, 0.0)),
			float(entity.get(width_key, 0.0)),
			float(entity.get(height_key, 0.0)))
	if region.size.x <= 0.0 or region.size.y <= 0.0:
		return texture
	var cache_key := _texture_region_cache_key(texture, texture_path, region)
	var cached: Variant = _region_textures_by_key.get(cache_key, null)
	if cached is Texture2D:
		return cached
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	_region_textures_by_key[cache_key] = atlas
	return atlas


func _texture_region_cache_key(texture: Texture2D, texture_path: String, region: Rect2) -> String:
	var source_key := texture_path
	if source_key.is_empty():
		source_key = str(texture.get_instance_id())
	return "%s|%s|%s|%s|%s" % [
		source_key,
		region.position.x,
		region.position.y,
		region.size.x,
		region.size.y,
	]


func _texture_height_for_part(entity: Dictionary, prefix: String) -> float:
	var height_key := "textureHeight" if prefix.is_empty() else "%sTextureHeight" % prefix
	return max(float(entity.get(height_key, entity.get("height", 1.0))), 1.0)


func _sprite_frames(entity: Dictionary) -> Array[Dictionary]:
	return _sprite_frames_for_part(entity, "")


func _sprite_frames_for_part(entity: Dictionary, prefix: String) -> Array[Dictionary]:
	var frames: Array[Dictionary] = []
	var key := "spriteFrames" if prefix.is_empty() else "%sSpriteFrames" % prefix
	var raw_frames: Variant = entity.get(key, [])
	if raw_frames is Array:
		for raw_frame: Variant in raw_frames:
			if raw_frame is Dictionary:
				frames.append(raw_frame.duplicate(true))
	return frames


func _frame_speed_for_part(entity: Dictionary, prefix: String) -> float:
	if prefix.is_empty():
		return float(entity.get("frameSpeed", 0.0))
	return float(entity.get("%sFrameSpeed" % prefix, 0.0))


func _update_animation_frames(now_ms: float) -> void:
	_update_animation_frames_for_node(self, now_ms)


func _update_animation_frames_for_node(node: Node, now_ms: float) -> void:
	if node is TextureRect:
		_apply_animation_frame(node, now_ms)
	if node is Control:
		_apply_judgment_effect_scale(node, now_ms)
	for child: Node in node.get_children():
		_update_animation_frames_for_node(child, now_ms)


func _apply_animation_frame(node: TextureRect, now_ms: float) -> void:
	if not node.has_meta("spriteFrames"):
		return
	var frames: Array = node.get_meta("spriteFrames")
	if frames.is_empty():
		return
	var frame_speed := float(node.get_meta("frameSpeed", 0.0))
	var animation_ms: float = max(now_ms - float(node.get_meta("animationStartMs", 0.0)), 0.0)
	var frame_index := 0
	if frame_speed > 0.0 and frames.size() > 1:
		frame_index = int(floor(animation_ms * frame_speed)) % frames.size()
	var frame: Variant = frames[frame_index]
	if not frame is Dictionary:
		return
	var texture := _texture_for_entity_part(frame, "")
	if texture == null:
		return
	node.texture = texture
	if bool(node.get_meta("javaBarSlice", false)):
		_set_bar_base_texture_region(node)


func _apply_judgment_effect_scale(node: Control, now_ms: float) -> void:
	if not bool(node.get_meta("judgmentEffect", false)):
		return
	var elapsed_ms: float = max(now_ms - float(node.get_meta("animationStartMs", 0.0)), 0.0)
	var ramp_ms := _judgment_scale_ramp_ms_from_node(node)
	var initial_scale := _judgment_initial_scale_from_node(node)
	var scale_factor := 1.0
	if ramp_ms > 0.0 and elapsed_ms < ramp_ms:
		scale_factor = initial_scale + elapsed_ms * (1.0 - initial_scale) / ramp_ms
	node.pivot_offset = node.size * 0.5
	node.scale = Vector2(scale_factor, scale_factor)


func _sync_pressed_lanes(raw_lanes: Variant) -> void:
	var active_lanes := {}
	if raw_lanes is Array:
		for raw_lane: Variant in raw_lanes:
			var lane := int(raw_lane)
			if lane >= 0:
				active_lanes[lane] = true

	for raw_lane: Variant in _pressed_lane_nodes.keys():
		var lane := int(raw_lane)
		if bool(active_lanes.get(lane, false)):
			continue
		_clear_pressed_lane(lane)

	if not raw_lanes is Array:
		return

	for raw_lane: Variant in raw_lanes:
		var lane := int(raw_lane)
		if lane < 0 or _pressed_lane_nodes.has(lane):
			continue
		var id := "PRESSED_NOTE_%d" % (lane + 1)
		var piece_index := 0
		var lane_nodes: Array[Node] = []
		for entity: Dictionary in _entities_by_id(id):
			var pressed_entity := entity.duplicate(true)
			pressed_entity["animationStartMs"] = _last_update_time_ms
			var node := _entity_rect(pressed_entity, "Pressed_%s_%03d" % [_safe_node_id(id), piece_index])
			_update_animation_frames_for_node(node, _last_update_time_ms)
			add_child(node)
			_pressed_nodes.append(node)
			lane_nodes.append(node)
			piece_index += 1
		_pressed_lane_nodes[lane] = lane_nodes


func _sync_judgment_event(raw_event: Variant, now_ms: float) -> void:
	if not raw_event is Dictionary or raw_event.is_empty():
		_clear_judgment_node()
		return

	var sequence := int(raw_event.get("sequence", -1))
	var result := str(raw_event.get("result", "")).to_upper()
	if result.is_empty():
		_clear_judgment_node()
		return
	var entity := _first_entity_by_id("EFFECT_JUDGMENT_%s" % result)
	if entity.is_empty():
		_clear_judgment_node()
		return

	var start_ms := float(raw_event.get("startMs", now_ms))
	if now_ms - start_ms > _judgment_show_time_ms(entity):
		_clear_judgment_node()
		return

	if sequence == _current_judgment_sequence and _judgment_node != null and is_instance_valid(_judgment_node):
		_update_animation_frames_for_node(_judgment_node, now_ms)
		return

	_clear_judgment_node()
	entity["animationStartMs"] = start_ms
	_judgment_node = _entity_rect(entity, "Judgment_EFFECT_JUDGMENT_%s" % result)
	if _judgment_node is Control:
		_judgment_node.set_meta("judgmentEffect", true)
		_judgment_node.pivot_offset = _judgment_node.size * 0.5
		_judgment_node.set_meta("judgmentSequence", sequence)
		_judgment_node.set_meta("judgmentInitialScale", _judgment_initial_scale(entity))
		_judgment_node.set_meta("judgmentScaleRampMs", _judgment_scale_ramp_ms(entity))
	add_child(_judgment_node)
	_current_judgment_sequence = sequence
	_update_animation_frames_for_node(_judgment_node, now_ms)


func _sync_click_events(raw_events: Variant, now_ms: float) -> void:
	if not raw_events is Array:
		_clear_click_nodes()
		return

	var entity := _first_entity_by_id("EFFECT_CLICK")
	if entity.is_empty():
		_clear_click_nodes()
		return
	var active_sequences := {}
	for raw_event: Variant in raw_events:
		if not raw_event is Dictionary:
			continue
		if _one_shot_animation_finished(entity, raw_event, now_ms):
			continue
		var sequence := int(raw_event.get("sequence", 0))
		active_sequences[sequence] = true
		var existing: Variant = _click_nodes_by_sequence.get(sequence)
		if existing is Control and is_instance_valid(existing):
			_position_click_node(existing, entity, int(raw_event.get("lane", -1)))
			_update_animation_frames_for_node(existing, now_ms)
			continue
		if _click_nodes_by_sequence.has(sequence):
			_clear_click_node(sequence)
		var event_entity := entity.duplicate(true)
		event_entity["animationStartMs"] = float(raw_event.get("startMs", 0.0))
		var node := _entity_rect(event_entity, "Click_EFFECT_CLICK_%03d" % sequence)
		_position_click_node(node, entity, int(raw_event.get("lane", -1)))
		_update_animation_frames_for_node(node, now_ms)
		add_child(node)
		_click_nodes.append(node)
		_click_nodes_by_sequence[sequence] = node
	for raw_sequence: Variant in _click_nodes_by_sequence.keys():
		var sequence := int(raw_sequence)
		if not bool(active_sequences.get(sequence, false)):
			_clear_click_node(sequence)


func _sync_pills(count: int) -> void:
	var target_count: int = int(clamp(count, 0, 5))
	for raw_index: Variant in _pill_nodes_by_index.keys():
		var index := int(raw_index)
		if index > target_count:
			_clear_pill_node(index)
	for i in range(target_count):
		var index := i + 1
		var existing: Variant = _pill_nodes_by_index.get(index)
		if existing is Node and is_instance_valid(existing):
			_update_animation_frames_for_node(existing, _last_update_time_ms)
			continue
		if _pill_nodes_by_index.has(index):
			_clear_pill_node(index)
		var id := "PILL_%d" % index
		var entity := _first_entity_by_id(id)
		if entity.is_empty():
			_clear_pill_node(index)
			continue
		var node := _entity_rect(entity, "Pill_%s" % _safe_node_id(id))
		add_child(node)
		_pill_nodes.append(node)
		_pill_nodes_by_index[index] = node


func _sync_longflares(raw_flares: Variant, now_ms: float) -> void:
	if not raw_flares is Array:
		_clear_longflare_nodes()
		return

	var entity := _first_entity_by_id("EFFECT_LONGFLARE")
	if entity.is_empty():
		_clear_longflare_nodes()
		return
	var active_lanes := {}
	for raw_flare: Variant in raw_flares:
		if not raw_flare is Dictionary:
			continue
		var lane_index := int(raw_flare.get("lane", -1))
		if lane_index < 0:
			continue
		active_lanes[lane_index] = true
		var start_ms := float(raw_flare.get("startMs", 0.0))
		var existing: Variant = _longflare_nodes_by_lane.get(lane_index)
		if existing is Control and is_instance_valid(existing) and is_equal_approx(float(existing.get_meta("longflareStartMs", -1.0)), start_ms):
			# Java creates the longflare at hold start and does not keep it attached to the moving note.
			_update_animation_frames_for_node(existing, now_ms)
			continue
		if _longflare_nodes_by_lane.has(lane_index):
			_clear_longflare_node(lane_index)
		var flare_entity := entity.duplicate(true)
		flare_entity["animationStartMs"] = start_ms
		var node := _entity_rect(flare_entity, "Longflare_EFFECT_LONGFLARE_%03d" % lane_index)
		node.set_meta("longflareStartMs", start_ms)
		_position_longflare_node(node, entity, lane_index, raw_flare)
		_update_animation_frames_for_node(node, now_ms)
		add_child(node)
		_longflare_nodes.append(node)
		_longflare_nodes_by_lane[lane_index] = node
	for raw_lane: Variant in _longflare_nodes_by_lane.keys():
		var lane := int(raw_lane)
		if not bool(active_lanes.get(lane, false)):
			_clear_longflare_node(lane)


func _sync_note_visibility(raw_hidden_notes: Variant, now_ms: float) -> void:
	var hidden := {}
	if raw_hidden_notes is Array:
		for raw_index: Variant in raw_hidden_notes:
			var index := int(raw_index)
			if index >= 0:
				hidden[index] = true

	for i in range(_note_entries.size()):
		var node: Variant = _note_entries[i].get("node")
		if node is CanvasItem:
			var visible := not bool(hidden.get(i, false))
			if visible and not node.visible:
				_reset_animation_start_for_node(node, now_ms)
			node.visible = visible


func _sync_measure_visibility(raw_hidden_measures: Variant, now_ms: float) -> void:
	var hidden := {}
	if raw_hidden_measures is Array:
		for raw_index: Variant in raw_hidden_measures:
			var index := int(raw_index)
			if index >= 0:
				hidden[index] = true

	for i in range(_measure_entries.size()):
		var node: Variant = _measure_entries[i].get("node")
		if node is CanvasItem:
			var visible := not bool(hidden.get(i, false))
			if visible and not node.visible:
				_reset_animation_start_for_node(node, now_ms)
			node.visible = visible


func _reset_animation_start_for_node(node: Node, now_ms: float) -> void:
	if node is TextureRect and node.has_meta("spriteFrames"):
		node.set_meta("animationStartMs", now_ms)
		_apply_animation_frame(node, now_ms)
	for child: Node in node.get_children():
		_reset_animation_start_for_node(child, now_ms)


func _sync_status_texts(raw_texts: Variant) -> void:
	_clear_nodes(_status_nodes)
	if not raw_texts is Array:
		return
	var layout := _status_text_layout()
	if _java_status_font_available():
		var right_x := _status_layout_float(layout, "rightX", JAVA_STATUS_RIGHT_X)
		var start_y := _status_layout_float(layout, "startY", JAVA_STATUS_START_Y)
		var line_height := _status_layout_float(layout, "lineHeight", JAVA_STATUS_LINE_HEIGHT)
		for i in range(raw_texts.size()):
			var text := str(raw_texts[i])
			if text.is_empty():
				continue
			var node := _java_status_text_node("StatusText_%03d" % i, text, right_x, start_y + line_height * i, layout)
			if node == null:
				break
			add_child(node)
			_status_nodes.append(node)
		return
	var right_x := _status_layout_float(layout, "rightX", JAVA_STATUS_RIGHT_X)
	var start_y := _status_layout_float(layout, "startY", JAVA_STATUS_START_Y)
	var line_height := _status_layout_float(layout, "lineHeight", JAVA_STATUS_LINE_HEIGHT)
	var label_width := _status_layout_float(layout, "labelWidth", JAVA_STATUS_WIDTH)
	var font_size := int(_status_layout_float(layout, "fontSize", float(JAVA_STATUS_FONT_SIZE)))
	var bold := bool(layout.get("bold", false))
	var anti_alias := bool(layout.get("antiAlias", false))
	var font_family := _status_font_family(layout)
	var font_weight := _status_font_weight(bold)
	var font_color := _status_font_color(layout)
	var alignment := _status_horizontal_alignment(layout)

	for i in range(raw_texts.size()):
		var text := str(raw_texts[i])
		if text.is_empty():
			continue
		var label := Label.new()
		label.name = "StatusText_%03d" % i
		label.text = text
		label.horizontal_alignment = alignment
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.z_index = 1000
		label.z_as_relative = false
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", font_color)
		label.set_meta("statusTextBold", bold)
		label.set_meta("statusTextAntiAlias", anti_alias)
		label.set_meta("statusTextFontFamily", font_family)
		label.set_meta("statusTextFontWeight", font_weight)
		_apply_status_text_font(label, font_family, font_weight, anti_alias)
		var actual_width: float = max(label_width, label.get_combined_minimum_size().x)
		var draw_y := start_y + line_height * i
		label.position = Vector2(right_x - actual_width, _status_label_y(layout, draw_y))
		label.size = Vector2(actual_width, line_height)
		add_child(label)
		_status_nodes.append(label)


func _java_status_font_available() -> bool:
	return _java_status_font_texture() != null and not _java_status_font_glyphs().is_empty()


func _java_status_text_node(node_name: String, text: String, x: float, y: float, layout: Dictionary) -> Control:
	var texture := _java_status_font_texture()
	var glyphs := _java_status_font_glyphs()
	if texture == null or glyphs.is_empty():
		return null

	var font := _status_font_metadata()
	var scale_x := float(layout.get("scaleX", 1.0))
	var scale_y := float(layout.get("scaleY", 1.0))
	var alignment := str(layout.get("horizontalAlignment", "right"))
	var font_height := float(font.get("fontHeight", JAVA_STATUS_GLYPH_HEIGHT))
	var correction := float(font.get("correctL", 0))
	var direction := 1
	var index := 0
	var total_width := 0.0
	var start_y := 0.0

	if alignment == "right":
		direction = -1
		correction = float(font.get("correctR", 0))
		index = text.length() - 1
		var scan := 0
		while scan < text.length() - 1:
			if text.substr(scan, 1) == "\n":
				start_y -= font_height
			scan += 1
	elif alignment == "center":
		total_width = _java_status_text_line_width(text, glyphs, float(font.get("correctL", 0))) / -2.0
		correction = float(font.get("correctL", 0))

	var glyph_nodes: Array[TextureRect] = []
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	var glyph_index := 0
	while index >= 0 and index < text.length():
		var code := text.unicode_at(index)
		var glyph: Dictionary = glyphs.get(code, {})
		if glyph.is_empty():
			index += direction
			continue
		if direction < 0:
			total_width += (float(glyph.get("width", 0.0)) - correction) * direction

		if code == 10:
			start_y -= font_height * direction
			total_width = 0.0
			if alignment == "center":
				total_width = _java_status_text_line_width(text.substr(index + 1), glyphs,
						float(font.get("correctL", 0))) / -2.0
		else:
			var draw_x: float = (total_width + float(glyph.get("width", 0.0))) * scale_x + x
			var draw_x2: float = total_width * scale_x + x
			var draw_y: float = start_y * scale_y + y
			var draw_y2: float = (start_y + float(glyph.get("height", 0.0))) * scale_y + y
			var left: float = min(draw_x, draw_x2)
			var top: float = min(draw_y, draw_y2)
			var width: float = absf(draw_x2 - draw_x)
			var height: float = absf(draw_y2 - draw_y)
			min_x = min(min_x, left)
			min_y = min(min_y, top)
			max_x = max(max_x, left + width)
			max_y = max(max_y, top + height)
			var glyph_node := _java_status_glyph_node(texture, glyph, glyph_index, layout)
			glyph_node.position = Vector2(left, top)
			glyph_node.size = Vector2(width, height)
			glyph_nodes.append(glyph_node)
			glyph_index += 1

		if direction > 0:
			total_width += (float(glyph.get("width", 0.0)) - correction) * direction
		index += direction

	var container := Control.new()
	container.name = node_name
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.z_index = 1000
	container.z_as_relative = false
	container.set_meta("statusText", text)
	container.set_meta("statusTextRenderer", "TrueTypeFont")
	container.set_meta("statusTextBold", bool(layout.get("bold", false)))
	container.set_meta("statusTextAntiAlias", bool(layout.get("antiAlias", false)))
	container.set_meta("statusTextFontFamily", _status_font_family(layout))
	container.set_meta("statusTextFontWeight", _status_font_weight(bool(layout.get("bold", false))))
	container.set_meta("statusTextRightX", x)
	container.set_meta("statusTextDrawY", y)
	if glyph_nodes.is_empty():
		container.position = Vector2(x, y)
		container.size = Vector2.ZERO
		return container

	container.position = Vector2(min_x, min_y)
	container.size = Vector2(max_x - min_x, max_y - min_y)
	for glyph_node: TextureRect in glyph_nodes:
		glyph_node.position -= container.position
		container.add_child(glyph_node)
	return container


func _java_status_text_line_width(text: String, glyphs: Dictionary, correction: float) -> float:
	var total := 0.0
	for i in range(text.length()):
		var code := text.unicode_at(i)
		if code == 10:
			break
		var glyph: Dictionary = glyphs.get(code, {})
		if glyph.is_empty():
			continue
		total += float(glyph.get("width", 0.0)) - correction
	return total


func _java_status_glyph_node(texture: Texture2D, glyph: Dictionary, index: int, layout: Dictionary) -> TextureRect:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(
			float(glyph.get("x", 0.0)),
			float(glyph.get("y", 0.0)),
			float(glyph.get("width", 1.0)),
			float(glyph.get("height", 1.0)))
	var node := TextureRect.new()
	node.name = "Glyph_%03d_%03d" % [index, int(glyph.get("code", 0))]
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.texture = atlas
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.modulate = _status_font_color(layout)
	_configure_java_texture_node(node, {})
	node.material = _java_texture_canvas_material()
	return node


func _java_status_font_texture() -> Texture2D:
	if _status_font_texture != null:
		return _status_font_texture
	var font := _status_font_metadata()
	if font.is_empty():
		return null
	var encoded := str(font.get("pngBase64", ""))
	if encoded.is_empty():
		return null
	var bytes := Marshalls.base64_to_raw(encoded)
	if bytes.is_empty():
		return null
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return null
	_status_font_texture = ImageTexture.create_from_image(image)
	return _status_font_texture


func _java_status_font_glyphs() -> Dictionary:
	if not _status_font_glyphs.is_empty():
		return _status_font_glyphs
	var font := _status_font_metadata()
	var raw_glyphs: Variant = font.get("glyphs", [])
	if not raw_glyphs is Array:
		return {}
	for raw_glyph: Variant in raw_glyphs:
		if not raw_glyph is Dictionary:
			continue
		var glyph: Dictionary = raw_glyph
		_status_font_glyphs[int(glyph.get("code", -1))] = glyph.duplicate(true)
	return _status_font_glyphs


func _status_font_metadata() -> Dictionary:
	var font: Variant = _metadata.get("statusFont", {})
	if font is Dictionary:
		return font
	return {}


func _status_text_layout() -> Dictionary:
	var layout: Variant = _metadata.get("statusTextLayout", {})
	if layout is Dictionary:
		return layout
	return {}


func _status_layout_float(layout: Dictionary, field: String, fallback: float) -> float:
	return max(float(layout.get(field, fallback)), 0.0)


func _status_label_y(layout: Dictionary, draw_y: float) -> float:
	var scale_y := float(layout.get("scaleY", 1.0))
	if scale_y < 0.0:
		return draw_y - _status_layout_float(layout, "glyphHeight", JAVA_STATUS_GLYPH_HEIGHT)
	return draw_y


func _status_font_family(layout: Dictionary) -> String:
	var family := str(layout.get("fontFamily", "")).strip_edges()
	if family.is_empty():
		return "Tahoma"
	return family


func _status_font_weight(bold: bool) -> int:
	return 700 if bold else 400


func _status_font_color(layout: Dictionary) -> Color:
	var color_text := str(layout.get("fontColor", "#ffffffff")).strip_edges()
	if Color.html_is_valid(color_text):
		return Color.html(color_text)
	return Color(1.0, 1.0, 1.0, 1.0)


func _apply_status_text_font(label: Label, font_family: String, font_weight: int, anti_alias: bool) -> void:
	var font := _status_font(font_family, font_weight, anti_alias)
	if font == null:
		return
	label.add_theme_font_override("font", font)


func _status_font(font_family: String, font_weight: int, anti_alias: bool) -> Font:
	var cache_key := "%s:%d:%s" % [font_family, font_weight, anti_alias]
	if _status_font_cache.has(cache_key):
		return _status_font_cache[cache_key]

	var font_path := OS.get_system_font_path(font_family, font_weight, 100, false)
	if font_path.is_empty():
		_status_font_cache[cache_key] = null
		return null

	var font_file := FontFile.new()
	font_file.load_dynamic_font(font_path)
	if font_file.data.is_empty():
		_status_font_cache[cache_key] = null
		return null
	font_file.antialiasing = TextServer.FONT_ANTIALIASING_GRAY if anti_alias else TextServer.FONT_ANTIALIASING_NONE

	_status_font_cache[cache_key] = font_file
	return font_file


func _status_horizontal_alignment(layout: Dictionary) -> HorizontalAlignment:
	match str(layout.get("horizontalAlignment", "right")):
		"left":
			return HORIZONTAL_ALIGNMENT_LEFT
		"center":
			return HORIZONTAL_ALIGNMENT_CENTER
		_:
			return HORIZONTAL_ALIGNMENT_RIGHT


func _sync_bga_event(raw_event: Variant, game_started: bool = true) -> void:
	if not game_started:
		return
	if not raw_event is Dictionary:
		return
	var raw_bga_node: Variant = get_node_or_null("Entity_BGA")
	if raw_bga_node is VideoStreamPlayer:
		raw_bga_node.set_meta("currentBgaEventStartMs", float(raw_event.get("startMs", 0.0)))
		if not bool(raw_bga_node.get_meta("bgaVideoStarted", false)):
			raw_bga_node.set_meta("bgaVideoStarted", true)
			if raw_bga_node.stream != null:
				raw_bga_node.play()
		return
	var sprite_id := int(raw_event.get("spriteId", 0))
	if sprite_id <= 0 or sprite_id == _current_bga_sprite_id:
		return
	var sprite: Dictionary = _bga_sprites.get(sprite_id, {})
	if sprite.is_empty():
		return
	if not has_node("Entity_BGA"):
		return
	var bga_node: Variant = get_node("Entity_BGA")
	if not bga_node is TextureRect:
		return
	var texture := _texture_for_entity(sprite)
	if texture == null:
		return
	bga_node.texture = texture
	bga_node.set_meta("currentBgaSpriteId", sprite_id)
	_current_bga_sprite_id = sprite_id


func _rebuild_visibility_nodes() -> void:
	_clear_nodes(_visibility_nodes)
	var modifier: String = _normalized_visibility_modifier(_chart.get("visibilityModifier", VISIBILITY_NONE))
	_apply_visibility_layers(modifier)
	if modifier == VISIBILITY_NONE:
		return
	if _java_visibility_composite_removed_before_draw():
		return
	var height: float = max(float(_metadata.get("judgmentLine", 0.0)), 1.0)
	var layer: int = _visibility_layer()
	var index: int = 0
	for lane: Dictionary in _metadata.get("lanes", []):
		var width: float = max(float(lane.get("width", 0.0)), 1.0)
		var node: TextureRect = TextureRect.new()
		node.name = "Visibility_%s_%03d" % [modifier, index]
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.position = Vector2(float(lane.get("x", 0.0)), 0.0)
		node.size = Vector2(width, height)
		node.texture = _visibility_texture(int(round(width)), int(round(height)), modifier)
		node.stretch_mode = TextureRect.STRETCH_SCALE
		_configure_java_texture_node(node, {})
		node.z_index = layer
		node.z_as_relative = false
		add_child(node)
		_visibility_nodes.append(node)
		index += 1


func _java_visibility_composite_removed_before_draw() -> bool:
	return true


func _normalized_visibility_modifier(value: Variant) -> String:
	var modifier := str(value)
	if modifier == VISIBILITY_HIDDEN:
		return VISIBILITY_HIDDEN
	if modifier == VISIBILITY_SUDDEN:
		return VISIBILITY_SUDDEN
	if modifier == VISIBILITY_DARK:
		return VISIBILITY_DARK
	return VISIBILITY_NONE


func _visibility_layer() -> int:
	var metadata_layer := int(_metadata.get("visibilityLayer", 0))
	if metadata_layer > 0:
		return metadata_layer

	var layer := _metadata_layer_for_id("NOTE_1") + 1
	for entity: Dictionary in _metadata.get("entities", []):
		if not str(entity.get("id", "")).is_empty():
			continue
		if int(entity.get("layer", 0)) > layer:
			layer += 1
	return layer + 1


func _apply_visibility_layers(modifier: String) -> void:
	_refresh_entity_layers_for_visibility(modifier)
	if modifier == VISIBILITY_NONE:
		return

	var layer := _visibility_layer()
	if modifier != VISIBILITY_SUDDEN:
		_set_static_entity_layer("JUDGMENT_LINE", layer)
	_set_measure_node_layer(layer)


func _set_static_entity_layer(id: String, layer: int) -> void:
	var node_path := "Entity_%s" % _safe_node_id(id)
	if not has_node(node_path):
		return
	var node: Variant = get_node(node_path)
	if node is CanvasItem:
		node.z_index = layer


func _refresh_entity_layers_for_visibility(modifier: String) -> void:
	for child: Node in get_children():
		if not child is CanvasItem or not child.has_meta("javaLayer"):
			continue
		child.z_index = _effective_entity_layer(int(child.get_meta("javaLayer")), modifier)


func _set_measure_node_layer(layer: int) -> void:
	for entry: Dictionary in _measure_entries:
		var node: Variant = entry.get("node")
		if node is CanvasItem:
			node.z_index = layer


func _metadata_layer_for_id(id: String) -> int:
	for entity: Dictionary in _metadata.get("entities", []):
		if str(entity.get("id", "")) == id:
			return int(entity.get("layer", 0))
	return 0


func _visibility_texture(width: int, height: int, modifier: String) -> Texture2D:
	var image: Image = Image.create(max(width, 1), max(height, 1), false, Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		var alpha := _visibility_alpha(modifier, float(y), float(image.get_height()))
		var color := Color(0.0, 0.0, 0.0, alpha)
		for x in range(image.get_width()):
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


func _visibility_alpha(modifier: String, y: float, height: float) -> float:
	var metadata_alpha := _visibility_alpha_from_metadata(modifier, y, height)
	if metadata_alpha >= 0.0:
		return metadata_alpha
	var split := height / 4.0
	if modifier == VISIBILITY_HIDDEN:
		if y < split * 1.9:
			return 0.0
		if y < split * 2.0:
			return (y - split * 1.9) / (split * 0.1)
		return 1.0
	if modifier == VISIBILITY_SUDDEN:
		if y < split * 1.9:
			return 1.0
		if y < split * 2.0:
			return 1.0 - (y - split * 1.9) / (split * 0.1)
		return 0.0
	if modifier == VISIBILITY_DARK:
		if y < split * 1.3:
			return 1.0
		if y < split * 1.5:
			return 1.0 - (y - split * 1.3) / (split * 0.2)
		if y < split * 2.5:
			return 0.0
		if y < split * 2.7:
			return (y - split * 2.5) / (split * 0.2)
		return 1.0
	return 0.0


func _visibility_alpha_from_metadata(modifier: String, y: float, height: float) -> float:
	var raw_masks: Variant = _metadata.get("visibilityMasks", {})
	if not raw_masks is Dictionary:
		return -1.0
	var raw_points: Variant = raw_masks.get(modifier, [])
	if not raw_points is Array or raw_points.is_empty():
		return -1.0
	var split: float = height / 4.0
	if split <= 0.0:
		return -1.0

	var position: float = y / split
	var has_previous := false
	var previous_at := 0.0
	var previous_alpha := 0.0
	for raw_point: Variant in raw_points:
		if not raw_point is Dictionary:
			continue
		var point_at: float = float(raw_point.get("at", 0.0))
		var point_alpha: float = clamp(float(raw_point.get("alpha", 0.0)), 0.0, 1.0)
		if position <= point_at:
			if not has_previous:
				return point_alpha
			if point_at <= previous_at:
				return point_alpha
			var blend: float = (position - previous_at) / (point_at - previous_at)
			return lerpf(previous_alpha, point_alpha, clamp(blend, 0.0, 1.0))
		previous_at = point_at
		previous_alpha = point_alpha
		has_previous = true
	return previous_alpha if has_previous else -1.0


func _position_click_node(node: Control, entity: Dictionary, lane_index: int) -> void:
	var lane := _lane_for_index(lane_index)
	if lane.is_empty():
		return
	var width: float = max(float(entity.get("width", 0.0)), 1.0)
	var height: float = max(float(entity.get("height", 0.0)), 1.0)
	node.position.x = float(lane.get("x", 0.0)) + float(lane.get("width", 0.0)) * 0.5 - width * 0.5
	node.position.y = float(_metadata.get("judgmentLine", 0.0)) - height * 0.5


func _position_longflare_node(node: Control, entity: Dictionary, lane_index: int, flare: Dictionary) -> void:
	var lane := _lane_for_index(lane_index)
	if lane.is_empty():
		return
	var width: float = max(float(entity.get("width", 0.0)), 1.0)
	node.position.x = float(lane.get("x", 0.0)) + float(lane.get("width", 0.0)) * 0.5 - width * 0.5
	var note_index := int(flare.get("noteIndex", -1))
	if note_index < 0 or note_index >= _note_entries.size():
		return
	var note_node: Variant = _note_entries[note_index].get("node")
	if note_node is Control:
		node.position.x = note_node.position.x + note_node.size.x * 0.5 - width * 0.5
		node.position.y = note_node.position.y


func _one_shot_animation_finished(entity: Dictionary, event: Dictionary, now_ms: float) -> bool:
	if _animation_loops(entity):
		return false
	var frames := _sprite_frames(entity)
	var frame_speed := float(entity.get("frameSpeed", 0.0))
	if frames.is_empty() or frame_speed <= 0.0:
		return false
	var duration_ms := float(frames.size()) / frame_speed
	return now_ms - float(event.get("startMs", 0.0)) >= duration_ms


func _animation_loops(entity: Dictionary) -> bool:
	var id := str(entity.get("id", ""))
	var fallback := id != "EFFECT_CLICK"
	return bool(entity.get("animationLoop", fallback))


func _clear_pressed_nodes() -> void:
	_clear_nodes(_pressed_nodes)
	_pressed_lane_nodes.clear()


func _clear_pressed_lane(lane: int) -> void:
	var raw_nodes: Variant = _pressed_lane_nodes.get(lane, [])
	var lane_nodes: Array[Node] = []
	if raw_nodes is Array:
		for raw_node: Variant in raw_nodes:
			if raw_node is Node:
				_pressed_nodes.erase(raw_node)
				lane_nodes.append(raw_node)
	_clear_nodes(lane_nodes)
	_pressed_lane_nodes.erase(lane)


func _clear_judgment_node() -> void:
	if _judgment_node == null or not is_instance_valid(_judgment_node):
		_judgment_node = null
		_current_judgment_sequence = -1
		return
	if _judgment_node.get_parent() == self:
		remove_child(_judgment_node)
	_judgment_node.free()
	_judgment_node = null
	_current_judgment_sequence = -1


func _clear_click_nodes() -> void:
	_clear_nodes(_click_nodes)
	_click_nodes_by_sequence.clear()


func _clear_click_node(sequence: int) -> void:
	var raw_node: Variant = _click_nodes_by_sequence.get(sequence)
	_click_nodes_by_sequence.erase(sequence)
	if not raw_node is Node:
		return
	_click_nodes.erase(raw_node)
	if not is_instance_valid(raw_node):
		return
	if raw_node.get_parent() == self:
		remove_child(raw_node)
	raw_node.free()


func _clear_pill_nodes() -> void:
	_clear_nodes(_pill_nodes)
	_pill_nodes_by_index.clear()


func _clear_pill_node(index: int) -> void:
	var raw_node: Variant = _pill_nodes_by_index.get(index)
	_pill_nodes_by_index.erase(index)
	if not raw_node is Node:
		return
	_pill_nodes.erase(raw_node)
	if not is_instance_valid(raw_node):
		return
	if raw_node.get_parent() == self:
		remove_child(raw_node)
	raw_node.free()


func _clear_longflare_nodes() -> void:
	_clear_nodes(_longflare_nodes)
	_longflare_nodes_by_lane.clear()


func _clear_longflare_node(lane: int) -> void:
	var raw_node: Variant = _longflare_nodes_by_lane.get(lane)
	_longflare_nodes_by_lane.erase(lane)
	if not raw_node is Node:
		return
	_longflare_nodes.erase(raw_node)
	if not is_instance_valid(raw_node):
		return
	if raw_node.get_parent() == self:
		remove_child(raw_node)
	raw_node.free()


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


func _register_bar_node(entity: Dictionary, node: Control) -> void:
	if str(entity.get("type", "")) != "bar":
		return
	var id := str(entity.get("id", ""))
	if id.is_empty():
		return
	_bar_nodes[id] = node
	node.set_meta("javaBarSlice", true)
	if node is TextureRect:
		_set_bar_base_texture_region(node)
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
	label.visible = not _has_sprite_frames(entity)

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
	_apply_entity_layer(label, entity)

	_hud_labels[id] = label
	_hud_counter_entities[id] = entity.duplicate(true)
	add_child(label)
	_register_hud_digit_container(entity)


func _is_hud_counter(entity: Dictionary) -> bool:
	var type := str(entity.get("type", ""))
	return (type == "numberCounter" or type == "comboCounter") and not str(entity.get("id", "")).is_empty()


func _set_hud_text(id: String, text: String) -> void:
	var display_text := _hud_text_with_show_digits(id, text)
	var label: Variant = _hud_labels.get(id)
	if label is Label:
		label.text = display_text
	_set_hud_digits(id, display_text)


func _hud_text_with_show_digits(id: String, text: String) -> String:
	if text.is_empty():
		return text
	var entity: Dictionary = _hud_counter_entities.get(id, {})
	if str(entity.get("type", "")) != "numberCounter":
		return text
	var show_digits := int(entity.get("showDigits", 1))
	if show_digits <= text.length():
		return text
	return "%s%s" % ["0".repeat(show_digits - text.length()), text]


func _set_combo_text(id: String, value: int, now_ms: float) -> void:
	var threshold := _combo_count_threshold(id)
	if value < threshold:
		_combo_counter_states[id] = {
			"value": value,
			"visibleUntilMs": -1.0,
			"currentY": _combo_base_y(id),
			"lastMoveMs": now_ms,
		}
		_set_hud_text(id, "")
		return

	var raw_state: Variant = _combo_counter_states.get(id, {})
	var state: Dictionary = {}
	if raw_state is Dictionary:
		state = raw_state.duplicate(true)

	if int(state.get("value", -1)) != value:
		state["value"] = value
		state["startMs"] = now_ms
		state["visibleUntilMs"] = now_ms + _combo_show_time_ms(id)
		state["currentY"] = _combo_base_y(id) + _combo_wobble_pixels(id)
		state["lastMoveMs"] = now_ms
	else:
		state = _move_combo_counter_like_java(id, state, now_ms)

	var visible_until_ms := float(state.get("visibleUntilMs", -1.0))
	if now_ms - visible_until_ms > 0.0:
		state["currentY"] = _combo_base_y(id)
		_combo_counter_states[id] = state
		_set_hud_text(id, "")
		return

	_combo_counter_states[id] = state
	_set_hud_text(id, _int_text(value - max(threshold - 1, 0)))


func _move_combo_counter_like_java(id: String, state: Dictionary, now_ms: float) -> Dictionary:
	var next_state := state.duplicate(true)
	var previous_ms := float(next_state.get("lastMoveMs", now_ms))
	var delta_ms: float = max(now_ms - previous_ms, 0.0)
	next_state["lastMoveMs"] = now_ms

	var base_y := _combo_base_y(id)
	var current_y := float(next_state.get("currentY", base_y))
	if current_y > base_y:
		next_state["currentY"] = current_y - delta_ms * _combo_wobble_speed(id)
	return next_state


func _register_hud_digit_container(entity: Dictionary) -> void:
	if not _has_sprite_frames(entity):
		return
	var id := str(entity.get("id", ""))
	var container := Control.new()
	container.name = "HudSprite_%s" % _safe_node_id(id)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.position = Vector2.ZERO
	container.size = custom_minimum_size
	_apply_entity_layer(container, entity)
	_hud_digit_entities[id] = {
		"entity": entity.duplicate(true),
		"container": container,
	}
	add_child(container)


func _has_sprite_frames(entity: Dictionary) -> bool:
	var frames: Variant = entity.get("spriteFrames", [])
	return frames is Array and not frames.is_empty()


func _set_hud_digits(id: String, text: String) -> void:
	var entry: Dictionary = _hud_digit_entities.get(id, {})
	if entry.is_empty():
		return
	var container: Variant = entry.get("container")
	if not container is Control:
		return

	var entity: Dictionary = entry.get("entity", {})
	var chars := text.split("")
	if text.is_empty():
		_clear_hud_digit_container(container)
		container.set_meta("hudText", "")
		return

	var is_combo_counter := str(entity.get("type", "")) == "comboCounter"
	if is_combo_counter and str(container.get_meta("hudText", "")) == text:
		if _update_combo_counter_digit_positions(container, entity, chars, _combo_current_y(id, entity)):
			_update_animation_frames_for_node(container, _last_update_time_ms)
			return

	_clear_hud_digit_container(container)
	container.set_meta("hudText", text)
	if str(entity.get("type", "")) == "comboCounter":
		_add_combo_counter_digits(container, entity, chars, _combo_current_y(id, entity))
	else:
		_add_number_counter_digits(container, entity, chars)


func _clear_hud_digit_container(container: Control) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.free()


func _add_number_counter_digits(container: Control, entity: Dictionary, chars: PackedStringArray) -> void:
	var tx := float(entity.get("x", 0.0))
	var y := float(entity.get("y", 0.0))
	var sequence := 0
	for i in range(chars.size() - 1, -1, -1):
		var frame := _digit_frame_for_char(entity, chars[i])
		if frame.is_empty():
			continue
		tx -= float(frame.get("textureWidth", entity.get("width", 1.0)))
		var digit := _digit_texture_rect(frame, "Digit_%03d" % sequence)
		digit.position = Vector2(tx, y)
		container.add_child(digit)
		sequence += 1


func _add_combo_counter_digits(container: Control, entity: Dictionary, chars: PackedStringArray, y: float) -> void:
	var frames: Array[Dictionary] = []
	var total_width := 0.0
	for value: String in chars:
		var frame := _digit_frame_for_char(entity, value)
		if frame.is_empty():
			continue
		frames.append(frame)
		total_width += float(frame.get("textureWidth", entity.get("width", 1.0)))

	var tx := float(entity.get("x", 0.0)) - total_width * 0.5
	for i in range(frames.size()):
		var frame := frames[i]
		var digit := _digit_texture_rect(frame, "Digit_%03d" % i)
		digit.position = Vector2(tx, y)
		container.add_child(digit)
		tx += float(frame.get("textureWidth", entity.get("width", 1.0)))
	_add_combo_title(container, entity)


func _update_combo_counter_digit_positions(container: Control, entity: Dictionary,
		chars: PackedStringArray, y: float) -> bool:
	var frames: Array[Dictionary] = []
	var total_width := 0.0
	for value: String in chars:
		var frame := _digit_frame_for_char(entity, value)
		if frame.is_empty():
			return false
		frames.append(frame)
		total_width += float(frame.get("textureWidth", entity.get("width", 1.0)))

	var tx := float(entity.get("x", 0.0)) - total_width * 0.5
	for i in range(frames.size()):
		var digit_node: Variant = container.get_node_or_null("Digit_%03d" % i)
		if not digit_node is Control:
			return false
		digit_node.position = Vector2(tx, y)
		tx += float(frames[i].get("textureWidth", entity.get("width", 1.0)))

	var title_node: Variant = container.get_node_or_null("Title")
	if title_node is Control:
		_position_combo_title(title_node, entity)
	return true


func _add_combo_title(container: Control, entity: Dictionary) -> void:
	var title_frame := _combo_title_frame(entity)
	if title_frame.is_empty():
		return
	var title := _digit_texture_rect(title_frame, "Title")
	title.set_meta("spriteFrames", _combo_title_frames(entity))
	title.set_meta("frameSpeed", float(entity.get("titleFrameSpeed", 0.0)))
	_position_combo_title(title, entity)
	_update_animation_frames_for_node(title, _last_update_time_ms)
	container.add_child(title)


func _position_combo_title(title: Control, entity: Dictionary) -> void:
	title.position = Vector2(
			float(entity.get("x", 0.0)) - title.size.x * 0.5,
			float(entity.get("y", 0.0)) - max(float(entity.get("height", 1.0)), 1.0))


func _combo_title_frame(entity: Dictionary) -> Dictionary:
	var frames := _combo_title_frames(entity)
	if frames.is_empty():
		return {}
	return frames[0].duplicate(true)


func _combo_title_frames(entity: Dictionary) -> Array[Dictionary]:
	var frames: Array[Dictionary] = []
	var raw_frames: Variant = entity.get("titleSpriteFrames", [])
	if raw_frames is Array:
		for raw_frame: Variant in raw_frames:
			if raw_frame is Dictionary:
				frames.append(raw_frame.duplicate(true))
	return frames


func _combo_base_y(id: String) -> float:
	var entry: Dictionary = _hud_digit_entities.get(id, {})
	var entity: Dictionary = entry.get("entity", {})
	return float(entity.get("y", 0.0))


func _combo_current_y(id: String, entity: Dictionary) -> float:
	var raw_state: Variant = _combo_counter_states.get(id, {})
	if raw_state is Dictionary:
		return float(raw_state.get("currentY", entity.get("y", 0.0)))
	return float(entity.get("y", 0.0))


func _combo_count_threshold(id: String) -> int:
	var entity := _combo_entity(id)
	var fallback := 2 if id == "COMBO_COUNTER" else 1
	return max(int(entity.get("countThreshold", fallback)), 1)


func _combo_show_time_ms(id: String) -> float:
	var entity := _combo_entity(id)
	return max(float(entity.get("showTimeMs", COMBO_SHOW_TIME_MS)), 0.0)


func _combo_wobble_pixels(id: String) -> float:
	var entity := _combo_entity(id)
	return max(float(entity.get("wobblePixels", COMBO_WOBBLE_PIXELS)), 0.0)


func _combo_wobble_speed(id: String) -> float:
	var entity := _combo_entity(id)
	return max(float(entity.get("wobbleSpeed", COMBO_WOBBLE_SPEED)), 0.0)


func _combo_entity(id: String) -> Dictionary:
	var entity: Variant = _hud_counter_entities.get(id, {})
	if entity is Dictionary:
		return entity
	return {}


func _judgment_show_time_ms(entity: Dictionary) -> float:
	return max(float(entity.get("showTimeMs", JUDGMENT_SHOW_TIME_MS)), 0.0)


func _judgment_scale_ramp_ms(entity: Dictionary) -> float:
	return max(float(entity.get("scaleRampMs", JUDGMENT_SCALE_RAMP_MS)), 0.0)


func _judgment_initial_scale(entity: Dictionary) -> float:
	return clampf(float(entity.get("initialScale", JUDGMENT_INITIAL_SCALE)), 0.0, 1.0)


func _judgment_scale_ramp_ms_from_node(node: Control) -> float:
	return max(float(node.get_meta("judgmentScaleRampMs", JUDGMENT_SCALE_RAMP_MS)), 0.0)


func _judgment_initial_scale_from_node(node: Control) -> float:
	return clampf(float(node.get_meta("judgmentInitialScale", JUDGMENT_INITIAL_SCALE)), 0.0, 1.0)


func _digit_frame_for_char(entity: Dictionary, value: String) -> Dictionary:
	if value.length() != 1 or value < "0" or value > "9":
		return {}
	var frames: Variant = entity.get("spriteFrames", [])
	if not frames is Array:
		return {}
	var index := int(value)
	if index < 0 or index >= frames.size():
		return {}
	var frame: Variant = frames[index]
	if not frame is Dictionary:
		return {}
	return frame.duplicate(true)


func _digit_texture_rect(frame: Dictionary, node_name: String) -> TextureRect:
	var digit := TextureRect.new()
	digit.name = node_name
	digit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	digit.texture = _texture_for_entity_part(frame, "")
	digit.stretch_mode = TextureRect.STRETCH_SCALE
	_configure_java_texture_node(digit, frame)
	digit.size = Vector2(
			max(float(frame.get("textureWidth", 1.0)), 1.0),
			max(float(frame.get("textureHeight", 1.0)), 1.0))
	return digit


func _configure_java_texture_node(node: TextureRect, entity: Dictionary) -> void:
	node.ignore_texture_size = true
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if _uses_java_premult_material(entity):
		node.material = _java_texture_canvas_material()


func _uses_java_premult_material(_entity: Dictionary) -> bool:
	# Java configures GL_ONE / GL_ONE_MINUS_SRC_ALPHA globally for textured sprites.
	return true


func _java_texture_canvas_material() -> CanvasItemMaterial:
	if _java_texture_material == null:
		_java_texture_material = CanvasItemMaterial.new()
		_java_texture_material.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	return _java_texture_material


func _apply_entity_layer(node: CanvasItem, entity: Dictionary) -> void:
	var layer := int(entity.get("layer", 0))
	node.set_meta("javaLayer", layer)
	node.z_index = _effective_entity_layer(layer)
	node.z_as_relative = false


func _effective_entity_layer(layer: int, modifier: String = "") -> int:
	var active_modifier := modifier
	if active_modifier.is_empty():
		active_modifier = _normalized_visibility_modifier(_chart.get("visibilityModifier", VISIBILITY_NONE))
	if active_modifier == VISIBILITY_NONE:
		return layer
	var visibility_layer := _visibility_layer()
	if layer >= visibility_layer:
		return layer + 1
	return layer


func _set_bar_fill(id: String, value: float, limit: float) -> void:
	var node: Variant = _bar_nodes.get(id)
	var rect: Dictionary = _bar_rects.get(id, {})
	if not node is Control or rect.is_empty():
		return

	var base_position: Vector2 = rect.get("position", Vector2.ZERO)
	var base_size: Vector2 = rect.get("size", Vector2.ZERO)
	var ratio := 0.0
	if limit > 0.0:
		ratio = clamp(value / limit, 0.0, 1.0)

	node.position = base_position
	node.size = base_size
	var region := _bar_base_texture_region(node)
	var has_region := region.size.x > 0.0 and region.size.y > 0.0

	match str(rect.get("fillDirection", "left_to_right")):
		"right_to_left":
			var slice_width := _bar_slice_screen_size(base_size.x, region.size.x, ratio, true)
			node.size.x = slice_width
			node.position.x = base_position.x + base_size.x - node.size.x
			if has_region:
				var texture_slice_width := _java_slice_size(region.size.x, ratio, true)
				if ratio > 0.0:
					region.position.x = region.position.x + region.size.x - texture_slice_width
				region.size.x = texture_slice_width
		"up_to_down":
			var slice_height := _bar_slice_screen_size(base_size.y, region.size.y, ratio, true)
			node.size.y = slice_height
			node.position.y = base_position.y + base_size.y - node.size.y
			if has_region:
				var texture_slice_height := _java_slice_size(region.size.y, ratio, true)
				if ratio > 0.0:
					region.position.y = region.position.y + region.size.y - texture_slice_height
				region.size.y = texture_slice_height
		"down_to_up":
			node.size.y = _bar_slice_screen_size(base_size.y, region.size.y, ratio, false)
			if has_region:
				region.size.y = _java_slice_size(region.size.y, ratio, false)
		_:
			node.size.x = _bar_slice_screen_size(base_size.x, region.size.x, ratio, false)
			if has_region:
				region.size.x = _java_slice_size(region.size.x, ratio, false)

	if has_region:
		_apply_bar_texture_region(node, region)
	node.visible = node.size.x > 0.0 and node.size.y > 0.0


func _set_bar_base_texture_region(node: TextureRect) -> void:
	if node.texture is AtlasTexture:
		var atlas: AtlasTexture = node.texture
		node.set_meta("barBaseTextureRegion", atlas.region)


func _bar_base_texture_region(node: Control) -> Rect2:
	if node.has_meta("barBaseTextureRegion"):
		var raw_region: Variant = node.get_meta("barBaseTextureRegion")
		if raw_region is Rect2:
			return raw_region
	return Rect2()


func _bar_slice_screen_size(base_screen_size: float, base_texture_size: float, ratio: float, negative: bool) -> float:
	if base_texture_size <= 0.0:
		return _java_slice_size(base_screen_size, ratio, negative)
	return _java_slice_size(base_texture_size, ratio, negative) * base_screen_size / base_texture_size


func _java_slice_size(base_size: float, ratio: float, negative: bool) -> float:
	var signed_size := base_size * ratio
	if negative:
		signed_size = -signed_size
	return absf(float(floor(signed_size + 0.5)))


func _apply_bar_texture_region(node: Control, region: Rect2) -> void:
	if not node is TextureRect:
		return
	var texture_node: TextureRect = node
	if not texture_node.texture is AtlasTexture:
		return
	var atlas: AtlasTexture = texture_node.texture
	var sliced := AtlasTexture.new()
	sliced.atlas = atlas.atlas
	sliced.region = region
	texture_node.texture = sliced


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
