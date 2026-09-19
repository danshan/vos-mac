extends Node

var _assets_by_sample_id: Dictionary = {}
var _preloaded_streams: Dictionary = {}
var _preload_sample_ids: Array[int] = []
var _play_events: Array[Dictionary] = []
var _registered_players: Dictionary = {}
var _master_volume: float = 1.0
var _key_volume: float = 1.0
var _bgm_volume: float = 1.0
var _pitch_scale: float = 1.0
var _paused: bool = false
var _manifest_signature: String = ""
var _preload_thread: Thread = null
const JAVA_PAN_DISTANCE_SCALE: float = 1.0
const JAVA_PANNING_STRENGTH: float = 1.0
const MAX_EAGER_PRELOAD_ASSETS: int = 32


func _exit_tree() -> void:
	_wait_for_preload_thread()


func load_manifest(manifest: Dictionary, eager_preload: bool = true) -> bool:
	_wait_for_preload_thread()
	var assets: Variant = manifest.get("assets")
	if not assets is Array:
		return false

	_assets_by_sample_id.clear()
	_preloaded_streams.clear()
	_preload_sample_ids.clear()
	_play_events.clear()
	_registered_players.clear()
	_manifest_signature = _manifest_signature_for(manifest)
	var allow_eager_preload: bool = eager_preload and assets.size() <= MAX_EAGER_PRELOAD_ASSETS
	for asset: Variant in assets:
		if not asset is Dictionary:
			return false
		var sample_id := int(asset.get("sampleId", 0))
		if sample_id <= 0:
			return false
		var normalized_asset: Dictionary = asset.duplicate(true)
		_assets_by_sample_id[sample_id] = normalized_asset
		if bool(normalized_asset.get("preload", false)):
			_preload_sample_ids.append(sample_id)
		if allow_eager_preload and _preload_sample_ids.has(sample_id):
			if not _preload_sample(sample_id):
				return false

	return true


func has_loaded_manifest(manifest: Dictionary) -> bool:
	return not _manifest_signature.is_empty() and _manifest_signature == _manifest_signature_for(manifest)


func asset_count() -> int:
	return _assets_by_sample_id.size()


func has_sample(sample_id: int) -> bool:
	return _assets_by_sample_id.has(sample_id)


func preloaded_sample_count() -> int:
	return _preloaded_streams.size()


func reset_playback_state() -> void:
	stop_all()
	_paused = false
	_play_events.clear()
	_registered_players.clear()


func preload_sample_count() -> int:
	return _preload_sample_ids.size()


func preload_pending_sample_count() -> int:
	if not _collect_preload_thread_if_done():
		return _preload_sample_ids.size()
	var count := 0
	for sample_id: int in _preload_sample_ids:
		if not _preloaded_streams.has(sample_id):
			count += 1
	return count


func preload_next_sample() -> bool:
	if not _wait_for_preload_thread():
		return false
	for sample_id: int in _preload_sample_ids:
		if _preloaded_streams.has(sample_id):
			continue
		return _preload_sample(sample_id)
	return true


func preload_next_sample_async() -> bool:
	var had_active_thread := _preload_thread != null
	if not _collect_preload_thread_if_done():
		return false
	if _preload_thread != null:
		return true
	if had_active_thread:
		return true

	var sample_id := _next_pending_preload_sample_id()
	if sample_id <= 0:
		return true

	var asset: Dictionary = _assets_by_sample_id[sample_id].duplicate(true)
	_preload_thread = Thread.new()
	var error := _preload_thread.start(_load_stream_for_asset_on_thread.bind(sample_id, asset))
	if error != OK:
		_preload_thread = null
		return false
	return true


func preload_in_progress() -> bool:
	return _preload_thread != null and _preload_thread.is_alive()


func set_volume_state(master_volume: float, key_volume: float, bgm_volume: float) -> void:
	_master_volume = _clamped_volume(master_volume)
	_key_volume = _clamped_volume(key_volume)
	_bgm_volume = _clamped_volume(bgm_volume)
	_update_active_player_volumes()


func set_pitch_scale(pitch_scale: float) -> void:
	_pitch_scale = _clamped_pitch_scale(pitch_scale)
	_update_active_player_pitch_scale()


func set_paused(paused: bool) -> void:
	_paused = paused
	for child in get_children():
		if child is AudioStreamPlayer2D:
			(child as AudioStreamPlayer2D).stream_paused = paused


func is_paused() -> bool:
	return _paused


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
		if not _preload_sample(sample_id):
			return {"played": false, "sampleId": sample_id, "reason": "missing_stream", "path": path}
		stream = _preloaded_streams.get(sample_id, null)
	if stream == null:
		return {"played": false, "sampleId": sample_id, "reason": "missing_stream", "path": path}

	var player := AudioStreamPlayer2D.new()
	player.name = "Sample_%d_%d" % [sample_id, _play_events.size() + 1]
	player.stream = stream
	var sample_volume := 1.0
	var pan := float(command.get("pan", 0.0))
	var uses_bgm_channel := _command_uses_bgm_channel(command)
	var channel_volume := _channel_volume(uses_bgm_channel)
	var effective_volume := _clamped_volume(_master_volume * channel_volume * sample_volume)
	player.position = Vector2(pan * JAVA_PAN_DISTANCE_SCALE, 0.0)
	player.panning_strength = JAVA_PANNING_STRENGTH
	player.attenuation = 0.0
	player.volume_db = _volume_db_for_linear(effective_volume)
	player.pitch_scale = _pitch_scale
	player.stream_paused = _paused
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
		if child is AudioStreamPlayer2D:
			child.stop()
			stopped += 1
	_registered_players.clear()
	_paused = false
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
	if player is AudioStreamPlayer2D and is_instance_valid(player):
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


func _preload_sample(sample_id: int) -> bool:
	if _preloaded_streams.has(sample_id):
		return true
	if not _assets_by_sample_id.has(sample_id):
		return false
	var stream := _load_stream_for_asset(_assets_by_sample_id[sample_id])
	if stream == null:
		return false
	_preloaded_streams[sample_id] = stream
	return true


func _next_pending_preload_sample_id() -> int:
	for sample_id: int in _preload_sample_ids:
		if not _preloaded_streams.has(sample_id):
			return sample_id
	return 0


func _load_stream_for_asset_on_thread(sample_id: int, asset: Dictionary) -> Dictionary:
	var stream := _load_stream_for_asset(asset)
	if stream == null:
		return {
			"ok": false,
			"sampleId": sample_id,
			"path": str(asset.get("path", "")),
		}
	return {
		"ok": true,
		"sampleId": sample_id,
		"path": str(asset.get("path", "")),
		"stream": stream,
	}


func _collect_preload_thread_if_done() -> bool:
	if _preload_thread == null:
		return true
	if _preload_thread.is_alive():
		return true
	var result: Variant = _preload_thread.wait_to_finish()
	_preload_thread = null
	return _store_preload_thread_result(result)


func _wait_for_preload_thread() -> bool:
	if _preload_thread == null:
		return true
	var result: Variant = _preload_thread.wait_to_finish()
	_preload_thread = null
	return _store_preload_thread_result(result)


func _store_preload_thread_result(result: Variant) -> bool:
	if not result is Dictionary:
		return false
	var sample_id := int(result.get("sampleId", 0))
	if not bool(result.get("ok", false)):
		return false
	if sample_id <= 0 or not _assets_by_sample_id.has(sample_id):
		return false
	var stream: Variant = result.get("stream", null)
	if not stream is AudioStream:
		return false
	_preloaded_streams[sample_id] = stream
	return true


func _manifest_signature_for(manifest: Dictionary) -> String:
	var assets: Variant = manifest.get("assets")
	if not assets is Array:
		return ""
	var parts: Array[String] = [
		str(manifest.get("sourcePath", "")),
		str(manifest.get("assetDir", "")),
		str(assets.size()),
	]
	for asset: Variant in assets:
		if asset is Dictionary:
			parts.append("%s:%s:%s" % [
				str(asset.get("sampleId", "")),
				str(asset.get("path", "")),
				str(asset.get("preload", false)),
			])
	return "|".join(parts)


func _command_uses_bgm_channel(command: Dictionary) -> bool:
	return str(command.get("source", "")) == "autoPlay"


func _channel_volume(uses_bgm_channel: bool) -> float:
	if uses_bgm_channel:
		return _bgm_volume
	return _key_volume


func _update_active_player_volumes() -> void:
	for child in get_children():
		if child is AudioStreamPlayer2D and child.has_meta("sample_volume") and child.has_meta("uses_bgm_channel"):
			var sample_volume := float(child.get_meta("sample_volume"))
			var uses_bgm_channel := bool(child.get_meta("uses_bgm_channel"))
			var effective_volume := _clamped_volume(_master_volume * _channel_volume(uses_bgm_channel) * sample_volume)
			(child as AudioStreamPlayer2D).volume_db = _volume_db_for_linear(effective_volume)


func _update_active_player_pitch_scale() -> void:
	for child in get_children():
		if child is AudioStreamPlayer2D:
			(child as AudioStreamPlayer2D).pitch_scale = _pitch_scale


func _clamped_volume(volume: float) -> float:
	return clampf(volume, 0.0, 1.0)


func _clamped_pitch_scale(pitch_scale: float) -> float:
	return clampf(pitch_scale, 0.25, 4.0)


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
