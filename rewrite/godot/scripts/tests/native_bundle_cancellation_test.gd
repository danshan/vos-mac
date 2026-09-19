extends SceneTree

const Loader = preload("res://scripts/native_bundle_loader.gd")
const AudioPool = preload("res://scripts/audio_player_pool.gd")
const Options = preload("res://scripts/gameplay_loader.gd")
const Integrity = preload("res://scripts/native_bundle_integrity.gd")
const Wire = preload("res://scripts/native_json.gd")
var _checks := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		_fail("Expected a valid native bundle.")
		return
	var positive: Dictionary = Loader.new().load_bundle(args[0])
	if positive.is_empty():
		_fail("Positive control rejected the bundle.")
		return
	if not Loader.new().load_bundle(args[0], "", func(): return true).is_empty():
		_fail("Already cancelled load returned a bundle.")
		return
	_checks = 0
	if not Integrity.new().verify(args[0], "", _cancel_after_work_begins).is_empty() or _checks < 2:
		_fail("Cancellation after validation began was ignored.")
		return
	_checks = 0
	var text := '{"value":"' + "x".repeat(100000) + '"}'
	if not Wire.parse_object(text, _cancel_during_long_token).is_empty() or _checks < 5:
		_fail("Long JSON token ignored cancellation.")
		return
	if Wire.parse_object(text).get("value", "").length() != 100000:
		_fail("Uncancelled long JSON changed.")
		return
	_checks = 0
	var escaped := '{"text":"' + "\\\\".repeat(50000) + '"}'
	if not Wire.parse_object(escaped, _cancel_during_long_token).is_empty():
		_fail("Escaped JSON token skipped cancellation checkpoints.")
		return
	if Wire.parse_object(escaped).get("text", "").length() != 50000:
		_fail("Uncancelled escaped JSON changed.")
		return
	var pool = AudioPool.new()
	if not pool.load_manifest(positive["audio"], false) or pool.preloaded_sample_count() != 0:
		_fail("Deferred native audio registration decoded on the caller thread.")
		return
	pool.free()
	var chart: Dictionary = positive["chart"].duplicate(true)
	chart["notes"][0]["sampleId"] = 0
	chart["judgmentTiming"].append({"timeMs": 500.0, "bpm": 0.0})
	var configured: Dictionary = Options.new().load_native_chart_with_overrides(chart, {"channelModifier": "Mirror"})
	if configured.is_empty() or configured["notes"][0]["lane"] != 6 or configured["notes"][0]["sampleId"] != 0 or configured["judgmentTiming"][1]["bpm"] != 0.0:
		_fail("Native option normalization lost sampleless notes, stops or mirror settings.")
		return
	print("Native validation and JSON scanning honour cancellation without changing valid input.")
	quit(0)


func _cancel_after_work_begins() -> bool:
	_checks += 1
	return _checks > 1


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _cancel_during_long_token() -> bool:
	_checks += 1
	return _checks > 4
