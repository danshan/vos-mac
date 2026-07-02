extends SceneTree

const AudioManifestLoader = preload("res://scripts/audio_manifest_loader.gd")
const GameplayRuntime = preload("res://scripts/gameplay_runtime.gd")


func _init() -> void:
	var oracle := _load_oracle()
	if oracle.is_empty():
		return

	var audio_loader = AudioManifestLoader.new()
	var audio_manifest: Dictionary = audio_loader.load_from_file("res://test/fixtures/audio-manifest.json")
	if audio_manifest.is_empty():
		push_error("Expected audio manifest fixture to load.")
		quit(1)
		return

	var scenarios: Variant = oracle.get("scenarios")
	if not scenarios is Array:
		push_error("Expected FPS timer oracle scenarios array.")
		quit(1)
		return

	for raw_scenario: Variant in scenarios:
		if not raw_scenario is Dictionary:
			push_error("Expected FPS timer oracle scenario object.")
			quit(1)
			return
		if not _verify_scenario(raw_scenario, audio_manifest):
			return

	quit(0)


func _load_oracle() -> Dictionary:
	var path := "res://test/fixtures/fps-timer-oracle.json"
	if not FileAccess.file_exists(path):
		push_error("Missing FPS timer oracle fixture: %s" % path)
		quit(1)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Expected FPS timer oracle root object.")
		quit(1)
		return {}

	var root: Dictionary = parsed
	if int(root.get("schemaVersion", 0)) != 1:
		push_error("Expected FPS timer oracle schema version 1.")
		quit(1)
		return {}
	if str(root.get("source", "")) != "Render.update_fps_counter":
		push_error("Expected FPS timer oracle source Render.update_fps_counter.")
		quit(1)
		return {}
	return root


func _verify_scenario(scenario: Dictionary, audio_manifest: Dictionary) -> bool:
	var name := str(scenario.get("name", ""))
	var runtime = GameplayRuntime.new()
	get_root().add_child(runtime)
	if not _expect_bool(runtime.start(_chart_for_scenario(name), audio_manifest), true, "%s runtime start" % name):
		return false

	var initial: Variant = scenario.get("initial")
	if not initial is Dictionary:
		push_error("Expected initial snapshot for FPS timer scenario %s." % name)
		quit(1)
		return false
	if not _expect_hud_snapshot(runtime.hud_state(), initial, "%s initial" % name):
		return false

	var frames: Variant = scenario.get("frames")
	if not frames is Array:
		push_error("Expected frames for FPS timer scenario %s." % name)
		quit(1)
		return false

	var elapsed_ms := 0.0
	for index in range(frames.size()):
		var raw_frame: Variant = frames[index]
		if not raw_frame is Dictionary:
			push_error("Expected FPS timer frame object for scenario %s." % name)
			quit(1)
			return false
		var frame: Dictionary = raw_frame
		elapsed_ms += float(frame.get("deltaMs", 0.0))
		runtime.advance_to(elapsed_ms)
		if not _expect_hud_snapshot(runtime.hud_state(), frame, "%s frame %d" % [name, index]):
			return false

	runtime.free()
	return true


func _chart_for_scenario(name: String) -> Dictionary:
	return {
		"schemaVersion": 1,
		"chartId": "vos:fps-timer-oracle:%s" % name,
		"format": "VOS",
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 120000,
		"notes": [{
			"lane": 0,
			"startMs": 999999.0,
			"measure": 0,
			"sampleId": 1,
			"volume": 1.0,
			"pan": 0.0,
			"kind": "tap",
		}],
		"measures": [],
		"autoPlayEvents": [],
	}


func _expect_hud_snapshot(hud_state: Dictionary, snapshot: Dictionary, label: String) -> bool:
	if not _expect_int(int(hud_state.get("fps", -1)), int(snapshot.get("displayFps", -2)), "%s display fps" % label):
		return false
	if not _expect_int(int(hud_state.get("minute", -1)), int(snapshot.get("minute", -2)), "%s minute" % label):
		return false
	if not _expect_int(int(hud_state.get("second", -1)), int(snapshot.get("second", -2)), "%s second" % label):
		return false
	return true


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
