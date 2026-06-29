extends Node

signal completed(result: Dictionary)

const AudioPlayerPool = preload("res://scripts/audio_player_pool.gd")
const GameplayController = preload("res://scripts/gameplay_controller.gd")
const InputMapStore = preload("res://scripts/input_map_store.gd")

const JAVA_FINISH_DELAY_MS: float = 10000.0

var _controller = GameplayController.new()
var _input_map = InputMapStore.new()
var _audio_pool: Node = null
var _running: bool = false
var _elapsed_ms: float = 0.0
var _duration_ms: float = 0.0
var _finish_after_ms: float = -1.0
var _fps_elapsed_ms: float = 0.0
var _fps_frame_count: int = 0
var _display_fps: int = 0
var _display_minute: int = 0
var _display_second: int = 0
var _last_result: Dictionary = {}


func _ready() -> void:
	_ensure_audio_pool()


func _process(delta: float) -> void:
	if not _running:
		return
	advance_to(_elapsed_ms + delta * 1000.0)


func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	if event is InputEventKey and event.echo:
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
	if not _controller.load_chart(chart):
		return false
	if not _input_map.apply_to_godot_input_map():
		return false
	if not _audio_pool.load_manifest(audio_manifest):
		return false

	_elapsed_ms = 0.0
	_duration_ms = float(chart.get("durationMs", 0.0))
	_finish_after_ms = -1.0
	_fps_elapsed_ms = 0.0
	_fps_frame_count = 0
	_display_fps = 0
	_display_minute = 0
	_display_second = 0
	_last_result.clear()
	_running = true
	return true


func stop() -> void:
	if _audio_pool != null:
		_audio_pool.stop_all()
	_finish_after_ms = -1.0
	_running = false


func is_running() -> bool:
	return _running


func elapsed_ms() -> float:
	return _elapsed_ms


func set_key_bindings(bindings: Array) -> bool:
	if not _input_map.set_key_bindings(bindings):
		return false
	if not _controller.set_key_bindings(bindings):
		return false
	return _input_map.apply_to_godot_input_map()


func advance_to(now_ms: float) -> void:
	if not _running:
		return

	var next_elapsed_ms: float = max(now_ms, _elapsed_ms)
	var delta_ms: float = next_elapsed_ms - _elapsed_ms
	_elapsed_ms = next_elapsed_ms
	_update_fps_counter(delta_ms)
	_controller.advance_to(_elapsed_ms)
	_apply_audio_commands()

	if _controller.note_layer_empty():
		if _finish_after_ms < 0.0:
			_finish_after_ms = _elapsed_ms + JAVA_FINISH_DELAY_MS
		elif _elapsed_ms > _finish_after_ms:
			_finish()


func press_action(action: String, now_ms: float = -1.0) -> Dictionary:
	var hit_time := _time_for_input(now_ms)
	var response: Dictionary = _controller.press_action(action, hit_time)
	_apply_audio_commands()
	return response


func release_action(action: String, now_ms: float = -1.0) -> Dictionary:
	var hit_time := _time_for_input(now_ms)
	var response: Dictionary = _controller.release_action(action, hit_time)
	_apply_audio_commands()
	return response


func result() -> Dictionary:
	if _last_result.is_empty():
		return _controller.result()
	return _last_result.duplicate(true)


func hud_state() -> Dictionary:
	var state := result()
	state["elapsedMs"] = int(round(_elapsed_ms))
	state["durationMs"] = int(round(_duration_ms))
	state["fps"] = _display_fps
	state["minute"] = _display_minute
	state["second"] = _display_second
	state["pressedLanes"] = _controller.pressed_lanes()
	state.merge(_controller.render_state(_elapsed_ms), true)
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
	_audio_pool.apply_audio_commands(_controller.drain_audio_commands())


func _time_for_input(now_ms: float) -> float:
	if now_ms >= 0.0:
		return now_ms
	return _elapsed_ms


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
	_last_result = _controller.result()
	stop()
	completed.emit(_last_result.duplicate(true))
