extends SceneTree

const AudioManifestLoader = preload("res://scripts/audio_manifest_loader.gd")
const ExporterClient = preload("res://scripts/exporter_client.gd")
const GameplayLoader = preload("res://scripts/gameplay_loader.gd")
const GameplayRuntime = preload("res://scripts/gameplay_runtime.gd")
const GameplayView = preload("res://scripts/gameplay_view.gd")
const RenderEntityModel = preload("res://scripts/render_entity_model.gd")

const DEMO_CHART := "/Users/honghao.shan/Music/demo/1187083 Jay Chou - Nocturne.osz"


func _init() -> void:
	_stage("start")
	if not FileAccess.file_exists(DEMO_CHART):
		print("Skipping real OSU gameplay runtime smoke test; demo OSZ file is not available.")
		quit(0)
		return

	var repo_root := ProjectSettings.globalize_path("res://../..")
	var jar_path := _join_path(repo_root, "target/open2jam-0.1.2.jar")
	if not FileAccess.file_exists(jar_path):
		print("Skipping real OSU gameplay runtime smoke test; packaged jar is not available.")
		quit(0)
		return

	var out_dir := ProjectSettings.globalize_path("user://real-osu-runtime-export-%d" % Time.get_unix_time_from_system())
	var exporter = ExporterClient.new()
	if not _expect_bool(exporter.configure_default(repo_root), true, "default exporter configuration"):
		return

	_stage("export_selected")
	var export_result: Dictionary = exporter.export_selected(DEMO_CHART, out_dir)
	if not _expect_bool(bool(export_result.get("ok", false)), true,
			"selected OSU export exit=%s outputTail=%s" % [
				str(export_result.get("exit_code", "")),
				_output_tail(export_result.get("output", [])),
			]):
		return
	_stage("export_selected_done")

	var gameplay_loader = GameplayLoader.new()
	var chart: Dictionary = gameplay_loader.load_from_file(_join_path(out_dir, "gameplay.json"))
	if not _expect_bool(chart.is_empty(), false, "OSU gameplay load"):
		return
	if not _expect_string(str(chart.get("format", "")), "OSU", "OSU gameplay format"):
		return
	if not _expect_int(int(chart.get("keys", 0)), 7, "OSU key count"):
		return
	_stage("gameplay_loaded")

	var audio_loader = AudioManifestLoader.new()
	var manifest: Dictionary = audio_loader.load_from_file(_join_path(out_dir, "audio-manifest.json"))
	if not _expect_bool(manifest.is_empty(), false, "OSU audio manifest load"):
		return
	if not _expect_string(str(manifest.get("format", "")), "OSU", "OSU audio format"):
		return
	_stage("audio_loaded")

	var metadata_loader = RenderEntityModel.new()
	var metadata: Dictionary = metadata_loader.load_from_file(_join_path(out_dir, "render-metadata.json"))
	if not _expect_bool(metadata.is_empty(), false, "OSU render metadata load"):
		return
	_stage("metadata_loaded")

	var runtime = GameplayRuntime.new()
	get_root().add_child(runtime)
	if not _expect_bool(runtime.start(chart, manifest), true, "OSU runtime start"):
		return
	_stage("runtime_started")
	runtime.advance_to(500.0)
	var state: Dictionary = runtime.hud_state()
	if not _expect_bool(runtime.is_running(), true, "OSU runtime running"):
		return
	if not _expect_int(int(state.get("gameTimeMs", -1)), 500, "OSU runtime game time"):
		return
	_stage("runtime_advanced")

	var view = GameplayView.new()
	get_root().add_child(view)
	if not _expect_bool(view.load_metadata(metadata), true, "OSU view metadata"):
		return
	_stage("view_metadata_loaded")
	var view_chart := _view_smoke_chart(chart)
	if not _expect_bool(view.load_chart(view_chart), true, "OSU view chart"):
		return
	_stage("view_chart_loaded")
	view.update_frame(float(state.get("displayTimeMs", 500.0)), state)
	if not _expect_bool(view.get_node_or_null("Note_000") != null, true, "OSU view note node"):
		return
	if not _expect_bool(view.get_node_or_null("HudSprite_SCORE_COUNTER") != null, true, "OSU view score HUD"):
		return
	_stage("view_updated")

	runtime.stop()
	view.free()
	runtime.free()
	_stage("done")
	quit(0)


func _stage(label: String) -> void:
	print("real_osu_gameplay_runtime_smoke_test:%s" % label)


func _view_smoke_chart(chart: Dictionary) -> Dictionary:
	var view_chart := chart.duplicate(true)
	view_chart["notes"] = _first_dictionaries(chart.get("notes", []), 48)
	view_chart["measures"] = _first_dictionaries(chart.get("measures", []), 16)
	view_chart["autoPlayEvents"] = _first_dictionaries(chart.get("autoPlayEvents", []), 16)
	view_chart["bgaEvents"] = _first_dictionaries(chart.get("bgaEvents", []), 16)
	return view_chart


func _first_dictionaries(value: Variant, limit: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not value is Array:
		return result
	for item: Variant in value:
		if result.size() >= limit:
			break
		if item is Dictionary:
			result.append((item as Dictionary).duplicate(true))
	return result


func _join_path(directory: String, file_name: String) -> String:
	if directory.ends_with("/") or directory.ends_with("\\"):
		return "%s%s" % [directory, file_name]
	return "%s/%s" % [directory, file_name]


func _expect_bool(actual: bool, expected: bool, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true


func _output_tail(output: Variant) -> String:
	if not output is Array or output.is_empty():
		return "[]"
	var text := str(output[output.size() - 1])
	var lines := text.split("\n", false)
	var start_index: int = max(lines.size() - 8, 0)
	var tail_lines: Array[String] = []
	for i in range(start_index, lines.size()):
		tail_lines.append(lines[i])
	return "\\n".join(tail_lines)


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
