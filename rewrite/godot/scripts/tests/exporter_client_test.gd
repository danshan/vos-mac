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

	var indexed_args: PackedStringArray = client.build_selected_export_arguments("build/ojn", "charts/sample.ojn", 2)
	if not _expect_int(indexed_args.size(), 8, "indexed selected export argument count"):
		return
	if not _expect_string(indexed_args[5], "--chart-index", "chart index flag"):
		return
	if not _expect_string(indexed_args[6], "2", "chart index value"):
		return
	if not _expect_string(indexed_args[7], "charts/sample.ojn", "indexed source path value"):
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

	OS.set_environment("OPEN2JAM_JAVA", "")
	OS.set_environment("OPEN2JAM_JAR", "")

	var default_root := _fake_repo_root()
	var default_client = ExporterClient.new()
	if not _expect_bool(default_client.configure_default(default_root), true, "default exporter configured"):
		return
	if not _expect_bool(default_client.is_configured(), true, "default exporter configured state"):
		return
	if not _expect_string(default_client.command_path(), "bash", "default exporter command"):
		return
	var default_catalog_args: PackedStringArray = default_client.build_catalog_export_arguments("build/catalog.json", "charts")
	if not _expect_string(default_catalog_args[0], _join_path(default_root, "rewrite/tools/open2jam-java"), "default launcher arg"):
		return
	if not _expect_string(default_catalog_args[1], "-jar", "default jar flag"):
		return
	if not _expect_string(default_catalog_args[2], _join_path(default_root, "target/open2jam-0.1.2.jar"), "default jar path"):
		return
	if not _expect_string(default_catalog_args[4], "--output", "default catalog output flag"):
		return

	quit(0)


func _fake_repo_root() -> String:
	var root := _join_path(OS.get_temp_dir(), "open2jam_exporter_client_test")
	DirAccess.make_dir_recursive_absolute(_join_path(root, "target"))
	DirAccess.make_dir_recursive_absolute(_join_path(root, "rewrite/tools"))
	var jar := FileAccess.open(_join_path(root, "target/open2jam-0.1.2.jar"), FileAccess.WRITE)
	if jar != null:
		jar.store_string("fake")
	var launcher := FileAccess.open(_join_path(root, "rewrite/tools/open2jam-java"), FileAccess.WRITE)
	if launcher != null:
		launcher.store_string("#!/usr/bin/env bash\n")
	return root


func _join_path(directory: String, file_name: String) -> String:
	if directory.ends_with("/") or directory.ends_with("\\"):
		return "%s%s" % [directory, file_name]
	return "%s/%s" % [directory, file_name]


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
