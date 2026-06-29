extends Node

var _assets_by_sample_id: Dictionary = {}
var _play_events: Array[Dictionary] = []


func load_manifest(manifest: Dictionary) -> bool:
	var assets: Variant = manifest.get("assets")
	if not assets is Array:
		return false

	_assets_by_sample_id.clear()
	_play_events.clear()
	for asset: Variant in assets:
		if not asset is Dictionary:
			return false
		var sample_id := int(asset.get("sampleId", 0))
		if sample_id <= 0:
			return false
		_assets_by_sample_id[sample_id] = asset.duplicate(true)

	return true


func asset_count() -> int:
	return _assets_by_sample_id.size()


func has_sample(sample_id: int) -> bool:
	return _assets_by_sample_id.has(sample_id)


func play_sample(sample_id: int) -> Dictionary:
	if not _assets_by_sample_id.has(sample_id):
		return {"played": false, "sampleId": sample_id, "reason": "missing_sample"}

	var asset: Dictionary = _assets_by_sample_id[sample_id]
	var path := str(asset.get("path", ""))
	var stream: AudioStream = AudioStreamWAV.load_from_file(path)
	if stream == null:
		return {"played": false, "sampleId": sample_id, "reason": "missing_stream", "path": path}

	var player := AudioStreamPlayer.new()
	player.name = "Sample_%d_%d" % [sample_id, _play_events.size() + 1]
	player.stream = stream
	add_child(player)
	if player.is_inside_tree():
		player.play()

	var event := {
		"played": true,
		"sampleId": sample_id,
		"path": path,
		"role": str(asset.get("role", "")),
		"player": player.name,
	}
	_play_events.append(event)
	return event.duplicate(true)


func play_event_count() -> int:
	return _play_events.size()


func play_events() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for event: Dictionary in _play_events:
		events.append(event.duplicate(true))
	return events


func stop_all() -> int:
	var stopped := 0
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			stopped += 1
	return stopped
