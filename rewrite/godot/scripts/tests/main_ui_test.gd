extends SceneTree

const MainUi = preload("res://scripts/main_ui.gd")

func _init() -> void:
	var ui = MainUi.new()
	ui.build()

	if not _expect_bool(ui is Control, true, "main ui control"):
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


func _expect_string(actual: String, expected: String, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true
