extends Control


func _ready() -> void:
	var result := _probe()
	$Status.text = "Native helper ready" if result.ok else "Native helper failed"
	$Status.text += "\n" + JSON.stringify(result, "  ")
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--probe-output":
		var output := FileAccess.open(args[1], FileAccess.WRITE)
		if output == null:
			push_error("Cannot write probe result")
			get_tree().quit(1)
			return
		output.store_string(JSON.stringify(result) + "\n")
		output.close()
		get_tree().quit(0 if result.ok else 1)


func _probe() -> Dictionary:
	var helper := OS.get_executable_path().get_base_dir().path_join("../Helpers/open2jam-converter").simplify_path()
	if not FileAccess.file_exists(helper):
		return {"ok": false, "error": "Embedded helper is missing", "helper_path": helper}
	var resource_path := OS.get_executable_path().get_base_dir().path_join("../Resources/probe-resource.txt").simplify_path()
	if not FileAccess.file_exists(resource_path):
		return {"ok": false, "error": "Packaged resource is missing"}
	var resource := FileAccess.get_file_as_string(resource_path).strip_edges()
	if resource != "native-helper-probe-v1":
		return {"ok": false, "error": "Packaged resource is invalid"}
	var output: Array = []
	# The version-only packaging probe is deliberately separate from production loading.
	var exit_code := OS.execute(helper, ["version"], output, true)
	if exit_code != 0 or output.is_empty():
		return {"ok": false, "error": "Embedded helper failed", "exit_code": exit_code}
	var parsed: Variant = JSON.parse_string(str(output[0]))
	if not parsed is Dictionary or parsed.get("converterVersion") != "0.1.0":
		return {"ok": false, "error": "Embedded helper returned an invalid handshake"}
	return {"ok": true, "converter": parsed, "resource": resource, "helper_path": helper}
