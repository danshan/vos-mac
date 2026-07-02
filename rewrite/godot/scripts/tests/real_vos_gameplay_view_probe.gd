extends SceneTree

const GameplayRuntime = preload("res://scripts/gameplay_runtime.gd")
const GameplayView = preload("res://scripts/gameplay_view.gd")


func _init() -> void:
	var chart_path := OS.get_environment("OPEN2JAM_GAMEPLAY_JSON")
	var metadata_path := OS.get_environment("OPEN2JAM_RENDER_METADATA_JSON")
	var manifest_path := OS.get_environment("OPEN2JAM_AUDIO_MANIFEST")
	if chart_path.is_empty() or metadata_path.is_empty():
		push_error("Set OPEN2JAM_GAMEPLAY_JSON and OPEN2JAM_RENDER_METADATA_JSON.")
		quit(1)
		return

	var chart := _load_json(chart_path)
	var metadata := _load_json(metadata_path)
	var manifest := _load_json(manifest_path) if not manifest_path.is_empty() else {}
	if chart.is_empty() or metadata.is_empty():
		push_error("Expected real VOS chart and metadata to load.")
		quit(1)
		return

	var view = GameplayView.new()
	view.name = "GameplayView"
	get_root().add_child(view)
	if not view.load_metadata(metadata):
		push_error("Expected metadata to load.")
		quit(1)
		return
	if not view.load_chart(chart):
		push_error("Expected chart to load.")
		quit(1)
		return

	print("real_vos_gameplay_view_probe:notes_in_chart=%d" % _array_size(chart.get("notes", [])))
	print("real_vos_gameplay_view_probe:note_nodes=%d" % _count_note_nodes(view))
	_dump_view_times(view, [0.0, 1000.0, 2000.0, 3000.0, 3300.0, 3388.0, 3600.0, 4108.0, 5000.0])

	if not manifest.is_empty():
		_dump_runtime_times(chart, manifest, view, [0.0, 1000.0, 2000.0, 3000.0, 3300.0, 3388.0, 3600.0, 4108.0, 5000.0])

	view.free()
	quit(0)


func _load_json(path: String) -> Dictionary:
	if path.is_empty():
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


func _dump_view_times(view: Node, times: Array) -> void:
	for raw_time: Variant in times:
		var now_ms := float(raw_time)
		view.update_time(now_ms)
		_dump_note_window("view_time", now_ms, view)


func _dump_runtime_times(chart: Dictionary, manifest: Dictionary, view: Node, times: Array) -> void:
	var runtime = GameplayRuntime.new()
	runtime.name = "GameplayRuntime"
	runtime.set_process(false)
	get_root().add_child(runtime)
	if not runtime.start(chart, manifest):
		print("real_vos_gameplay_view_probe:runtime_start=false")
		runtime.free()
		return

	for raw_time: Variant in times:
		var now_ms := float(raw_time)
		runtime.advance_to(now_ms)
		var state: Dictionary = runtime.hud_state()
		var display_time_ms := float(state.get("displayTimeMs", now_ms))
		view.update_frame(display_time_ms, state)
		print("real_vos_gameplay_view_probe:runtime elapsed=%d game=%d display=%d hidden=%d" % [
			int(state.get("elapsedMs", -1)),
			int(state.get("gameTimeMs", -1)),
			int(state.get("displayTimeMs", -1)),
			_array_size(state.get("hiddenNotes", [])),
		])
		_dump_note_window("runtime_time", display_time_ms, view)

	runtime.stop()
	runtime.free()


func _dump_note_window(label: String, now_ms: float, view: Node) -> void:
	var onscreen := 0
	var visible_count := 0
	for index in range(_count_note_nodes(view)):
		var node := _note_node(view, index)
		if node == null:
			continue
		if node.visible:
			visible_count += 1
		if _node_onscreen(node):
			onscreen += 1
	var first := _note_node(view, 0)
	var second := _note_node(view, 1)
	print("real_vos_gameplay_view_probe:%s now=%.1f visible=%d onscreen=%d first=%s second=%s" % [
		label,
		now_ms,
		visible_count,
		onscreen,
		_note_description(first),
		_note_description(second),
	])


func _count_note_nodes(view: Node) -> int:
	var count := 0
	while _note_node(view, count) != null:
		count += 1
	return count


func _note_node(view: Node, index: int) -> Control:
	var node := view.get_node_or_null("Note_%03d" % index)
	if node is Control:
		return node
	return null


func _node_onscreen(node: Control) -> bool:
	return node.visible and node.position.y + node.size.y >= 0.0 and node.position.y <= 600.0


func _note_description(node: Control) -> String:
	if node == null:
		return "null"
	return "x=%.1f,y=%.1f,w=%.1f,h=%.1f,visible=%s,z=%d" % [
		node.position.x,
		node.position.y,
		node.size.x,
		node.size.y,
		str(node.visible),
		node.z_index,
	]


func _array_size(value: Variant) -> int:
	if value is Array:
		return value.size()
	return 0
