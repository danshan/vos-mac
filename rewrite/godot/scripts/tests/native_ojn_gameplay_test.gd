extends SceneTree

const MainUi = preload("res://scripts/main_ui.gd")
const CatalogLoader = preload("res://scripts/native_catalog_loader.gd")
const Coordinator = preload("res://scripts/native_load_coordinator.gd")
var _catalog := {}
var _errors: Array = []

const AppState = preload("res://scripts/app_state.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var coordinator = Coordinator.new()
	get_root().add_child(coordinator)
	coordinator.catalog_loaded.connect(func(_generation: int, catalog: Dictionary): _catalog = catalog)
	coordinator.failed.connect(func(_generation: int, error: Dictionary): _errors.append(error))
	var songs_root: String = args[1]
	var root_id := "library:sha256:" + "01".repeat(32)
	var staging := args[2].path_join("catalog-staging")
	DirAccess.make_dir_recursive_absolute(staging)
	coordinator.start_loading(args[0], {"schemaVersion": 1, "command": "CATALOG", "roots": [songs_root],
		"rootIds": {songs_root: root_id}, "previousIndexPath": null, "stagingRoot": staging}, args[2])
	var catalog_deadline := Time.get_ticks_msec() + 15000
	while coordinator.pending_count() > 0 and Time.get_ticks_msec() < catalog_deadline:
		await process_frame
	if not _errors.is_empty() or _catalog.get("entries", []).size() != 3:
		_fail("Godot did not accept the three native OJN chart entries.")
		return
	var ids := {}
	var song_id: String = _catalog["entries"][0]["songId"]
	for index in range(3):
		var entry: Dictionary = _catalog["entries"][index]
		if entry["songId"] != song_id or ids.has(entry["id"]) or entry["nativeRequest"]["selector"]["index"] != index:
			_fail("OJN chart identity or selector was lost in the catalog consumer.")
			return
		ids[entry["id"]] = true
	var jobs := DirAccess.get_directories_at(staging)
	var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(staging.path_join(jobs[0]).path_join("catalog-v2.json")))
	# Preserve integer wire syntax when round-tripping metadata for rejection checks.
	snapshot["schemaVersion"] = 2
	for entry: Dictionary in snapshot["entries"]:
		for field: String in ["chartIndex", "level", "durationSeconds"]:
			entry[field] = int(entry[field])
	var candidate_path := args[2].path_join("candidate.json")
	for mutation: String in ["valid", "duplicate", "same-index", "foreign-song", "index-range", "negative-level", "missing-root", "missing-chart"]:
		var changed := snapshot.duplicate(true)
		match mutation:
			"duplicate": changed["entries"].append(changed["entries"][0].duplicate(true))
			"same-index": changed["entries"][1]["chartIndex"] = 0
			"foreign-song": changed["entries"][1]["songId"] = "song:sha256:" + "02".repeat(32)
			"index-range": changed["entries"][0]["chartIndex"] = 3
			"negative-level": changed["entries"][0]["level"] = -1
			"missing-root": changed["entries"][0].erase("rootId")
			"missing-chart": changed["entries"].pop_back()
		var file := FileAccess.open(candidate_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(changed))
		file.close()
		var loaded: Dictionary = CatalogLoader.new().load_catalog(candidate_path, [songs_root], Callable(), {songs_root: root_id})
		if loaded.is_empty() == (mutation == "valid"):
			_fail("OJN catalog validation disagreed with metadata mutation: " + mutation)
			return
	var ui = MainUi.new()
	ui.set_settings_path(args[2].path_join("settings.cfg"))
	ui.configure_native_converter(args[0], args[2])
	ui.set_song_entries(_catalog["entries"])
	get_root().add_child(ui)
	ui.get_node("Content/Menu/StartButton").pressed.emit()
	var song := ui.find_child("Song_" + _catalog["entries"][0]["id"], true, false)
	if song == null:
		_fail("OJN entry was absent from the real song selection UI.")
		return
	song.pressed.emit()
	var deadline := Time.get_ticks_msec() + 15000
	while ui.current_state() == AppState.LOADING and Time.get_ticks_msec() < deadline:
		await process_frame
	var runtime := ui.get_node_or_null("GameplayRuntime")
	if ui.current_state() != AppState.GAMEPLAY or runtime == null or not runtime.is_running():
		_fail("Raw OJN conversion did not reach running gameplay.")
		return
	runtime.advance_to(1500.0)
	if not runtime.press_action("vos_lane_1", 1500.0).get("accepted", false) or runtime.audio_play_event_count() < 1:
		_fail("Converted OJN note did not trigger judgment and prepared audio.")
		return
	ui.free()
	coordinator.free()
	print("Raw OJN reached Gameplay Ready through the native converter and judged its note with audio.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
