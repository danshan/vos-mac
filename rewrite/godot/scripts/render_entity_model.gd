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
	normalized["baseWidth"] = _number(metadata.get("baseWidth"), 0.0)
	normalized["baseHeight"] = _number(metadata.get("baseHeight"), 0.0)
	normalized["judgmentLine"] = int(_number(metadata.get("judgmentLine"), 0.0))
	if metadata.has("visibilityLayer"):
		normalized["visibilityLayer"] = int(_number(metadata.get("visibilityLayer"), 0.0))
	normalized["measureSize"] = _number(metadata.get("measureSize"), 0.0)
	normalized["entities"] = normalized_entities
	normalized["lanes"] = normalized_lanes

	if normalized["baseWidth"] <= 0.0 or normalized["baseHeight"] <= 0.0 or normalized["measureSize"] <= 0.0:
		return {}

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

	var normalized := entity.duplicate(true)
	normalized["layer"] = int(_number(entity.get("layer"), 0.0))
	normalized["x"] = _number(entity.get("x"), 0.0)
	normalized["y"] = _number(entity.get("y"), 0.0)
	normalized["width"] = _number(entity.get("width"), 0.0)
	normalized["height"] = _number(entity.get("height"), 0.0)
	normalized["named"] = bool(entity.get("named", false))
	normalized["sprites"] = normalized_sprites
	return normalized


func _normalized_lane(lane: Dictionary) -> Dictionary:
	if not lane.get("channel") is String:
		return {}
	var normalized := lane.duplicate(true)
	normalized["lane"] = int(_number(lane.get("lane"), -1.0))
	normalized["x"] = _number(lane.get("x"), 0.0)
	normalized["width"] = _number(lane.get("width"), 0.0)
	if normalized["lane"] < 0 or normalized["width"] <= 0.0:
		return {}
	return normalized


func _number(value: Variant, fallback: float) -> float:
	if value is int or value is float:
		return float(value)
	return fallback
