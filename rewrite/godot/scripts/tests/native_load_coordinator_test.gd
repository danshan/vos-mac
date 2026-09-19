extends SceneTree

const Coordinator = preload("res://scripts/native_load_coordinator.gd")
const Runtime = preload("res://scripts/gameplay_runtime.gd")
var _ready_generations: Array[int] = []
var _errors: Array = []
var _bundle := {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		_fail("Expected converter, bundle and work root.")
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[1].path_join("bundle.json")))
	var request := {
		"schemaVersion": 1, "command": "BUNDLE", "chartId": manifest["chartId"],
		"sourceKind": "BUNDLE_V2", "sourcePath": args[1],
		"selector": {"kind": "BUNDLE_CHART", "chartId": manifest["chartId"]},
		"stagingRoot": args[2].path_join("staging"),
		"soundfont": {"path": args[2].path_join("unused.sf2"), "version": "2.0.3", "sha256": manifest["soundfont"]["sha256"]},
		"staticAssetsVersion": manifest["staticAssetsVersion"],
	}
	DirAccess.make_dir_absolute(request["stagingRoot"])
	var coordinator = Coordinator.new()
	get_root().add_child(coordinator)
	coordinator.loaded.connect(func(generation: int, bundle: Dictionary):
		_ready_generations.append(generation)
		_bundle = bundle)
	coordinator.failed.connect(func(generation: int, error: Dictionary): _errors.append([generation, error]))
	var first: int = coordinator.start_loading(args[0], request, args[2])
	coordinator.cancel_loading()
	var current: int = coordinator.start_loading(args[0], request, args[2])
	var frames := 0
	var deadline := Time.get_ticks_msec() + 15000
	while coordinator.pending_count() > 0 and Time.get_ticks_msec() < deadline:
		frames += 1
		await process_frame
	if coordinator.pending_count() != 0 or not _errors.is_empty() or _ready_generations != [current] or current <= first:
		_fail("Cancelled generation leaked or current load did not finish: %s %s" % [_ready_generations, _errors])
		return
	if frames < 2:
		_fail("Load did not yield to frame processing.")
		return
	var runtime = Runtime.new()
	get_root().add_child(runtime)
	if not runtime.start(_bundle["chart"], _bundle["audio"]) or not runtime.is_running():
		_fail("Current async load did not reach gameplay.")
		return
	runtime.stop()
	runtime.free()
	var old_progress: Array = []
	coordinator.progressed.connect(func(generation: int, _event: Dictionary): old_progress.append(generation))
	for helper_name: String in ["late-helper", "hang-helper", "marker-error-helper"]:
		var retired: int = coordinator.start_loading(args[2].path_join(helper_name), request, args[2])
		deadline = Time.get_ticks_msec() + 5000
		while not FileAccess.file_exists(args[2].path_join(helper_name + ".ready")) and Time.get_ticks_msec() < deadline:
			await process_frame
		if not FileAccess.file_exists(args[2].path_join(helper_name + ".ready")):
			_fail("Controlled helper did not start.")
			return
		var cancelled_at := Time.get_ticks_msec()
		coordinator.cancel_loading()
		current = coordinator.start_loading(args[0], request, args[2])
		deadline = Time.get_ticks_msec() + 5000
		frames = 0
		while coordinator.pending_count() > 0 and Time.get_ticks_msec() < deadline:
			frames += 1
			await process_frame
		if coordinator.pending_count() != 0 or _ready_generations.has(retired) or old_progress.has(retired) or not _errors.is_empty() or _ready_generations.back() != current:
			_fail("Late helper data affected the current generation or helper was not reclaimed.")
			return
		if frames < 2 or Time.get_ticks_msec() - cancelled_at > 4000:
			_fail("Cancelled helper blocked frames or exceeded reclamation deadline.")
			return

	var changed := request.duplicate(true)
	changed["chartId"] = "chart:sha256:" + "0".repeat(64)
	changed["selector"]["chartId"] = changed["chartId"]
	coordinator.start_loading(args[0], changed, args[2])
	deadline = Time.get_ticks_msec() + 5000
	while coordinator.pending_count() > 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	if _errors.size() != 1 or _errors[0][1].get("code") != "SOURCE_CHANGED":
		_fail("Native structured failure code was lost.")
		return
	coordinator.free()
	print("Async native loading yielded frames, discarded cancelled generation and started current gameplay.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
