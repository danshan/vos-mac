extends SceneTree

const SelectedExportJob = preload("res://scripts/selected_export_job.gd")


func _init() -> void:
	if not _test_process_runs_without_blocking_until_completion():
		return
	if not _test_failed_process_reports_exit_code():
		return
	quit(0)


func _test_process_runs_without_blocking_until_completion() -> bool:
	var job = SelectedExportJob.new()
	job.start("/bin/sh", PackedStringArray(["-c", "sleep 0.2; printf selected-export-ok"]))
	if not _expect_bool(job.is_done(), false, "job pending immediately after start"):
		job.wait_for_finish()
		return false

	OS.delay_msec(300)
	if not _expect_bool(job.is_done(), true, "job done after process exits"):
		job.wait_for_finish()
		return false

	var result := job.take_result()
	if not _expect_bool(bool(result.get("ok", false)), true, "successful process result"):
		return false
	if not _expect_int(int(result.get("exit_code", -1)), 0, "successful process exit code"):
		return false
	if not _expect_string(_joined_output(result), "selected-export-ok", "successful process output"):
		return false
	return true


func _test_failed_process_reports_exit_code() -> bool:
	var job = SelectedExportJob.new()
	job.start("/bin/sh", PackedStringArray(["-c", "printf selected-export-fail; exit 7"]))

	var attempts := 0
	while not job.is_done() and attempts < 20:
		OS.delay_msec(25)
		attempts += 1

	if not _expect_bool(job.is_done(), true, "failed process completes"):
		job.wait_for_finish()
		return false

	var result := job.take_result()
	if not _expect_bool(bool(result.get("ok", true)), false, "failed process result"):
		return false
	if not _expect_int(int(result.get("exit_code", -1)), 7, "failed process exit code"):
		return false
	if not _expect_string(_joined_output(result), "selected-export-fail", "failed process output"):
		return false
	return true


func _joined_output(result: Dictionary) -> String:
	var lines: Variant = result.get("output", [])
	if not lines is Array:
		return str(lines)
	var text := ""
	for line: Variant in lines:
		text += str(line)
	return text


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


func _expect_string(actual: String, expected: String, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true
