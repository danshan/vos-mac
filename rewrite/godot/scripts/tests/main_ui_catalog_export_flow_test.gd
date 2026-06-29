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
			file.store_string(FileAccess.get_file_as_string("res://test/fixtures/catalog.json"))
		return {"ok": true, "exit_code": 0}


func _init() -> void:
	var exporter = FakeExporter.new()
	var ui = MainUi.new()
	ui.set_exporter_client(exporter)
	ui.build()

	ui.get_node("Content/Menu/SettingsButton").emit_signal("pressed")
	ui.get_node("Content/SongDirectoryInput").text = "charts"
	ui.get_node("Content/BackButton").emit_signal("pressed")

	ui.get_node("Content/Menu/StartButton").emit_signal("pressed")
	if not _expect_string(ui.current_state(), AppState.SONG_SELECT, "song select state"):
		return
	if not _expect_int(exporter.catalog_calls.size(), 1, "catalog export call count"):
		return
	if not _expect_string(exporter.catalog_calls[0].get("sourcePath", ""), "charts", "catalog source path"):
		return
	if not _expect_bool(ui.has_node("Content/SongList/Song_vos_fixture"), true, "catalog song button"):
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
