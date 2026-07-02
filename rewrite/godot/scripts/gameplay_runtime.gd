extends Node

signal completed(result: Dictionary)

const AudioPlayerPool = preload("res://scripts/audio_player_pool.gd")
const GameplayController = preload("res://scripts/gameplay_controller.gd")
const InputMapStore = preload("res://scripts/input_map_store.gd")
const PartytimeClient = preload("res://scripts/partytime_client.gd")
const PartytimeServer = preload("res://scripts/partytime_server.gd")

const JAVA_FINISH_DELAY_MS: float = 10000.0
const JAVA_MANUAL_START_PROMPT: String = "Press any note button to start the game."
const JAVA_LOCAL_MATCHING_CONNECTING_STATUS: String = "Connecting..."
const JAVA_LOCAL_MATCHING_STARTED_STATUS: String = "Game start!"

var _controller = GameplayController.new()
var _input_map = InputMapStore.new()
var _audio_pool: Node = null
var _running: bool = false
var _paused: bool = false
var _elapsed_ms: float = 0.0
var _game_time_ms: float = 0.0
var _duration_ms: float = 0.0
var _finish_after_ms: float = -1.0
var _fps_elapsed_ms: float = 0.0
var _fps_frame_count: int = 0
var _display_fps: int = 0
var _display_minute: int = 0
var _display_second: int = 0
var _last_result: Dictionary = {}
var _manual_start: bool = false
var _game_started: bool = true
var _autosound_enabled: bool = true
var _audio_latency_ms: float = 0.0
var _display_latency_ms: float = 0.0
var _local_matching_enabled: bool = false
var _local_matching_ready: bool = false
var _local_matching_status: String = ""
var _local_matching_client = null
var _partytime_server = null
var _partytime_server_owned: bool = false
var _partytime_server_start_game_count: int = 0


func _ready() -> void:
	_ensure_audio_pool()


func _process(delta: float) -> void:
	if not _running or _paused:
		return
	advance_to(_elapsed_ms + delta * 1000.0)


func _unhandled_input(event: InputEvent) -> void:
	if not _running or _paused:
		return
	if event is InputEventKey and event.echo:
		return
	if event is InputEventKey and event.pressed and _is_return_key(event):
		if _partytime_server != null:
			_start_partytime_server_game()
			_mark_input_handled()
			return

	for action: String in _input_map.misc_actions():
		if event.is_action_pressed(action):
			_controller.press_misc_action(action)
			_mark_input_handled()
			return
		if event.is_action_released(action):
			_controller.release_misc_action(action)
			_mark_input_handled()
			return

	for lane in range(InputMapStore.LANE_COUNT):
		var action := _input_map.action_for_lane(lane)
		if event.is_action_pressed(action):
			press_action(action)
			_mark_input_handled()
			return
		if event.is_action_released(action):
			release_action(action)
			_mark_input_handled()
			return


func start(chart: Dictionary, audio_manifest: Dictionary) -> bool:
	if chart.is_empty() or audio_manifest.is_empty():
		return false

	_ensure_audio_pool()
	if _audio_pool.has_method("reset_playback_state"):
		_audio_pool.reset_playback_state()
	if not _controller.load_chart(chart):
		return false
	if not _input_map.apply_to_godot_input_map():
		return false
	var audio_manifest_ready := _audio_pool.has_method("has_loaded_manifest") \
			and bool(_audio_pool.has_loaded_manifest(audio_manifest))
	if not audio_manifest_ready and not _audio_pool.load_manifest(audio_manifest):
		return false

	_elapsed_ms = 0.0
	_game_time_ms = 0.0
	_duration_ms = float(chart.get("durationMs", 0.0))
	_finish_after_ms = -1.0
	_fps_elapsed_ms = 0.0
	_fps_frame_count = 0
	_display_fps = 0
	_display_minute = 0
	_display_second = 0
	_last_result.clear()
	_manual_start = bool(chart.get("manualStart", false))
	_autosound_enabled = bool(chart.get("autosound", false))
	_audio_latency_ms = float(chart.get("audioLatencyMs", 0.0))
	_display_latency_ms = float(chart.get("displayLatencyMs", 0.0))
	_load_partytime_server_state(chart)
	_sync_latency_from_controller()
	_start_local_matching_client(chart)
	_game_started = not _manual_start and not _local_matching_enabled
	_paused = false
	if _audio_pool.has_method("set_paused"):
		_audio_pool.set_paused(false)
	_running = true
	return true


func stop() -> void:
	if _audio_pool != null:
		_audio_pool.stop_all()
	if _local_matching_client != null:
		_local_matching_client.disconnect_from_host()
		_local_matching_client = null
	if _partytime_server_owned and _partytime_server != null:
		_partytime_server.stop()
		_partytime_server = null
		_partytime_server_owned = false
	_finish_after_ms = -1.0
	_running = false
	_paused = false


func is_running() -> bool:
	return _running


func set_paused(paused: bool) -> void:
	if not _running:
		_paused = false
	else:
		_paused = paused
	if _audio_pool != null and _audio_pool.has_method("set_paused"):
		_audio_pool.set_paused(_paused)


func is_paused() -> bool:
	return _paused


func set_volume_state(master_volume: float, key_volume: float, bgm_volume: float) -> void:
	_controller.set_volume_state(master_volume, key_volume, bgm_volume)
	_apply_audio_commands()


func elapsed_ms() -> float:
	return _elapsed_ms


func game_time_ms() -> float:
	return _game_time_ms


func judgment_time_ms() -> float:
	return _judgment_time_ms()


func display_time_ms() -> float:
	return _display_time_ms()


func set_key_bindings(bindings: Array) -> bool:
	if not _input_map.set_key_bindings(bindings):
		return false
	if not _controller.set_key_bindings(bindings):
		return false
	return _input_map.apply_to_godot_input_map()


func set_misc_key_bindings(bindings: Dictionary) -> bool:
	if not _input_map.set_misc_key_bindings(bindings):
		return false
	return _input_map.apply_to_godot_input_map()


func set_audio_pool(audio_pool: Node) -> bool:
	if audio_pool == null or not audio_pool.has_method("load_manifest"):
		return false
	if _audio_pool == audio_pool:
		return true
	if _audio_pool != null and _audio_pool.get_parent() == self:
		remove_child(_audio_pool)
		_audio_pool.queue_free()
	var old_parent := audio_pool.get_parent()
	if old_parent != null:
		old_parent.remove_child(audio_pool)
	_audio_pool = audio_pool
	_audio_pool.name = "AudioPlayerPool"
	add_child(_audio_pool)
	return true


func set_local_matching_ready(ready: bool, status: String = "") -> void:
	if not _local_matching_enabled:
		return
	_local_matching_ready = ready
	if not status.is_empty():
		_local_matching_status = status
	elif ready:
		_local_matching_status = JAVA_LOCAL_MATCHING_STARTED_STATUS
	if ready and _local_matching_client != null:
		_local_matching_client.disconnect_from_host()
		_local_matching_client = null


func advance_to(now_ms: float) -> void:
	if not _running or _paused:
		return

	var next_elapsed_ms: float = max(now_ms, _elapsed_ms)
	var delta_ms: float = next_elapsed_ms - _elapsed_ms
	var audio_state := _controller.audio_state()
	_elapsed_ms = next_elapsed_ms
	_update_fps_counter(delta_ms)
	_poll_partytime_server()
	_poll_local_matching_client()
	if not _game_started:
		if _local_matching_enabled and _local_matching_ready:
			_game_started = true
		else:
			return

	_game_time_ms += delta_ms * float(audio_state.get("pitchScale", 1.0))
	_controller.advance_to(_judgment_time_ms(), _display_time_ms(), _game_time_ms, _game_time_ms, delta_ms)
	_sync_latency_from_controller()
	_apply_audio_commands()

	if _controller.note_layer_empty() and _controller.event_buffer_empty():
		if _finish_after_ms < 0.0:
			_finish_after_ms = _elapsed_ms + JAVA_FINISH_DELAY_MS
		elif _elapsed_ms > _finish_after_ms:
			_finish()


func press_action(action: String, now_ms: float = -1.0) -> Dictionary:
	if _paused:
		return {
			"accepted": false,
			"action": action,
			"hitTime": _time_for_input(now_ms),
			"reason": "paused",
		}
	if _local_matching_enabled and not _game_started:
		return {
			"accepted": false,
			"action": action,
			"hitTime": _time_for_input(now_ms),
			"reason": "local_matching_wait",
		}
	var starts_game := _starts_game(action)
	if starts_game:
		_game_started = true
	var hit_time := _judgment_time_ms() if starts_game else _time_for_input(now_ms)
	var response: Dictionary = _controller.press_action(action, hit_time)
	_sync_latency_from_controller()
	_apply_audio_commands()
	return response


func release_action(action: String, now_ms: float = -1.0) -> Dictionary:
	if _paused:
		return {
			"released": false,
			"accepted": false,
			"action": action,
			"hitTime": _time_for_input(now_ms),
			"reason": "paused",
		}
	if _local_matching_enabled and not _game_started:
		return {
			"accepted": false,
			"action": action,
			"hitTime": _time_for_input(now_ms),
			"reason": "local_matching_wait",
		}
	var hit_time := _time_for_input(now_ms)
	var response: Dictionary = _controller.release_action(action, hit_time)
	_sync_latency_from_controller()
	_apply_audio_commands()
	return response


func result() -> Dictionary:
	if _last_result.is_empty():
		return _result_with_runtime_state(_controller.result())
	return _last_result.duplicate(true)


func partytime_server_start_game_count() -> int:
	return _partytime_server_start_game_count


func hud_state() -> Dictionary:
	var state := result()
	state["elapsedMs"] = int(round(_elapsed_ms))
	state["gameTimeMs"] = int(round(_game_time_ms))
	state["judgmentTimeMs"] = int(round(_judgment_time_ms()))
	state["displayTimeMs"] = int(round(_display_time_ms()))
	state["durationMs"] = int(round(_duration_ms))
	state["gameStarted"] = _game_started
	state["fps"] = _display_fps
	state["minute"] = _display_minute
	state["second"] = _display_second
	state["pressedLanes"] = _controller.pressed_lanes()
	state.merge(_controller.render_state(_judgment_time_ms(), _game_time_ms), true)
	if _local_matching_enabled:
		var matching_status_texts: Array = state.get("statusTexts", []).duplicate()
		matching_status_texts.append(_local_matching_status)
		state["statusTexts"] = matching_status_texts
	elif not _game_started:
		var status_texts: Array = state.get("statusTexts", []).duplicate()
		status_texts.append(JAVA_MANUAL_START_PROMPT)
		state["statusTexts"] = status_texts
	if _partytime_server != null:
		state["networkStatusTexts"] = _partytime_server.status_texts()
	return state


func audio_play_event_count() -> int:
	if _audio_pool == null:
		return 0
	return _audio_pool.play_event_count()


func _ensure_audio_pool() -> void:
	if _audio_pool != null:
		return
	_audio_pool = AudioPlayerPool.new()
	_audio_pool.name = "AudioPlayerPool"
	add_child(_audio_pool)


func _apply_audio_commands() -> void:
	if _audio_pool == null:
		return
	var volume_state := _controller.volume_state()
	var audio_state := _controller.audio_state()
	_audio_pool.set_volume_state(
			float(volume_state.get("masterVolume", 1.0)),
			float(volume_state.get("keyVolume", 1.0)),
			float(volume_state.get("bgmVolume", 1.0)))
	_audio_pool.set_pitch_scale(float(audio_state.get("pitchScale", 1.0)))
	_audio_pool.apply_audio_commands(_controller.drain_audio_commands())


func _time_for_input(now_ms: float) -> float:
	if now_ms >= 0.0:
		return now_ms
	return _judgment_time_ms()


func _judgment_time_ms() -> float:
	if _autosound_enabled:
		return _game_time_ms - _audio_latency_ms
	return _game_time_ms


func _display_time_ms() -> float:
	return _judgment_time_ms() + _display_latency_ms


func _sync_latency_from_controller() -> void:
	var audio_state := _controller.audio_state()
	_audio_latency_ms = float(audio_state.get("audioLatencyMs", _audio_latency_ms))
	_display_latency_ms = float(audio_state.get("displayLatencyMs", _display_latency_ms))


func _starts_game(action: String) -> bool:
	if _game_started:
		return false
	if _local_matching_enabled:
		return false
	return _input_map.lane_for_action(action) >= 0


func _start_local_matching_client(chart: Dictionary) -> void:
	_local_matching_client = null
	_local_matching_ready = bool(chart.get("localMatchingReady", false))
	_local_matching_status = str(chart.get("localMatchingStatus", JAVA_LOCAL_MATCHING_CONNECTING_STATUS))
	var server_parts := _local_matching_server_parts(str(chart.get("localMatchingServer", "")))
	_local_matching_enabled = not server_parts.is_empty()
	if not _local_matching_enabled:
		return
	if not bool(chart.get("localMatchingClientEnabled", true)):
		return
	_local_matching_client = PartytimeClient.new()
	_local_matching_client.start(str(server_parts[0]), int(server_parts[1]), int(_audio_latency_ms))
	_local_matching_status = _local_matching_client.status()


func _poll_local_matching_client() -> void:
	if _local_matching_client == null:
		return
	_local_matching_client.poll()
	_local_matching_status = _local_matching_client.status()
	if _local_matching_client.is_ready():
		_local_matching_ready = true
		_local_matching_client = null


func _local_matching_server_parts(value: String) -> Array:
	var parts := value.strip_edges().split(":")
	if parts.size() != 2:
		return []
	if not str(parts[1]).is_valid_int():
		return []
	return [str(parts[0]), int(parts[1])]


func _load_partytime_server_state(chart: Dictionary) -> void:
	if _partytime_server_owned and _partytime_server != null:
		_partytime_server.stop()
	_partytime_server = null
	_partytime_server_owned = false
	_partytime_server_start_game_count = 0

	var raw_connections: Variant = chart.get("partytimeServerConnections", [])
	var external_server: Variant = chart.get("partytimeServerObject", null)
	if external_server != null and external_server.has_method("status_texts"):
		_partytime_server = external_server
		return

	if chart.has("partytimeServerPort") and str(chart.get("partytimeServerPort", "")).is_valid_int():
		_partytime_server = PartytimeServer.new()
		_partytime_server_owned = true
		_partytime_server.start(int(chart.get("partytimeServerPort", 0)))
		return

	if bool(chart.get("partytimeServerEnabled", false)) or chart.has("partytimeServerStatus") or chart.has("partytimeServerConnections"):
		_partytime_server = PartytimeServer.new()
		_partytime_server.start_with_state(str(chart.get("partytimeServerStatus", "Creating server...")),
				raw_connections if raw_connections is Array else [])


func _poll_partytime_server() -> void:
	if _partytime_server != null and _partytime_server.has_method("poll"):
		_partytime_server.poll()


func _start_partytime_server_game() -> void:
	_partytime_server_start_game_count += 1
	if _partytime_server != null and _partytime_server.has_method("start_game"):
		_partytime_server.start_game()
	_partytime_server = null
	_partytime_server_owned = false


func _is_return_key(event: InputEventKey) -> bool:
	return event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER


func _update_fps_counter(delta_ms: float) -> void:
	_fps_elapsed_ms += delta_ms
	_fps_frame_count += 1
	if _fps_elapsed_ms < 1000.0:
		return

	_display_fps = _fps_frame_count
	_fps_elapsed_ms -= 1000.0
	_fps_frame_count = 0
	if _display_second >= 59:
		_display_second = 0
		_display_minute += 1
	else:
		_display_second += 1


func _mark_input_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _finish() -> void:
	_last_result = _result_with_runtime_state(_controller.result())
	stop()
	completed.emit(_last_result.duplicate(true))


func _result_with_runtime_state(result: Dictionary) -> Dictionary:
	var next_result := result.duplicate(true)
	var audio_state := _controller.audio_state()
	next_result["audioLatencyMs"] = float(audio_state.get("audioLatencyMs", _audio_latency_ms))
	next_result["displayLatencyMs"] = float(audio_state.get("displayLatencyMs", _display_latency_ms))
	next_result["autosyncMode"] = str(audio_state.get("autosyncMode", ""))
	return next_result
