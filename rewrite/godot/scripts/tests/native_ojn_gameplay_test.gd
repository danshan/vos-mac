extends SceneTree

const Settings = preload("res://scripts/settings_store.gd")
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
	if not _errors.is_empty() or _catalog.get("entries", []).size() != 6:
		_fail("Godot did not accept two distinct OJN songs with three charts each.")
		return
	if _catalog["entries"][0]["songId"] == _catalog["entries"][3]["songId"] or _catalog["entries"][0]["sourceId"] == _catalog["entries"][3]["sourceId"]:
		_fail("Identical OJN copies must retain distinct source and song identities.")
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
	var settings = Settings.new()
	settings.set_song_directories([songs_root])
	if not settings.save_to_file(args[2].path_join("settings.cfg")):
		_fail("Unable to prepare library settings.")
		return
	var previous_song_names: Array[String] = []
	for chart_index in range(3):
		var ui = MainUi.new()
		ui.set_settings_path(args[2].path_join("settings.cfg"))
		ui.configure_native_converter(args[0], args[2])
		get_root().add_child(ui)
		ui.get_node("Content/Menu/StartButton").pressed.emit()
		var scan_deadline := Time.get_ticks_msec() + 15000
		while ui.find_children("Song_*", "Button", true, false).is_empty() and Time.get_ticks_msec() < scan_deadline:
			await process_frame
		var songs := ui.find_children("Song_*", "Button", true, false)
		var song_names: Array[String] = []
		for song: Button in songs:
			song_names.append(str(song.name))
		if chart_index > 0 and song_names != previous_song_names:
			_fail("Library song identity changed when reopening the UI.")
			return
		previous_song_names = song_names
		if songs.size() != 2 or songs[0].text != _catalog["entries"][0]["title"]:
			_fail("Each OJN source must occupy one title-only song row, even when titles match.")
			return
		songs[0].pressed.emit()
		var difficulties := ui.find_children("Difficulty_*", "Button", true, false)
		if difficulties.size() != 3 or ui.current_state() == AppState.LOADING:
			_fail("Selecting a song must open its three difficulties before loading.")
			return
		ui.get_node("Content/BackButton").pressed.emit()
		songs = ui.find_children("Song_*", "Button", true, false)
		if songs.size() != 2:
			_fail("Returning from difficulty selection must preserve song grouping.")
			return
		songs[0].pressed.emit()
		difficulties = ui.find_children("Difficulty_*", "Button", true, false)
		difficulties[chart_index].pressed.emit()
		var deadline := Time.get_ticks_msec() + 15000
		while ui.current_state() == AppState.LOADING and Time.get_ticks_msec() < deadline:
			await process_frame
		var runtime := ui.get_node_or_null("GameplayRuntime")
		if ui.current_state() != AppState.GAMEPLAY or runtime == null or not runtime.is_running():
			_fail("Raw OJN conversion did not reach running gameplay.")
			return
		runtime.advance_to(1500.0)
		if not runtime.press_action("vos_lane_%d" % (chart_index + 1), 1500.0).get("accepted", false) or runtime.audio_play_event_count() < 1:
			_fail("Converted OJN note did not trigger judgment and prepared audio.")
			return
		runtime.advance_to(120000.0)
		runtime.advance_to(130001.0)
		if ui.current_state() != AppState.RESULT:
			_fail("The selected OJN chart did not finish into the result screen.")
			return
		ui.free()
	var settings_path := args[2].path_join("settings.cfg")
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		_fail("Unable to inspect the persisted settings fixture.")
		return
	config.set_value("songs", "root_ids", {songs_root: "library:sha256:broken"})
	config.save(settings_path)
	var damaged := FileAccess.get_file_as_bytes(settings_path)
	var invalid_ui = MainUi.new()
	invalid_ui.set_settings_path(settings_path)
	invalid_ui.configure_native_converter(args[0], args[2])
	get_root().add_child(invalid_ui)
	invalid_ui.get_node("Content/Menu/StartButton").pressed.emit()
	var status := invalid_ui.get_node_or_null("Content/CatalogStatus")
	if status == null or not str(status.text).contains("identity") or not invalid_ui.find_children("Song_*", "Button", true, false).is_empty():
		_fail("Damaged library identity must stop scanning with a visible error.")
		return
	invalid_ui.free()
	if FileAccess.get_file_as_bytes(settings_path) != damaged:
		_fail("Damaged library identity must not be silently replaced.")
		return
	coordinator.free()
	print("Raw OJN reached Gameplay Ready through the native converter and judged its note with audio.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
