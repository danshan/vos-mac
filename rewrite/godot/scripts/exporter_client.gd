extends RefCounted

const SelectedExportJob = preload("res://scripts/selected_export_job.gd")

const ERROR_NOT_CONFIGURED := "not_configured"

var _java_path: String = ""
var _jar_path: String = ""
var _command_prefix_args: PackedStringArray = PackedStringArray()


func configure(java_path: String, jar_path: String) -> void:
	_java_path = java_path
	_jar_path = jar_path
	_command_prefix_args = PackedStringArray()


func configure_command(command_path: String, prefix_args: PackedStringArray, jar_path: String) -> void:
	_java_path = command_path
	_jar_path = jar_path
	_command_prefix_args = prefix_args


func configure_default(repo_root: String) -> bool:
	var env_java := OS.get_environment("OPEN2JAM_JAVA").strip_edges()
	var env_jar := OS.get_environment("OPEN2JAM_JAR").strip_edges()
	var jar_path := env_jar if not env_jar.is_empty() else _default_jar_path(repo_root)
	if jar_path.is_empty():
		return false

	if not env_java.is_empty():
		configure(env_java, jar_path)
		return true

	var launcher_path := _join_path(repo_root, "rewrite/tools/open2jam-java")
	if FileAccess.file_exists(launcher_path):
		configure_command("bash", PackedStringArray([launcher_path]), jar_path)
		return true

	configure("java", jar_path)
	return true


func is_configured() -> bool:
	return not _java_path.strip_edges().is_empty() and not _jar_path.strip_edges().is_empty()


func command_path() -> String:
	return _java_path


func build_selected_export_arguments(out_dir: String, source_path: String, chart_index: int = -1) -> PackedStringArray:
	var args := _base_export_arguments()
	args.append("--export-vos-selected")
	args.append("--out-dir")
	args.append(out_dir)
	if chart_index >= 0:
		args.append("--chart-index")
		args.append(str(chart_index))
	args.append(source_path)
	return args


func build_catalog_export_arguments(output_path: String, source_path: String) -> PackedStringArray:
	var args := _base_export_arguments()
	args.append("--export-vos-catalog")
	args.append("--output")
	args.append(output_path)
	args.append(source_path)
	return args


func export_catalog(source_path: String, output_path: String) -> Dictionary:
	if not is_configured():
		return {
			"ok": false,
			"exit_code": -1,
			"error": ERROR_NOT_CONFIGURED,
		}

	var output: Array = []
	var exit_code: int = OS.execute(_java_path, build_catalog_export_arguments(output_path, source_path), output, true, false)
	return {
		"ok": exit_code == 0,
		"exit_code": exit_code,
		"output": output,
	}


func _base_export_arguments() -> PackedStringArray:
	var args := PackedStringArray()
	for arg: String in _command_prefix_args:
		args.append(arg)
	args.append("-jar")
	args.append(_jar_path)
	return args


func _default_jar_path(repo_root: String) -> String:
	var target_dir := _join_path(repo_root, "target")
	var dir := DirAccess.open(target_dir)
	if dir == null:
		return ""

	var candidates: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() \
				and file_name.begins_with("open2jam-") \
				and file_name.ends_with(".jar") \
				and not file_name.begins_with("original-") \
				and not file_name.ends_with("-sources.jar") \
				and not file_name.ends_with("-javadoc.jar"):
			candidates.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	if candidates.is_empty():
		return ""
	candidates.sort()
	return _join_path(target_dir, candidates[candidates.size() - 1])


func _join_path(directory: String, file_name: String) -> String:
	if directory.ends_with("/") or directory.ends_with("\\"):
		return "%s%s" % [directory, file_name]
	return "%s/%s" % [directory, file_name]


func export_selected(source_path: String, out_dir: String, chart_index: int = -1) -> Dictionary:
	if not is_configured():
		return {
			"ok": false,
			"exit_code": -1,
			"error": ERROR_NOT_CONFIGURED,
		}

	var output: Array = []
	var exit_code: int = OS.execute(_java_path, build_selected_export_arguments(out_dir, source_path, chart_index),
			output, true, false)
	return {
		"ok": exit_code == 0,
		"exit_code": exit_code,
		"output": output,
	}


func export_selected_async(source_path: String, out_dir: String, chart_index: int = -1) -> Variant:
	var job = SelectedExportJob.new()
	if not is_configured():
		job.complete_immediately({
			"ok": false,
			"exit_code": -1,
			"error": ERROR_NOT_CONFIGURED,
		})
		return job

	job.start(_java_path, build_selected_export_arguments(out_dir, source_path, chart_index))
	return job
