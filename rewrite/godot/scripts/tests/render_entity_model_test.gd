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
			entity["frameSpeed"] = 0.012
			entity["spriteFrames"] = [
				{
					"id": "head_note_white_0",
					"texturePath": "%s/main.png" % resource_root,
					"textureX": 225.0,
					"textureY": 142.0,
					"textureWidth": 28.0,
					"textureHeight": 7.0,
				},
				{
					"id": "head_note_white_1",
					"texturePath": "%s/main.png" % resource_root,
					"textureX": 225.0,
					"textureY": 150.0,
					"textureWidth": 28.0,
					"textureHeight": 7.0,
				},
				{
					"id": "head_note_white_2",
					"texturePath": "%s/main.png" % resource_root,
					"textureX": 225.0,
					"textureY": 158.0,
					"textureWidth": 28.0,
					"textureHeight": 7.0,
				},
			]
			entity["bodyTexturePath"] = "%s/main.png" % resource_root
			entity["bodyTextureX"] = 225.0
			entity["bodyTextureY"] = 143.0
			entity["bodyTextureWidth"] = 28.0
			entity["bodyTextureHeight"] = 5.0
			entity["bodyFrameSpeed"] = 0.012
			entity["bodySpriteFrames"] = [
				{
					"id": "body_note_white_0",
					"texturePath": "%s/main.png" % resource_root,
					"textureX": 225.0,
					"textureY": 143.0,
					"textureWidth": 28.0,
					"textureHeight": 5.0,
				},
				{
					"id": "body_note_white_1",
					"texturePath": "%s/main.png" % resource_root,
					"textureX": 225.0,
					"textureY": 151.0,
					"textureWidth": 28.0,
					"textureHeight": 5.0,
				},
				{
					"id": "body_note_white_2",
					"texturePath": "%s/main.png" % resource_root,
					"textureX": 225.0,
					"textureY": 159.0,
					"textureWidth": 28.0,
					"textureHeight": 5.0,
				},
			]
			entity["tailTexturePath"] = "%s/main.png" % resource_root
			entity["tailTextureX"] = 225.0
			entity["tailTextureY"] = 142.0
			entity["tailTextureWidth"] = 28.0
			entity["tailTextureHeight"] = 7.0
			entity["tailFrameSpeed"] = 0.012
			entity["tailSpriteFrames"] = [
				{
					"id": "head_note_white_0",
					"texturePath": "%s/main.png" % resource_root,
					"textureX": 225.0,
					"textureY": 142.0,
					"textureWidth": 28.0,
					"textureHeight": 7.0,
				},
				{
					"id": "head_note_white_1",
					"texturePath": "%s/main.png" % resource_root,
					"textureX": 225.0,
					"textureY": 150.0,
					"textureWidth": 28.0,
					"textureHeight": 7.0,
				},
				{
					"id": "head_note_white_2",
					"texturePath": "%s/main.png" % resource_root,
					"textureX": 225.0,
					"textureY": 158.0,
					"textureWidth": 28.0,
					"textureHeight": 7.0,
				},
			]
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
		if str(entity.get("id", "")) == "PRESSED_NOTE_1" and int(entity.get("layer", 0)) == 3:
			entity["frameSpeed"] = 0.005
			entity["spriteFrames"] = [
				{
					"id": "pressed_note_lane_0",
					"texturePath": "%s/main.png" % resource_root,
					"textureX": 225.0,
					"textureY": 134.0,
					"textureWidth": 28.0,
					"textureHeight": 3.0,
				},
				{
					"id": "pressed_note_lane_1",
					"texturePath": "%s/main.png" % resource_root,
					"textureX": 225.0,
					"textureY": 138.0,
					"textureWidth": 28.0,
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
	if not _expect_int(bga_texture_node.z_index, 0, "bga Java layer"):
		return
	if not _expect_bool(bga_texture_node.texture != null, true, "bga texture loaded"):
		return
	if not _expect_bool(view.load_chart({
		"bpm": 120.0,
		"notes": [],
		"measures": [],
		"bgaSprites": [
			{
				"spriteId": 7,
				"texturePath": "%s/main.png" % resource_root,
				"textureX": 0.0,
				"textureY": 0.0,
				"textureWidth": 16.0,
				"textureHeight": 16.0,
			},
			{
				"spriteId": 8,
				"texturePath": "%s/main.png" % resource_root,
				"textureX": 32.0,
				"textureY": 48.0,
				"textureWidth": 24.0,
				"textureHeight": 12.0,
			},
		],
	}), true, "bga sprite chart load"):
		return
	view.update_hud_state({
		"currentBgaEvent": {
			"spriteId": 7,
			"startMs": 500.0,
		},
	})
	if not _expect_bool(bga_texture_node.has_meta("currentBgaSpriteId"), true, "bga current sprite metadata"):
		return
	if not _expect_int(int(bga_texture_node.get_meta("currentBgaSpriteId")), 7, "bga first current sprite id"):
		return
	if not _expect_bool(bga_texture_node.texture is AtlasTexture, true, "bga first sprite atlas"):
		return
	var first_bga_texture: AtlasTexture = bga_texture_node.texture
	if not _expect_float(first_bga_texture.region.position.x, 0.0, "bga first sprite texture x"):
		return
	if not _expect_float(first_bga_texture.region.position.y, 0.0, "bga first sprite texture y"):
		return
	if not _expect_float(first_bga_texture.region.size.x, 16.0, "bga first sprite texture width"):
		return
	if not _expect_float(first_bga_texture.region.size.y, 16.0, "bga first sprite texture height"):
		return
	view.update_hud_state({
		"currentBgaEvent": {
			"spriteId": 999,
			"startMs": 750.0,
		},
	})
	if not _expect_int(int(bga_texture_node.get_meta("currentBgaSpriteId")), 7, "missing bga sprite keeps previous id"):
		return
	view.update_hud_state({
		"currentBgaEvent": {
			"spriteId": 8,
			"startMs": 1000.0,
		},
	})
	if not _expect_int(int(bga_texture_node.get_meta("currentBgaSpriteId")), 8, "bga second current sprite id"):
		return
	var second_bga_texture: AtlasTexture = bga_texture_node.texture
	if not _expect_float(second_bga_texture.region.position.x, 32.0, "bga second sprite texture x"):
		return
	if not _expect_float(second_bga_texture.region.position.y, 48.0, "bga second sprite texture y"):
		return
	if not _expect_float(second_bga_texture.region.size.x, 24.0, "bga second sprite texture width"):
		return
	if not _expect_float(second_bga_texture.region.size.y, 12.0, "bga second sprite texture height"):
		return
	var video_view = GameplayView.new()
	if not _expect_bool(video_view.load_metadata(metadata), true, "bga video view metadata load"):
		return
	if not _expect_bool(video_view.load_chart({
		"bpm": 120.0,
		"notes": [],
		"measures": [],
		"bgaVideoPath": "res://test/fixtures/intro.ogv",
	}), true, "missing bga video chart load"):
		return
	if not _expect_bool(video_view.has_node("Entity_BGA"), true, "bga video node exists"):
		return
	if not _expect_bool(video_view.get_node("Entity_BGA") is TextureRect, true, "missing bga video falls back to texture"):
		return
	var fallback_bga_node: TextureRect = video_view.get_node("Entity_BGA")
	if not _expect_float(fallback_bga_node.position.x, bga_texture_node.position.x, "bga fallback x"):
		return
	if not _expect_float(fallback_bga_node.position.y, bga_texture_node.position.y, "bga fallback y"):
		return
	if not _expect_float(fallback_bga_node.size.x, bga_texture_node.size.x, "bga fallback width"):
		return
	if not _expect_float(fallback_bga_node.size.y, bga_texture_node.size.y, "bga fallback height"):
		return
	if not _expect_int(fallback_bga_node.z_index, bga_texture_node.z_index, "bga fallback Java layer"):
		return
	if not _expect_bool(fallback_bga_node.has_meta("bgaVideoPath"), false, "missing bga video metadata omitted"):
		return
	video_view.free()
	var gated_video_view = GameplayView.new()
	if not _expect_bool(gated_video_view.load_metadata(metadata), true, "gated bga video metadata load"):
		return
	var gated_bga_template: Control = gated_video_view.get_node("Entity_BGA")
	var gated_video_node := VideoStreamPlayer.new()
	gated_video_node.name = "Entity_BGA"
	gated_video_node.position = gated_bga_template.position
	gated_video_node.size = gated_bga_template.size
	gated_video_node.z_index = gated_bga_template.z_index
	gated_video_node.z_as_relative = gated_bga_template.z_as_relative
	gated_video_node.set_meta("bgaVideoStarted", false)
	gated_video_view._replace_bga_node(gated_video_node)
	gated_video_view.update_hud_state({
		"elapsedMs": 0.0,
		"gameStarted": false,
	})
	if not _expect_bool(bool(gated_video_node.get_meta("bgaVideoStarted", false)), false, "manual start bga video waits"):
		return
	gated_video_view.update_hud_state({
		"elapsedMs": 0.0,
		"gameStarted": true,
	})
	if not _expect_bool(bool(gated_video_node.get_meta("bgaVideoStarted", false)), true, "started bga video begins"):
		return
	gated_video_view.free()
	var judgment_line_node: Control = view.get_node("Entity_JUDGMENT_LINE")
	if not _expect_int(judgment_line_node.z_index, 2, "judgment line Java layer"):
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
		"statusTexts": [
			"HI-SPEED: x1.0",
			"Current Measure: 2",
			"Game Speed: +0",
		],
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
	if not _expect_bool(view.has_node("StatusText_000"), true, "status text first label"):
		return
	if not _expect_string(view.get_node("StatusText_000").text, "HI-SPEED: x1.0", "status speed text"):
		return
	if not _expect_string(view.get_node("StatusText_001").text, "Current Measure: 2", "status measure text"):
		return
	if not _expect_string(view.get_node("StatusText_002").text, "Game Speed: +0", "status game speed text"):
		return
	var status_label: Label = view.get_node("StatusText_000")
	if not _expect_int(status_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT, "status Java right alignment"):
		return
	if not _expect_float(status_label.position.x, 520.0, "status Java x"):
		return
	if not _expect_float(status_label.position.y, 300.0, "status Java y"):
		return
	if not _expect_float(view.get_node("StatusText_001").position.y, 330.0, "status Java next y"):
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
	view.update_time(83084.0)
	combo_title = combo_sprite_hud.get_node("Title")
	var combo_title_texture: AtlasTexture = combo_title.texture
	if not _expect_float(combo_title_texture.region.position.x, 64.0, "combo title animation advances like Java entity"):
		return
	view.update_hud_state({
		"combo": 12,
		"jamCombo": 2,
		"elapsedMs": 83084.0,
	})
	combo_title = combo_sprite_hud.get_node("Title")
	combo_title_texture = combo_title.texture
	if not _expect_float(combo_title_texture.region.position.x, 64.0, "combo title animation survives same-value state sync"):
		return
	view.update_time(0.0)
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
	var pressed_lane_node: Control = view.get_node("Pressed_PRESSED_NOTE_1_000")
	if not _expect_int(pressed_lane_node.z_index, 3, "pressed lane Java layer"):
		return
	if not _expect_bool(pressed_lane_node is TextureRect, true, "pressed lane texture node"):
		return
	var pressed_lane_texture_node: TextureRect = pressed_lane_node
	if not _expect_bool(pressed_lane_texture_node.texture is AtlasTexture, true, "pressed lane atlas texture"):
		return
	var pressed_lane_texture: AtlasTexture = pressed_lane_texture_node.texture
	if not _expect_float(pressed_lane_texture.region.position.y, 134.0, "pressed lane starts on first frame"):
		return
	var pressed_keyboard_node: Control = view.get_node("Pressed_PRESSED_NOTE_1_001")
	if not _expect_int(pressed_keyboard_node.z_index, 8, "pressed keyboard Java layer"):
		return
	view.update_time(200.0)
	view.update_hud_state({
		"pressedLanes": [0],
	})
	pressed_lane_texture_node = view.get_node("Pressed_PRESSED_NOTE_1_000")
	pressed_lane_texture = pressed_lane_texture_node.texture
	if not _expect_float(pressed_lane_texture.region.position.y, 138.0, "pressed lane advances while held"):
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
	var pill_node: Control = view.get_node("Pill_PILL_1")
	var pill_instance_id := pill_node.get_instance_id()
	var judgment_node: TextureRect = view.get_node("Judgment_EFFECT_JUDGMENT_COOL")
	var judgment_instance_id := judgment_node.get_instance_id()
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
	var click_instance_id := click_node.get_instance_id()
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
		"elapsedMs": 1200.0,
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
	judgment_node = view.get_node("Judgment_EFFECT_JUDGMENT_COOL")
	judgment_texture = judgment_node.texture
	if not _expect_int(judgment_node.get_instance_id(), judgment_instance_id, "judgment effect keeps Java entity instance during state sync"):
		return
	if not _expect_float(judgment_texture.region.position.y, 308.0, "judgment effect advances during state sync"):
		return
	if not _expect_float(judgment_node.scale.x, 1.0, "judgment effect scale advances during state sync"):
		return
	click_node = view.get_node("Click_EFFECT_CLICK_002")
	click_texture = click_node.texture
	if not _expect_int(click_node.get_instance_id(), click_instance_id, "click effect keeps Java entity instance during state sync"):
		return
	if not _expect_float(click_texture.region.position.y, 436.0, "click effect advances during state sync"):
		return
	pill_node = view.get_node("Pill_PILL_1")
	if not _expect_int(pill_node.get_instance_id(), pill_instance_id, "pill keeps Java entity instance during state sync"):
		return
	view.update_hud_state({
		"elapsedMs": 1400.0,
		"clickEvents": [
			{
				"sequence": 2,
				"lane": 0,
				"startMs": 1000.0,
			},
		],
	})
	if not _expect_int(_count_children_with_prefix(view, "Click_EFFECT_CLICK_"), 0, "click clears at Java animation loop boundary"):
		return
	view.update_hud_state({
		"elapsedMs": 1401.0,
		"clickEvents": [
			{
				"sequence": 2,
				"lane": 0,
				"startMs": 1000.0,
			},
		],
	})
	if not _expect_int(_count_children_with_prefix(view, "Click_EFFECT_CLICK_"), 0, "click clears after one Java animation loop"):
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
	var longflare_instance_id := longflare_node.get_instance_id()
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
		"elapsedMs": 3200.0,
		"longFlares": [
			{
				"lane": 2,
				"startMs": 3000.0,
			},
		],
	})
	longflare_node = view.get_node("Longflare_EFFECT_LONGFLARE_002")
	longflare_texture = longflare_node.texture
	if not _expect_int(longflare_node.get_instance_id(), longflare_instance_id, "longflare keeps Java entity instance during state sync"):
		return
	if not _expect_float(longflare_texture.region.position.y, 308.0, "longflare advances during state sync"):
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
	if not _expect_int(note_node.z_index, 5, "dynamic note Java layer"):
		return
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
	var fast_chart: Dictionary = chart.duplicate(true)
	fast_chart["speedMultiplier"] = 2.0
	var fast_view = GameplayView.new()
	if not _expect_bool(fast_view.load_metadata(metadata), true, "speed view metadata load"):
		return
	if not _expect_bool(fast_view.load_chart(fast_chart), true, "speed view chart load"):
		return
	var fast_note_node: Control = fast_view.get_node("Note_000")
	if not _expect_float(fast_note_node.position.y, -104.5, "dynamic note node y with speed multiplier"):
		return
	fast_view.free()
	var regul_chart: Dictionary = chart.duplicate(true)
	regul_chart["speedMultiplier"] = 2.0
	regul_chart["speedType"] = "RegulSpeed"
	var regul_view = GameplayView.new()
	if not _expect_bool(regul_view.load_metadata(metadata), true, "regul speed view metadata load"):
		return
	if not _expect_bool(regul_view.load_chart(regul_chart), true, "regul speed view chart load"):
		return
	var regul_note_node: Control = regul_view.get_node("Note_000")
	if not _expect_float(regul_note_node.position.y, -8.25, "dynamic note node y with regul speed"):
		return
	regul_view.free()
	var w_chart: Dictionary = chart.duplicate(true)
	w_chart["speedMultiplier"] = 2.0
	w_chart["speedType"] = "WSpeed"
	var w_view = GameplayView.new()
	if not _expect_bool(w_view.load_metadata(metadata), true, "w speed view metadata load"):
		return
	if not _expect_bool(w_view.load_chart(w_chart), true, "w speed view chart load"):
		return
	var w_note_node: Control = w_view.get_node("Note_000")
	if not _expect_float(w_note_node.position.y, 328.625, "dynamic note node y with initial w speed"):
		return
	w_view.update_time(250.0)
	if not _expect_float(w_note_node.position.y, 322.609375, "dynamic note node y with updated w speed"):
		return
	w_view.free()
	var xr_chart: Dictionary = chart.duplicate(true)
	xr_chart["speedMultiplier"] = 2.0
	xr_chart["speedType"] = "xRSpeed"
	xr_chart["xRSpeedFactors"] = [0.25, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	var xr_view = GameplayView.new()
	if not _expect_bool(xr_view.load_metadata(metadata), true, "xr speed view metadata load"):
		return
	if not _expect_bool(xr_view.load_chart(xr_chart), true, "xr speed view chart load"):
		return
	var xr_note_node: Control = xr_view.get_node("Note_000")
	if not _expect_float(xr_note_node.position.y, -248.875, "dynamic note node y with xr speed"):
		return
	xr_view.free()
	var hidden_chart: Dictionary = chart.duplicate(true)
	hidden_chart["visibilityModifier"] = "Hidden"
	var hidden_view = GameplayView.new()
	if not _expect_bool(hidden_view.load_metadata(metadata), true, "hidden visibility view metadata load"):
		return
	if not _expect_bool(hidden_view.load_chart(hidden_chart), true, "hidden visibility view chart load"):
		return
	if not _expect_int(_count_children_with_prefix(hidden_view, "Visibility_Hidden_"), 7, "hidden visibility lane overlay count"):
		return
	if not _expect_bool(hidden_view.has_node("Visibility_Hidden_000"), true, "hidden visibility first lane overlay"):
		return
	var hidden_overlay: Control = hidden_view.get_node("Visibility_Hidden_000")
	if not _expect_bool(hidden_overlay is TextureRect, true, "hidden visibility texture node"):
		return
	if not _expect_float(hidden_overlay.position.x, 5.0, "hidden visibility x"):
		return
	if not _expect_float(hidden_overlay.position.y, 0.0, "hidden visibility y"):
		return
	if not _expect_float(hidden_overlay.size.x, 28.0, "hidden visibility width"):
		return
	if not _expect_float(hidden_overlay.size.y, 480.0, "hidden visibility height"):
		return
	if not _expect_int(hidden_overlay.z_index, 7, "hidden visibility Java layer"):
		return
	var hidden_judgment_line: Control = hidden_view.get_node("Entity_JUDGMENT_LINE")
	if not _expect_int(hidden_judgment_line.z_index, 7, "hidden judgment line Java layer"):
		return
	var hidden_measure: Control = hidden_view.get_node("Measure_000")
	if not _expect_int(hidden_measure.z_index, 7, "hidden measure mark Java layer"):
		return
	var hidden_jam_bar: Control = hidden_view.get_node("Entity_JAM_BAR")
	if not _expect_int(hidden_jam_bar.z_index, 8, "hidden shifts Java higher layers"):
		return
	hidden_view.free()
	var mirror_chart: Dictionary = chart.duplicate(true)
	mirror_chart["channelModifier"] = "Mirror"
	var mirror_path := _chart_path("mirror_modifier_render")
	if not _write_chart(mirror_path, mirror_chart):
		return
	var mirrored_chart: Dictionary = gameplay_loader.load_from_file(mirror_path)
	if not _expect_bool(mirrored_chart.is_empty(), false, "mirrored render chart load"):
		return
	var mirror_view = GameplayView.new()
	if not _expect_bool(mirror_view.load_metadata(metadata), true, "mirror view metadata load"):
		return
	if not _expect_bool(mirror_view.load_chart(mirrored_chart), true, "mirror view chart load"):
		return
	var mirrored_note_node: Control = mirror_view.get_node("Note_000")
	if not _expect_float(mirrored_note_node.position.x, 165.0, "mirrored dynamic note x"):
		return
	mirror_view.free()
	var shuffle_chart: Dictionary = chart.duplicate(true)
	shuffle_chart["channelModifier"] = "Shuffle"
	shuffle_chart["channelMap"] = [6, 4, 2, 3, 1, 5, 0]
	var shuffle_path := _chart_path("shuffle_modifier_render")
	if not _write_chart(shuffle_path, shuffle_chart):
		return
	var shuffled_chart: Dictionary = gameplay_loader.load_from_file(shuffle_path)
	if not _expect_bool(shuffled_chart.is_empty(), false, "shuffled render chart load"):
		return
	var shuffle_view = GameplayView.new()
	if not _expect_bool(shuffle_view.load_metadata(metadata), true, "shuffle view metadata load"):
		return
	if not _expect_bool(shuffle_view.load_chart(shuffled_chart), true, "shuffle view chart load"):
		return
	var shuffled_note_node: Control = shuffle_view.get_node("Note_000")
	if not _expect_float(shuffled_note_node.position.x, 165.0, "shuffled dynamic note x"):
		return
	shuffle_view.free()
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
	if not _expect_int(measure_node.z_index, 4, "dynamic measure Java layer"):
		return
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
	var buffered_measure_view = GameplayView.new()
	if not _expect_bool(buffered_measure_view.load_metadata(metadata), true, "buffered measure view metadata load"):
		return
	if not _expect_bool(buffered_measure_view.load_chart(chart), true, "buffered measure view chart load"):
		return
	var buffered_measure_node: TextureRect = buffered_measure_view.get_node("Measure_000")
	buffered_measure_view.update_hud_state({
		"hiddenMeasures": [0],
		"elapsedMs": 0.0,
	})
	buffered_measure_view.update_time(200.0)
	buffered_measure_view.update_hud_state({
		"hiddenMeasures": [],
		"elapsedMs": 200.0,
	})
	var buffered_measure_texture: AtlasTexture = buffered_measure_node.texture
	if not _expect_float(buffered_measure_texture.region.position.y, 134.0, "measure animation starts when Java buffers it"):
		return
	buffered_measure_view.free()
	var long_note_head_texture: AtlasTexture = long_note_head.texture
	if not _expect_float(long_note_head_texture.region.position.y, 158.0, "long note head advances from Java frame speed"):
		return
	long_note_body_texture = long_note_body.texture
	if not _expect_float(long_note_body_texture.region.position.y, 159.0, "long note body advances from Java frame speed"):
		return
	long_note_tail_texture = long_note_tail.texture
	if not _expect_float(long_note_tail_texture.region.position.y, 158.0, "long note tail advances from Java frame speed"):
		return

	if not _expect_bool(measure_node.visible, true, "dynamic measure starts visible"):
		return
	view.update_hud_state({
		"hiddenMeasures": [0],
	})
	if not _expect_bool(measure_node.visible, false, "judged measure is hidden"):
		return

	view.update_time(1000.0)
	if not _expect_float(note_node.position.y, 473.0, "dynamic note node y at judgment"):
		return
	view.update_hud_state({
		"renderSpeed": 2.0,
	})
	view.update_time(500.0)
	if not _expect_float(note_node.position.y, 88.0, "dynamic note follows runtime speed"):
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

	view.update_time(1300.0)
	var longflare_y := long_note_node.position.y
	view.update_hud_state({
		"longFlares": [
			{
				"lane": 0,
				"noteIndex": 1,
				"startMs": 1300.0,
			},
		],
	})
	if not _expect_bool(view.has_node("Longflare_EFFECT_LONGFLARE_000"), true, "longflare with note index node"):
		return
	var note_longflare_node: TextureRect = view.get_node("Longflare_EFFECT_LONGFLARE_000")
	if not _expect_float(note_longflare_node.position.y, longflare_y + long_note_head.size.y, "longflare follows long note y"):
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


func _chart_path(label: String) -> String:
	return "%s/open2jam_%s_render_gameplay.json" % [OS.get_temp_dir(), label.replace(" ", "_")]


func _write_chart(path: String, chart: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write chart fixture '%s'." % path)
		quit(1)
		return false

	file.store_string(JSON.stringify(chart))
	return true


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
