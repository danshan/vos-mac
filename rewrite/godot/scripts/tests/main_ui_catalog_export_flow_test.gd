extends SceneTree

const AppState = preload("res://scripts/app_state.gd")
const MainUi = preload("res://scripts/main_ui.gd")


class FakeExporter:
	extends RefCounted

	var catalog_calls: Array[Dictionary] = []

	func export_catalog(source_path: String, output_path: String) -> Dictionary:
		catalog_calls.append({
			"sourcePath": source_path,
			"outputPath": output_path,
		})
		var parent := output_path.get_base_dir()
		DirAccess.make_dir_recursive_absolute(parent)
		var file := FileAccess.open(output_path, FileAccess.WRITE)
		if file != null:
			file.store_string(_catalog_json_for_source(source_path))
		return {"ok": true, "exit_code": 0}

	func _catalog_json_for_source(source_path: String) -> String:
		if source_path == "empty_charts":
			return JSON.stringify({
				"schemaVersion": 1,
				"entries": [],
			})
		if source_path == "charts_next":
			return JSON.stringify({
				"schemaVersion": 1,
				"entries": [{
					"id": "vos:next",
					"format": "VOS",
					"sourcePath": "/tmp/next.vos",
					"title": "Next Song",
					"artist": "Next Artist",
					"noter": "Next Noter",
					"genre": "Electronic",
					"keys": 7,
					"level": 9,
					"levelKnown": true,
					"bpm": 150.0,
					"durationMs": 90000,
					"noteCount": 12,
					"coverAsset": "",
					"exportStatus": "ready",
				}],
			})
		return FileAccess.get_file_as_string("res://test/fixtures/catalog.json")


class DelayedExporter:
	extends RefCounted

	var configure_default_calls := 0
	var catalog_calls: Array[Dictionary] = []
	var _configured := false

	func configure(_java_path: String, _jar_path: String) -> void:
		_configured = true

	func configure_default(_repo_root: String) -> bool:
		configure_default_calls += 1
		_configured = configure_default_calls >= 2
		return _configured

	func is_configured() -> bool:
		return _configured

	func export_catalog(source_path: String, output_path: String) -> Dictionary:
		catalog_calls.append({
			"sourcePath": source_path,
			"outputPath": output_path,
			"configured": _configured,
		})
		if not _configured:
			return {"ok": false, "exit_code": 1}

		var parent := output_path.get_base_dir()
		DirAccess.make_dir_recursive_absolute(parent)
		var file := FileAccess.open(output_path, FileAccess.WRITE)
		if file != null:
			file.store_string(FileAccess.get_file_as_string("res://test/fixtures/catalog.json"))
		return {"ok": true, "exit_code": 0}


class RefreshingExporter:
	extends RefCounted

	var catalog_calls: Array[Dictionary] = []

	func export_catalog(source_path: String, output_path: String) -> Dictionary:
		catalog_calls.append({
			"sourcePath": source_path,
			"outputPath": output_path,
		})
		var parent := output_path.get_base_dir()
		DirAccess.make_dir_recursive_absolute(parent)
		var file := FileAccess.open(output_path, FileAccess.WRITE)
		if file != null:
			file.store_string(_catalog_json(catalog_calls.size()))
		return {"ok": true, "exit_code": 0}

	func _catalog_json(call_count: int) -> String:
		var suffix := "first" if call_count == 1 else "refreshed"
		return JSON.stringify({
			"schemaVersion": 1,
			"entries": [{
				"id": "vos:%s" % suffix,
				"format": "VOS",
				"sourcePath": "/tmp/%s.vos" % suffix,
				"title": "%s Song" % suffix.capitalize(),
				"artist": "Catalog",
				"noter": "Refresh",
				"genre": "Test",
				"keys": 7,
				"level": 4,
				"levelKnown": true,
				"bpm": 140.0,
				"durationMs": 60000,
				"noteCount": call_count,
				"coverAsset": "",
				"exportStatus": "ready",
			}],
		})


class FailingExporter:
	extends RefCounted

	var catalog_calls: Array[Dictionary] = []

	func export_catalog(source_path: String, output_path: String) -> Dictionary:
		catalog_calls.append({
			"sourcePath": source_path,
			"outputPath": output_path,
		})
		return {
			"ok": false,
			"exit_code": 64,
			"output": ["Usage: open2jam --export-vos-catalog --output <file> <file-or-directory>"],
		}


func _init() -> void:
	if not _test_catalog_export_path_is_scoped_to_settings_file():
		return
	if not _test_catalog_export_failure_shows_actionable_status():
		return
	if not _test_start_retries_default_exporter_configuration():
		return
	if not _test_configured_directory_overrides_seeded_song_entries():
		return
	if not _test_start_rescans_configured_directory():
		return
	if not _test_directory_change_clears_song_filter():
		return
	if not _test_reselecting_current_directory_clears_song_filter():
		return

	var settings_path := "user://main-ui-catalog-export-flow-test.cfg"
	_remove_settings_file(settings_path)
	var exporter = FakeExporter.new()
	var ui = MainUi.new()
	ui.set_settings_path(settings_path)
	ui.set_exporter_client(exporter)
	ui.build()

	ui.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	_settings_node(ui, "SongDirectoryDialog").emit_signal("dir_selected", "charts")
	ui.get_node("Content/BackButton").emit_signal("pressed")

	ui.get_node("Content/Menu/StartButton").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.SONG_SELECT, "song select state"):
		return
	if not _expect_int(exporter.catalog_calls.size(), 1, "catalog export call count"):
		return
	if not _expect_string(exporter.catalog_calls[0].get("sourcePath", ""), "charts", "catalog source path"):
		return
	if not _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/Song_vos_fixture"), true, "catalog song button"):
		return
	if not _expect_string(ui.get_node("Content/SongSelectScroll/SongList/Song_vos_fixture").text,
			"Pachelbel - Canon in D", "catalog song title"):
		return
	if not _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/SongMeta_vos_fixture"), true, "catalog song metadata"):
		return
	if not _expect_string(ui.get_node("Content/SongSelectScroll/SongList/SongMeta_vos_fixture").text,
			"Level 7 | BPM 120 | Notes 2 | Duration 02:03 | Source /tmp/fixture.vos",
			"catalog song metadata text"):
		return

	ui.get_node("Content/BackButton").emit_signal("pressed")
	ui.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	_settings_node(ui, "SongDirectoryDialog").emit_signal("dir_selected", "charts_next")
	ui.get_node("Content/BackButton").emit_signal("pressed")

	ui.get_node("Content/Menu/StartButton").emit_signal("pressed")
	if not _expect_int(exporter.catalog_calls.size(), 2, "catalog export call count after directory change"):
		return
	if not _expect_string(exporter.catalog_calls[1].get("sourcePath", ""), "charts_next", "updated catalog source path"):
		return
	if not _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/Song_vos_next"), true, "updated catalog song button"):
		return
	if not _expect_string(ui.get_node("Content/SongSelectScroll/SongList/Song_vos_next").text,
			"Next Artist - Next Song", "updated catalog song title"):
		return
	if not _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/Song_vos_fixture"), false, "stale catalog song button removed"):
		return

	ui.get_node("Content/BackButton").emit_signal("pressed")
	ui.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	_settings_node(ui, "SongDirectoryDialog").emit_signal("dir_selected", "empty_charts")
	ui.get_node("Content/BackButton").emit_signal("pressed")

	ui.get_node("Content/Menu/StartButton").emit_signal("pressed")
	if not _expect_int(exporter.catalog_calls.size(), 3, "catalog export call count after empty directory"):
		return
	if not _expect_string(exporter.catalog_calls[2].get("sourcePath", ""), "empty_charts", "empty catalog source path"):
		return
	if not _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/Song_vos_next"), false, "empty catalog removes previous song button"):
		return
	if not _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/EmptySongList"), true, "empty catalog no songs label"):
		return

	ui.free()
	quit(0)


func _test_catalog_export_path_is_scoped_to_settings_file() -> bool:
	var first_settings_path := "user://main-ui-catalog-scope-first.cfg"
	var second_settings_path := "user://main-ui-catalog-scope-second.cfg"
	_remove_settings_file(first_settings_path)
	_remove_settings_file(second_settings_path)

	var first_exporter = FakeExporter.new()
	var first_ui = MainUi.new()
	first_ui.set_settings_path(first_settings_path)
	first_ui.set_exporter_client(first_exporter)
	first_ui.build()
	first_ui.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	_settings_node(first_ui, "SongDirectoryDialog").emit_signal("dir_selected", "charts")
	first_ui.get_node("Content/BackButton").emit_signal("pressed")
	first_ui.get_node("Content/Menu/StartButton").emit_signal("pressed")
	if not _expect_int(first_exporter.catalog_calls.size(), 1, "first scoped catalog call count"):
		return false

	var second_exporter = FakeExporter.new()
	var second_ui = MainUi.new()
	second_ui.set_settings_path(second_settings_path)
	second_ui.set_exporter_client(second_exporter)
	second_ui.build()
	second_ui.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	_settings_node(second_ui, "SongDirectoryDialog").emit_signal("dir_selected", "charts")
	second_ui.get_node("Content/BackButton").emit_signal("pressed")
	second_ui.get_node("Content/Menu/StartButton").emit_signal("pressed")
	if not _expect_int(second_exporter.catalog_calls.size(), 1, "second scoped catalog call count"):
		return false

	var first_output := str(first_exporter.catalog_calls[0].get("outputPath", ""))
	var second_output := str(second_exporter.catalog_calls[0].get("outputPath", ""))
	var result := _expect_bool(first_output == second_output, false, "scoped catalog output path differs")
	first_ui.free()
	second_ui.free()
	return result


func _test_catalog_export_failure_shows_actionable_status() -> bool:
	var settings_path := "user://main-ui-catalog-failure-test.cfg"
	_remove_settings_file(settings_path)

	var exporter = FailingExporter.new()
	var ui = MainUi.new()
	ui.set_settings_path(settings_path)
	ui.set_exporter_client(exporter)
	ui.build()
	ui.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	_settings_node(ui, "SongDirectoryDialog").emit_signal("dir_selected", "charts")
	ui.get_node("Content/BackButton").emit_signal("pressed")
	ui.get_node("Content/Menu/StartButton").emit_signal("pressed")

	if not _expect_string(ui.current_state(), AppState.SONG_SELECT, "catalog failure song select state"):
		return false
	if not _expect_bool(ui.has_node("Content/CatalogStatus"), true, "catalog failure status label"):
		return false
	var status: Label = ui.get_node("Content/CatalogStatus")
	var result := _expect_string_contains(status.text, "Catalog export failed for charts", "catalog failure source")
	result = result and _expect_string_contains(status.text, "exit 64", "catalog failure exit code")
	result = result and _expect_string_contains(status.text, "Usage: open2jam --export-vos-catalog",
			"catalog failure output")
	result = result and _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/EmptySongList"), true,
			"catalog failure empty list")
	ui.free()
	return result


func _test_start_retries_default_exporter_configuration() -> bool:
	var settings_path := "user://main-ui-delayed-exporter-test.cfg"
	_remove_settings_file(settings_path)

	var exporter = DelayedExporter.new()
	var ui = MainUi.new()
	ui.set_settings_path(settings_path)
	ui.set_exporter_client(exporter)
	ui.build()
	if not _expect_int(exporter.configure_default_calls, 1, "initial exporter configure attempts"):
		return false
	if not _expect_bool(ui.is_exporter_configured(), false, "initial exporter state"):
		return false

	ui.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	_settings_node(ui, "SongDirectoryDialog").emit_signal("dir_selected", "charts")
	ui.get_node("Content/BackButton").emit_signal("pressed")

	ui.get_node("Content/Menu/StartButton").emit_signal("pressed")
	if not _expect_int(exporter.configure_default_calls, 2, "start exporter configure attempts"):
		return false
	if not _expect_int(exporter.catalog_calls.size(), 1, "delayed catalog export call count"):
		return false
	if not _expect_bool(bool(exporter.catalog_calls[0].get("configured", false)), true, "delayed catalog configured call"):
		return false
	if not _expect_string(ui.current_state(), AppState.SONG_SELECT, "delayed song select state"):
		return false
	if not _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/Song_vos_fixture"), true, "delayed catalog song button"):
		return false

	ui.free()
	return true


func _test_start_rescans_configured_directory() -> bool:
	var settings_path := "user://main-ui-catalog-refresh-test.cfg"
	_remove_settings_file(settings_path)

	var exporter = RefreshingExporter.new()
	var ui = MainUi.new()
	ui.set_settings_path(settings_path)
	ui.set_exporter_client(exporter)
	ui.build()

	ui.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	_settings_node(ui, "SongDirectoryDialog").emit_signal("dir_selected", "charts")
	ui.get_node("Content/BackButton").emit_signal("pressed")

	ui.get_node("Content/Menu/StartButton").emit_signal("pressed")
	if not _expect_int(exporter.catalog_calls.size(), 1, "initial refresh catalog call count"):
		return false
	if not _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/Song_vos_first"), true, "initial catalog song"):
		return false

	ui.get_node("Content/BackButton").emit_signal("pressed")
	ui.get_node("Content/Menu/StartButton").emit_signal("pressed")
	var result := _expect_int(exporter.catalog_calls.size(), 2, "same directory refresh catalog call count")
	result = result and _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/Song_vos_refreshed"), true,
			"refreshed catalog song")
	result = result and _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/Song_vos_first"), false,
			"stale catalog song removed after refresh")
	ui.free()
	return result


func _test_configured_directory_overrides_seeded_song_entries() -> bool:
	var settings_path := "user://main-ui-configured-directory-overrides-seeded-test.cfg"
	_remove_settings_file(settings_path)

	var exporter = FakeExporter.new()
	var ui = MainUi.new()
	ui.set_settings_path(settings_path)
	ui.set_exporter_client(exporter)
	ui.build()
	ui.set_song_entries([{
		"id": "seeded:local",
		"title": "Seeded Song",
		"artist": "Seeded Artist",
		"level": 1,
	}])

	ui.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	_settings_node(ui, "SongDirectoryDialog").emit_signal("dir_selected", "charts")
	ui.get_node("Content/BackButton").emit_signal("pressed")
	ui.get_node("Content/Menu/StartButton").emit_signal("pressed")

	var result := _expect_int(exporter.catalog_calls.size(), 1, "configured directory export call count")
	result = result and _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/Song_vos_fixture"), true,
			"configured directory song is shown")
	result = result and _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/Song_seeded_local"), false,
			"seeded song is replaced")
	ui.free()
	return result


func _test_directory_change_clears_song_filter() -> bool:
	var settings_path := "user://main-ui-filter-reset-test.cfg"
	_remove_settings_file(settings_path)

	var exporter = FakeExporter.new()
	var ui = MainUi.new()
	ui.set_settings_path(settings_path)
	ui.set_exporter_client(exporter)
	ui.build()

	ui.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	_settings_node(ui, "SongDirectoryDialog").emit_signal("dir_selected", "charts")
	ui.get_node("Content/BackButton").emit_signal("pressed")
	ui.get_node("Content/Menu/StartButton").emit_signal("pressed")
	ui.get_node("Content/SongFilterInput").text = "Canon"
	ui.get_node("Content/SongFilterInput").emit_signal("text_changed", "Canon")
	if not _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/Song_vos_fixture"), true, "filtered initial catalog song"):
		return false

	ui.get_node("Content/BackButton").emit_signal("pressed")
	ui.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	_settings_node(ui, "SongDirectoryDialog").emit_signal("dir_selected", "charts_next")
	ui.get_node("Content/BackButton").emit_signal("pressed")
	ui.get_node("Content/Menu/StartButton").emit_signal("pressed")

	var result := _expect_string(ui.get_node("Content/SongFilterInput").text, "", "directory change clears filter text")
	result = result and _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/Song_vos_next"), true,
			"new directory song visible after filter reset")
	result = result and _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/EmptySongList"), false,
			"new directory does not show empty filter label")
	ui.free()
	return result


func _test_reselecting_current_directory_clears_song_filter() -> bool:
	var settings_path := "user://main-ui-filter-reselect-test.cfg"
	_remove_settings_file(settings_path)

	var exporter = FakeExporter.new()
	var ui = MainUi.new()
	ui.set_settings_path(settings_path)
	ui.set_exporter_client(exporter)
	ui.build()

	ui.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	_settings_node(ui, "SongDirectoryDialog").emit_signal("dir_selected", "charts")
	ui.get_node("Content/BackButton").emit_signal("pressed")
	ui.get_node("Content/Menu/StartButton").emit_signal("pressed")
	ui.get_node("Content/SongFilterInput").text = "missing"
	ui.get_node("Content/SongFilterInput").emit_signal("text_changed", "missing")
	if not _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/EmptySongList"), true,
			"missing filter hides current directory songs"):
		return false

	ui.get_node("Content/BackButton").emit_signal("pressed")
	ui.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	_settings_node(ui, "SongDirectoryDialog").emit_signal("dir_selected", "charts")
	ui.get_node("Content/BackButton").emit_signal("pressed")
	ui.get_node("Content/Menu/StartButton").emit_signal("pressed")

	var result := _expect_string(ui.get_node("Content/SongFilterInput").text, "",
			"reselecting directory clears filter text")
	result = result and _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/Song_vos_fixture"), true,
			"reselected directory song visible after filter reset")
	result = result and _expect_bool(ui.has_node("Content/SongSelectScroll/SongList/EmptySongList"), false,
			"reselected directory does not show empty filter label")
	ui.free()
	return result


func _settings_node(ui: Node, node_name: String) -> Variant:
	return ui.get_node("Content").find_child(node_name, true, false)


func _remove_settings_file(path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _expect_bool(actual: bool, expected: bool, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true


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


func _expect_string_contains(actual: String, expected: String, label: String) -> bool:
	if not actual.contains(expected):
		push_error("Expected %s to contain '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true
