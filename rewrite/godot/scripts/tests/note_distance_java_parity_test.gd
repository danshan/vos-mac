extends SceneTree

const NoteDistanceCalculator = preload("res://scripts/note_distance_calculator.gd")
const TimingModel = preload("res://scripts/timing_model.gd")


func _init() -> void:
	var oracle: Dictionary = _load_oracle()
	if oracle.is_empty():
		return

	var timing = TimingModel.new()
	for change in oracle.get("timingChanges", []):
		if not change is Dictionary:
			push_error("Expected note distance timing change object.")
			quit(1)
			return
		timing.add_change(float(change.get("timeMs", 0.0)), float(change.get("bpm", 120.0)))
	timing.finish()

	for beat_case in oracle.get("beatCases", []):
		if not beat_case is Dictionary:
			push_error("Expected note distance beat case object.")
			quit(1)
			return
		if not _expect_float(
				timing.get_beat(float(beat_case.get("timeMs", 0.0))),
				float(beat_case.get("expectedBeat", 0.0)),
				"beat at %.1fms" % float(beat_case.get("timeMs", 0.0))):
			return

	for distance_case in oracle.get("distanceCases", []):
		if not distance_case is Dictionary:
			push_error("Expected note distance case object.")
			quit(1)
			return
		if not _verify_distance_case(timing, float(oracle.get("measureSize", 385.0)), distance_case):
			return

	quit(0)


func _load_oracle() -> Dictionary:
	var path := "res://test/fixtures/note-distance-oracle.json"
	if not FileAccess.file_exists(path):
		push_error("Missing note distance oracle fixture: %s" % path)
		quit(1)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Expected note distance oracle root object.")
		quit(1)
		return {}

	var root: Dictionary = parsed
	if int(root.get("schemaVersion", 0)) != 1:
		push_error("Expected note distance oracle schema version 1.")
		quit(1)
		return {}
	if str(root.get("source", "")) != "NoteDistanceCalculator Java speed modes":
		push_error("Expected note distance oracle source NoteDistanceCalculator Java speed modes.")
		quit(1)
		return {}
	return root


func _verify_distance_case(timing, measure_size: float, distance_case: Dictionary) -> bool:
	var calculator = NoteDistanceCalculator.new(timing, measure_size)
	calculator.speed_factor = float(distance_case.get("speedFactor", 1.0))
	var mode := str(distance_case.get("mode", ""))
	if mode == "xRSpeed":
		calculator.set_xr_speed_factors(distance_case.get("xrFactors", []))
	for update in distance_case.get("updates", []):
		if not update is Dictionary:
			push_error("Expected note distance update object.")
			quit(1)
			return false
		calculator.update_w_speed(float(update.get("deltaMs", 0.0)), float(update.get("targetSpeed", 1.0)))

	var now_ms := float(distance_case.get("nowMs", 0.0))
	var target_ms := float(distance_case.get("targetMs", 0.0))
	var speed := float(distance_case.get("speed", 1.0))
	var lane := int(distance_case.get("lane", -1))
	var actual := 0.0
	match mode:
		"HiSpeed":
			actual = calculator.calculate_hi_speed(now_ms, target_ms, speed)
		"RegulSpeed":
			actual = calculator.calculate_regul_speed(now_ms, target_ms, speed)
		"WSpeed":
			actual = calculator.calculate_w_speed(now_ms, target_ms)
		"xRSpeed":
			actual = calculator.calculate_xr_speed(now_ms, target_ms, speed, lane)
		_:
			push_error("Unknown note distance mode: %s" % mode)
			quit(1)
			return false

	return _expect_float(actual, float(distance_case.get("expectedDistance", 0.0)),
			str(distance_case.get("name", mode)))


func _expect_float(actual: float, expected: float, label: String) -> bool:
	if absf(actual - expected) > 0.0001:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true


func _expect_bool(actual: bool, expected: bool, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true
