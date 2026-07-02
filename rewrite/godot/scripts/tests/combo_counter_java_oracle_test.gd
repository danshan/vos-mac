extends SceneTree

const GameplayView = preload("res://scripts/gameplay_view.gd")
const RenderEntityModel = preload("res://scripts/render_entity_model.gd")


func _init() -> void:
	var oracle := _load_oracle()
	if oracle.is_empty():
		return

	var model = RenderEntityModel.new()
	var metadata := model.load_from_file("res://test/fixtures/render-metadata.json")
	if metadata.is_empty():
		push_error("Expected render metadata fixture to load.")
		quit(1)
		return

	var view = GameplayView.new()
	if not _expect_bool(view.load_metadata(metadata), true, "view metadata load"):
		return

	var steps: Variant = oracle.get("steps")
	if not steps is Array:
		push_error("Expected combo counter oracle steps.")
		quit(1)
		return

	for raw_step: Variant in steps:
		if not raw_step is Dictionary:
			push_error("Expected combo counter oracle step object.")
			quit(1)
			return
		if not _verify_step(view, raw_step):
			return

	view.free()
	quit(0)


func _load_oracle() -> Dictionary:
	var path := "res://test/fixtures/combo-counter-oracle.json"
	if not FileAccess.file_exists(path):
		push_error("Missing combo counter oracle fixture: %s" % path)
		quit(1)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Expected combo counter oracle root object.")
		quit(1)
		return {}
	var root: Dictionary = parsed
	if int(root.get("schemaVersion", 0)) != 1:
		push_error("Expected combo counter oracle schema version 1.")
		quit(1)
		return {}
	if str(root.get("source", "")) != "ComboCounterEntity.draw":
		push_error("Expected combo counter oracle source ComboCounterEntity.draw.")
		quit(1)
		return {}
	return root


func _verify_step(view: Node, step: Dictionary) -> bool:
	view.update_hud_state({
		"elapsedMs": float(step.get("elapsedMs", 0.0)),
		"combo": int(step.get("comboValue", 0)),
	})

	var container: Control = view.get_node("HudSprite_COMBO_COUNTER")
	if not bool(step.get("visible", false)):
		if not _expect_int(container.get_child_count(), 0, "%s hidden child count" % step.get("name", "")):
			return false
		if not _expect_string(view.get_node("Hud_COMBO_COUNTER").text,
				str(step.get("displayedText", "")),
				"%s hidden text" % step.get("name", "")):
			return false
		return true

	var digits: Variant = step.get("digits")
	if not digits is Array:
		push_error("Expected combo counter oracle digit array.")
		quit(1)
		return false

	if not _expect_string(view.get_node("Hud_COMBO_COUNTER").text,
			str(step.get("displayedText", "")),
			"%s displayed text" % step.get("name", "")):
		return false
	if not _expect_int(container.get_child_count(), digits.size() + 1,
			"%s digit plus title child count" % step.get("name", "")):
		return false

	for i in range(digits.size()):
		var digit_step: Dictionary = digits[i]
		var digit: Control = container.get_node("Digit_%03d" % i)
		if not _expect_float(digit.position.x, float(digit_step.get("x", 0.0)),
				"%s digit %d x" % [step.get("name", ""), i]):
			return false
		if not _expect_float(digit.position.y, float(digit_step.get("y", 0.0)),
				"%s digit %d y" % [step.get("name", ""), i]):
			return false

	var title_steps: Variant = step.get("title")
	if not title_steps is Array or title_steps.is_empty():
		push_error("Expected combo counter oracle title draw.")
		quit(1)
		return false
	var title_step: Dictionary = title_steps[0]
	var title: Control = container.get_node("Title")
	if not _expect_float(title.position.x, float(title_step.get("x", 0.0)),
			"%s title x" % step.get("name", "")):
		return false
	if not _expect_float(title.position.y, float(title_step.get("y", 0.0)),
			"%s title y" % step.get("name", "")):
		return false
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


func _expect_float(actual: float, expected: float, label: String) -> bool:
	if absf(actual - expected) > 0.0001:
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
