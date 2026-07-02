extends SceneTree

const AudioManifestLoader = preload("res://scripts/audio_manifest_loader.gd")
const AudioPlayerPool = preload("res://scripts/audio_player_pool.gd")
const ExporterClient = preload("res://scripts/exporter_client.gd")
const GameplayLoader = preload("res://scripts/gameplay_loader.gd")

const DEMO_CHART := "/Users/honghao.shan/Music/demo/o2ma101.ojn"
const DEMO_SAMPLE_BANK := "/Users/honghao.shan/Music/demo/o2ma101.ojm"


func _init() -> void:
	if not FileAccess.file_exists(DEMO_CHART) or not FileAccess.file_exists(DEMO_SAMPLE_BANK):
		print("Skipping real OJN selected bundle loader test; demo OJN/OJM files are not available.")
		quit(0)
		return

	var repo_root := ProjectSettings.globalize_path("res://../..")
	var jar_path := _join_path(repo_root, "target/open2jam-0.1.2.jar")
	if not FileAccess.file_exists(jar_path):
		print("Skipping real OJN selected bundle loader test; packaged jar is not available.")
		quit(0)
		return

	var out_dir := ProjectSettings.globalize_path("user://real-ojn-hard-selected-export-%d" % Time.get_unix_time_from_system())
	var exporter = ExporterClient.new()
	if not _expect_bool(exporter.configure_default(repo_root), true, "default exporter configuration"):
		return

	var export_result: Dictionary = exporter.export_selected(DEMO_CHART, out_dir, 2)
	if not _expect_bool(bool(export_result.get("ok", false)), true, "selected OJN export"):
		return

	var gameplay_loader = GameplayLoader.new()
	var chart: Dictionary = gameplay_loader.load_from_file(_join_path(out_dir, "gameplay.json"))
	if not _expect_bool(chart.is_empty(), false, "OJN gameplay load"):
		return
	if not _expect_string(str(chart.get("format", "")), "OJN", "OJN gameplay format"):
		return
	var notes: Array = chart.get("notes", [])
	if not _expect_bool(notes.size() > 0, true, "OJN gameplay notes"):
		return
	if not _expect_bool(notes.size() > 900, true, "OJN hard gameplay notes"):
		return
	if not _expect_bool(int(notes[0].get("sampleId", 0)) > 0, true, "OJN shifted note sample id"):
		return

	var audio_loader = AudioManifestLoader.new()
	var manifest: Dictionary = audio_loader.load_from_file(_join_path(out_dir, "audio-manifest.json"))
	if not _expect_bool(manifest.is_empty(), false, "OJN audio manifest load"):
		return
	if not _expect_string(str(manifest.get("format", "")), "OJN", "OJN audio format"):
		return

	var pool = AudioPlayerPool.new()
	get_root().add_child(pool)
	if not _expect_bool(pool.load_manifest(manifest), true, "OJN audio pool load"):
		return
	if not _expect_bool(pool.has_sample(1), true, "OJN shifted sample zero asset"):
		return
	if not _expect_bool(pool.has_sample(1001), true, "OJN shifted autoplay sample asset"):
		return

	pool.free()
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


func _expect_string(actual: String, expected: String, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true
