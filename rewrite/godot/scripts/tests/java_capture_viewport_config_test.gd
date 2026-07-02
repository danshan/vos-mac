extends SceneTree

const CAPTURE_SIZE := Vector2i(800, 600)


func _init() -> void:
	var config_script := _load_config_script()
	if config_script == null:
		return
	if not _test_project_disables_control_pixel_snap_by_default():
		return
	if not _test_java_capture_viewport_disables_control_pixel_snap(config_script):
		return
	quit(0)


func _load_config_script() -> Script:
	var script: Variant = load("res://scripts/java_capture_viewport_config.gd")
	if not script is Script or not script.can_instantiate():
		push_error("Expected Java capture viewport config script to load.")
		quit(1)
		return null
	return script


func _test_project_disables_control_pixel_snap_by_default() -> bool:
	if not ProjectSettings.has_setting("gui/common/snap_controls_to_pixels"):
		push_error("Expected project setting gui/common/snap_controls_to_pixels to be declared.")
		quit(1)
		return false
	return _expect_bool(
			bool(ProjectSettings.get_setting("gui/common/snap_controls_to_pixels")),
			false,
			"project control pixel snapping")


func _test_java_capture_viewport_disables_control_pixel_snap(config_script: Script) -> bool:
	var viewport := SubViewport.new()
	var config = config_script.new()
	config.configure_java_reference_viewport(viewport, CAPTURE_SIZE, 2)

	if not _expect_vector2i(viewport.size, CAPTURE_SIZE * 2, "Java capture viewport size"):
		return false
	if not _expect_bool(viewport.disable_3d, true, "Java capture viewport disables 3D"):
		return false
	if not _expect_bool(viewport.transparent_bg, false, "Java capture viewport opaque background"):
		return false
	if not _expect_int(viewport.render_target_update_mode, SubViewport.UPDATE_ALWAYS, "Java capture viewport update mode"):
		return false
	if not _expect_bool(viewport.gui_snap_controls_to_pixels, false, "Java capture viewport control pixel snapping"):
		return false

	viewport.free()
	return true


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


func _expect_vector2i(actual: Vector2i, expected: Vector2i, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true
