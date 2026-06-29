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
	var cool_effect: Dictionary = _entity_by_id(entities, "EFFECT_JUDGMENT_COOL")
	if not _expect_float(cool_effect.get("x", 0.0), -34.0, "cool judgment Java anchored x"):
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
	var resource_root := ProjectSettings.globalize_path("res://../../src/resources")
	for entity: Dictionary in metadata.get("entities", []):
		if str(entity.get("id", "")) == "BGA":
			entity["texturePath"] = "%s/Playing_BG10.png" % resource_root
		if str(entity.get("id", "")) == "NOTE_1":
			entity["texturePath"] = "%s/main.png" % resource_root
			entity["textureX"] = 225.0
			entity["textureY"] = 142.0
			entity["textureWidth"] = 28.0
			entity["textureHeight"] = 7.0
		if str(entity.get("id", "")) == "LONG_NOTE_1":
			entity["texturePath"] = "%s/main.png" % resource_root
			entity["textureX"] = 225.0
			entity["textureY"] = 142.0
			entity["textureWidth"] = 28.0
			entity["textureHeight"] = 7.0
			entity["bodyTexturePath"] = "%s/main.png" % resource_root
			entity["bodyTextureX"] = 225.0
			entity["bodyTextureY"] = 143.0
			entity["bodyTextureWidth"] = 28.0
			entity["bodyTextureHeight"] = 5.0
			entity["tailTexturePath"] = "%s/main.png" % resource_root
			entity["tailTextureX"] = 225.0
			entity["tailTextureY"] = 142.0
			entity["tailTextureWidth"] = 28.0
			entity["tailTextureHeight"] = 7.0
		if str(entity.get("id", "")) == "SCORE_COUNTER":
			var digit_frames: Array[Dictionary] = []
			for digit in range(10):
				digit_frames.append({
					"id": "score_number_%d" % digit,
					"texturePath": "%s/Numbers.png" % resource_root,
					"textureX": 28.0,
					"textureY": float(digit * 19),
					"textureWidth": 24.0,
					"textureHeight": 18.0,
				})
			entity["spriteFrames"] = digit_frames
		if str(entity.get("id", "")) == "COMBO_COUNTER":
			var combo_frames: Array[Dictionary] = []
			for digit in range(10):
				combo_frames.append({
					"id": "combo_number_%d" % digit,
					"texturePath": "%s/Numbers.png" % resource_root,
					"textureX": 0.0,
					"textureY": float(digit * 71),
					"textureWidth": 46.0,
					"textureHeight": 71.0,
				})
			entity["spriteFrames"] = combo_frames
			entity["titleFrameSpeed"] = 0.012
			entity["titleSpriteFrames"] = [
				{
					"id": "combo_title_0",
					"texturePath": "%s/combo_title.png" % resource_root,
					"textureX": 0.0,
					"textureY": 0.0,
					"textureWidth": 64.0,
					"textureHeight": 64.0,
				},
				{
					"id": "combo_title_1",
					"texturePath": "%s/combo_title.png" % resource_root,
					"textureX": 64.0,
					"textureY": 0.0,
					"textureWidth": 64.0,
					"textureHeight": 64.0,
				},
			]
		if str(entity.get("id", "")) == "MEASURE_MARK":
			entity["frameSpeed"] = 0.005
			entity["spriteFrames"] = [
				{
					"id": "measure_mark_0",
					"texturePath": "%s/main.png" % resource_root,
					"textureX": 225.0,
					"textureY": 134.0,
					"textureWidth": 188.0,
					"textureHeight": 3.0,
				},
				{
					"id": "measure_mark_1",
					"texturePath": "%s/main.png" % resource_root,
					"textureX": 225.0,
					"textureY": 138.0,
					"textureWidth": 188.0,
					"textureHeight": 3.0,
				},
			]
		if str(entity.get("id", "")) == "EFFECT_JUDGMENT_COOL":
			entity["frameSpeed"] = 0.005
			entity["spriteFrames"] = [
				{
					"id": "judgment_cool_0",
					"texturePath": "%s/main.png" % resource_root,
					"textureX": 225.0,
					"textureY": 180.0,
					"textureWidth": 128.0,
					"textureHeight": 128.0,
				},
				{
					"id": "judgment_cool_1",
					"texturePath": "%s/main.png" % resource_root,
					"textureX": 225.0,
					"textureY": 308.0,
					"textureWidth": 128.0,
					"textureHeight": 128.0,
				},
			]
		if str(entity.get("id", "")) == "EFFECT_CLICK":
			entity["frameSpeed"] = 0.005
			entity["spriteFrames"] = [
				{
					"id": "click_0",
					"texturePath": "%s/main.png" % resource_root,
					"textureX": 100.0,
					"textureY": 180.0,
					"textureWidth": 256.0,
					"textureHeight": 256.0,
				},
				{
					"id": "click_1",
					"texturePath": "%s/main.png" % resource_root,
					"textureX": 100.0,
					"textureY": 436.0,
					"textureWidth": 256.0,
					"textureHeight": 256.0,
				},
			]
		if str(entity.get("id", "")) == "EFFECT_LONGFLARE":
			entity["frameSpeed"] = 0.005
			entity["spriteFrames"] = [
				{
					"id": "longflare_0",
					"texturePath": "%s/main.png" % resource_root,
					"textureX": 0.0,
					"textureY": 180.0,
					"textureWidth": 128.0,
					"textureHeight": 128.0,
				},
				{
					"id": "longflare_1",
					"texturePath": "%s/main.png" % resource_root,
					"textureX": 0.0,
					"textureY": 308.0,
					"textureWidth": 128.0,
					"textureHeight": 128.0,
				},
			]
	if not _expect_bool(view.load_metadata(metadata), true, "view metadata load"):
		return
	if not _expect_int(_count_children_with_prefix(view, "Entity_"), 21, "Java initial entity node count"):
		return
	if not _expect_bool(view.has_node("Entity_BGA"), true, "bga node"):
		return
	if not _expect_bool(view.get_node("Entity_BGA") is TextureRect, true, "bga texture node"):
		return
	var bga_texture_node: TextureRect = view.get_node("Entity_BGA")
	if not _expect_bool(bga_texture_node.texture != null, true, "bga texture loaded"):
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
	if not _expect_bool(view.has_node("Hud_FPS_COUNTER"), true, "fps hud label"):
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
		"fps": 144,
		"minute": 2,
		"second": 5,
		"judgments": {
			"cool": 7,
			"good": 3,
			"bad": 1,
			"miss": 2,
		},
	})
	if not _expect_string(view.get_node("Hud_SCORE_COUNTER").text, "12345", "score hud text"):
		return
	if not _expect_bool(view.has_node("HudSprite_SCORE_COUNTER"), true, "score sprite hud node"):
		return
	var score_sprite_hud: Control = view.get_node("HudSprite_SCORE_COUNTER")
	if not _expect_int(score_sprite_hud.get_child_count(), 5, "score sprite digit count"):
		return
	var score_digit_0: TextureRect = score_sprite_hud.get_child(0)
	var score_digit_4: TextureRect = score_sprite_hud.get_child(4)
	if not _expect_float(score_digit_0.position.x, 168.0, "score rightmost digit x"):
		return
	if not _expect_float(score_digit_4.position.x, 72.0, "score leftmost digit x"):
		return
	var score_left_digit_texture: AtlasTexture = score_digit_4.texture
	if not _expect_float(score_left_digit_texture.region.position.y, 19.0, "score leftmost digit texture y"):
		return
	if not _expect_string(view.get_node("Hud_COMBO_COUNTER").text, "11", "combo hud text"):
		return
	if not _expect_string(view.get_node("Hud_JAM_COUNTER").text, "2", "jam hud text"):
		return
	if not _expect_string(view.get_node("Hud_MAXCOMBO_COUNTER").text, "34", "max combo hud text"):
		return
	if not _expect_string(view.get_node("Hud_FPS_COUNTER").text, "144", "fps hud text"):
		return
	if not _expect_string(view.get_node("Hud_MINUTE_COUNTER").text, "2", "minute hud text"):
		return
	if not _expect_string(view.get_node("Hud_SECOND_COUNTER").text, "05", "second hud text"):
		return
	if not _expect_string(view.get_node("Hud_COUNTER_JUDGMENT_COOL").text, "7", "cool counter hud text"):
		return
	if not _expect_string(view.get_node("Hud_COUNTER_JUDGMENT_GOOD").text, "3", "good counter hud text"):
		return
	if not _expect_string(view.get_node("Hud_COUNTER_JUDGMENT_BAD").text, "1", "bad counter hud text"):
		return
	if not _expect_string(view.get_node("Hud_COUNTER_JUDGMENT_MISS").text, "2", "miss counter hud text"):
		return

	var life_bar: Control = view.get_node("Entity_LIFE_BAR")
	if not _expect_float(life_bar.size.y, 150.5, "life bar half fill height"):
		return
	if not _expect_float(life_bar.position.y, 397.5, "life bar half fill y"):
		return

	var jam_bar: Control = view.get_node("Entity_JAM_BAR")
	if not _expect_float(jam_bar.size.x, 95.5, "jam bar half fill width"):
		return

	var combo_sprite_hud: Control = view.get_node("HudSprite_COMBO_COUNTER")
	if not _expect_int(combo_sprite_hud.get_child_count(), 3, "combo sprite digit and title count"):
		return
	if not _expect_bool(combo_sprite_hud.has_node("Title"), true, "combo title node"):
		return
	var combo_title: TextureRect = combo_sprite_hud.get_node("Title")
	if not _expect_float(combo_title.position.x, 67.0, "combo title Java x"):
		return
	if not _expect_float(combo_title.position.y, 139.0, "combo title Java y"):
		return
	var combo_digit_0: TextureRect = combo_sprite_hud.get_child(0)
	if not _expect_float(combo_digit_0.position.y, 220.0, "combo wobble start y"):
		return
	view.update_hud_state({
		"combo": 12,
		"jamCombo": 2,
		"elapsedMs": 83010.0,
	})
	combo_digit_0 = combo_sprite_hud.get_child(0)
	if not _expect_float(combo_digit_0.position.y, 215.0, "combo wobble mid y"):
		return
	view.update_hud_state({
		"combo": 12,
		"jamCombo": 2,
		"elapsedMs": 83020.0,
	})
	combo_digit_0 = combo_sprite_hud.get_child(0)
	if not _expect_float(combo_digit_0.position.y, 210.0, "combo wobble base y"):
		return
	view.update_hud_state({
		"combo": 12,
		"jamCombo": 2,
		"elapsedMs": 87001.0,
	})
	if not _expect_int(combo_sprite_hud.get_child_count(), 0, "combo hidden after Java show time"):
		return
	view.update_hud_state({
		"combo": 13,
		"jamCombo": 2,
		"elapsedMs": 87002.0,
	})
	if not _expect_int(combo_sprite_hud.get_child_count(), 3, "combo reappears after increment"):
		return
	combo_digit_0 = combo_sprite_hud.get_child(0)
	if not _expect_float(combo_digit_0.position.y, 220.0, "combo wobble restarts after increment"):
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
	if not _expect_bool(view.load_chart({
		"bpm": 120.0,
		"notes": [],
		"measures": [],
	}), true, "empty chart load for effect animation"):
		return

	view.update_hud_state({
		"judgmentEvent": {
			"sequence": 1,
			"result": "cool",
			"lane": 0,
			"startMs": 1000.0,
		},
		"clickEvents": [
			{
				"sequence": 2,
				"lane": 0,
				"startMs": 1000.0,
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
	var judgment_node: TextureRect = view.get_node("Judgment_EFFECT_JUDGMENT_COOL")
	view.update_time(1000.0)
	var judgment_texture: AtlasTexture = judgment_node.texture
	if not _expect_float(judgment_texture.region.position.y, 180.0, "judgment effect starts on first frame"):
		return
	if not _expect_float(judgment_node.position.x, -34.0, "judgment effect Java anchored x"):
		return
	if not _expect_float(judgment_node.pivot_offset.x, 64.0, "judgment effect pivot x"):
		return
	if not _expect_float(judgment_node.pivot_offset.y, 64.0, "judgment effect pivot y"):
		return
	if not _expect_float(judgment_node.scale.x, 0.5, "judgment effect initial scale x"):
		return
	if not _expect_float(judgment_node.scale.y, 0.5, "judgment effect initial scale y"):
		return
	view.update_time(1050.0)
	if not _expect_float(judgment_node.scale.x, 0.75, "judgment effect mid enter scale x"):
		return
	if not _expect_float(judgment_node.scale.y, 0.75, "judgment effect mid enter scale y"):
		return
	view.update_time(1200.0)
	judgment_texture = judgment_node.texture
	if not _expect_float(judgment_texture.region.position.y, 308.0, "judgment effect advances from event time"):
		return
	if not _expect_float(judgment_node.scale.x, 1.0, "judgment effect final scale x"):
		return
	if not _expect_float(judgment_node.scale.y, 1.0, "judgment effect final scale y"):
		return
	var click_node: TextureRect = view.get_node("Click_EFFECT_CLICK_002")
	view.update_time(1000.0)
	var click_texture: AtlasTexture = click_node.texture
	if not _expect_float(click_texture.region.position.y, 180.0, "click effect starts on first frame"):
		return
	view.update_time(1200.0)
	click_texture = click_node.texture
	if not _expect_float(click_texture.region.position.y, 436.0, "click effect advances from event time"):
		return
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
				"startMs": 3000.0,
			},
		],
	})
	if not _expect_bool(view.has_node("Longflare_EFFECT_LONGFLARE_002"), true, "longflare lane three node"):
		return
	var longflare_node: TextureRect = view.get_node("Longflare_EFFECT_LONGFLARE_002")
	view.update_time(3000.0)
	var longflare_texture: AtlasTexture = longflare_node.texture
	if not _expect_float(longflare_texture.region.position.y, 180.0, "longflare starts on first frame"):
		return
	view.update_time(3200.0)
	longflare_texture = longflare_node.texture
	if not _expect_float(longflare_texture.region.position.y, 308.0, "longflare advances from hold start"):
		return
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
	chart["notes"].append({
		"id": 2,
		"lane": 0,
		"startMs": 1300.0,
		"endMs": 1600.0,
		"sampleId": 2,
		"volume": 1.0,
		"pan": 0.0,
		"kind": "holdStart",
	})
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
	if not _expect_bool(view.has_node("Note_001"), true, "dynamic long note node"):
		return
	if not _expect_bool(view.has_node("Measure_000"), true, "dynamic measure node"):
		return

	var note_node: Control = view.get_node("Note_000")
	if not _expect_bool(note_node is TextureRect, true, "dynamic note texture node"):
		return
	var note_texture_node: TextureRect = note_node
	if not _expect_bool(note_texture_node.texture is AtlasTexture, true, "dynamic note atlas texture"):
		return
	var note_texture: AtlasTexture = note_texture_node.texture
	if not _expect_float(note_texture.region.position.x, 225.0, "dynamic note texture x"):
		return
	if not _expect_float(note_texture.region.position.y, 142.0, "dynamic note texture y"):
		return
	if not _expect_float(note_texture.region.size.x, 28.0, "dynamic note texture width"):
		return
	if not _expect_float(note_texture.region.size.y, 7.0, "dynamic note texture height"):
		return
	if not _expect_float(note_node.position.x, 5.0, "dynamic note node x"):
		return
	if not _expect_float(note_node.position.y, 184.25, "dynamic note node y with visual timing at zero"):
		return
	if not _expect_float(note_node.size.x, 28.0, "dynamic note node width"):
		return
	if not _expect_float(note_node.size.y, 7.0, "dynamic note node height"):
		return
	var long_note_node: Control = view.get_node("Note_001")
	if not _expect_bool(long_note_node.has_node("Head"), true, "long note head node"):
		return
	if not _expect_bool(long_note_node.has_node("Body"), true, "long note body node"):
		return
	if not _expect_bool(long_note_node.has_node("Tail"), true, "long note tail node"):
		return
	var long_note_head: TextureRect = long_note_node.get_node("Head")
	var long_note_body: TextureRect = long_note_node.get_node("Body")
	var long_note_tail: TextureRect = long_note_node.get_node("Tail")
	if not _expect_bool(long_note_head.texture is AtlasTexture, true, "long note head atlas"):
		return
	if not _expect_bool(long_note_body.texture is AtlasTexture, true, "long note body atlas"):
		return
	if not _expect_bool(long_note_tail.texture is AtlasTexture, true, "long note tail atlas"):
		return
	var long_note_body_texture: AtlasTexture = long_note_body.texture
	if not _expect_float(long_note_body_texture.region.position.y, 143.0, "long note body texture y"):
		return
	if not _expect_float(long_note_body_texture.region.size.y, 5.0, "long note body texture height"):
		return
	var long_note_tail_texture: AtlasTexture = long_note_tail.texture
	if not _expect_float(long_note_tail_texture.region.position.y, 142.0, "long note tail texture y"):
		return
	if not _expect_float(long_note_tail_texture.region.size.y, 7.0, "long note tail texture height"):
		return
	if not _expect_float(long_note_node.position.y, -46.75, "long note node y"):
		return
	if not _expect_float(long_note_node.size.y, 122.5, "long note node height"):
		return
	if not _expect_float(long_note_head.position.y, 0.0, "long note head y"):
		return
	if not _expect_float(long_note_body.size.y, 122.5, "long note body height"):
		return
	if not _expect_float(long_note_tail.position.y, 115.5, "long note tail y"):
		return
	var measure_node: Control = view.get_node("Measure_000")
	if not _expect_bool(measure_node is TextureRect, true, "dynamic measure texture node"):
		return
	var measure_texture_node: TextureRect = measure_node
	if not _expect_float(measure_node.position.x, 5.0, "dynamic measure node x"):
		return
	if not _expect_float(measure_node.position.y, 479.0, "dynamic measure node y at zero"):
		return
	if not _expect_float(measure_node.size.x, 188.0, "dynamic measure node width"):
		return
	if not _expect_float(measure_node.size.y, 3.0, "dynamic measure node height"):
		return
	var measure_texture: AtlasTexture = measure_texture_node.texture
	if not _expect_float(measure_texture.region.position.y, 134.0, "measure texture first frame y"):
		return
	view.update_time(200.0)
	measure_texture = measure_texture_node.texture
	if not _expect_float(measure_texture.region.position.y, 138.0, "measure texture second frame y"):
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
