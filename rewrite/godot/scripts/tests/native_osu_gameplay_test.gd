extends SceneTree

const MainUi = preload("res://scripts/main_ui.gd")
const Settings = preload("res://scripts/settings_store.gd")
const AppState = preload("res://scripts/app_state.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var settings = Settings.new()
	settings.set_song_directories([args[1]])
	var settings_path := args[2].path_join("settings.cfg")
	if not settings.save_to_file(settings_path):
		_fail("Unable to prepare osu library settings.")
		return
	var previous_names: Array[String] = []
	for chart_index in range(2):
		var ui = MainUi.new()
		ui.set_settings_path(settings_path)
		ui.configure_native_converter(args[0], args[2])
		get_root().add_child(ui)
		ui.get_node("Content/Menu/StartButton").pressed.emit()
		var deadline := Time.get_ticks_msec() + 15000
		while ui.find_children("Song_*", "Button", true, false).is_empty() and Time.get_ticks_msec() < deadline:
			await process_frame
		var songs := ui.find_children("Song_*", "Button", true, false)
		if songs.size() != 3:
			_fail("Mixed catalog must contain one OJN song and two osu beatmap sets.")
			return
		var names: Array[String] = []
		for song: Button in songs:
			names.append(str(song.name))
		if chart_index > 0 and names != previous_names:
			_fail("Reopening the library changed osu song selection identity.")
			return
		previous_names = names
		if songs[1].text != "Seven Key Fixture" or songs[2].text != "Seven Key Fixture":
			_fail("Same-title beatmap sets must remain distinct title-only rows.")
			return
		songs[2].pressed.emit()
		var difficulties := ui.find_children("Difficulty_*", "Button", true, false)
		if difficulties.size() != 2 or not str(difficulties[chart_index].text).contains(["Test 7K", "Hard 7K"][chart_index]):
			_fail("osu difficulties lost their beatmap names or grouping.")
			return
		difficulties[chart_index].pressed.emit()
		deadline = Time.get_ticks_msec() + 15000
		while ui.current_state() == AppState.LOADING and Time.get_ticks_msec() < deadline:
			await process_frame
		var runtime := ui.get_node_or_null("GameplayRuntime")
		if ui.current_state() != AppState.GAMEPLAY or runtime == null or not runtime.is_running():
			_fail("Raw osu did not reach running gameplay.")
			return
		for lane in range(7):
			var at := 1500.0 + 250.0 * lane
			runtime.advance_to(at)
			if not runtime.press_action("vos_lane_%d" % (lane + 1), at).get("accepted", false):
				_fail("Converted seven-key osu tap was not judged.")
				return
			runtime.release_action("vos_lane_%d" % (lane + 1), at)
		runtime.advance_to(3500.0)
		if not runtime.press_action("vos_lane_4", 3500.0).get("accepted", false):
			_fail("Converted osu hold was not judged.")
			return
		runtime.advance_to(4500.0)
		runtime.release_action("vos_lane_4", 4500.0)
		if runtime.audio_play_event_count() < 2 or int(runtime.result().get("score", 0)) <= 0:
			_fail("osu BGM and custom key sample did not produce scored audio.")
			return
		runtime.advance_to(120000.0)
		runtime.advance_to(130001.0)
		if ui.current_state() != AppState.RESULT:
			_fail("osu gameplay did not finish into the result screen.")
			return
		ui.free()
	print("Raw osu reached Gameplay Ready and judged seven lanes and a hold with audio.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
