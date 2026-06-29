extends RefCounted

const ERROR_NOT_CONFIGURED := "not_configured"

var _java_path: String = ""
var _jar_path: String = ""


func configure(java_path: String, jar_path: String) -> void:
	_java_path = java_path
	_jar_path = jar_path


func is_configured() -> bool:
	return not _java_path.strip_edges().is_empty() and not _jar_path.strip_edges().is_empty()


func build_selected_export_arguments(out_dir: String, source_path: String) -> PackedStringArray:
	return PackedStringArray([
		"-jar",
		_jar_path,
		"--export-vos-selected",
		"--out-dir",
		out_dir,
		source_path,
	])


func export_selected(source_path: String, out_dir: String) -> Dictionary:
	if not is_configured():
		return {
			"ok": false,
			"exit_code": -1,
			"error": ERROR_NOT_CONFIGURED,
		}

	var output: Array = []
	var exit_code: int = OS.execute(_java_path, build_selected_export_arguments(out_dir, source_path), output, true, false)
	return {
		"ok": exit_code == 0,
		"exit_code": exit_code,
		"output": output,
	}
