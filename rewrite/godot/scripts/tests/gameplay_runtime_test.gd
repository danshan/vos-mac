extends SceneTree

const AudioManifestLoader = preload("res://scripts/audio_manifest_loader.gd")
const GameplayLoader = preload("res://scripts/gameplay_loader.gd")
const GameplayRuntime = preload("res://scripts/gameplay_runtime.gd")


func _init() -> void:
	var gameplay_loader = GameplayLoader.new()
	var chart: Dictionary = gameplay_loader.load_from_file("res://test/fixtures/gameplay.json")
	if not _expect_bool(chart.is_empty(), false, "gameplay fixture load"):
		return

	var audio_loader = AudioManifestLoader.new()
	var audio_manifest: Dictionary = audio_loader.load_from_file("res://test/fixtures/audio-manifest.json")
	if not _expect_bool(audio_manifest.is_empty(), false, "audio fixture load"):
		return

	var runtime = GameplayRuntime.new()
	get_root().add_child(runtime)
	if not _expect_bool(runtime.start(chart, audio_manifest), true, "runtime start"):
		return
	if not _expect_bool(runtime.is_running(), true, "runtime running"):
		return

	runtime.advance_to(0.0)
	if not _expect_int(runtime.audio_play_event_count(), 1, "autoplay play event"):
		return

	var hit: Dictionary = runtime.press_action("vos_lane_1", 1000.0)
	if not _expect_bool(hit.get("accepted", false), true, "note hit accepted"):
		return
	if not _expect_int(runtime.audio_play_event_count(), 2, "note hit play event"):
		return

	runtime.stop()
	if not _expect_bool(runtime.start(chart, audio_manifest), true, "runtime restart"):
		return
	runtime.advance_to(1000.0)
	var input_event := InputEventAction.new()
	input_event.action = "vos_lane_1"
	input_event.pressed = true
	runtime._unhandled_input(input_event)
	if not _expect_int(runtime.result().get("score", 0), 200, "input event hit score"):
		return
	if not _expect_int(runtime.audio_play_event_count(), 2, "input event audio count"):
		return

	runtime.advance_to(3000.0)
	if not _expect_bool(runtime.is_running(), false, "runtime stops at duration"):
		return
	if not _expect_int(runtime.result().get("score", 0), 200, "runtime result score"):
		return

	runtime.free()
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
