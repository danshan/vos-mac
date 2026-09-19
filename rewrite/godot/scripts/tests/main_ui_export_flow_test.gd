extends SceneTree

const AppState = preload("res://scripts/app_state.gd")
const MainUi = preload("res://scripts/main_ui.gd")


class ManualExportJob:
	extends RefCounted

	var completed: bool = false
	var result: Dictionary = {}

	func is_done() -> bool:
		return completed

	func take_result() -> Dictionary:
		return result


class AsyncFakeExporter:
	extends RefCounted

	var calls: Array[Dictionary] = []
	var job := ManualExportJob.new()

	func export_selected_async(source_path: String, out_dir: String, chart_index: int = -1) -> Variant:
		calls.append({
			"sourcePath": source_path,
			"outDir": out_dir,
			"chartIndex": chart_index,
		})
		return job

	func complete_selected_export() -> void:
		var out_dir := str(calls[0].get("outDir", ""))
		DirAccess.make_dir_recursive_absolute(out_dir)
		_write_file("%s/gameplay.json" % out_dir, FileAccess.get_file_as_string("res://test/fixtures/gameplay.json"))
		_write_file("%s/audio-manifest.json" % out_dir, FileAccess.get_file_as_string("res://test/fixtures/audio-manifest.json"))
		_write_file("%s/render-metadata.json" % out_dir, FileAccess.get_file_as_string("res://test/fixtures/render-metadata.json"))
		job.result = {"ok": true, "exit_code": 0}
		job.completed = true

	func write_pending_audio_samples(count: int) -> void:
		var out_dir := str(calls[0].get("outDir", ""))
		var audio_dir := "%s/audio" % out_dir
		DirAccess.make_dir_recursive_absolute(audio_dir)
		for i in range(count):
			_write_file("%s/sample-%d.wav" % [audio_dir, i + 1], "RIFF")

	func _write_file(path: String, content: String) -> void:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(content)


class FakeExporter:
	extends RefCounted

	var calls: Array[Dictionary] = []

	func export_selected(source_path: String, out_dir: String, chart_index: int = -1) -> Dictionary:
		calls.append({
			"sourcePath": source_path,
			"outDir": out_dir,
			"chartIndex": chart_index,
		})
		DirAccess.make_dir_recursive_absolute(out_dir)
		_write_file("%s/gameplay.json" % out_dir, FileAccess.get_file_as_string("res://test/fixtures/gameplay.json"))
		_write_file("%s/audio-manifest.json" % out_dir, FileAccess.get_file_as_string("res://test/fixtures/audio-manifest.json"))
		_write_file("%s/render-metadata.json" % out_dir, _render_metadata_with_status_templates())
		return {"ok": true, "exit_code": 0}

	func _write_file(path: String, content: String) -> void:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(content)

	func _render_metadata_with_status_templates() -> String:
		var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://test/fixtures/render-metadata.json"))
		metadata["statusTextTemplates"] = {
			"speed": "From metadata {speedType} {speedMultiplier}",
			"measure": "Metadata measure {measure}",
			"gameSpeed": "Metadata pitch {gameSpeedPitch}",
			"speedTypes": {
				"HiSpeed": "HI",
				"xRSpeed": "XR",
				"RegulSpeed": "REGUL",
				"WSpeed": "W",
			},
		}
		return JSON.stringify(metadata)


func _init() -> void:
	if not _test_async_export_starts_before_min_loading_delay():
		return
	if not _test_async_export_keeps_loading_until_job_completes():
		return
	if not _test_existing_selected_bundle_skips_export():
		return
	if not _test_cached_large_bundle_preloads_audio_before_gameplay():
		return

	var settings_path := "user://main-ui-export-flow-test.cfg"
	_remove_settings_file(settings_path)
	_remove_path("user://exports/vos_export-flow")
	var exporter = FakeExporter.new()
	var ui = MainUi.new()
	ui.set_settings_path(settings_path)
	ui.set_exporter_client(exporter)
	ui.build()
	ui._settings_store.set_speed_type("RegulSpeed")
	ui._settings_store.set_speed_multiplier(2.0)
	ui.set_song_entries([
		{
			"id": "vos:export-flow",
			"title": "Canon in D",
			"artist": "Pachelbel",
			"level": 7,
			"sourcePath": "charts/canon.vos",
			"chartIndex": 2,
		},
	])

	ui.get_node("Content/Menu/StartButton").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.SONG_SELECT, "song select state"):
		return

	ui.get_node("Content/SongSelectScroll/SongList/Song_vos_export-flow").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.LOADING, "loading state before export gameplay"):
		return
	if not _expect_bool(ui.has_node("Content/LoadingLayer/LoadingImage"), true, "loading image before export gameplay"):
		return
	ui._process(0.3)
	if not _expect_string(ui.current_state(), AppState.GAMEPLAY, "gameplay state"):
		return
	if not _expect_bool(ui.has_node("GameplayRuntime"), true, "runtime after export"):
		return
	if not _expect_bool(ui.has_node("Content/GameplayArea/GameplayView/Note_000"), true, "note after export"):
		return
	var runtime = ui.get_node("GameplayRuntime")
	var status_texts: Array = runtime.hud_state().get("statusTexts", [])
	if not _expect_string(str(status_texts[0]), "From metadata REGUL 2.0", "runtime status template from render metadata"):
		return
	if not _expect_int(exporter.calls.size(), 1, "export call count"):
		return
	if not _expect_string(exporter.calls[0].get("sourcePath", ""), "charts/canon.vos", "export source path"):
		return
	if not _expect_int(int(exporter.calls[0].get("chartIndex", -1)), 2, "export chart index"):
		return

	ui.free()
	quit(0)


func _test_async_export_starts_before_min_loading_delay() -> bool:
	var settings_path := "user://main-ui-async-export-starts-before-delay-test.cfg"
	_remove_settings_file(settings_path)
	_remove_path("user://exports/vos_async-export-starts-before-delay")
	var exporter = AsyncFakeExporter.new()
	var ui = MainUi.new()
	ui.set_settings_path(settings_path)
	ui.set_exporter_client(exporter)
	ui.build()
	ui.set_song_entries([
		{
			"id": "vos:async-export-starts-before-delay",
			"title": "Async Start Canon",
			"artist": "Pachelbel",
			"level": 7,
			"sourcePath": "charts/async-start-canon.vos",
			"chartIndex": 4,
		},
	])

	ui.get_node("Content/Menu/StartButton").emit_signal("pressed")
	ui.get_node("Content/SongSelectScroll/SongList/Song_vos_async-export-starts-before-delay").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.LOADING, "async early loading state"):
		return false
	ui._process(0.016)
	if not _expect_int(exporter.calls.size(), 1, "async export starts during first loading frame"):
		return false
	if not _expect_string(ui.current_state(), AppState.LOADING, "async early state waits for min loading time"):
		return false

	exporter.complete_selected_export()
	ui._process(0.016)
	if not _expect_string(ui.current_state(), AppState.LOADING, "async completed export still waits for min loading time"):
		return false
	ui._process(0.3)
	if not _expect_string(ui.current_state(), AppState.GAMEPLAY, "async early export gameplay after min loading time"):
		return false
	if not _expect_bool(ui.has_node("GameplayRuntime"), true, "async early export runtime"):
		return false

	ui.free()
	return true


func _test_async_export_keeps_loading_until_job_completes() -> bool:
	var settings_path := "user://main-ui-async-export-flow-test.cfg"
	_remove_settings_file(settings_path)
	_remove_path("user://exports/vos_async-export-flow")
	var exporter = AsyncFakeExporter.new()
	var ui = MainUi.new()
	ui.set_settings_path(settings_path)
	ui.set_exporter_client(exporter)
	ui.build()
	ui.set_song_entries([
		{
			"id": "vos:async-export-flow",
			"title": "Async Canon",
			"artist": "Pachelbel",
			"level": 7,
			"sourcePath": "charts/async-canon.vos",
			"chartIndex": 3,
		},
	])

	ui.get_node("Content/Menu/StartButton").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.SONG_SELECT, "async song select state"):
		return false
	var song_button := ui.get_node("Content/SongSelectScroll/SongList/Song_vos_async-export-flow")
	song_button.emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.LOADING, "async loading state before export"):
		return false
	ui._process(0.3)
	if not _expect_string(ui.current_state(), AppState.LOADING, "async export keeps loading state"):
		return false
	if not _expect_bool(ui.has_node("Content/LoadingLayer/LoadingImage"), true, "async export keeps loading image"):
		return false
	if not _expect_bool(ui.has_node("Content/LoadingLayer/LoadingStatus"), true, "async export loading status"):
		return false
	var loading_status: Label = ui.get_node("Content/LoadingLayer/LoadingStatus")
	if not _expect_bool(loading_status.text.begins_with("Exporting selected chart..."),
			true, "async export loading status starts with selected chart export"):
		return false
	if not _expect_int(exporter.calls.size(), 1, "async export call count while loading"):
		return false
	if not _expect_string(exporter.calls[0].get("sourcePath", ""), "charts/async-canon.vos", "async export source path"):
		return false
	if not _expect_int(int(exporter.calls[0].get("chartIndex", -1)), 3, "async export chart index"):
		return false
	song_button.emit_signal("pressed")
	ui._process(0.016)
	if not _expect_int(exporter.calls.size(), 1, "duplicate selection retains the active legacy export"):
		return false
	exporter.write_pending_audio_samples(2)
	ui._process(1.0)
	if not _expect_bool(loading_status.text.contains("2 rendered"),
			true, "async export loading status shows rendered samples"):
		return false

	exporter.complete_selected_export()
	ui._process(0.016)
	if not _expect_string(ui.current_state(), AppState.GAMEPLAY, "async export gameplay state after job completion"):
		return false
	if not _expect_bool(ui.has_node("GameplayRuntime"), true, "async export runtime after job completion"):
		return false
	if not _expect_bool(ui.has_node("Content/GameplayArea/GameplayView/Note_000"), true, "async export note after job completion"):
		return false
	ui.free()
	return true


func _test_existing_selected_bundle_skips_export() -> bool:
	var settings_path := "user://main-ui-cached-export-flow-test.cfg"
	var export_path := "user://exports/vos_cached-export-flow"
	_remove_settings_file(settings_path)
	_remove_path(export_path)
	_write_fixture_bundle(ProjectSettings.globalize_path(export_path))

	var exporter = FakeExporter.new()
	var ui = MainUi.new()
	ui.set_settings_path(settings_path)
	ui.set_exporter_client(exporter)
	ui.build()
	ui.set_song_entries([
		{
			"id": "vos:cached-export-flow",
			"title": "Cached Canon",
			"artist": "Pachelbel",
			"level": 7,
			"sourcePath": "charts/cached-canon.vos",
			"chartIndex": 1,
		},
	])

	ui.get_node("Content/Menu/StartButton").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.SONG_SELECT, "cached song select state"):
		return false
	ui.get_node("Content/SongSelectScroll/SongList/Song_vos_cached-export-flow").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.LOADING, "cached loading state"):
		return false
	if not _expect_bool(ui.has_node("Content/LoadingLayer/LoadingStatus"), true, "cached loading status"):
		return false
	var loading_status: Label = ui.get_node("Content/LoadingLayer/LoadingStatus")
	if not _expect_string(loading_status.text, "Loading gameplay...", "cached loading status text"):
		return false
	ui._process(0.3)
	if not _expect_string(ui.current_state(), AppState.GAMEPLAY, "cached gameplay state"):
		return false
	if not _expect_bool(ui.has_node("GameplayRuntime"), true, "cached runtime"):
		return false
	if not _expect_int(exporter.calls.size(), 0, "cached export call count"):
		return false

	ui.free()
	return true


func _test_cached_large_bundle_preloads_audio_before_gameplay() -> bool:
	var settings_path := "user://main-ui-cached-large-audio-flow-test.cfg"
	var export_path := "user://exports/vos_cached-large-audio-flow"
	_remove_settings_file(settings_path)
	_remove_path(export_path)
	_write_large_fixture_bundle(ProjectSettings.globalize_path(export_path), 40)

	var exporter = FakeExporter.new()
	var ui = MainUi.new()
	ui.set_settings_path(settings_path)
	ui.set_exporter_client(exporter)
	ui.build()
	ui.set_song_entries([
		{
			"id": "vos:cached-large-audio-flow",
			"title": "Cached Large Audio",
			"artist": "Pachelbel",
			"level": 7,
			"sourcePath": "charts/cached-large-audio.vos",
			"chartIndex": 1,
		},
	])

	ui.get_node("Content/Menu/StartButton").emit_signal("pressed")
	ui.get_node("Content/SongSelectScroll/SongList/Song_vos_cached-large-audio-flow").emit_signal("pressed")
	ui._process(0.3)
	if not _expect_string(ui.current_state(), AppState.LOADING, "cached large audio stays loading during preload"):
		return false
	var loading_status: Label = ui.get_node("Content/LoadingLayer/LoadingStatus")
	if not _expect_bool(loading_status.text.begins_with("Loading audio samples..."),
			true, "cached large audio loading status"):
		return false

	for i in range(120):
		if ui.current_state() == AppState.GAMEPLAY:
			break
		ui._process(0.016)
	if not _expect_string(ui.current_state(), AppState.GAMEPLAY, "cached large audio gameplay after preload"):
		return false
	if not _expect_bool(ui.has_node("GameplayRuntime"), true, "cached large audio runtime"):
		return false
	var runtime = ui.get_node("GameplayRuntime")
	if not _expect_bool(runtime.has_node("AudioPlayerPool"), true, "cached large audio runtime pool"):
		return false
	var audio_pool = runtime.get_node("AudioPlayerPool")
	if not _expect_int(audio_pool.preloaded_sample_count(), 40, "cached large audio runtime preloaded sample count"):
		return false
	if not _expect_int(exporter.calls.size(), 0, "cached large audio export call count"):
		return false

	ui.free()
	return true


func _expect_bool(actual: bool, expected: bool, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true


func _remove_settings_file(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _remove_path(path: String) -> void:
	_remove_absolute_path(ProjectSettings.globalize_path(path))


func _remove_absolute_path(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		return

	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		var child_path := "%s/%s" % [path, entry]
		if dir.current_is_dir():
			_remove_absolute_path(child_path)
		else:
			DirAccess.remove_absolute(child_path)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


func _write_fixture_bundle(out_dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	_write_file("%s/gameplay.json" % out_dir, FileAccess.get_file_as_string("res://test/fixtures/gameplay.json"))
	_write_file("%s/audio-manifest.json" % out_dir, FileAccess.get_file_as_string("res://test/fixtures/audio-manifest.json"))
	_write_file("%s/render-metadata.json" % out_dir, FileAccess.get_file_as_string("res://test/fixtures/render-metadata.json"))


func _write_large_fixture_bundle(out_dir: String, sample_count: int) -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	_write_file("%s/gameplay.json" % out_dir, FileAccess.get_file_as_string("res://test/fixtures/gameplay.json"))
	_write_file("%s/audio-manifest.json" % out_dir, _large_audio_manifest(sample_count))
	_write_file("%s/render-metadata.json" % out_dir, FileAccess.get_file_as_string("res://test/fixtures/render-metadata.json"))


func _large_audio_manifest(sample_count: int) -> String:
	var manifest := {
		"schemaVersion": 1,
		"format": "VOS",
		"sourcePath": "res://test/fixtures/large-audio.vos",
		"assetDir": "res://test/fixtures",
		"assets": [],
	}
	for sample_id in range(1, sample_count + 1):
		manifest["assets"].append({
			"sampleId": sample_id,
			"fileName": "sample.wav",
			"path": "res://test/fixtures/sample.wav",
			"type": "wav",
			"role": "keysound",
			"preload": true,
		})
	return JSON.stringify(manifest)


func _write_file(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(content)


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
