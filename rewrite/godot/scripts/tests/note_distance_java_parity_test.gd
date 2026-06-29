extends SceneTree

const NoteDistanceCalculator = preload("res://scripts/note_distance_calculator.gd")
const TimingModel = preload("res://scripts/timing_model.gd")


func _init() -> void:
	var timing = TimingModel.new()
	timing.add_change(0.0, 120.0)
	timing.add_change(1000.0, 240.0)
	timing.finish()

	if not _expect_float(timing.get_beat(-500.0), -1.0, "beat before first change"):
		return
	if not _expect_float(timing.get_beat(0.0), 0.0, "beat at first change"):
		return
	if not _expect_float(timing.get_beat(500.0), 1.0, "beat before bpm change"):
		return
	if not _expect_float(timing.get_beat(1000.0), 2.0, "beat at bpm change"):
		return
	if not _expect_float(timing.get_beat(1500.0), 4.0, "beat after bpm change"):
		return

	var calculator = NoteDistanceCalculator.new(timing)

	if not _expect_float(calculator.calculate_hi_speed(0.0, 1000.0, 2.0), 385.0, "hi speed distance"):
		return
	if not _expect_float(calculator.calculate_hi_speed(500.0, 1500.0, 1.5), 433.125, "hi speed with bpm change"):
		return
	if not _expect_float(calculator.calculate_regul_speed(0.0, 1000.0, 2.0), 481.25, "regul speed distance"):
		return

	calculator.speed_factor = 1.25
	if not _expect_float(calculator.calculate_hi_speed(0.0, 1000.0, 2.0), 481.25, "adjusted hi speed distance"):
		return
	calculator.speed_factor = 1.0

	if not _expect_bool(calculator.has_method("calculate_w_speed"), true, "w speed distance method"):
		return
	if not _expect_bool(calculator.has_method("update_w_speed"), true, "w speed update method"):
		return
	if not _expect_float(calculator.calculate_w_speed(0.0, 1000.0), 96.25, "initial w speed distance"):
		return
	calculator.update_w_speed(1000.0, 2.0)
	if not _expect_float(calculator.calculate_w_speed(0.0, 1000.0), 192.5, "updated w speed distance"):
		return

	quit(0)


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
