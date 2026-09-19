extends SceneTree

const BundleLoader = preload("res://scripts/native_bundle_loader.gd")
const GameplayRuntime = preload("res://scripts/gameplay_runtime.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		_fail("Expected controlled bundle directory.")
		return
	var loaded: Dictionary = BundleLoader.new().load_bundle(args[0])
	if loaded.is_empty():
		_fail("Native bundle was rejected.")
		return
	if BundleLoader.new().load_bundle(args[0] + "/").is_empty():
		_fail("Valid bundle with trailing slash was rejected.")
		return
	var chart: Dictionary = loaded["chart"]
	if chart["notes"][0]["startMs"] != 1000.125 or chart["notes"][0]["volume"] != 0.9375 or chart["notes"][0]["pan"] != -0.875:
		_fail("Time or volume precision was lost.")
		return
	if chart["notes"][1]["endMs"] != 2500.25 or chart["notes"][1]["releaseEventOrder"] != 4:
		_fail("Hold tail semantics were lost.")
		return
	if chart["visualTiming"][1]["bpm"] != 180.0 or chart["judgmentTiming"].size() != 1:
		_fail("Visual and judgment timing were merged.")
		return
	if chart["scroll"][0]["multiplier"] != 1.5 or chart["measures"][1]["startMs"] != 2000.0 or chart["format"] != "OJN":
		_fail("Scroll, measure or format mapping changed.")
		return
	var runtime = GameplayRuntime.new()
	get_root().add_child(runtime)
	if not runtime.start(chart, loaded["audio"]) or not runtime.is_running():
		_fail("Native chart did not reach a running gameplay runtime.")
		return
	runtime.advance_to(0.125)
	if runtime.audio_play_event_count() != 1:
		_fail("Native autoplay did not trigger audio.")
		return
	runtime.advance_to(1000.125)
	if not runtime.press_action("vos_lane_1", 1000.125).get("accepted", false):
		_fail("Native tap could not be judged.")
		return
	runtime.release_action("vos_lane_1", 1000.125)
	runtime.advance_to(1500.125)
	if not runtime.press_action("vos_lane_2", 1500.125).get("accepted", false):
		_fail("Native hold could not be started.")
		return
	runtime.advance_to(2500.25)
	runtime.release_action("vos_lane_2", 2500.25)
	if not runtime.press_action("vos_lane_2", 2500.25).get("accepted", false):
		_fail("Same-time note after hold release was lost.")
		return
	if runtime.audio_play_event_count() < 4 or int(runtime.result().get("score", 0)) <= 0:
		_fail("Native notes did not produce scored audio events.")
		return
	runtime.stop()
	runtime.free()
	print("Native bundle reached Gameplay Ready and judged tap/hold/tap with audio.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
