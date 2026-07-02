extends RefCounted


func load_from_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var content := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(content)
	if not parsed is Dictionary:
		return {}

	return normalize(parsed)


func normalize(metadata: Dictionary) -> Dictionary:
	if metadata.get("schemaVersion") != 1:
		return {}
	if metadata.get("format") != "VOS_RENDER_METADATA":
		return {}

	var entities: Variant = metadata.get("entities")
	if not entities is Array:
		return {}
	var normalized_entities: Array[Dictionary] = []
	for entity: Variant in entities:
		if not entity is Dictionary:
			return {}
		var normalized_entity := _normalized_entity(entity)
		if normalized_entity.is_empty():
			return {}
		normalized_entities.append(normalized_entity)

	var lanes: Variant = metadata.get("lanes")
	if not lanes is Array:
		return {}
	var normalized_lanes: Array[Dictionary] = []
	for lane: Variant in lanes:
		if not lane is Dictionary:
			return {}
		var normalized_lane := _normalized_lane(lane)
		if normalized_lane.is_empty():
			return {}
		normalized_lanes.append(normalized_lane)

	var normalized := metadata.duplicate(true)
	if not _is_positive_number(metadata.get("baseWidth")):
		return {}
	if not _is_positive_number(metadata.get("baseHeight")):
		return {}
	if not _is_non_negative_number(metadata.get("judgmentLine")):
		return {}
	if not _is_positive_number(metadata.get("measureSize")):
		return {}
	normalized["baseWidth"] = float(metadata.get("baseWidth"))
	normalized["baseHeight"] = float(metadata.get("baseHeight"))
	normalized["judgmentLine"] = int(metadata.get("judgmentLine"))
	if metadata.has("visibilityLayer"):
		if not _is_non_negative_integer_like(metadata.get("visibilityLayer")):
			return {}
		normalized["visibilityLayer"] = int(metadata.get("visibilityLayer"))
	normalized["measureSize"] = float(metadata.get("measureSize"))
	normalized["entities"] = normalized_entities
	normalized["lanes"] = normalized_lanes

	return normalized


func entities_by_layer(metadata: Dictionary) -> Array[Dictionary]:
	var entities: Array[Dictionary] = []
	for entity: Dictionary in metadata.get("entities", []):
		entities.append(entity.duplicate(true))

	for i in range(1, entities.size()):
		var current := entities[i]
		var j := i - 1
		while j >= 0 and int(entities[j].get("layer", 0)) > int(current.get("layer", 0)):
			entities[j + 1] = entities[j]
			j -= 1
		entities[j + 1] = current

	return entities


func lane_for_channel(metadata: Dictionary, channel: String) -> Dictionary:
	for lane: Dictionary in metadata.get("lanes", []):
		if lane.get("channel", "") == channel:
			return lane.duplicate(true)
	return {}


func _normalized_entity(entity: Dictionary) -> Dictionary:
	if not entity.get("id") is String:
		return {}
	if not entity.get("type") is String:
		return {}

	var sprites: Variant = entity.get("sprites", [])
	if not sprites is Array:
		return {}
	var normalized_sprites: Array[String] = []
	for sprite: Variant in sprites:
		if not sprite is String:
			return {}
		normalized_sprites.append(sprite)

	if not _is_non_negative_integer_like(entity.get("layer")):
		return {}
	if not _is_number(entity.get("x")) or not _is_number(entity.get("y")):
		return {}
	if not _is_positive_number(entity.get("width")) or not _is_positive_number(entity.get("height")):
		return {}

	var normalized := entity.duplicate(true)
	normalized["layer"] = int(entity.get("layer"))
	normalized["x"] = float(entity.get("x"))
	normalized["y"] = float(entity.get("y"))
	normalized["width"] = float(entity.get("width"))
	normalized["height"] = float(entity.get("height"))
	normalized["named"] = bool(entity.get("named", false))
	normalized["sprites"] = normalized_sprites
	if not _normalize_optional_entity_render_fields(normalized):
		return {}
	return normalized


func _normalized_lane(lane: Dictionary) -> Dictionary:
	if not lane.get("channel") is String:
		return {}
	if not _is_non_negative_integer_like(lane.get("lane")):
		return {}
	if not _is_number(lane.get("x")):
		return {}
	if not _is_positive_number(lane.get("width")):
		return {}
	var normalized := lane.duplicate(true)
	normalized["lane"] = int(lane.get("lane"))
	normalized["x"] = float(lane.get("x"))
	normalized["width"] = float(lane.get("width"))
	return normalized


func _is_number(value: Variant) -> bool:
	return value is int or value is float


func _is_positive_number(value: Variant) -> bool:
	return _is_number(value) and float(value) > 0.0


func _is_non_negative_number(value: Variant) -> bool:
	return _is_number(value) and float(value) >= 0.0


func _is_non_negative_integer_like(value: Variant) -> bool:
	if value is int:
		return int(value) >= 0
	if value is float:
		return float(value) >= 0.0 and is_equal_approx(float(value), floor(float(value)))
	return false


func _normalize_optional_entity_render_fields(entity: Dictionary) -> bool:
	if not _normalize_optional_texture_fields(entity, "textureX", "textureY", "textureWidth", "textureHeight"):
		return false
	if not _normalize_optional_positive_number(entity, "frameSpeed"):
		return false
	if not _normalize_optional_sprite_frames(entity, "spriteFrames"):
		return false

	for prefix in ["body", "tail", "title"]:
		if not _normalize_optional_texture_fields(entity,
				"%sTextureX" % prefix,
				"%sTextureY" % prefix,
				"%sTextureWidth" % prefix,
				"%sTextureHeight" % prefix):
			return false
		if not _normalize_optional_positive_number(entity, "%sFrameSpeed" % prefix):
			return false
		if not _normalize_optional_sprite_frames(entity, "%sSpriteFrames" % prefix):
			return false

	if not _normalize_optional_positive_number(entity, "normalHeight"):
		return false
	if not _normalize_optional_positive_integer(entity, "countThreshold"):
		return false
	if not _normalize_optional_non_negative_number(entity, "showTimeMs"):
		return false
	if not _normalize_optional_non_negative_number(entity, "wobblePixels"):
		return false
	if not _normalize_optional_non_negative_number(entity, "wobbleSpeed"):
		return false
	if not _normalize_optional_non_negative_number(entity, "scaleRampMs"):
		return false
	if not _normalize_optional_non_negative_number(entity, "initialScale"):
		return false
	return true


func _normalize_optional_texture_fields(
		entry: Dictionary,
		x_field: String,
		y_field: String,
		width_field: String,
		height_field: String) -> bool:
	if not _normalize_optional_non_negative_number(entry, x_field):
		return false
	if not _normalize_optional_non_negative_number(entry, y_field):
		return false
	if not _normalize_optional_positive_number(entry, width_field):
		return false
	return _normalize_optional_positive_number(entry, height_field)


func _normalize_optional_sprite_frames(entry: Dictionary, field: String) -> bool:
	if not entry.has(field):
		return true
	var raw_frames: Variant = entry.get(field)
	if not raw_frames is Array:
		return false
	var frames: Array[Dictionary] = []
	for raw_frame: Variant in raw_frames:
		if not raw_frame is Dictionary:
			return false
		var frame: Dictionary = raw_frame.duplicate(true)
		if frame.has("id") and not frame.get("id") is String:
			return false
		if frame.has("texturePath") and not frame.get("texturePath") is String:
			return false
		if not _normalize_optional_texture_fields(frame, "textureX", "textureY", "textureWidth", "textureHeight"):
			return false
		frames.append(frame)
	entry[field] = frames
	return true


func _normalize_optional_non_negative_number(entry: Dictionary, field: String) -> bool:
	if not entry.has(field):
		return true
	if not _is_non_negative_number(entry.get(field)):
		return false
	entry[field] = float(entry.get(field))
	return true


func _normalize_optional_positive_number(entry: Dictionary, field: String) -> bool:
	if not entry.has(field):
		return true
	if not _is_positive_number(entry.get(field)):
		return false
	entry[field] = float(entry.get(field))
	return true


func _normalize_optional_positive_integer(entry: Dictionary, field: String) -> bool:
	if not entry.has(field):
		return true
	var value: Variant = entry.get(field)
	if value is int and int(value) > 0:
		entry[field] = int(value)
		return true
	if value is float and float(value) > 0.0 and is_equal_approx(float(value), floor(float(value))):
		entry[field] = int(value)
		return true
	return false
