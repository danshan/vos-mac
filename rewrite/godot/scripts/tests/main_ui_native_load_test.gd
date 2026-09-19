extends SceneTree

const MainUi = preload("res://scripts/main_ui.gd")
const Wire = preload("res://scripts/native_json.gd")
const AppState = preload("res://scripts/app_state.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		_fail("Expected converter, source bundle and work root.")
		return
	if not _skin_valid():
		_fail("Bundled skin integrity or image decoding failed.")
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1].path_join("bundle.json")))
	var request := {
		"schemaVersion": 1, "command": "BUNDLE", "chartId": manifest["chartId"],
		"sourceKind": "BUNDLE_V2", "sourcePath": args[1],
		"selector": {"kind": "BUNDLE_CHART", "chartId": manifest["chartId"]},
		"soundfont": {"path": args[2].path_join("unused.sf2"), "version": "2.0.3", "sha256": manifest["soundfont"]["sha256"]},
		"staticAssetsVersion": manifest["staticAssetsVersion"],
	}
	var entry := {"id": "native-song", "title": "Native song", "nativeRequest": request}
	var ui = MainUi.new()
	ui.set_settings_path(args[2].path_join("settings.cfg"))
	if not ui.has_method("configure_native_converter"):
		_fail("Native UI converter integration is missing.")
		return
	ui.configure_native_converter(args[2].get_base_dir().path_join("late-helper"), args[2])
	ui.set_song_entries([entry])
	get_root().add_child(ui)
	ui.get_node("Content/Menu/StartButton").pressed.emit()
	var song_button := ui.find_child("Song_native-song", true, false)
	if song_button == null:
		_fail("Native song did not appear in the real selection UI.")
		return
	song_button.pressed.emit()
	if ui.current_state() != AppState.LOADING:
		_fail("Native song did not enter loading.")
		return
	var helper_deadline := Time.get_ticks_msec() + 5000
	while not FileAccess.file_exists(args[2].path_join("late-helper.ready")) and Time.get_ticks_msec() < helper_deadline:
		await process_frame
	if not FileAccess.file_exists(args[2].path_join("late-helper.ready")):
		_fail("Late UI helper never became ready.")
		return
	ui.get_node("Content/LoadingLayer/CancelLoadingButton").pressed.emit()
	if ui.current_state() != AppState.SONG_SELECT:
		_fail("Loading back did not return to song selection.")
		return
	ui.configure_native_converter(args[0], args[2])
	ui.find_child("Song_native-song", true, false).pressed.emit()
	var deadline := Time.get_ticks_msec() + 15000
	var frames := 0
	while ui.current_state() == AppState.LOADING and Time.get_ticks_msec() < deadline:
		frames += 1
		await process_frame
	var runtime := ui.get_node_or_null("GameplayRuntime")
	if ui.current_state() != AppState.GAMEPLAY or runtime == null or not runtime.is_running() or frames < 2:
		_fail("Native UI failed to enter running gameplay.")
		return
	if ui.get_node_or_null("Content/GameplayArea/GameplayView") == null:
		_fail("Native gameplay view was not created.")
		return
	runtime.advance_to(1000.125)
	if not runtime.press_action("vos_lane_1", 1000.125).get("accepted", false):
		_fail("Native UI chart cannot be judged.")
		return
	deadline = Time.get_ticks_msec() + 4000
	while ui.get_node("NativeLoadCoordinator").pending_count() > 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	if ui.get_node("NativeLoadCoordinator").pending_count() != 0 or ui.current_state() != AppState.GAMEPLAY:
		_fail("Retired UI helper leaked or changed current gameplay.")
		return
	ui.free()
	print("Native UI selected, cancelled, reselected and reached playable gameplay with bundled skin.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _skin_valid() -> bool:
	var base := "res://assets/o2jam/"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + "asset-manifest.json"))
	for entry: Dictionary in manifest["files"]:
		var path: String = base + entry["path"]
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or Wire.sha256(file.get_buffer(file.get_length())) != "sha256:" + entry["sha256"]:
			return false
		if path.ends_with(".png") and Image.new().load(path) != OK:
			return false
	return true
