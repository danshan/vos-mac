extends SceneTree

const MainUi = preload("res://scripts/main_ui.gd")

func _init() -> void:
	if not _expect_int(int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)), 1280, "viewport width"):
		return
	if not _expect_int(int(ProjectSettings.get_setting("display/window/size/viewport_height", 0)), 720, "viewport height"):
		return
	if not _expect_string(str(ProjectSettings.get_setting("display/window/stretch/mode", "")), "canvas_items", "stretch mode"):
		return
	if not _expect_string(str(ProjectSettings.get_setting("display/window/stretch/aspect", "")), "expand", "stretch aspect"):
		return

	var ui = MainUi.new()
	ui.build()

	if not _expect_bool(ui is Control, true, "main ui control"):
		return
	if not _expect_float(ui.anchor_right, 1.0, "main ui right anchor"):
		return
	if not _expect_float(ui.anchor_bottom, 1.0, "main ui bottom anchor"):
		return
	if not _expect_bool(ui.has_node("Background"), true, "background node"):
		return
	if not _expect_bool(ui.has_node("Content/Title"), true, "title node"):
		return
	if not _expect_bool(ui.has_node("Content/Menu/StartButton"), true, "start button"):
		return
	if not _expect_bool(ui.has_node("Content/Menu/SettingsButton"), true, "settings button"):
		return
	if not _expect_bool(ui.has_node("Content/Status"), true, "status label"):
		return

	var title: Label = ui.get_node("Content/Title")
	if not _expect_string(title.text, "Open2Jam VOS", "title text"):
		return

	var background: ColorRect = ui.get_node("Background")
	if not _expect_float(background.anchor_right, 1.0, "background right anchor"):
		return
	if not _expect_float(background.anchor_bottom, 1.0, "background bottom anchor"):
		return

	var content: VBoxContainer = ui.get_node("Content")
	if not _expect_float(content.anchor_right, 1.0, "content right anchor"):
		return
	if not _expect_float(content.anchor_bottom, 1.0, "content bottom anchor"):
		return

	ui.apply_layout_for_size(Vector2(1280.0, 720.0))
	var base_title_font: int = title.get_theme_font_size("font_size")
	var base_start_size: Vector2 = ui.get_node("Content/Menu/StartButton").custom_minimum_size
	var base_content_left: float = content.offset_left

	ui.apply_layout_for_size(Vector2(2560.0, 1440.0))
	var fullscreen_title_font: int = title.get_theme_font_size("font_size")
	var fullscreen_start_size: Vector2 = ui.get_node("Content/Menu/StartButton").custom_minimum_size
	var fullscreen_content_left: float = content.offset_left

	if not _expect_bool(fullscreen_title_font > base_title_font, true, "fullscreen title font grows"):
		return
	if not _expect_bool(fullscreen_start_size.x > base_start_size.x, true, "fullscreen button width grows"):
		return
	if not _expect_bool(fullscreen_start_size.y > base_start_size.y, true, "fullscreen button height grows"):
		return
	if not _expect_bool(fullscreen_content_left > base_content_left, true, "fullscreen content margin grows"):
		return

	var status: Label = ui.get_node("Content/Status")
	if not _expect_bool(status.text.is_empty(), false, "status text"):
		return

	var scene: PackedScene = load("res://scenes/main.tscn")
	var scene_root = scene.instantiate()
	if not _expect_bool(scene_root is Control, true, "main scene root control"):
		return
	if not _expect_bool(scene_root.has_method("build"), true, "main scene build method"):
		return
	scene_root.free()
	ui.free()

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


func _expect_float(actual: float, expected: float, label: String) -> bool:
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
