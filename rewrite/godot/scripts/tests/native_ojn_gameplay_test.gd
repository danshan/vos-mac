extends SceneTree

const MainUi = preload("res://scripts/main_ui.gd")
const AppState = preload("res://scripts/app_state.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var entry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	var request := {
		"schemaVersion": 1, "command": "BUNDLE", "chartId": entry["chartId"],
		"sourceKind": "OJN", "sourcePath": entry["sourcePath"],
		"libraryRoot": {"id": entry["rootId"], "path": entry["rootPath"]},
		"selector": {"kind": "OJN_CHART", "index": 0},
		"soundfont": {"path": args[2].path_join("unused.sf2"), "version": "unused", "sha256": "sha256:" + "00".repeat(32)},
		"staticAssetsVersion": "open2jam-gameplay-assets-v1",
	}
	var ui = MainUi.new()
	ui.set_settings_path(args[2].path_join("settings.cfg"))
	ui.configure_native_converter(args[0], args[2])
	ui.set_song_entries([{"id": "raw-ojn", "title": entry["title"], "nativeRequest": request}])
	get_root().add_child(ui)
	ui.get_node("Content/Menu/StartButton").pressed.emit()
	var song := ui.find_child("Song_raw-ojn", true, false)
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
	print("Raw OJN reached Gameplay Ready through the native converter and judged its note with audio.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
