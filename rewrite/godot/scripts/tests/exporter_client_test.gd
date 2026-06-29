extends SceneTree

const ExporterClient = preload("res://scripts/exporter_client.gd")

func _init() -> void:
	var client = ExporterClient.new()
	client.configure("java", "target/open2jam.jar")

	var args: PackedStringArray = client.build_selected_export_arguments("build/vos", "charts/sample.vos")
	if not _expect_int(args.size(), 6, "selected export argument count"):
		return
	if not _expect_string(args[0], "-jar", "jar flag"):
		return
	if not _expect_string(args[1], "target/open2jam.jar", "jar path"):
		return
	if not _expect_string(args[2], "--export-vos-selected", "export flag"):
		return
	if not _expect_string(args[3], "--out-dir", "out dir flag"):
		return
	if not _expect_string(args[4], "build/vos", "out dir value"):
		return
	if not _expect_string(args[5], "charts/sample.vos", "source path value"):
		return

	var catalog_args: PackedStringArray = client.build_catalog_export_arguments("build/catalog.json", "charts")
	if not _expect_int(catalog_args.size(), 6, "catalog export argument count"):
		return
	if not _expect_string(catalog_args[2], "--export-vos-catalog", "catalog export flag"):
		return
	if not _expect_string(catalog_args[3], "--output", "catalog output flag"):
		return
	if not _expect_string(catalog_args[4], "build/catalog.json", "catalog output value"):
		return
	if not _expect_string(catalog_args[5], "charts", "catalog source path value"):
		return

	var unconfigured_client = ExporterClient.new()
	var result: Dictionary = unconfigured_client.export_selected("charts/sample.vos", "build/vos")
	if not _expect_bool(result.get("ok", true), false, "unconfigured run result"):
		return
	if not _expect_int(result.get("exit_code", 0), -1, "unconfigured exit code"):
		return
	if not _expect_string(result.get("error", ""), "not_configured", "unconfigured error"):
		return
	var catalog_result: Dictionary = unconfigured_client.export_catalog("charts", "build/catalog.json")
	if not _expect_bool(catalog_result.get("ok", true), false, "unconfigured catalog result"):
		return
	if not _expect_string(catalog_result.get("error", ""), "not_configured", "unconfigured catalog error"):
		return

	quit(0)


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
