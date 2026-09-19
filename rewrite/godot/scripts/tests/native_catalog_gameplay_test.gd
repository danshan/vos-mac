extends SceneTree

const CatalogLoader = preload("res://scripts/native_catalog_loader.gd")
const Coordinator = preload("res://scripts/native_load_coordinator.gd")
const MainUi = preload("res://scripts/main_ui.gd")
const Settings = preload("res://scripts/settings_store.gd")
const AppState = preload("res://scripts/app_state.gd")
var _catalog := {}
var _errors: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var coordinator = Coordinator.new()
	get_root().add_child(coordinator)
	if not coordinator.has_signal("catalog_loaded"):
		_fail("Native coordinator cannot deliver a catalog.")
		return
	coordinator.catalog_loaded.connect(func(_generation: int, catalog: Dictionary): _catalog = catalog)
	coordinator.failed.connect(func(_generation: int, error: Dictionary): _errors.append(error))
	DirAccess.make_dir_recursive_absolute(args[2].path_join("staging"))
	var root_id := "library:sha256:" + "01".repeat(32)
	var root_ids := {args[1]: root_id}
	var request := {"rootIds": root_ids, "schemaVersion": 1, "command": "CATALOG", "roots": [args[1]], "previousIndexPath": null, "stagingRoot": args[2].path_join("staging")}
	coordinator.start_loading(args[0], request, args[2])
	var deadline := Time.get_ticks_msec() + 15000
	while coordinator.pending_count() > 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _errors.is_empty() or _catalog.get("entries", []).size() != 1 or _catalog.get("errors", []).size() != 1:
		_fail("Catalog did not preserve the playable entry beside the rejected bundle.")
		return
	if not str(_catalog["errors"][0]).contains("broken"):
		_fail("Rejected catalog source was not identified.")
		return
	if _catalog["entries"][0].get("rootId", "") != root_id:
		_fail("Catalog lost the persistent library root identity.")
		return
	var jobs := DirAccess.get_directories_at(args[2].path_join("staging"))
	var snapshot_path := args[2].path_join("staging").path_join(jobs[0]).path_join("catalog-v2.json")
	var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(snapshot_path))
	# Keep the valid wire integer while rewriting individual fields below.
	snapshot["schemaVersion"] = 2
	var moved_root := args[2].path_join("relocated-library")
	for copied: bool in [false, true]:
		var moved := snapshot.duplicate(true)
		var expected_id := "library:sha256:" + ("02" if copied else "01").repeat(32)
		moved["entries"][0]["rootPath"] = moved_root
		moved["entries"][0]["sourcePath"] = moved_root.path_join(moved["entries"][0]["relativePath"])
		moved["entries"][0]["rootId"] = expected_id
		var moved_path := args[2].path_join("moved-catalog.json")
		var file := FileAccess.open(moved_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(moved))
		file.close()
		var loaded: Dictionary = CatalogLoader.new().load_catalog(moved_path, [moved_root], Callable(), {moved_root: expected_id})
		if loaded.is_empty() or (loaded["entries"][0]["id"] == _catalog["entries"][0]["id"]) == copied:
			_fail("Relocation must preserve selection identity; adding a copy must not.")
			return
	for mutation: String in ["outside", "traversal", "foreign-root", "duplicate", "soundfont", "root-id", "missing-id"]:
		var changed := snapshot.duplicate(true)
		match mutation:
			"root-id": changed["entries"][0]["rootId"] = "library:sha256:" + "02".repeat(32)
			"missing-id": changed["entries"][0].erase("rootId")
			"outside": changed["entries"][0]["sourcePath"] = "/outside/library"
			"traversal": changed["entries"][0]["relativePath"] = "../outside"
			"foreign-root": changed["entries"][0]["rootPath"] = "/outside"
			"duplicate": changed["entries"].append(changed["entries"][0].duplicate(true))
			"soundfont": changed["entries"][0]["soundfont"]["sha256"] = "sha256:bad"
		var invalid_path := args[2].path_join("invalid-catalog.json")
		var file := FileAccess.open(invalid_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(changed))
		file.close()
		if not CatalogLoader.new().load_catalog(invalid_path, [args[1]], Callable(), root_ids).is_empty():
			_fail("Catalog consumer accepted invalid metadata: " + mutation)
			return
	var ui = MainUi.new()
	ui.set_settings_path(args[2].path_join("settings.cfg"))
	ui.configure_native_converter(args[0], args[2])
	var settings = Settings.new()
	settings.set_song_directories([args[1]])
	if not settings.save_to_file(args[2].path_join("settings.cfg")):
		_fail("Unable to save native catalog test settings.")
		return
	get_root().add_child(ui)
	ui.get_node("Content/Menu/StartButton").pressed.emit()
	deadline = Time.get_ticks_msec() + 15000
	while ui.find_children("Song_*", "Button", true, false).is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	if not ui.has_node("Content/CatalogStatus") or not str(ui.get_node("Content/CatalogStatus").text).contains("broken"):
		_fail("Native UI did not display the rejected source alongside its songs.")
		return
	var songs := ui.find_children("Song_*", "Button", true, false)
	if songs.size() != 1:
		_fail("Discovered native chart did not appear in song selection.")
		return
	songs[0].pressed.emit()
	var difficulties := ui.find_children("Difficulty_*", "Button", true, false)
	if difficulties.size() != 1:
		_fail("The discovered bundle must offer its chart in difficulty selection.")
		return
	difficulties[0].pressed.emit()
	deadline = Time.get_ticks_msec() + 15000
	while ui.current_state() == AppState.LOADING and Time.get_ticks_msec() < deadline:
		await process_frame
	var runtime := ui.get_node_or_null("GameplayRuntime")
	if ui.current_state() != AppState.GAMEPLAY or runtime == null or not runtime.is_running():
		_fail("Discovered bundle did not reach gameplay through the real UI.")
		return
	runtime.advance_to(1000.125)
	if not runtime.press_action("vos_lane_1", 1000.125).get("accepted", false):
		_fail("Discovered chart was not playable.")
		return
	ui.free()
	coordinator.free()
	print("Native catalog discovered a bundle beside a rejected source and reached playable UI gameplay.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
