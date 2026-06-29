extends Node

var _assets_by_sample_id: Dictionary = {}
var _preloaded_streams: Dictionary = {}
var _play_events: Array[Dictionary] = []
var _registered_players: Dictionary = {}
var _master_volume: float = 1.0
var _key_volume: float = 1.0
var _bgm_volume: float = 1.0
var _pitch_scale: float = 1.0


func load_manifest(manifest: Dictionary) -> bool:
	var assets: Variant = manifest.get("assets")
	if not assets is Array:
		return false

	_assets_by_sample_id.clear()
	_preloaded_streams.clear()
	_play_events.clear()
	_registered_players.clear()
	for asset: Variant in assets:
		if not asset is Dictionary:
			return false
		var sample_id := int(asset.get("sampleId", 0))
		if sample_id <= 0:
			return false
		var normalized_asset: Dictionary = asset.duplicate(true)
		_assets_by_sample_id[sample_id] = normalized_asset
		if bool(normalized_asset.get("preload", false)):
			var stream := _load_stream_for_asset(normalized_asset)
			if stream == null:
				return false
			_preloaded_streams[sample_id] = stream

	return true


func asset_count() -> int:
	return _assets_by_sample_id.size()


func has_sample(sample_id: int) -> bool:
	return _assets_by_sample_id.has(sample_id)


func preloaded_sample_count() -> int:
	return _preloaded_streams.size()


func set_volume_state(master_volume: float, key_volume: float, bgm_volume: float) -> void:
	_master_volume = _clamped_volume(master_volume)
	_key_volume = _clamped_volume(key_volume)
	_bgm_volume = _clamped_volume(bgm_volume)
	_update_active_player_volumes()


func set_pitch_scale(pitch_scale: float) -> void:
	_pitch_scale = _clamped_pitch_scale(pitch_scale)
	_update_active_player_pitch_scale()


func apply_audio_commands(commands: Array) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for command: Variant in commands:
		if command is Dictionary:
			results.append(apply_audio_command(command))
		else:
			results.append({"ok": false, "reason": "invalid_command"})
	return results


func apply_audio_command(command: Dictionary) -> Dictionary:
	var action := str(command.get("action", ""))
	match action:
		"playSample":
			return _play_sample_with_command(int(command.get("sampleId", 0)), command)
		"stopSample":
			return _stop_sample_for_command(command)
		_:
			return {"ok": false, "action": action, "reason": "unknown_action"}


func play_sample(sample_id: int) -> Dictionary:
	return _play_sample_with_command(sample_id, {})


func _play_sample_with_command(sample_id: int, command: Dictionary) -> Dictionary:
	if not _assets_by_sample_id.has(sample_id):
		return {"played": false, "sampleId": sample_id, "reason": "missing_sample"}

	var instance_key := _instance_key(command)
	var should_register := _should_register_instance(command) and not instance_key.is_empty()
	if should_register and _registered_players.has(instance_key):
		return {
			"played": false,
			"sampleId": sample_id,
			"reason": "already_played",
			"registeredInstance": true,
		}

	var asset: Dictionary = _assets_by_sample_id[sample_id]
	var path := str(asset.get("path", ""))
	var stream: AudioStream = _preloaded_streams.get(sample_id, null)
	if stream == null:
		stream = _load_stream_for_asset(asset)
	if stream == null:
		return {"played": false, "sampleId": sample_id, "reason": "missing_stream", "path": path}

	var player := AudioStreamPlayer.new()
	player.name = "Sample_%d_%d" % [sample_id, _play_events.size() + 1]
	player.stream = stream
	var sample_volume := 1.0
	var pan := _clamped_pan(float(command.get("pan", 0.0)))
	var uses_bgm_channel := _asset_uses_bgm_channel(asset)
	var channel_volume := _channel_volume(uses_bgm_channel)
	var effective_volume := _clamped_volume(_master_volume * channel_volume * sample_volume)
	player.volume_db = _volume_db_for_linear(effective_volume)
	player.pitch_scale = _pitch_scale
	player.set_meta("sample_volume", sample_volume)
	player.set_meta("uses_bgm_channel", uses_bgm_channel)
	player.set_meta("pan", pan)
	add_child(player)
	if player.is_inside_tree():
		player.play()

	var event := {
		"played": true,
		"sampleId": sample_id,
		"path": path,
		"role": str(asset.get("role", "")),
		"player": player.name,
		"registeredInstance": should_register,
		"sampleVolume": sample_volume,
		"masterVolume": _master_volume,
		"channelVolume": channel_volume,
		"effectiveVolume": effective_volume,
		"pan": pan,
		"pitchScale": _pitch_scale,
	}
	_copy_command_field(command, event, "action")
	_copy_command_field(command, event, "source")
	_copy_command_field(command, event, "trigger")
	_copy_command_field(command, event, "noteId")
	_copy_command_field(command, event, "lane")
	_copy_command_field(command, event, "startMs")
	if should_register:
		_registered_players[instance_key] = player

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
	_registered_players.clear()
	return stopped


func _stop_sample_for_command(command: Dictionary) -> Dictionary:
	var sample_id := int(command.get("sampleId", 0))
	var instance_key := _instance_key(command)
	if instance_key.is_empty():
		return {"stopped": false, "sampleId": sample_id, "reason": "missing_instance_key"}
	if not _registered_players.has(instance_key):
		return {"stopped": false, "sampleId": sample_id, "reason": "missing_instance"}

	var player: Variant = _registered_players.get(instance_key)
	_registered_players.erase(instance_key)
	if player is AudioStreamPlayer and is_instance_valid(player):
		player.stop()
		return {
			"stopped": true,
			"sampleId": sample_id,
			"player": player.name,
		}
	return {"stopped": false, "sampleId": sample_id, "reason": "invalid_instance"}


func _should_register_instance(command: Dictionary) -> bool:
	var trigger := str(command.get("trigger", ""))
	return str(command.get("source", "")) == "note" and (trigger == "keysound" or trigger == "autosound")


func _load_stream_for_asset(asset: Dictionary) -> AudioStream:
	var path := str(asset.get("path", ""))
	if path.is_empty():
		return null
	return AudioStreamWAV.load_from_file(path)


func _asset_uses_bgm_channel(asset: Dictionary) -> bool:
	var role := str(asset.get("role", "")).to_lower()
	return role == "background" or role == "bgm"


func _channel_volume(uses_bgm_channel: bool) -> float:
	if uses_bgm_channel:
		return _bgm_volume
	return _key_volume


func _update_active_player_volumes() -> void:
	for child in get_children():
		if child is AudioStreamPlayer and child.has_meta("sample_volume") and child.has_meta("uses_bgm_channel"):
			var sample_volume := float(child.get_meta("sample_volume"))
			var uses_bgm_channel := bool(child.get_meta("uses_bgm_channel"))
			var effective_volume := _clamped_volume(_master_volume * _channel_volume(uses_bgm_channel) * sample_volume)
			(child as AudioStreamPlayer).volume_db = _volume_db_for_linear(effective_volume)


func _update_active_player_pitch_scale() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			(child as AudioStreamPlayer).pitch_scale = _pitch_scale


func _clamped_volume(volume: float) -> float:
	return clampf(volume, 0.0, 1.0)


func _clamped_pitch_scale(pitch_scale: float) -> float:
	return clampf(pitch_scale, 0.25, 4.0)


func _clamped_pan(pan: float) -> float:
	return clampf(pan, -1.0, 1.0)


func _volume_db_for_linear(volume: float) -> float:
	if volume <= 0.0:
		return -80.0
	return linear_to_db(volume)


func _instance_key(command: Dictionary) -> String:
	if command.has("noteId"):
		return "note:%d" % int(command.get("noteId", 0))
	if command.has("lane") and command.has("startMs"):
		return "note:%d:%0.3f:%d" % [
			int(command.get("lane", -1)),
			float(command.get("startMs", 0.0)),
			int(command.get("sampleId", 0)),
		]
	return ""


func _copy_command_field(source: Dictionary, target: Dictionary, field: String) -> void:
	if source.has(field):
		target[field] = source.get(field)
