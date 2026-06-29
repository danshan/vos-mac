extends Node

signal completed(result: Dictionary)

const AudioPlayerPool = preload("res://scripts/audio_player_pool.gd")
const GameplayController = preload("res://scripts/gameplay_controller.gd")
const InputMapStore = preload("res://scripts/input_map_store.gd")

var _controller = GameplayController.new()
var _input_map = InputMapStore.new()
var _audio_pool: Node = null
var _running: bool = false
var _elapsed_ms: float = 0.0
var _duration_ms: float = 0.0
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
	_last_result.clear()
	_running = true
	return true


func stop() -> void:
	if _audio_pool != null:
		_audio_pool.stop_all()
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

	_elapsed_ms = max(now_ms, _elapsed_ms)
	_controller.advance_to(_elapsed_ms)
	_apply_audio_commands()

	if _duration_ms > 0.0 and _elapsed_ms >= _duration_ms:
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


func _mark_input_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _finish() -> void:
	_last_result = _controller.result()
	stop()
	completed.emit(_last_result.duplicate(true))
