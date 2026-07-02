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
	if not _expect_int(metadata.get("visibilityLayer", 0), 7, "visibility layer"):
		return
	var status_layout: Dictionary = metadata.get("statusTextLayout", {})
	if not _expect_float(status_layout.get("rightX", 0.0), 780.0, "status text Java right x"):
		return
	if not _expect_float(status_layout.get("startY", 0.0), 300.0, "status text Java start y"):
		return
	if not _expect_float(status_layout.get("lineHeight", 0.0), 30.0, "status text Java line height"):
		return
	if not _expect_float(status_layout.get("labelWidth", 0.0), 260.0, "status text label width"):
		return
	if not _expect_int(int(status_layout.get("fontSize", 0)), 14, "status text Java font size"):
		return
	if not _expect_float(status_layout.get("glyphHeight", 0.0), 20.0, "status text Java glyph height"):
		return
	if not _expect_string(status_layout.get("horizontalAlignment", ""), "right", "status text Java alignment"):
		return
	if not _expect_float(status_layout.get("scaleY", 0.0), -1.0, "status text Java scale y"):
		return
	var status_font: Dictionary = metadata.get("statusFont", {})
	if not _expect_string(str(status_font.get("source", "")), "TrueTypeFont", "status font source"):
		return
	if not _expect_int(int(status_font.get("textureWidth", 0)), 512, "status font texture width"):
		return
	if not _expect_int(int(status_font.get("textureHeight", 0)), 512, "status font texture height"):
		return
	if not _expect_int(int(status_font.get("correctL", 0)), 9, "status font left correction"):
		return
	if not _expect_int(int(status_font.get("correctR", 0)), 8, "status font right correction"):
		return
	if not _expect_bool(str(status_font.get("pngBase64", "")).is_empty(), false, "status font atlas png"):
		return
	var status_font_glyphs: Array = status_font.get("glyphs", [])
	if not _expect_int(status_font_glyphs.size(), 256, "status font glyph count"):
		return

	var entities: Array = metadata.get("entities", [])
	if not _expect_int(entities.size(), 66, "full Java skin entity count"):
		return
	if not _expect_string(entities[0].get("id", ""), "BGA", "first entity id"):
		return
	if not _expect_bool(_entity_by_id(entities, "JUDGMENT_LINE").is_empty(), false, "judgment line entity exists"):
		return
	var timebar_decoration: Dictionary = _entity_by_sprite(entities, "timebar")
	if not _expect_bool(timebar_decoration.is_empty(), false, "static timebar decoration entity exists"):
		return
	if not _expect_string(str(timebar_decoration.get("id", "")), "", "static timebar decoration id"):
		return
	if not _expect_string(str(timebar_decoration.get("type", "")), "entity", "static timebar decoration type"):
		return
	if not _expect_bool(bool(timebar_decoration.get("named", true)), false, "static timebar decoration named flag"):
		return
	if not _expect_bool(timebar_decoration.has("fillDirection"), false, "static timebar ignores bar fill direction"):
		return
	if not _expect_bool(_entity_by_id(entities, "LONG_NOTE_1").is_empty(), false, "long note entity exists"):
		return
	if not _expect_bool(_entity_by_id(entities, "SCORE_COUNTER").is_empty(), false, "score counter entity exists"):
		return
	var second_counter: Dictionary = _entity_by_id(entities, "SECOND_COUNTER")
	if not _expect_int(int(second_counter.get("showDigits", 0)), 2, "second counter Java show digits"):
		return
	if not _expect_bool(_entity_by_id(entities, "EFFECT_JUDGMENT_COOL").is_empty(), false, "cool judgment entity exists"):
		return
	var cool_effect: Dictionary = _entity_by_id(entities, "EFFECT_JUDGMENT_COOL")
	if not _expect_float(cool_effect.get("x", 0.0), -34.0, "cool judgment Java anchored x"):
		return
	if not _expect_float(cool_effect.get("showTimeMs", 0.0), 3000.0, "cool judgment Java show time"):
		return
	if not _expect_float(cool_effect.get("scaleRampMs", 0.0), 100.0, "cool judgment Java scale ramp"):
		return
	if not _expect_float(cool_effect.get("initialScale", 0.0), 0.5, "cool judgment Java initial scale"):
		return
	var click_effect: Dictionary = _entity_by_id(entities, "EFFECT_CLICK")
	if not _expect_bool(bool(click_effect.get("animationLoop", true)), false, "click effect Java one-shot animation"):
		return
	var longflare_effect: Dictionary = _entity_by_id(entities, "EFFECT_LONGFLARE")
	if not _expect_bool(bool(longflare_effect.get("animationLoop", false)), true, "longflare effect Java looping animation"):
		return

	if not _test_combo_counter_uses_metadata_behavior():
		return
	if not _test_judgment_effect_uses_metadata_behavior():
		return
	if not _test_status_text_uses_metadata_layout():
		return
	if not _test_bar_fill_directions_match_java_slice_geometry():
		return
	if not _test_timebar_decoration_matches_java_static_entity_lifecycle():
		return
	if not _test_click_effect_uses_animation_loop_metadata():
		return
	if not _test_longflare_uses_note_entity_center():
		return
	if not _test_render_metadata_rejects_invalid_numeric_contract(model):
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
	if not _expect_int(_count_children_with_prefix(view, "Entity_"), 9, "Java static initial entity node count"):
		return
	if not _expect_int(_count_children_with_prefix(view, "HudSprite_"), 12, "Java HUD counter renderer count"):
		return
	if not _expect_bool(view.has_node("Entity_BGA"), true, "bga node"):
		return
	if not _expect_bool(view.get_node("Entity_BGA") is TextureRect, true, "bga texture node"):
		return
	var bga_texture_node: TextureRect = view.get_node("Entity_BGA")
	if not _expect_int(bga_texture_node.z_index, 0, "bga Java layer"):
		return
	if not _expect_int(bga_texture_node.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR, "bga Java texture filter"):
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
	if not _expect_bool(view.has_node("Entity_SCORE_COUNTER"), false, "score counter is not static"):
		return
	if not _expect_bool(view.has_node("Entity_COMBO_COUNTER"), false, "combo counter is not static"):
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
	view._set_hud_text("SECOND_COUNTER", "5")
	if not _expect_string(view.get_node("Hud_SECOND_COUNTER").text, "05", "second counter metadata-padded text"):
		return
	if not _expect_bool(view.has_node("HudSprite_SECOND_COUNTER"), true, "second sprite hud node"):
		return
	var second_sprite_hud: Control = view.get_node("HudSprite_SECOND_COUNTER")
	if not _expect_int(second_sprite_hud.get_child_count(), 2, "second sprite metadata-padded digit count"):
		return
	var second_digit_5: TextureRect = second_sprite_hud.get_child(0)
	var second_digit_0: TextureRect = second_sprite_hud.get_child(1)
	if not _expect_float(second_digit_5.position.x, 383.0, "second rightmost digit x"):
		return
	if not _expect_float(second_digit_0.position.x, 356.0, "second padded zero digit x"):
		return
	if not _expect_bool(view.has_node("Hud_COUNTER_JUDGMENT_PERFECT"), true, "perfect counter hud label"):
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
			"perfect": 11,
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
	if not _expect_int(score_digit_0.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR, "score digit Java texture filter"):
		return
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
	if not _expect_string(view.get_node("Hud_COUNTER_JUDGMENT_PERFECT").text, "11", "perfect counter hud text"):
		return
	if not _expect_bool(view.has_node("HudSprite_COUNTER_JUDGMENT_PERFECT"), true, "perfect sprite hud node"):
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
	if not _expect_string(_status_node_text(view.get_node("StatusText_000")), "HI-SPEED: x1.0", "status speed text"):
		return
	if not _expect_string(_status_node_text(view.get_node("StatusText_001")), "Current Measure: 2", "status measure text"):
		return
	if not _expect_string(_status_node_text(view.get_node("StatusText_002")), "Game Speed: +0", "status game speed text"):
		return
	var gameplay_status_font: Dictionary = metadata.get("statusFont", {})
	var status_label: Control = view.get_node("StatusText_000")
	if not _expect_string(str(status_label.get_meta("statusTextRenderer", "")), "TrueTypeFont",
			"status Java renderer"):
		return
	if not _expect_float(status_label.position.x + status_label.size.x,
			780.0 + float(gameplay_status_font.get("correctR", 8.0)),
			"status Java corrected right edge"):
		return
	if not _expect_float(status_label.position.y, 280.0, "status Java y"):
		return
	if not _expect_float(view.get_node("StatusText_001").position.y, 310.0, "status Java next y"):
		return
	if not _expect_bool(status_label.get_child_count() > 0, true, "status Java glyph children"):
		return
	var status_glyph: CanvasItem = status_label.get_child(0)
	if not _expect_bool(status_glyph.material is CanvasItemMaterial, true, "status glyph Java blend material"):
		return
	var status_glyph_material: CanvasItemMaterial = status_glyph.material
	if not _expect_int(status_glyph_material.blend_mode, CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA,
			"status glyph Java premultiplied blend mode"):
		return

	var timebar_texture_node := _timebar_decoration_node(view)
	if not _expect_bool(timebar_texture_node != null, true, "timebar Java texture node"):
		return

	var life_bar: Control = view.get_node("Entity_LIFE_BAR")
	if not _expect_float(life_bar.size.y, 150.0, "life bar Java slice half fill height"):
		return
	if not _expect_float(life_bar.position.y, 398.0, "life bar Java slice half fill y"):
		return
	if not _expect_bool(life_bar is TextureRect, true, "life bar texture rect"):
		return
	var life_bar_texture_node: TextureRect = life_bar
	var life_texture: AtlasTexture = life_bar_texture_node.texture
	if not _expect_float(life_texture.region.position.y, 152.0, "life bar Java slice texture y"):
		return
	if not _expect_float(life_texture.region.size.y, 150.0, "life bar Java slice texture height"):
		return

	var jam_bar: Control = view.get_node("Entity_JAM_BAR")
	if not _expect_float(jam_bar.size.x, 96.0, "jam bar Java slice half fill width"):
		return
	if not _expect_bool(jam_bar is TextureRect, true, "jam bar texture rect"):
		return
	var jam_bar_texture_node: TextureRect = jam_bar
	var jam_texture: AtlasTexture = jam_bar_texture_node.texture
	if not _expect_float(jam_texture.region.position.x, 1.0, "jam bar Java slice texture x"):
		return
	if not _expect_float(jam_texture.region.size.x, 96.0, "jam bar Java slice texture width"):
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
	view.update_time(87084.0)
	view.update_hud_state({
		"combo": 13,
		"jamCombo": 2,
		"elapsedMs": 87084.0,
	})
	if not _expect_int(combo_sprite_hud.get_child_count(), 3, "combo reappears after increment"):
		return
	combo_title = combo_sprite_hud.get_node("Title")
	combo_title_texture = combo_title.texture
	if not _expect_float(combo_title_texture.region.position.x, 64.0, "combo title animation persists while hidden"):
		return
	combo_digit_0 = combo_sprite_hud.get_child(0)
	if not _expect_float(combo_digit_0.position.y, 220.0, "combo wobble restarts after increment"):
		return
	view.update_hud_state({
		"combo": 13,
		"jamCombo": 2,
		"elapsedMs": 87105.0,
	})
	combo_digit_0 = combo_sprite_hud.get_child(0)
	if not _expect_float(combo_digit_0.position.y, 209.5, "combo wobble Java overshoot y"):
		return
	view.update_time(0.0)

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
		"elapsedMs": 4000.0,
		"judgmentEvent": {
			"sequence": 1,
			"result": "cool",
			"lane": 0,
			"startMs": 1000.0,
		},
	})
	if not _expect_bool(view.has_node("Judgment_EFFECT_JUDGMENT_COOL"), true, "judgment effect remains at Java show-time boundary"):
		return
	view.update_hud_state({
		"elapsedMs": 4001.0,
		"judgmentEvent": {
			"sequence": 1,
			"result": "cool",
			"lane": 0,
			"startMs": 1000.0,
		},
	})
	if not _expect_bool(view.has_node("Judgment_EFFECT_JUDGMENT_COOL"), false, "judgment effect clears after Java show time"):
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
		"lane": 0,
		"startMs": 1300.0,
		"measure": 0,
		"endMs": 1600.0,
		"endMeasure": 0,
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
	var w_target_chart: Dictionary = chart.duplicate(true)
	w_target_chart["speedMultiplier"] = 10.0
	w_target_chart["speedType"] = "WSpeed"
	w_target_chart["visualTiming"] = [{"timeMs": 0.0, "bpm": 120.0}]
	var w_target_view = GameplayView.new()
	if not _expect_bool(w_target_view.load_metadata(metadata), true, "w speed target view metadata load"):
		return
	if not _expect_bool(w_target_view.load_chart(w_target_chart), true, "w speed target view chart load"):
		return
	var w_target_note_node: Control = w_target_view.get_node("Note_000")
	w_target_view.update_hud_state({
		"renderSpeed": 10.0,
		"targetSpeed": 0.5,
	})
	w_target_view.update_time(1600.0)
	if not _expect_float(w_target_note_node.position.y, 530.75, "w speed view cycle uses target speed"):
		return
	w_target_view.free()
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
	if not _expect_int(_count_children_with_prefix(hidden_view, "Visibility_Hidden_"), 0,
			"hidden visibility overlay removed by Java composite lifecycle"):
		return
	if not _expect_bool(hidden_view.has_node("Visibility_Hidden_000"), false,
			"hidden visibility first lane overlay absent"):
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
	var metadata_visibility_layer: Dictionary = metadata.duplicate(true)
	metadata_visibility_layer["visibilityLayer"] = 12
	var metadata_layer_view = GameplayView.new()
	if not _expect_bool(metadata_layer_view.load_metadata(metadata_visibility_layer), true, "metadata visibility layer view metadata load"):
		return
	if not _expect_bool(metadata_layer_view.load_chart(hidden_chart), true, "metadata visibility layer view chart load"):
		return
	if not _expect_int(_count_children_with_prefix(metadata_layer_view, "Visibility_Hidden_"), 0,
			"metadata visibility overlay removed by Java composite lifecycle"):
		return
	var metadata_layer_judgment_line: Control = metadata_layer_view.get_node("Entity_JUDGMENT_LINE")
	if not _expect_int(metadata_layer_judgment_line.z_index, 12, "judgment line uses Java visibility layer metadata"):
		return
	var metadata_layer_measure: Control = metadata_layer_view.get_node("Measure_000")
	if not _expect_int(metadata_layer_measure.z_index, 12, "measure mark uses Java visibility layer metadata"):
		return
	metadata_layer_view.free()
	var metadata_visibility_mask: Dictionary = metadata.duplicate(true)
	metadata_visibility_mask["visibilityMasks"] = {
		"Hidden": [
			{"at": 0.0, "alpha": 0.0},
			{"at": 1.0, "alpha": 0.0},
			{"at": 2.0, "alpha": 1.0},
			{"at": 4.0, "alpha": 1.0},
		],
	}
	var metadata_mask_view = GameplayView.new()
	if not _expect_bool(metadata_mask_view.load_metadata(metadata_visibility_mask), true, "metadata visibility mask view metadata load"):
		return
	if not _expect_bool(metadata_mask_view.load_chart(hidden_chart), true, "metadata visibility mask view chart load"):
		return
	if not _expect_int(_count_children_with_prefix(metadata_mask_view, "Visibility_Hidden_"), 0,
			"metadata visibility mask overlay removed by Java composite lifecycle"):
		return
	if not _expect_float(metadata_mask_view._visibility_alpha("Hidden", 180.0, 480.0), 0.5,
			"visibility mask math still uses Java metadata"):
		return
	metadata_mask_view.free()
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
	if not _expect_float(note_longflare_node.position.y, longflare_y, "longflare follows Java long note y"):
		return

	view.free()
	quit(0)


func _test_combo_counter_uses_metadata_behavior() -> bool:
	var view = GameplayView.new()
	if not _expect_bool(view.load_metadata(_combo_behavior_metadata()), true, "combo behavior metadata load"):
		return false

	view.update_hud_state({
		"combo": 2,
		"elapsedMs": 1000.0,
	})
	var combo_sprite_hud: Control = view.get_node("HudSprite_COMBO_COUNTER")
	if not _expect_int(combo_sprite_hud.get_child_count(), 0, "metadata combo threshold hides low count"):
		return false

	view.update_hud_state({
		"combo": 3,
		"elapsedMs": 1000.0,
	})
	if not _expect_int(combo_sprite_hud.get_child_count(), 1, "metadata combo threshold shows count"):
		return false
	var combo_digit: TextureRect = combo_sprite_hud.get_child(0)
	if not _expect_float(combo_digit.position.y, 70.0, "metadata combo wobble start y"):
		return false

	view.update_hud_state({
		"combo": 3,
		"elapsedMs": 1005.0,
	})
	combo_digit = combo_sprite_hud.get_child(0)
	if not _expect_float(combo_digit.position.y, 60.0, "metadata combo wobble speed"):
		return false

	view.update_hud_state({
		"combo": 3,
		"elapsedMs": 1101.0,
	})
	if not _expect_int(combo_sprite_hud.get_child_count(), 0, "metadata combo show time"):
		return false

	view.free()
	return true


func _test_judgment_effect_uses_metadata_behavior() -> bool:
	var view = GameplayView.new()
	if not _expect_bool(view.load_metadata(_judgment_behavior_metadata()), true, "judgment behavior metadata load"):
		return false
	if not _expect_bool(view.load_chart({
		"bpm": 120.0,
		"notes": [],
		"measures": [],
	}), true, "judgment behavior empty chart load"):
		return false

	view.update_hud_state({
		"elapsedMs": 1000.0,
		"judgmentEvent": {
			"sequence": 1,
			"result": "cool",
			"lane": 0,
			"startMs": 1000.0,
		},
	})
	var judgment_node: TextureRect = view.get_node("Judgment_EFFECT_JUDGMENT_COOL")
	if not _expect_float(judgment_node.scale.x, 0.25, "metadata judgment initial scale"):
		return false

	view.update_hud_state({
		"elapsedMs": 1010.0,
		"judgmentEvent": {
			"sequence": 1,
			"result": "cool",
			"lane": 0,
			"startMs": 1000.0,
		},
	})
	judgment_node = view.get_node("Judgment_EFFECT_JUDGMENT_COOL")
	if not _expect_float(judgment_node.scale.x, 0.625, "metadata judgment scale ramp"):
		return false

	view.update_hud_state({
		"elapsedMs": 1051.0,
		"judgmentEvent": {
			"sequence": 1,
			"result": "cool",
			"lane": 0,
			"startMs": 1000.0,
		},
	})
	if not _expect_bool(view.has_node("Judgment_EFFECT_JUDGMENT_COOL"), false, "metadata judgment show time"):
		return false

	view.free()
	return true


func _test_status_text_uses_metadata_layout() -> bool:
	var view = GameplayView.new()
	if not _expect_bool(view.load_metadata(_status_text_layout_metadata()), true, "status layout metadata load"):
		return false

	view.update_hud_state({
		"statusTexts": [
			"One",
			"Two",
		],
	})
	var first_label: Label = view.get_node("StatusText_000")
	var second_label: Label = view.get_node("StatusText_001")
	if not _expect_float(first_label.position.x, 50.0, "metadata status layout x"):
		return false
	if not _expect_float(first_label.position.y, 40.0, "metadata status layout y"):
		return false
	if not _expect_float(second_label.position.y, 52.0, "metadata status layout line height"):
		return false
	if not _expect_float(first_label.size.x, 50.0, "metadata status label width"):
		return false
	if not _expect_int(first_label.get_theme_font_size("font_size"), 9, "metadata status font size"):
		return false
	if not _expect_bool(bool(first_label.get_meta("statusTextBold", false)), true, "metadata status bold"):
		return false
	if not _expect_bool(bool(first_label.get_meta("statusTextAntiAlias", true)), false, "metadata status antialias"):
		return false
	if not _expect_bool(first_label.has_theme_color_override("font_color"), true, "metadata status font color override"):
		return false
	if not _expect_color(first_label.get_theme_color("font_color"), Color(1.0, 1.0, 1.0, 1.0), "metadata status font color"):
		return false
	if not _expect_string(str(first_label.get_meta("statusTextFontFamily", "")), "sans-serif", "metadata status font family"):
		return false
	if not _expect_int(int(first_label.get_meta("statusTextFontWeight", 0)), 700, "metadata status font weight"):
		return false
	if not OS.get_system_font_path("sans-serif", 700, 100, false).is_empty():
		if not _expect_bool(first_label.has_theme_font_override("font"), true, "metadata status font override"):
			return false
		var font := first_label.get_theme_font("font")
		if font is FontFile:
			if not _expect_int(int(font.antialiasing), TextServer.FONT_ANTIALIASING_NONE, "metadata status font antialiasing"):
				return false

	view.free()
	return true


func _test_click_effect_uses_animation_loop_metadata() -> bool:
	var view = GameplayView.new()
	if not _expect_bool(view.load_metadata(_click_loop_metadata()), true, "click loop metadata load"):
		return false
	if not _expect_bool(view.load_chart({
		"bpm": 120.0,
		"notes": [],
		"measures": [],
	}), true, "click loop empty chart load"):
		return false

	view.update_hud_state({
		"elapsedMs": 1000.0,
		"clickEvents": [
			{
				"sequence": 1,
				"lane": 0,
				"startMs": 1000.0,
			},
		],
	})
	if not _expect_bool(view.has_node("Click_EFFECT_CLICK_001"), true, "metadata looping click starts"):
		return false

	view.update_hud_state({
		"elapsedMs": 1003.0,
		"clickEvents": [
			{
				"sequence": 1,
				"lane": 0,
				"startMs": 1000.0,
			},
		],
	})
	if not _expect_bool(view.has_node("Click_EFFECT_CLICK_001"), true, "metadata looping click remains after animation cycle"):
		return false

	view.free()
	return true


func _test_longflare_uses_note_entity_center() -> bool:
	var view = GameplayView.new()
	if not _expect_bool(view.load_metadata(_longflare_position_metadata()), true, "longflare position metadata load"):
		return false

	var note_node := Control.new()
	note_node.name = "SyntheticNote"
	note_node.position = Vector2(123.0, 45.0)
	note_node.size = Vector2(20.0, 10.0)
	view.add_child(note_node)
	view._note_entries.append({
		"node": note_node,
	})

	view.update_hud_state({
		"elapsedMs": 1000.0,
		"longFlares": [
			{
				"lane": 0,
				"noteIndex": 0,
				"startMs": 1000.0,
			},
		],
	})

	var longflare_node: TextureRect = view.get_node("Longflare_EFFECT_LONGFLARE_000")
	if not _expect_float(longflare_node.position.x, 108.0, "longflare follows Java note center x"):
		return false
	if not _expect_float(longflare_node.position.y, 45.0, "longflare follows Java note y"):
		return false

	view.free()
	return true


func _test_bar_fill_directions_match_java_slice_geometry() -> bool:
	var view = GameplayView.new()
	if not _expect_bool(view.load_metadata(_bar_direction_metadata()), true, "bar direction metadata load"):
		return false
	if not _expect_bool(view.load_chart({
		"bpm": 120.0,
		"notes": [],
		"measures": [],
	}), true, "bar direction chart load"):
		return false

	view._set_bar_fill("LIFE_BAR", 25.0, 100.0)
	var left_bar: TextureRect = view.get_node("Entity_LIFE_BAR")
	var left_texture: AtlasTexture = left_bar.texture
	if not _expect_float(left_bar.position.x, 10.0, "left bar x"):
		return false
	if not _expect_float(left_bar.size.x, 25.0, "left bar width"):
		return false
	if not _expect_float(left_texture.region.position.x, 20.0, "left bar texture x"):
		return false
	if not _expect_float(left_texture.region.size.x, 25.0, "left bar texture width"):
		return false

	view._set_bar_fill("JAM_BAR", 25.0, 100.0)
	var right_bar: TextureRect = view.get_node("Entity_JAM_BAR")
	var right_texture: AtlasTexture = right_bar.texture
	if not _expect_float(right_bar.position.x, 185.0, "right bar x"):
		return false
	if not _expect_float(right_bar.size.x, 25.0, "right bar width"):
		return false
	if not _expect_float(right_texture.region.position.x, 95.0, "right bar texture x"):
		return false
	if not _expect_float(right_texture.region.size.x, 25.0, "right bar texture width"):
		return false

	view._set_bar_fill("SCORE_COUNTER", 25.0, 100.0)
	var up_bar: TextureRect = view.get_node("Entity_SCORE_COUNTER")
	var up_texture: AtlasTexture = up_bar.texture
	if not _expect_float(up_bar.position.y, 120.0, "up bar y"):
		return false
	if not _expect_float(up_bar.size.y, 20.0, "up bar height"):
		return false
	if not _expect_float(up_texture.region.position.y, 80.0, "up bar texture y"):
		return false
	if not _expect_float(up_texture.region.size.y, 20.0, "up bar texture height"):
		return false

	view._set_bar_fill("FPS_COUNTER", 25.0, 100.0)
	var down_bar: TextureRect = view.get_node("Entity_FPS_COUNTER")
	var down_texture: AtlasTexture = down_bar.texture
	if not _expect_float(down_bar.position.y, 170.0, "down bar y"):
		return false
	if not _expect_float(down_bar.size.y, 20.0, "down bar height"):
		return false
	if not _expect_float(down_texture.region.position.y, 20.0, "down bar texture y"):
		return false
	if not _expect_float(down_texture.region.size.y, 20.0, "down bar texture height"):
		return false

	view.free()
	return true


func _test_timebar_decoration_matches_java_static_entity_lifecycle() -> bool:
	var view = GameplayView.new()
	var model = RenderEntityModel.new()
	var metadata: Dictionary = model.load_from_file("res://test/fixtures/render-metadata.json")
	if not _expect_bool(view.load_metadata(metadata), true, "static timebar metadata load"):
		return false
	if not _expect_bool(view.load_chart({
		"bpm": 120.0,
		"durationMs": 1000,
		"notes": [],
		"measures": [],
	}), true, "static timebar chart load"):
		return false

	var timebar := _timebar_decoration_node(view)
	if not _expect_bool(timebar != null, true, "static timebar decoration node"):
		return false
	var instance_id := timebar.get_instance_id()
	if not _expect_bool(str(timebar.name).begins_with("Entity_"), true, "static timebar decoration node name"):
		return false
	if not _expect_float(timebar.position.x, 226.0, "static timebar x"):
		return false
	if not _expect_float(timebar.position.y, 515.0, "static timebar y"):
		return false
	if not _expect_float(timebar.size.x, 226.0, "static timebar width"):
		return false
	if not _expect_float(timebar.size.y, 72.0, "static timebar height"):
		return false
	if not _expect_bool(timebar.visible, true, "static timebar initial visibility"):
		return false

	view.update_hud_state({
		"gameTimeMs": 0.0,
		"durationMs": 1000.0,
	})
	timebar = _timebar_decoration_node(view)
	if not _expect_int(timebar.get_instance_id(), instance_id, "static timebar keeps entity instance after hud update"):
		return false
	if not _expect_float(timebar.size.x, 226.0, "static timebar keeps full width at start"):
		return false
	if not _expect_bool(timebar.visible, true, "static timebar remains visible at start"):
		return false

	view.update_hud_state({
		"gameTimeMs": 500.0,
		"durationMs": 1000.0,
	})
	timebar = _timebar_decoration_node(view)
	if not _expect_float(timebar.size.x, 226.0, "static timebar ignores runtime game time"):
		return false
	if not _expect_bool(timebar.visible, true, "static timebar remains visible after runtime game time"):
		return false

	view.free()
	return true


func _test_render_metadata_rejects_invalid_numeric_contract(model: RefCounted) -> bool:
	if not _expect_bool(model.normalize(_render_metadata_with("visibilityLayer", "7")).is_empty(), true,
			"string visibility layer rejected"):
		return false
	if not _expect_bool(model.normalize(_render_metadata_with_entity("x", "5")).is_empty(), true,
			"string entity x rejected"):
		return false
	if not _expect_bool(model.normalize(_render_metadata_with_entity("width", -1.0)).is_empty(), true,
			"negative entity width rejected"):
		return false
	if not _expect_bool(model.normalize(_render_metadata_with_entity("textureWidth", "16")).is_empty(), true,
			"string entity texture width rejected"):
		return false
	if not _expect_bool(model.normalize(_render_metadata_with_entity("frameSpeed", 0.0)).is_empty(), true,
			"zero entity frame speed rejected"):
		return false
	if not _expect_bool(model.normalize(_render_metadata_with_sprite_frame("textureHeight", 0.0)).is_empty(), true,
			"zero sprite frame texture height rejected"):
		return false
	if not _expect_bool(model.normalize(_render_metadata_with_lane("x", "5")).is_empty(), true,
			"string lane x rejected"):
		return false
	return true


func _render_metadata_with(field: String, value: Variant) -> Dictionary:
	var metadata := _minimal_render_metadata()
	metadata[field] = value
	return metadata


func _render_metadata_with_entity(field: String, value: Variant) -> Dictionary:
	var metadata := _minimal_render_metadata()
	metadata["entities"][0][field] = value
	return metadata


func _render_metadata_with_lane(field: String, value: Variant) -> Dictionary:
	var metadata := _minimal_render_metadata()
	metadata["lanes"][0][field] = value
	return metadata


func _render_metadata_with_sprite_frame(field: String, value: Variant) -> Dictionary:
	var metadata := _minimal_render_metadata()
	metadata["entities"][0]["spriteFrames"] = [{
		"id": "frame_0",
		"texturePath": "res://test/fixtures/bga.png",
		"textureX": 0.0,
		"textureY": 0.0,
		"textureWidth": 16.0,
		"textureHeight": 16.0,
	}]
	metadata["entities"][0]["spriteFrames"][0][field] = value
	return metadata


func _minimal_render_metadata() -> Dictionary:
	return {
		"schemaVersion": 1,
		"format": "VOS_RENDER_METADATA",
		"baseWidth": 800.0,
		"baseHeight": 600.0,
		"judgmentLine": 480,
		"measureSize": 385.0,
		"visibilityLayer": 7,
		"entities": [
			{
				"id": "BGA",
				"type": "static",
				"layer": 0,
				"x": 0.0,
				"y": 0.0,
				"width": 800.0,
				"height": 600.0,
				"named": true,
				"sprites": [],
			},
		],
		"lanes": [
			{
				"channel": "NOTE_1",
				"lane": 0,
				"x": 5.0,
				"width": 28.0,
			},
		],
	}


func _combo_behavior_metadata() -> Dictionary:
	var digit_frames: Array[Dictionary] = []
	for digit in range(10):
		digit_frames.append({
			"id": "metadata_combo_%d" % digit,
			"textureWidth": 10.0,
			"textureHeight": 10.0,
		})
	return {
		"schemaVersion": 1,
		"format": "VOS_RENDER_METADATA",
		"baseWidth": 800.0,
		"baseHeight": 600.0,
		"judgmentLine": 480,
		"measureSize": 385.0,
		"entities": [
			{
				"id": "COMBO_COUNTER",
				"type": "comboCounter",
				"layer": 0,
				"x": 100.0,
				"y": 50.0,
				"width": 10.0,
				"height": 10.0,
				"named": true,
				"countThreshold": 3,
				"showTimeMs": 100.0,
				"wobblePixels": 20.0,
				"wobbleSpeed": 2.0,
				"sprites": [],
				"spriteFrames": digit_frames,
			},
		],
		"lanes": [],
	}


func _bar_direction_metadata() -> Dictionary:
	var resource_root := ProjectSettings.globalize_path("res://../../src/resources")
	return {
		"schemaVersion": 1,
		"format": "VOS_RENDER_METADATA",
		"baseWidth": 800.0,
		"baseHeight": 600.0,
		"judgmentLine": 480,
		"measureSize": 385.0,
		"entities": [
			_bar_direction_entity("LIFE_BAR", 10.0, 10.0, "left_to_right", resource_root),
			_bar_direction_entity("JAM_BAR", 110.0, 10.0, "right_to_left", resource_root),
			_bar_direction_entity("SCORE_COUNTER", 10.0, 60.0, "up_to_down", resource_root),
			_bar_direction_entity("FPS_COUNTER", 110.0, 170.0, "down_to_up", resource_root),
		],
		"lanes": [],
	}


func _bar_direction_entity(id: String, x: float, y: float, fill_direction: String, resource_root: String) -> Dictionary:
	return {
		"id": id,
		"type": "bar",
		"layer": 0,
		"x": x,
		"y": y,
		"width": 100.0,
		"height": 80.0,
		"named": true,
		"fillDirection": fill_direction,
		"texturePath": "%s/main.png" % resource_root,
		"textureX": 20.0,
		"textureY": 20.0,
		"textureWidth": 100.0,
		"textureHeight": 80.0,
		"sprites": [],
		"spriteFrames": [
			{
				"id": "%s_frame" % id,
				"texturePath": "%s/main.png" % resource_root,
				"textureX": 20.0,
				"textureY": 20.0,
				"textureWidth": 100.0,
				"textureHeight": 80.0,
			},
		],
	}


func _click_loop_metadata() -> Dictionary:
	return {
		"schemaVersion": 1,
		"format": "VOS_RENDER_METADATA",
		"baseWidth": 800.0,
		"baseHeight": 600.0,
		"judgmentLine": 480,
		"measureSize": 385.0,
		"entities": [
			{
				"id": "EFFECT_CLICK",
				"type": "entity",
				"layer": 0,
				"x": 0.0,
				"y": 0.0,
				"width": 10.0,
				"height": 10.0,
				"named": true,
				"frameSpeed": 1.0,
				"animationLoop": true,
				"sprites": [],
				"spriteFrames": [
					{
						"id": "metadata_click_0",
						"textureWidth": 10.0,
						"textureHeight": 10.0,
					},
					{
						"id": "metadata_click_1",
						"textureWidth": 10.0,
						"textureHeight": 10.0,
					},
				],
			},
		],
		"lanes": [
			{
				"channel": "NOTE_1",
				"lane": 0,
				"x": 0.0,
				"width": 20.0,
			},
		],
	}


func _longflare_position_metadata() -> Dictionary:
	return {
		"schemaVersion": 1,
		"format": "VOS_RENDER_METADATA",
		"baseWidth": 800.0,
		"baseHeight": 600.0,
		"judgmentLine": 480,
		"measureSize": 385.0,
		"entities": [
			{
				"id": "EFFECT_LONGFLARE",
				"type": "entity",
				"layer": 0,
				"x": 0.0,
				"y": 0.0,
				"width": 50.0,
				"height": 20.0,
				"named": true,
				"sprites": [],
				"spriteFrames": [
					{
						"id": "metadata_longflare",
						"textureWidth": 50.0,
						"textureHeight": 20.0,
					},
				],
			},
		],
		"lanes": [
			{
				"channel": "NOTE_1",
				"lane": 0,
				"x": 0.0,
				"width": 200.0,
			},
		],
	}


func _status_text_layout_metadata() -> Dictionary:
	return {
		"schemaVersion": 1,
		"format": "VOS_RENDER_METADATA",
		"baseWidth": 800.0,
		"baseHeight": 600.0,
		"judgmentLine": 480,
		"measureSize": 385.0,
		"statusTextLayout": {
			"rightX": 100.0,
			"startY": 40.0,
			"lineHeight": 12.0,
			"labelWidth": 50.0,
			"fontFamily": "sans-serif",
			"fontSize": 9,
			"bold": true,
			"antiAlias": false,
			"fontColor": "#ffffffff",
			"horizontalAlignment": "right",
		},
		"entities": [],
		"lanes": [],
	}


func _judgment_behavior_metadata() -> Dictionary:
	return {
		"schemaVersion": 1,
		"format": "VOS_RENDER_METADATA",
		"baseWidth": 800.0,
		"baseHeight": 600.0,
		"judgmentLine": 480,
		"measureSize": 385.0,
		"entities": [
			{
				"id": "EFFECT_JUDGMENT_COOL",
				"type": "judgmentEffect",
				"layer": 0,
				"x": 10.0,
				"y": 20.0,
				"width": 20.0,
				"height": 10.0,
				"named": true,
				"showTimeMs": 50.0,
				"scaleRampMs": 20.0,
				"initialScale": 0.25,
				"sprites": [],
				"spriteFrames": [
					{
						"id": "metadata_judgment_cool",
						"textureWidth": 20.0,
						"textureHeight": 10.0,
					},
				],
			},
		],
		"lanes": [],
	}


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


func _entity_by_sprite(entities: Array, sprite_id: String) -> Dictionary:
	for entity: Variant in entities:
		if not entity is Dictionary:
			continue
		var sprites: Variant = entity.get("sprites", [])
		if not sprites is Array:
			continue
		for sprite: Variant in sprites:
			if str(sprite) == sprite_id:
				return entity
	return {}


func _timebar_decoration_node(view: Node) -> TextureRect:
	for child: Node in view.get_children():
		if not child is TextureRect:
			continue
		var node: TextureRect = child
		if is_equal_approx(node.position.x, 226.0) \
				and is_equal_approx(node.position.y, 515.0) \
				and is_equal_approx(node.size.x, 226.0) \
				and is_equal_approx(node.size.y, 72.0):
			return node
	return null


func _status_node_text(node: Node) -> String:
	if node is Label:
		return node.text
	return str(node.get_meta("statusText", ""))


func _count_children_with_prefix(node: Node, prefix: String) -> int:
	var count := 0
	for child: Node in node.get_children():
		if child.name.begins_with(prefix):
			count += 1
	return count


func _texture_alpha_at(node: TextureRect, x: int, y: int) -> float:
	if node.texture == null:
		return -1.0
	var image: Image = node.texture.get_image()
	if image == null:
		return -1.0
	var clamped_x := int(clamp(x, 0, image.get_width() - 1))
	var clamped_y := int(clamp(y, 0, image.get_height() - 1))
	return image.get_pixel(clamped_x, clamped_y).a


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


func _expect_color(actual: Color, expected: Color, label: String) -> bool:
	if not is_equal_approx(actual.r, expected.r) \
			or not is_equal_approx(actual.g, expected.g) \
			or not is_equal_approx(actual.b, expected.b) \
			or not is_equal_approx(actual.a, expected.a):
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true
