extends RefCounted

const ERROR_NOT_STARTED := "not_started"
const ERROR_NOT_DONE := "not_done"
const ERROR_THREAD_START_FAILED := "thread_start_failed"
const ERROR_INVALID_RESULT := "invalid_result"

var _thread: Thread = null
var _thread_started: bool = false
var _immediate_done: bool = false
var _immediate_result: Dictionary = {}
var _finished_result: Dictionary = {}
var _finished: bool = false


func start(command_path: String, arguments: PackedStringArray) -> void:
	if command_path.strip_edges().is_empty():
		complete_immediately({
			"ok": false,
			"exit_code": -1,
			"error": ERROR_NOT_STARTED,
		})
		return

	_thread = Thread.new()
	var error := _thread.start(_run_execute.bind(command_path, arguments))
	if error != OK:
		_thread = null
		complete_immediately({
			"ok": false,
			"exit_code": -1,
			"error": ERROR_THREAD_START_FAILED,
			"thread_error": error,
		})
		return
	_thread_started = true


func complete_immediately(result: Dictionary) -> void:
	_immediate_result = result.duplicate(true)
	_immediate_done = true
	_finished = false


func is_done() -> bool:
	if _finished or _immediate_done:
		return true
	if _thread == null or not _thread_started:
		return false
	return not _thread.is_alive()


func take_result() -> Dictionary:
	if _finished:
		return _finished_result.duplicate(true)
	if _immediate_done:
		_finished_result = _immediate_result.duplicate(true)
		_immediate_done = false
		_finished = true
		return _finished_result.duplicate(true)
	if _thread == null or not _thread_started:
		return {
			"ok": false,
			"exit_code": -1,
			"error": ERROR_NOT_STARTED,
		}
	if _thread.is_alive():
		return {
			"ok": false,
			"exit_code": -1,
			"error": ERROR_NOT_DONE,
		}

	var result: Variant = _thread.wait_to_finish()
	_thread = null
	_thread_started = false
	if result is Dictionary:
		_finished_result = result.duplicate(true)
	else:
		_finished_result = {
			"ok": false,
			"exit_code": -1,
			"error": ERROR_INVALID_RESULT,
		}
	_finished = true
	return _finished_result.duplicate(true)


func wait_for_finish() -> void:
	if _thread != null and _thread_started:
		var result: Variant = _thread.wait_to_finish()
		_thread = null
		_thread_started = false
		if result is Dictionary:
			_finished_result = result.duplicate(true)
		else:
			_finished_result = {
				"ok": false,
				"exit_code": -1,
				"error": ERROR_INVALID_RESULT,
			}
		_finished = true


func _run_execute(command_path: String, arguments: PackedStringArray) -> Dictionary:
	var output: Array = []
	var exit_code: int = OS.execute(command_path, arguments, output, true, false)
	return {
		"ok": exit_code == 0,
		"exit_code": exit_code,
		"output": output,
	}
