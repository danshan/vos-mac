extends SceneTree

const AudioManifestLoader = preload("res://scripts/audio_manifest_loader.gd")
const ExporterClient = preload("res://scripts/exporter_client.gd")
const GameplayLoader = preload("res://scripts/gameplay_loader.gd")
const GameplayRuntime = preload("res://scripts/gameplay_runtime.gd")
const GameplayView = preload("res://scripts/gameplay_view.gd")
const RenderEntityModel = preload("res://scripts/render_entity_model.gd")

const DEMO_CHART := "/Users/honghao.shan/Music/demo/o2ma101.ojn"
const DEMO_SAMPLE_BANK := "/Users/honghao.shan/Music/demo/o2ma101.ojm"


func _init() -> void:
	if not FileAccess.file_exists(DEMO_CHART) or not FileAccess.file_exists(DEMO_SAMPLE_BANK):
		print("Skipping real OJN gameplay runtime smoke test; demo OJN/OJM files are not available.")
		quit(0)
		return

	var repo_root := ProjectSettings.globalize_path("res://../..")
	var jar_path := _join_path(repo_root, "target/open2jam-0.1.2.jar")
	if not FileAccess.file_exists(jar_path):
		print("Skipping real OJN gameplay runtime smoke test; packaged jar is not available.")
		quit(0)
		return

	var out_dir := ProjectSettings.globalize_path("user://real-ojn-runtime-export-%d" % Time.get_unix_time_from_system())
	var exporter = ExporterClient.new()
	if not _expect_bool(exporter.configure_default(repo_root), true, "default exporter configuration"):
		return

	var export_result: Dictionary = exporter.export_selected(DEMO_CHART, out_dir, 2)
	if not _expect_bool(bool(export_result.get("ok", false)), true,
			"selected OJN export exit=%s outputTail=%s" % [
				str(export_result.get("exit_code", "")),
				_output_tail(export_result.get("output", [])),
			]):
		return

	var gameplay_loader = GameplayLoader.new()
	var chart: Dictionary = gameplay_loader.load_from_file(_join_path(out_dir, "gameplay.json"))
	if not _expect_bool(chart.is_empty(), false, "OJN gameplay load"):
		return
	if not _expect_string(str(chart.get("format", "")), "OJN", "OJN gameplay format"):
		return
	if not _expect_int(int(chart.get("keys", 0)), 7, "OJN key count"):
		return

	var audio_loader = AudioManifestLoader.new()
	var manifest: Dictionary = audio_loader.load_from_file(_join_path(out_dir, "audio-manifest.json"))
	if not _expect_bool(manifest.is_empty(), false, "OJN audio manifest load"):
		return
	if not _expect_string(str(manifest.get("format", "")), "OJN", "OJN audio format"):
		return

	var metadata_loader = RenderEntityModel.new()
	var metadata: Dictionary = metadata_loader.load_from_file(_join_path(out_dir, "render-metadata.json"))
	if not _expect_bool(metadata.is_empty(), false, "OJN render metadata load"):
		return

	var runtime = GameplayRuntime.new()
	get_root().add_child(runtime)
	if not _expect_bool(runtime.start(chart, manifest), true, "OJN runtime start"):
		return
	runtime.advance_to(500.0)
	var state: Dictionary = runtime.hud_state()
	if not _expect_bool(runtime.is_running(), true, "OJN runtime running"):
		return
	if not _expect_int(int(state.get("gameTimeMs", -1)), 500, "OJN runtime game time"):
		return

	var view = GameplayView.new()
	get_root().add_child(view)
	if not _expect_bool(view.load_metadata(metadata), true, "OJN view metadata"):
		return
	if not _expect_bool(view.load_chart(chart), true, "OJN view chart"):
		return
	view.update_frame(float(state.get("displayTimeMs", 500.0)), state)
	if not _expect_bool(view.get_node_or_null("Note_000") != null, true, "OJN view note node"):
		return
	if not _expect_bool(view.get_node_or_null("HudSprite_SCORE_COUNTER") != null, true, "OJN view score HUD"):
		return

	view.free()
	runtime.free()
	quit(0)


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
