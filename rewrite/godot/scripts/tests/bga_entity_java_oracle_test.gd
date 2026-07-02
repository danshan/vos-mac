extends SceneTree

const GameplayView = preload("res://scripts/gameplay_view.gd")

const TEXTURE_PATH := "user://bga-entity-oracle.png"


func _init() -> void:
	var oracle := _load_oracle()
	if oracle.is_empty():
		return
	_write_test_texture()

	var view = GameplayView.new()
	if not _expect_bool(view.load_metadata(_metadata_for_oracle(oracle)), true, "BGA metadata load"):
		return
	if not _expect_bool(view.load_chart(_chart_for_oracle(oracle)), true, "BGA chart load"):
		return
	if not _expect_bool(view.has_node("Entity_BGA"), true, "BGA node"):
		return
	if not _expect_bool(view.get_node("Entity_BGA") is TextureRect, true, "BGA texture node"):
		return

	var snapshots: Variant = oracle.get("snapshots")
	if not snapshots is Array:
		push_error("Expected BGA entity oracle snapshots.")
		quit(1)
		return

	var expected_sprite := "base"
	for raw_snapshot: Variant in snapshots:
		if not raw_snapshot is Dictionary:
			push_error("Expected BGA entity oracle snapshot object.")
			quit(1)
			return
		var snapshot: Dictionary = raw_snapshot
		var name := str(snapshot.get("name", ""))
		match name:
			"initial_draw":
				if not _verify_snapshot(view, snapshot, oracle):
					return
			"first_queued", "second_queued":
				if not _expect_string(_current_sprite(view), expected_sprite, "%s keeps current sprite before judgment" % name):
					return
			"first_judgment":
				expected_sprite = str(snapshot.get("sprite", ""))
				view.update_hud_state({"currentBgaEvent": {"spriteId": 1}, "gameStarted": true})
				if not _verify_snapshot(view, snapshot, oracle):
					return
			"second_judgment":
				expected_sprite = str(snapshot.get("sprite", ""))
				view.update_hud_state({"currentBgaEvent": {"spriteId": 2}, "gameStarted": true})
				if not _verify_snapshot(view, snapshot, oracle):
					return
			"empty_queue_keeps_second":
				view.update_hud_state({"currentBgaEvent": {}, "gameStarted": true})
				if not _verify_snapshot(view, snapshot, oracle):
					return
			_:
				push_error("Unexpected BGA entity oracle snapshot: %s" % name)
				quit(1)
				return

	view.free()
	_remove_test_texture()
	quit(0)


func _load_oracle() -> Dictionary:
	var path := "res://test/fixtures/bga-entity-oracle.json"
	if not FileAccess.file_exists(path):
		push_error("Missing BGA entity oracle fixture: %s" % path)
		quit(1)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Expected BGA entity oracle root object.")
		quit(1)
		return {}
	var root: Dictionary = parsed
	if int(root.get("schemaVersion", 0)) != 1:
		push_error("Expected BGA entity oracle schema version 1.")
		quit(1)
		return {}
	if str(root.get("source", "")) != "BgaEntity.setSprite setTime judgment draw":
		push_error("Expected BGA entity oracle source BgaEntity.setSprite setTime judgment draw.")
		quit(1)
		return {}
	return root


func _metadata_for_oracle(oracle: Dictionary) -> Dictionary:
	var texture_path := ProjectSettings.globalize_path(TEXTURE_PATH)
	return {
		"schemaVersion": 1,
		"format": "VOS_RENDER_METADATA",
		"baseWidth": 800.0,
		"baseHeight": 600.0,
		"judgmentLine": 480.0,
		"measureSize": 385.0,
		"entities": [{
			"id": "BGA",
			"type": "bga",
			"layer": 0,
			"x": float(oracle.get("x", 0.0)),
			"y": float(oracle.get("y", 0.0)),
			"width": float(oracle.get("baseWidth", 1.0)),
			"height": float(oracle.get("baseHeight", 1.0)),
			"named": true,
			"texturePath": texture_path,
			"textureX": 0.0,
			"textureY": 0.0,
			"textureWidth": float(oracle.get("baseWidth", 1.0)),
			"textureHeight": float(oracle.get("baseHeight", 1.0)),
			"sprites": [],
		}],
		"lanes": [],
	}


func _chart_for_oracle(_oracle: Dictionary) -> Dictionary:
	var texture_path := ProjectSettings.globalize_path(TEXTURE_PATH)
	return {
		"schemaVersion": 1,
		"format": "VOS_GAMEPLAY",
		"title": "BGA Oracle",
		"artist": "",
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 1000,
		"notes": [],
		"measures": [],
		"timingPoints": [],
		"bgaSprites": [
			_bga_sprite(1, "first", texture_path, 320.0, 0.0, 160.0, 120.0),
			_bga_sprite(2, "second", texture_path, 0.0, 240.0, 640.0, 480.0),
		],
	}


func _bga_sprite(sprite_id: int, sprite_name: String, texture_path: String,
		texture_x: float, texture_y: float, width: float, height: float) -> Dictionary:
	return {
		"spriteId": sprite_id,
		"spriteName": sprite_name,
		"texturePath": texture_path,
		"textureX": texture_x,
		"textureY": texture_y,
		"textureWidth": width,
		"textureHeight": height,
		"width": width,
		"height": height,
	}


func _verify_snapshot(view: Node, snapshot: Dictionary, oracle: Dictionary) -> bool:
	var node: TextureRect = view.get_node("Entity_BGA")
	var sprite_name := str(snapshot.get("sprite", ""))
	if not _expect_string(_current_sprite(view), sprite_name, "%s sprite" % snapshot.get("name", "")):
		return false
	if not _expect_float(node.position.x, float(snapshot.get("drawX", 0.0)), "%s x" % snapshot.get("name", "")):
		return false
	if not _expect_float(node.position.y, float(snapshot.get("drawY", 0.0)), "%s y" % snapshot.get("name", "")):
		return false
	var expected_width := float(snapshot.get("spriteWidth", oracle.get("baseWidth", 1.0))) * float(snapshot.get("drawScaleX", 1.0))
	var expected_height := float(snapshot.get("spriteHeight", oracle.get("baseHeight", 1.0))) * float(snapshot.get("drawScaleY", 1.0))
	if not _expect_float(node.size.x, expected_width, "%s screen width" % snapshot.get("name", "")):
		return false
	if not _expect_float(node.size.y, expected_height, "%s screen height" % snapshot.get("name", "")):
		return false
	if not node.texture is AtlasTexture:
		push_error("Expected %s BGA texture to be an AtlasTexture." % snapshot.get("name", ""))
		quit(1)
		return false
	var texture: AtlasTexture = node.texture
	if not _expect_float(texture.region.size.x, float(snapshot.get("spriteWidth", oracle.get("baseWidth", 1.0))),
			"%s source width" % snapshot.get("name", "")):
		return false
	if not _expect_float(texture.region.size.y, float(snapshot.get("spriteHeight", oracle.get("baseHeight", 1.0))),
			"%s source height" % snapshot.get("name", "")):
		return false
	return true


func _current_sprite(view: Node) -> String:
	var node: TextureRect = view.get_node("Entity_BGA")
	if node.has_meta("currentBgaSpriteName"):
		return str(node.get_meta("currentBgaSpriteName"))
	if node.has_meta("currentBgaSpriteId"):
		var sprite_id := int(node.get_meta("currentBgaSpriteId"))
		if sprite_id == 1:
			return "first"
		if sprite_id == 2:
			return "second"
	return "base"


func _write_test_texture() -> void:
	var image := Image.create(960, 720, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	image.fill_rect(Rect2i(0, 0, 320, 240), Color(1.0, 0.0, 0.0, 1.0))
	image.fill_rect(Rect2i(320, 0, 160, 120), Color(0.0, 1.0, 0.0, 1.0))
	image.fill_rect(Rect2i(0, 240, 640, 480), Color(0.0, 0.0, 1.0, 1.0))
	image.save_png(ProjectSettings.globalize_path(TEXTURE_PATH))


func _remove_test_texture() -> void:
	var path := ProjectSettings.globalize_path(TEXTURE_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _expect_bool(actual: bool, expected: bool, label: String) -> bool:
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
