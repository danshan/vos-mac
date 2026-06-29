extends SceneTree

const GameplayView = preload("res://scripts/gameplay_view.gd")
const GameplayLoader = preload("res://scripts/gameplay_loader.gd")
const RenderEntityModel = preload("res://scripts/render_entity_model.gd")


func _init() -> void:
	var model = RenderEntityModel.new()
	var metadata: Dictionary = model.load_from_file("res://test/fixtures/render-metadata.json")
	if metadata.is_empty():
		push_error("Expected render metadata fixture to load.")
		quit(1)
		return

	if not _expect_float(metadata.get("baseWidth", 0.0), 800.0, "base width"):
		return
	if not _expect_float(metadata.get("baseHeight", 0.0), 600.0, "base height"):
		return
	if not _expect_float(metadata.get("measureSize", 0.0), 385.0, "measure size"):
		return
	if not _expect_int(metadata.get("judgmentLine", 0), 480, "judgment line"):
		return

	var entities: Array = metadata.get("entities", [])
	if not _expect_int(entities.size(), 66, "full Java skin entity count"):
		return
	if not _expect_string(entities[0].get("id", ""), "BGA", "first entity id"):
		return
	if not _expect_bool(_entity_by_id(entities, "JUDGMENT_LINE").is_empty(), false, "judgment line entity exists"):
		return
	if not _expect_bool(_entity_by_id(entities, "LONG_NOTE_1").is_empty(), false, "long note entity exists"):
		return
	if not _expect_bool(_entity_by_id(entities, "SCORE_COUNTER").is_empty(), false, "score counter entity exists"):
		return
	if not _expect_bool(_entity_by_id(entities, "EFFECT_JUDGMENT_COOL").is_empty(), false, "cool judgment entity exists"):
		return

	var lane: Dictionary = model.lane_for_channel(metadata, "NOTE_1")
	if lane.is_empty():
		push_error("Expected NOTE_1 lane.")
		quit(1)
		return
	if not _expect_int(lane.get("lane", -1), 0, "lane index"):
		return
	if not _expect_float(lane.get("x", 0.0), 5.0, "lane x"):
		return
	if not _expect_float(lane.get("width", 0.0), 28.0, "lane width"):
		return
	var last_lane: Dictionary = model.lane_for_channel(metadata, "NOTE_7")
	if last_lane.is_empty():
		push_error("Expected NOTE_7 lane.")
		quit(1)
		return
	if not _expect_int(last_lane.get("lane", -1), 6, "last lane index"):
		return
	if not _expect_float(last_lane.get("x", 0.0), 165.0, "last lane x"):
		return

	var view = GameplayView.new()
	if not _expect_bool(view.load_metadata(metadata), true, "view metadata load"):
		return
	if not _expect_int(_count_children_with_prefix(view, "Entity_"), 21, "Java initial entity node count"):
		return
	if not _expect_bool(view.has_node("Entity_BGA"), true, "bga node"):
		return
	if not _expect_bool(view.has_node("Entity_SCORE_COUNTER"), true, "score counter node"):
		return
	if not _expect_bool(view.has_node("Entity_COMBO_COUNTER"), true, "combo counter node"):
		return
	if not _expect_bool(view.has_node("Entity_LIFE_BAR"), true, "life bar node"):
		return
	if not _expect_bool(view.has_node("Entity_EFFECT_JUDGMENT_COOL"), false, "judgment effect template is not static"):
		return
	if not _expect_bool(view.has_node("Entity_NOTE_1"), false, "note template is not static"):
		return
	if not _expect_bool(view.has_node("Entity_PRESSED_NOTE_1"), false, "pressed note template is not static"):
		return
	if not _expect_bool(view.has_node("Entity_PILL_1"), false, "pill template is not static"):
		return
	if not _expect_bool(view.has_node("Entity_MEASURE_MARK"), false, "measure template is not static"):
		return
	if not _expect_bool(view.has_method("update_hud_state"), true, "view hud state method"):
		return
	if not _expect_bool(view.has_node("Hud_SCORE_COUNTER"), true, "score hud label"):
		return
	if not _expect_bool(view.has_node("Hud_COMBO_COUNTER"), true, "combo hud label"):
		return
	if not _expect_bool(view.has_node("Hud_JAM_COUNTER"), true, "jam hud label"):
		return
	if not _expect_bool(view.has_node("Hud_MINUTE_COUNTER"), true, "minute hud label"):
		return
	if not _expect_bool(view.has_node("Hud_SECOND_COUNTER"), true, "second hud label"):
		return
	if not _expect_bool(view.has_node("Hud_COUNTER_JUDGMENT_COOL"), true, "cool counter hud label"):
		return

	view.update_hud_state({
		"score": 12345,
		"combo": 12,
		"maxCombo": 34,
		"jamCombo": 2,
		"jamBar": 25,
		"jamBarLimit": 50,
		"life": 12000,
		"lifeLimit": 24000,
		"elapsedMs": 83000.0,
		"judgments": {
			"cool": 7,
			"good": 3,
			"bad": 1,
			"miss": 2,
		},
	})
	if not _expect_string(view.get_node("Hud_SCORE_COUNTER").text, "12345", "score hud text"):
		return
	if not _expect_string(view.get_node("Hud_COMBO_COUNTER").text, "11", "combo hud text"):
		return
	if not _expect_string(view.get_node("Hud_JAM_COUNTER").text, "2", "jam hud text"):
		return
	if not _expect_string(view.get_node("Hud_MAXCOMBO_COUNTER").text, "34", "max combo hud text"):
		return
	if not _expect_string(view.get_node("Hud_MINUTE_COUNTER").text, "1", "minute hud text"):
		return
	if not _expect_string(view.get_node("Hud_SECOND_COUNTER").text, "23", "second hud text"):
		return
	if not _expect_string(view.get_node("Hud_COUNTER_JUDGMENT_COOL").text, "7", "cool counter hud text"):
		return
	if not _expect_string(view.get_node("Hud_COUNTER_JUDGMENT_GOOD").text, "3", "good counter hud text"):
		return
	if not _expect_string(view.get_node("Hud_COUNTER_JUDGMENT_BAD").text, "1", "bad counter hud text"):
		return
	if not _expect_string(view.get_node("Hud_COUNTER_JUDGMENT_MISS").text, "2", "miss counter hud text"):
		return

	var life_bar: ColorRect = view.get_node("Entity_LIFE_BAR")
	if not _expect_float(life_bar.size.y, 150.5, "life bar half fill height"):
		return
	if not _expect_float(life_bar.position.y, 397.5, "life bar half fill y"):
		return

	var jam_bar: ColorRect = view.get_node("Entity_JAM_BAR")
	if not _expect_float(jam_bar.size.x, 95.5, "jam bar half fill width"):
		return
	if not _expect_bool(view.has_node("Pressed_PRESSED_NOTE_1_000"), false, "pressed lane starts hidden"):
		return

	view.update_hud_state({
		"pressedLanes": [0],
	})
	if not _expect_int(_count_children_with_prefix(view, "Pressed_PRESSED_NOTE_1_"), 3, "pressed lane one pieces"):
		return
	if not _expect_bool(view.has_node("Pressed_PRESSED_NOTE_1_000"), true, "pressed lane one first piece"):
		return

	view.update_hud_state({
		"pressedLanes": [],
	})
	if not _expect_int(_count_children_with_prefix(view, "Pressed_PRESSED_NOTE_1_"), 0, "pressed lane clears"):
		return
	if not _expect_bool(view.has_node("Judgment_EFFECT_JUDGMENT_COOL"), false, "judgment starts hidden"):
		return
	if not _expect_bool(view.has_node("Click_EFFECT_CLICK_002"), false, "click starts hidden"):
		return
	if not _expect_bool(view.has_node("Pill_PILL_1"), false, "pill starts hidden"):
		return

	view.update_hud_state({
		"judgmentEvent": {
			"sequence": 1,
			"result": "cool",
			"lane": 0,
		},
		"clickEvents": [
			{
				"sequence": 2,
				"lane": 0,
			},
		],
		"pills": 1,
	})
	if not _expect_bool(view.has_node("Judgment_EFFECT_JUDGMENT_COOL"), true, "cool judgment node"):
		return
	if not _expect_bool(view.has_node("Click_EFFECT_CLICK_002"), true, "cool click node"):
		return
	if not _expect_bool(view.has_node("Pill_PILL_1"), true, "first pill node"):
		return
	var click_node: ColorRect = view.get_node("Click_EFFECT_CLICK_002")
	if not _expect_float(click_node.position.x, -109.0, "click node x"):
		return
	if not _expect_float(click_node.position.y, 352.0, "click node y"):
		return

	view.update_hud_state({
		"judgmentEvent": {
			"sequence": 3,
			"result": "bad",
			"lane": 0,
		},
		"clickEvents": [],
		"pills": 0,
	})
	if not _expect_bool(view.has_node("Judgment_EFFECT_JUDGMENT_COOL"), false, "cool judgment replaced"):
		return
	if not _expect_bool(view.has_node("Judgment_EFFECT_JUDGMENT_BAD"), true, "bad judgment node"):
		return
	if not _expect_int(_count_children_with_prefix(view, "Click_EFFECT_CLICK_"), 0, "click nodes clear"):
		return
	if not _expect_bool(view.has_node("Pill_PILL_1"), false, "pill node clears"):
		return
	if not _expect_bool(view.has_node("Longflare_EFFECT_LONGFLARE_002"), false, "longflare starts hidden"):
		return

	view.update_hud_state({
		"longFlares": [
			{
				"lane": 2,
			},
		],
	})
	if not _expect_bool(view.has_node("Longflare_EFFECT_LONGFLARE_002"), true, "longflare lane three node"):
		return
	var longflare_node: ColorRect = view.get_node("Longflare_EFFECT_LONGFLARE_002")
	if not _expect_float(longflare_node.position.x, 5.0, "longflare node x"):
		return

	view.update_hud_state({
		"longFlares": [],
	})
	if not _expect_bool(view.has_node("Longflare_EFFECT_LONGFLARE_002"), false, "longflare clears"):
		return

	var gameplay_loader = GameplayLoader.new()
	var chart: Dictionary = gameplay_loader.load_from_file("res://test/fixtures/gameplay.json")
	if chart.is_empty():
		push_error("Expected gameplay fixture to load.")
		quit(1)
		return
	chart["visualTiming"] = [
		{
			"timeMs": 0.0,
			"bpm": 120.0,
		},
		{
			"timeMs": 500.0,
			"bpm": 240.0,
		},
	]
	if not _expect_bool(view.load_chart(chart), true, "view chart load"):
		return
	if not _expect_bool(view.has_node("Note_000"), true, "dynamic note node"):
		return
	if not _expect_bool(view.has_node("Measure_000"), true, "dynamic measure node"):
		return

	var note_node: ColorRect = view.get_node("Note_000")
	if not _expect_float(note_node.position.x, 5.0, "dynamic note node x"):
		return
	if not _expect_float(note_node.position.y, 184.25, "dynamic note node y with visual timing at zero"):
		return
	if not _expect_float(note_node.size.x, 28.0, "dynamic note node width"):
		return
	if not _expect_float(note_node.size.y, 7.0, "dynamic note node height"):
		return
	var measure_node: ColorRect = view.get_node("Measure_000")
	if not _expect_float(measure_node.position.x, 5.0, "dynamic measure node x"):
		return
	if not _expect_float(measure_node.position.y, 479.0, "dynamic measure node y at zero"):
		return
	if not _expect_float(measure_node.size.x, 188.0, "dynamic measure node width"):
		return
	if not _expect_float(measure_node.size.y, 3.0, "dynamic measure node height"):
		return

	view.update_time(1000.0)
	if not _expect_float(note_node.position.y, 473.0, "dynamic note node y at judgment"):
		return
	if not _expect_bool(note_node.visible, true, "dynamic note starts visible"):
		return

	view.update_hud_state({
		"hiddenNotes": [0],
	})
	if not _expect_bool(note_node.visible, false, "judged note is hidden"):
		return

	view.update_hud_state({
		"hiddenNotes": [],
	})
	if not _expect_bool(note_node.visible, true, "visible note is restored"):
		return

	view.free()
	quit(0)


func _expect_bool(actual: bool, expected: bool, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true


func _entity_by_id(entities: Array, id: String) -> Dictionary:
	for entity: Variant in entities:
		if entity is Dictionary and str(entity.get("id", "")) == id:
			return entity
	return {}


func _count_children_with_prefix(node: Node, prefix: String) -> int:
	var count := 0
	for child: Node in node.get_children():
		if child.name.begins_with(prefix):
			count += 1
	return count


func _expect_float(actual: float, expected: float, label: String) -> bool:
	if absf(actual - expected) > 0.0001:
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
