extends SceneTree

const AppState = preload("res://scripts/app_state.gd")
const MainUi = preload("res://scripts/main_ui.gd")


class FakeExporter:
	extends RefCounted

	var calls: Array[Dictionary] = []

	func export_selected(source_path: String, out_dir: String) -> Dictionary:
		calls.append({
			"sourcePath": source_path,
			"outDir": out_dir,
		})
		DirAccess.make_dir_recursive_absolute(out_dir)
		_write_file("%s/gameplay.json" % out_dir, FileAccess.get_file_as_string("res://test/fixtures/gameplay.json"))
		_write_file("%s/audio-manifest.json" % out_dir, FileAccess.get_file_as_string("res://test/fixtures/audio-manifest.json"))
		_write_file("%s/render-metadata.json" % out_dir, FileAccess.get_file_as_string("res://test/fixtures/render-metadata.json"))
		return {"ok": true, "exit_code": 0}

	func _write_file(path: String, content: String) -> void:
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(content)


func _init() -> void:
	var exporter = FakeExporter.new()
	var ui = MainUi.new()
	ui.set_exporter_client(exporter)
	ui.build()
	ui.set_song_entries([
		{
			"id": "vos:export-flow",
			"title": "Canon in D",
			"artist": "Pachelbel",
			"level": 7,
			"sourcePath": "charts/canon.vos",
		},
	])

	ui.get_node("Content/Menu/StartButton").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.SONG_SELECT, "song select state"):
		return

	ui.get_node("Content/SongList/Song_vos_export-flow").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.GAMEPLAY, "gameplay state"):
		return
	if not _expect_bool(ui.has_node("GameplayRuntime"), true, "runtime after export"):
		return
	if not _expect_bool(ui.has_node("Content/GameplayArea/GameplayView/Note_000"), true, "note after export"):
		return
	if not _expect_int(exporter.calls.size(), 1, "export call count"):
		return
	if not _expect_string(exporter.calls[0].get("sourcePath", ""), "charts/canon.vos", "export source path"):
		return

	ui.free()
	quit(0)


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
