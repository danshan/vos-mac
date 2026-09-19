extends SceneTree

const Coordinator = preload("res://scripts/native_load_coordinator.gd")
const Loader = preload("res://scripts/native_bundle_loader.gd")
var _bundle := {}
var _errors: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1].path_join("bundle.json")))
	var work: String = args[2].path_join("cache-test")
	var cache := work.path_join("artifacts-v2")
	DirAccess.make_dir_recursive_absolute(work.path_join("staging"))
	var request := {
		"schemaVersion": 1, "command": "BUNDLE", "chartId": manifest["chartId"],
		"sourceKind": "BUNDLE_V2", "sourcePath": args[1],
		"selector": {"kind": "BUNDLE_CHART", "chartId": manifest["chartId"]},
		"stagingRoot": work.path_join("staging"),
		"soundfont": {"path": work.path_join("unused.sf2"), "version": "2.0.3", "sha256": manifest["soundfont"]["sha256"]},
		"staticAssetsVersion": manifest["staticAssetsVersion"],
	}
	var coordinator = Coordinator.new()
	get_root().add_child(coordinator)
	coordinator.loaded.connect(func(_generation: int, bundle: Dictionary): _bundle = bundle)
	coordinator.failed.connect(func(_generation: int, error: Dictionary): _errors.append(error))
	coordinator.start_loading(args[0], request, work, cache)
	await _wait(coordinator)
	var published := cache.path_join(str(manifest["bundleKey"]).trim_prefix("sha256:"))
	if _bundle.is_empty() or not _errors.is_empty() or Loader.new().load_bundle(published).is_empty():
		_fail("Verified native output was not atomically published.")
		return
	for asset: Dictionary in _bundle["audio"]["assets"]:
		if not str(asset["path"]).begins_with(published + "/") or not FileAccess.file_exists(asset["path"]):
			_fail("Published gameplay still references job staging.")
			return
	_bundle = {}
	# A valid hit needs no converter process; source and cached bytes must still validate.
	coordinator.start_loading(work.path_join("missing-converter"), request, work, cache)
	await _wait(coordinator)
	if _bundle.is_empty() or not _errors.is_empty():
		_fail("Valid cache hit required conversion.")
		return
	for damage: String in ["hash", "size", "missing"]:
		var asset_path: String = _bundle["audio"]["assets"][0]["path"]
		var bytes := FileAccess.get_file_as_bytes(asset_path)
		if damage == "missing":
			DirAccess.remove_absolute(asset_path)
		else:
			if damage == "hash":
				bytes[bytes.size() - 1] ^= 1
			else:
				bytes.resize(bytes.size() - 1)
			var file := FileAccess.open(asset_path, FileAccess.WRITE)
			file.store_buffer(bytes)
			file.close()
		_bundle = {}
		coordinator.start_loading(args[0], request, work, cache)
		await _wait(coordinator)
		if _bundle.is_empty() or not _errors.is_empty() or Loader.new().load_bundle(published).is_empty():
			_fail("Corrupt cache was not rebuilt: " + damage)
			return
	coordinator.free()
	print("Native artifact cache published validated output and reused a verified hit.")
	quit(0)


func _wait(coordinator: Node) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while coordinator.pending_count() > 0 and Time.get_ticks_msec() < deadline:
		await process_frame


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
