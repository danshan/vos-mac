extends Node

const LoadJob = preload("res://scripts/native_load_job.gd")
signal loaded(generation: int, bundle: Dictionary)
signal failed(generation: int, error: Dictionary)
signal progressed(generation: int, event: Dictionary)

var _generation := 0
var _jobs: Array = []
var _active: Variant = null


func start_loading(converter: String, request: Dictionary, work_root: String) -> int:
	cancel_loading()
	var job = LoadJob.new()
	job.start(converter, request, work_root, _generation)
	_jobs.append(job)
	_active = job
	return _generation


func cancel_loading() -> void:
	_generation += 1
	if _active != null:
		_active.cancel()
	_active = null


func current_generation() -> int:
	return _generation


func pending_count() -> int:
	return _jobs.size()


func _process(_delta: float) -> void:
	for job: Variant in _jobs.duplicate():
		var current: bool = job == _active and job.generation == _generation
		if current:
			var progress: Dictionary = job.read_progress()
			if not progress.is_empty():
				progressed.emit(job.generation, progress)
		if not job.is_done():
			continue
		var result: Dictionary = job.take_result()
		_jobs.erase(job)
		# A progress callback may have cancelled or replaced the active generation.
		if job != _active or job.generation != _generation:
			continue
		_active = null
		if result.get("ok", false):
			loaded.emit(job.generation, result["bundle"])
		else:
			failed.emit(job.generation, result["error"])


func _exit_tree() -> void:
	cancel_loading()
	for job: Variant in _jobs:
		job.cancel()
	for job: Variant in _jobs:
		job.finish_on_shutdown()
	_jobs.clear()
