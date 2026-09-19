extends RefCounted

const Wire = preload("res://scripts/native_json.gd")
const Integrity = preload("res://scripts/native_bundle_integrity.gd")
const Loader = preload("res://scripts/native_bundle_loader.gd")
const CatalogLoader = preload("res://scripts/native_catalog_loader.gd")
const ArtifactCache = preload("res://scripts/native_artifact_cache.gd")
const CANCEL_GRACE_MS := 1000

var _command := "BUNDLE"
var cache_root := ""
var generation: int
var job_id: String
var _directory := ""
var _owns_directory := false
var _thread: Thread
var _immediate := {}
var _cancelled := false
var _cancel_mutex := Mutex.new()
var _progress_offset := 0
var _progress_pending := PackedByteArray()
var _sequence := 0
var _progress_invalid := false


func start(converter: String, template: Dictionary, work_root: String, load_generation: int, artifact_root: String = "") -> void:
	_command = str(template.get("command", "BUNDLE"))
	cache_root = artifact_root
	generation = load_generation
	if not cache_root.is_empty():
		var parent := DirAccess.open(cache_root.get_base_dir())
		if not cache_root.is_absolute_path() or parent == null or parent.is_link(cache_root.get_file()):
			_immediate = _failure("INVALID_REQUEST", "Cache root must be an owned absolute directory, not a link.")
			return
	job_id = "load-" + Crypto.new().generate_random_bytes(16).hex_encode()
	_directory = work_root.path_join(job_id)
	if not work_root.is_absolute_path() or DirAccess.make_dir_absolute(_directory) != OK:
		_immediate = _failure("INTERNAL_ERROR", "Unable to allocate private job transport.")
		return
	_owns_directory = true
	var request := template.duplicate(true)
	request["jobId"] = job_id
	request["cancelMarkerPath"] = _directory.path_join("cancel")
	var file := FileAccess.open(_directory.path_join("request.json"), FileAccess.WRITE)
	if file == null:
		_immediate = _failure("INTERNAL_ERROR", "Unable to write native request.")
		return
	file.store_string(JSON.stringify(request))
	file.close()
	_thread = Thread.new()
	if _thread.start(_run.bind(converter, request, _directory)) != OK:
		_thread = null
		_immediate = _failure("INTERNAL_ERROR", "Unable to start native worker.")


func cancel() -> void:
	_cancel_mutex.lock()
	_cancelled = true
	_cancel_mutex.unlock()
	if _owns_directory:
		var marker := FileAccess.open(_directory.path_join("cancel"), FileAccess.WRITE)
		if marker != null:
			marker.close()


func _cancellation_requested() -> bool:
	_cancel_mutex.lock()
	var requested := _cancelled
	_cancel_mutex.unlock()
	return requested


func is_done() -> bool:
	return _thread == null or not _thread.is_alive()


func take_result() -> Dictionary:
	if not is_done():
		return {}
	var result := _immediate
	if _thread != null:
		result = _thread.wait_to_finish()
		_thread = null
		_immediate = result
	if _progress_invalid:
		return _failure("INVALID_REQUEST", "Invalid native progress stream.")
	return _failure("CANCELLED", "Load generation cancelled.") if _cancelled else result


func finish_on_shutdown() -> void:
	cancel()
	if _thread != null:
		_immediate = _thread.wait_to_finish()
		_thread = null


func progress_complete() -> bool:
	if _progress_invalid:
		return true
	var path := _directory.path_join("progress.jsonl")
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() < _progress_offset:
			_progress_invalid = true
			return true
		if file.get_length() > _progress_offset:
			return false
	if not _progress_pending.is_empty():
		_progress_invalid = true
	return true


func read_progress() -> Dictionary:
	if _cancelled or _progress_invalid:
		return {}
	var path := _directory.path_join("progress.jsonl")
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < _progress_offset:
		_progress_invalid = true
		return {}
	file.seek(_progress_offset)
	var bytes := file.get_buffer(mini(16384, file.get_length() - _progress_offset))
	_progress_offset += bytes.size()
	_progress_pending.append_array(bytes)
	var latest := {}
	while true:
		var end := _progress_pending.find(10)
		if end < 0:
			break
		var line := _progress_pending.slice(0, end)
		_progress_pending = _progress_pending.slice(end + 1)
		if line.get_string_from_utf8().to_utf8_buffer() != line:
			_progress_invalid = true
			return {}
		var event := Wire.parse_object(line.get_string_from_utf8())
		if not Wire.fields(event, ["schemaVersion", "jobId", "sequence", "command", "phase", "completedUnits", "totalUnits", "unit", "currentItem"]) or event.get("schemaVersion") != 1 or event.get("jobId") != job_id or event.get("command") != _command or event.get("sequence") != _sequence + 1:
			_progress_invalid = true
			return {}
		var phases := ["DISCOVER_SOURCES", "FINGERPRINT_SOURCES", "PARSE_SOURCES", "WRITE_CATALOG", "CATALOG_READY"] if _command == "CATALOG" else ["HASH_SOURCES", "PARSE_CHART", "COMPILE_TIMING", "PREPARE_AUDIO", "WRITE_BUNDLE", "VERIFY_BUNDLE"]
		if not event["phase"] in phases or not Wire.integer(event["completedUnits"]) or not Wire.integer(event["totalUnits"]) or event["completedUnits"] > event["totalUnits"]:
			_progress_invalid = true
			return {}
		if not Wire.text(event["unit"], true) or (event["currentItem"] != null and not Wire.text(event["currentItem"])):
			_progress_invalid = true
			return {}
		_sequence += 1
		latest = event
	if _progress_pending.size() > 65536:
		_progress_invalid = true
		return {}
	return latest


# Only this worker owns the PID. A live child is never reaped by another thread
# between the running check and kill; retired generations retain their worker.
func _run(converter: String, request: Dictionary, directory: String) -> Dictionary:
	var cancel_path: String = request["cancelMarkerPath"]
	if _cancellation_requested() or FileAccess.file_exists(cancel_path):
		return _failure("CANCELLED", "Cancelled before helper startup.")
	var replace_key := ""
	if not cache_root.is_empty():
		var cached: Dictionary = ArtifactCache.new().lookup(cache_root, request, _cancellation_requested)
		if cached.has("bundle"):
			return {"ok": true, "bundle": cached["bundle"]}
		if cached.get("conflict", false):
			return _failure("CACHE_CORRUPT", "Valid cache and source disagree under the same bundle key.")
		replace_key = cached.get("replaceKey", "")
		if _cancellation_requested():
			return _failure("CANCELLED", "Cancelled during cache validation.")
	var child := OS.execute_with_pipe(converter, [_command.to_lower(), "--request", directory.path_join("request.json"), "--progress", directory.path_join("progress.jsonl"), "--result", directory.path_join("result.json")], false)
	if child.is_empty():
		return _failure("CONVERTER_CRASHED", "Unable to start native helper.")
	var pid: int = child["pid"]
	var cancellation_started: int = -1
	var forced := false
	while OS.is_process_running(pid):
		# Drain both non-blocking pipes with a fixed memory/work budget.
		for stream: String in ["stdio", "stderr"]:
			child[stream].get_buffer(16384)
		if _cancellation_requested() or FileAccess.file_exists(cancel_path):
			if cancellation_started < 0:
				cancellation_started = Time.get_ticks_msec()
			if Time.get_ticks_msec() - cancellation_started >= CANCEL_GRACE_MS:
				if OS.kill(pid) == OK:
					forced = true
					break
		OS.delay_msec(5)
	var exit_code := -1 if forced else OS.get_process_exit_code(pid)
	for stream: String in ["stdio", "stderr"]:
		child[stream].close()
	if forced or cancellation_started >= 0 or _cancellation_requested() or FileAccess.file_exists(cancel_path):
		return _failure("CANCELLED", "Native helper cancelled and reaped.")
	var result: Dictionary = Integrity.new().read_json(directory.path_join("result.json"), 1048576)
	if not Wire.fields(result, ["schemaVersion", "jobId", "command", "status", "output", "error"]) or result["schemaVersion"] != 1 or result["jobId"] != request["jobId"] or result["command"] != _command:
		return _failure("CONVERTER_CRASHED", "Native result is absent or does not belong to this job.")
	if exit_code != 0 or result["status"] != "SUCCEEDED":
		return _native_failure(result, exit_code)
	var output: Variant = result["output"]
	var expected_path: String = str(request["stagingRoot"]).path_join(request["jobId"])
	if _command == "CATALOG":
		var catalog_path := expected_path.path_join("catalog-v2.json")
		if result["error"] != null or not Wire.fields(output, ["catalogPath", "sourceCount", "songCount", "chartCount", "rejectedSourceCount"]) or output["catalogPath"] != catalog_path:
			return _failure("CACHE_CORRUPT", "Native catalog does not match job ownership.")
		for count_name: String in ["sourceCount", "songCount", "chartCount", "rejectedSourceCount"]:
			if not Wire.integer(output[count_name]):
				return _failure("CACHE_CORRUPT", "Invalid native catalog count.")
		var catalog: Dictionary = CatalogLoader.new().load_catalog(catalog_path, request["roots"], _cancellation_requested, request.get("rootIds", {}))
		if catalog.is_empty():
			return _failure("CACHE_CORRUPT", "Invalid native catalog snapshot.")
		var count: int = catalog["entries"].size()
		var rejected: int = catalog["errors"].size()
		if output["sourceCount"] != count + rejected or output["songCount"] != count or output["chartCount"] != count or output["rejectedSourceCount"] != rejected:
			return _failure("CACHE_CORRUPT", "Native catalog counts disagree with its snapshot.")
		return {"ok": true, "catalog": catalog}
	if result["error"] != null or not Wire.fields(output, ["stagingPath", "bundleKey", "manifestPath"]) or output["stagingPath"] != expected_path or output["manifestPath"] != expected_path.path_join("bundle.json") or not Wire.identifier(output["bundleKey"], "sha256:"):
		return _failure("CACHE_CORRUPT", "Native output does not match job staging ownership.")
	var bundle: Dictionary = Loader.new().load_bundle(expected_path, output["bundleKey"], _cancellation_requested)
	if _cancellation_requested() or FileAccess.file_exists(cancel_path):
		return _failure("CANCELLED", "Cancelled while validating native output.")
	if bundle.is_empty() or bundle["chart"]["chartId"] != request["chartId"]:
		return _failure("CACHE_CORRUPT", "Native bundle validation failed.")
	return {"ok": true, "bundle": bundle, "stagingPath": expected_path, "replaceKey": replace_key}


static func _failure(code: String, message: String) -> Dictionary:
	return {"ok": false, "error": {"code": code, "message": message}}


static func _native_failure(result: Dictionary, exit_code: int) -> Dictionary:
	var error: Variant = result["error"]
	if result["output"] != null or not Wire.fields(error, ["code", "message", "sourcePath", "context"]):
		return _failure("CONVERTER_CRASHED", "Invalid native failure envelope.")
	if not error["code"] in ["UNSUPPORTED_FORMAT", "CORRUPT_CHART", "MISSING_COMPANION", "MISSING_ASSET", "AUDIO_DECODE_FAILED", "SOUNDFONT_FAILED", "OUT_OF_SPACE", "CACHE_CORRUPT", "CONVERTER_CRASHED", "CANCELLED", "INTERNAL_ERROR", "INVALID_REQUEST", "UNSUPPORTED_SCHEMA", "SOURCE_CHANGED"] or not Wire.text(error["message"]) or not error["context"] is Dictionary:
		return _failure("CONVERTER_CRASHED", "Invalid native error information.")
	if result["status"] == "CANCELLED" and exit_code == 3 and error["code"] == "CANCELLED":
		return {"ok": false, "error": error}
	if result["status"] == "FAILED" and exit_code in [1, 2, 4]:
		return {"ok": false, "error": error}
	return _failure("CONVERTER_CRASHED", "Native status and exit code disagree.")
