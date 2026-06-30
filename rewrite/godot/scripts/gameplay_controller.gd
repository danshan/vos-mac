extends RefCounted

const InputMapStore = preload("res://scripts/input_map_store.gd")
const JudgmentStrategy = preload("res://scripts/judgment_strategy.gd")
const NoteDistanceCalculator = preload("res://scripts/note_distance_calculator.gd")
const ResultModel = preload("res://scripts/result_model.gd")
const ScoreState = preload("res://scripts/score_state.gd")
const TimingModel = preload("res://scripts/timing_model.gd")

const STATE_NOT_JUDGED: String = "not_judged"
const STATE_DEAD: String = "dead"
const STATE_HOLDING: String = "holding"
const STATE_TO_KILL: String = "to_kill"
const VOS_LIVE_TRIGGER_THRESHOLD: float = 280.0
const AUDIO_ACTION_PLAY_SAMPLE: String = "playSample"
const AUDIO_ACTION_STOP_SAMPLE: String = "stopSample"
const AUDIO_SOURCE_NOTE: String = "note"
const AUDIO_SOURCE_AUTO_PLAY: String = "autoPlay"
const AUDIO_TRIGGER_KEYSOUND: String = "keysound"
const AUDIO_TRIGGER_EXTRASOUND: String = "extrasound"
const AUDIO_TRIGGER_AUTOSOUND: String = "autosound"
const AUDIO_TRIGGER_MISSED: String = "missed"
const JUDGMENT_EVENT_DURATION_MS: float = 3000.0
const CLICK_EVENT_DURATION_MS: float = 3000.0
const JAVA_VIEWPORT_HEIGHT: float = 600.0
const JAVA_JUDGMENT_LINE: float = 480.0
const JAVA_MEASURE_SIZE: float = 385.0
const JAVA_RENDER_SPEED: float = 1.0
const JAVA_TAP_NOTE_HEIGHT: float = 7.0
const JAVA_BEAT_JUDGMENT_FACTOR: float = 0.664
const JUDGMENT_TYPE_BEAT: String = "beat"
const JUDGMENT_TYPE_TIME: String = "time"
const SPEED_TYPE_HI_SPEED: String = "HiSpeed"
const SPEED_TYPE_XR_SPEED: String = "xRSpeed"
const SPEED_TYPE_REGUL_SPEED: String = "RegulSpeed"
const SPEED_TYPE_W_SPEED: String = "WSpeed"
const JAVA_GAME_SPEED_PITCH: int = 0
const SPEED_ACTION_UP: String = "speed_up"
const SPEED_ACTION_DOWN: String = "speed_down"
const SPEED_STEP: float = 0.5
const SPEED_MIN: float = 0.5
const SPEED_MAX: float = 10.0
const SPEED_FACTOR: float = 0.005
const VOLUME_ACTION_MAIN_UP: String = "main_volume_up"
const VOLUME_ACTION_MAIN_DOWN: String = "main_volume_down"
const VOLUME_ACTION_KEY_UP: String = "key_volume_up"
const VOLUME_ACTION_KEY_DOWN: String = "key_volume_down"
const VOLUME_ACTION_BGM_UP: String = "bgm_volume_up"
const VOLUME_ACTION_BGM_DOWN: String = "bgm_volume_down"
const VOLUME_STEP: float = 0.05
const VOLUME_MIN: float = 0.0
const VOLUME_MAX: float = 1.0
const HASTE_SPEED_STEP: float = 1.0594630943592953
const HASTE_CHANGE_INTERVAL_MS: float = 5333.0

var _chart: Dictionary = {}
var _notes: Array[Dictionary] = []
var _auto_play_events: Array[Dictionary] = []
var _bga_events: Array[Dictionary] = []
var _bga_event_index: int = 0
var _current_bga_event_state: Dictionary = {}
var _buffer_events: Array[Dictionary] = []
var _buffer_event_index: int = 0
var _buffer_timer_ms: float = 0.0
var _buffered_note_indices: Dictionary = {}
var _buffered_measure_indices: Dictionary = {}
var _audio_commands: Array[Dictionary] = []
var _last_sound_by_lane: Dictionary = {}
var _render_sequence: int = 0
var _last_judgment_event: Dictionary = {}
var _click_events: Array[Dictionary] = []
var _score_state = ScoreState.new()
var _input_map = InputMapStore.new()
var _judgment = JudgmentStrategy.new()
var _pressed_lanes: Dictionary = {}
var _held_note_indices: Dictionary = {}
var _longflare_lanes: Dictionary = {}
var _distance = null
var _timing = null
var _autosound_enabled: bool = false
var _disable_autosound: bool = false
var _autoplay_enabled: bool = false
var _judgment_type: String = JUDGMENT_TYPE_BEAT
var _render_speed: float = JAVA_RENDER_SPEED
var _target_render_speed: float = JAVA_RENDER_SPEED
var _speed_type: String = SPEED_TYPE_HI_SPEED
var _last_distance_update_ms: float = 0.0
var _has_distance_update_ms: bool = false
var _last_speed_update_ms: float = 0.0
var _has_speed_update_ms: bool = false
var _pressed_misc_actions: Dictionary = {}
var _master_volume: float = 1.0
var _key_volume: float = 1.0
var _bgm_volume: float = 1.0
var _haste_enabled: bool = false
var _normalize_haste_speed: bool = true
var _game_speed: float = 1.0
var _audio_pitch_scale: float = 1.0
var _game_speed_pitch: int = 0
var _last_game_speed_change_measure: int = 0
var _last_game_speed_update_measure: int = 0
var _last_game_speed_change_time_ms: float = 0.0


func load_chart(chart: Dictionary) -> bool:
	if chart.is_empty():
		return false
	if not _notes_match_java_contract(chart.get("notes", [])):
		return false

	_chart = chart.duplicate(true)
	_score_state = ScoreState.new(_normalized_rank(_chart.get("rank", 0)))
	_notes = _normalized_notes(_chart.get("notes", []))
	_auto_play_events = _normalized_auto_play_events(_chart.get("autoPlayEvents", []))
	_bga_events = _normalized_bga_events(_chart.get("bgaEvents", []))
	_bga_event_index = 0
	_current_bga_event_state.clear()
	_buffer_events = _normalized_buffer_events(_chart.get("measures", []), _notes,
			_chart.get("autoPlayEvents", []), _chart.get("bgaEvents", []))
	_buffer_event_index = 0
	_buffer_timer_ms = 0.0
	_buffered_note_indices.clear()
	_buffered_measure_indices.clear()
	_last_sound_by_lane.clear()
	_autosound_enabled = _normalized_bool(_chart.get("autosound", false))
	_disable_autosound = false
	_autoplay_enabled = _normalized_bool(_chart.get("autoplay", false))
	_judgment_type = _normalized_judgment_type(_chart.get("judgmentType", JUDGMENT_TYPE_BEAT))
	_render_speed = _normalized_speed_multiplier(_chart.get("speedMultiplier", JAVA_RENDER_SPEED))
	_target_render_speed = _render_speed
	_speed_type = _normalized_speed_type(_chart.get("speedType", SPEED_TYPE_HI_SPEED))
	_configure_distance()
	_audio_commands.clear()
	_render_sequence = 0
	_last_judgment_event.clear()
	_click_events.clear()
	_pressed_lanes.clear()
	_held_note_indices.clear()
	_longflare_lanes.clear()
	_pressed_misc_actions.clear()
	_last_distance_update_ms = 0.0
	_has_distance_update_ms = false
	_last_speed_update_ms = 0.0
	_has_speed_update_ms = true
	_master_volume = _normalized_volume(_chart.get("masterVolume", 1.0))
	_key_volume = _normalized_volume(_chart.get("keyVolume", 1.0))
	_bgm_volume = _normalized_volume(_chart.get("bgmVolume", 1.0))
	_haste_enabled = _normalized_bool(_chart.get("hasteMode", false))
	_normalize_haste_speed = _normalized_bool(_chart.get("hasteModeNormalizeSpeed", true))
	_game_speed = 1.0
	_audio_pitch_scale = 1.0
	_game_speed_pitch = 0
	_last_game_speed_change_measure = 0
	_last_game_speed_update_measure = 0
	_last_game_speed_change_time_ms = 0.0
	_advance_event_buffer(0.0)
	return true


func current_chart_id() -> String:
	return str(_chart.get("chartId", ""))


func apply_judgment(name: String) -> void:
	_score_state.apply_judgment(name)


func set_key_bindings(bindings: Array) -> bool:
	return _input_map.set_key_bindings(bindings)


func press_action(action: String, now_ms: float) -> Dictionary:
	return press_lane(_input_map.lane_for_action(action), now_ms)


func release_action(action: String, now_ms: float) -> Dictionary:
	return release_lane(_input_map.lane_for_action(action), now_ms)


func press_misc_action(action: String) -> Dictionary:
	if bool(_pressed_misc_actions.get(action, false)):
		return {"pressed": false, "accepted": false, "reason": "already_pressed"}

	_pressed_misc_actions[action] = true
	match action:
		SPEED_ACTION_UP:
			_target_render_speed = min(_target_render_speed + SPEED_STEP, SPEED_MAX)
			return {"pressed": true, "accepted": true, "action": action, "targetSpeed": _target_render_speed}
		SPEED_ACTION_DOWN:
			_target_render_speed = max(_target_render_speed - SPEED_STEP, SPEED_MIN)
			return {"pressed": true, "accepted": true, "action": action, "targetSpeed": _target_render_speed}
		VOLUME_ACTION_MAIN_UP:
			_master_volume = _clamped_volume(_master_volume + VOLUME_STEP)
			return {"pressed": true, "accepted": true, "action": action, "masterVolume": _master_volume}
		VOLUME_ACTION_MAIN_DOWN:
			_master_volume = _clamped_volume(_master_volume - VOLUME_STEP)
			return {"pressed": true, "accepted": true, "action": action, "masterVolume": _master_volume}
		VOLUME_ACTION_KEY_UP:
			_key_volume = _clamped_volume(_key_volume + VOLUME_STEP)
			return {"pressed": true, "accepted": true, "action": action, "keyVolume": _key_volume}
		VOLUME_ACTION_KEY_DOWN:
			_key_volume = _clamped_volume(_key_volume - VOLUME_STEP)
			return {"pressed": true, "accepted": true, "action": action, "keyVolume": _key_volume}
		VOLUME_ACTION_BGM_UP:
			_bgm_volume = _clamped_volume(_bgm_volume + VOLUME_STEP)
			return {"pressed": true, "accepted": true, "action": action, "bgmVolume": _bgm_volume}
		VOLUME_ACTION_BGM_DOWN:
			_bgm_volume = _clamped_volume(_bgm_volume - VOLUME_STEP)
			return {"pressed": true, "accepted": true, "action": action, "bgmVolume": _bgm_volume}
		_:
			return {"pressed": true, "accepted": false, "reason": "unknown_misc_action"}


func release_misc_action(action: String) -> Dictionary:
	if not _pressed_misc_actions.has(action):
		return {"released": false, "accepted": false, "reason": "not_pressed"}
	_pressed_misc_actions.erase(action)
	return {"released": true, "accepted": true, "action": action}


func drain_audio_commands() -> Array[Dictionary]:
	var drained: Array[Dictionary] = []
	for command: Dictionary in _audio_commands:
		drained.append(command.duplicate(true))
	_audio_commands.clear()
	return drained


func volume_state() -> Dictionary:
	return {
		"masterVolume": _master_volume,
		"keyVolume": _key_volume,
		"bgmVolume": _bgm_volume,
	}


func audio_state() -> Dictionary:
	return {
		"pitchScale": _audio_pitch_scale,
		"gameSpeedPitch": _game_speed_pitch,
	}


func pressed_lanes() -> Array[int]:
	var lanes: Array[int] = []
	for raw_lane: Variant in _pressed_lanes.keys():
		var lane := int(raw_lane)
		if bool(_pressed_lanes.get(lane, false)):
			lanes.append(lane)
	lanes.sort()
	return lanes


func render_state(now_ms: float, status_now_ms: float = -1.0) -> Dictionary:
	var status_time_ms := status_now_ms if status_now_ms >= 0.0 else now_ms
	var state := {
		"pills": _score_state.pills,
		"clickEvents": _active_events(_click_events, now_ms, CLICK_EVENT_DURATION_MS),
		"longFlares": _active_longflares(),
		"hiddenNotes": _hidden_note_indices(),
		"hiddenMeasures": _hidden_measure_indices(status_time_ms),
		"statusTexts": _status_texts(status_time_ms),
		"renderSpeed": _render_speed,
		"targetSpeed": _target_render_speed,
		"masterVolume": _master_volume,
		"keyVolume": _key_volume,
		"bgmVolume": _bgm_volume,
		"audioPitchScale": _audio_pitch_scale,
		"gameSpeedPitch": _game_speed_pitch,
	}
	var current_bga_event := _current_bga_event()
	if not current_bga_event.is_empty():
		state["currentBgaEvent"] = current_bga_event
	if _event_is_active(_last_judgment_event, now_ms, JUDGMENT_EVENT_DURATION_MS):
		state["judgmentEvent"] = _last_judgment_event.duplicate(true)
	return state


func press_lane(lane: int, now_ms: float) -> Dictionary:
	var audio_start_index := _audio_commands.size()
	if lane < 0:
		return {"pressed": false, "accepted": false, "reason": "invalid_lane", "audioCommands": []}
	if _autoplay_enabled:
		return {"pressed": false, "accepted": false, "reason": "autoplay_lane", "audioCommands": []}
	if bool(_pressed_lanes.get(lane, false)):
		return {"pressed": false, "accepted": false, "reason": "already_pressed", "audioCommands": []}

	_pressed_lanes[lane] = true

	var note_index := _next_note_index_for_lane(lane)
	if note_index < 0:
		var replayed_last_sound := _emit_last_sound_for_lane(lane)
		return {
			"pressed": true,
			"accepted": false,
			"reason": "no_note",
			"rejectedKeysound": replayed_last_sound,
			"audioCommands": _audio_commands_since(audio_start_index),
		}

	var note := _notes[note_index]
	_last_sound_by_lane[lane] = note.duplicate(true)
	var hit_time := _hit_time_for_note(note, now_ms)
	note["hitTime"] = hit_time
	_notes[note_index] = note

	if not _accept_note(note, hit_time, now_ms):
		var rejected_keysound := _should_trigger_rejected_keysound(hit_time)
		if rejected_keysound:
			_emit_note_play_command(note_index, AUDIO_TRIGGER_EXTRASOUND, false)
		return {
			"pressed": true,
			"accepted": false,
			"hitTime": hit_time,
			"rejectedKeysound": rejected_keysound,
			"audioCommands": _audio_commands_since(audio_start_index),
		}

	_disable_autosound = false
	_emit_note_play_command(note_index, AUDIO_TRIGGER_KEYSOUND, true)
	var result := _apply_note_judgment(note_index, hit_time, now_ms)
	if str(note.get("kind", "")) == "holdStart" and result != "miss":
		note = _notes[note_index]
		note["state"] = STATE_HOLDING
		_notes[note_index] = note
		_held_note_indices[lane] = note_index
		_longflare_lanes[lane] = {
			"noteIndex": note_index,
			"startMs": now_ms,
		}

	return {
		"pressed": true,
		"accepted": true,
		"hitTime": hit_time,
		"result": result,
		"keysound": true,
		"rejectedKeysound": false,
		"audioCommands": _audio_commands_since(audio_start_index),
	}


func release_lane(lane: int, now_ms: float) -> Dictionary:
	var audio_start_index := _audio_commands.size()
	if lane < 0:
		return {"released": false, "accepted": false, "reason": "invalid_lane", "audioCommands": []}
	if _autoplay_enabled:
		return {"released": false, "accepted": false, "reason": "autoplay_lane", "audioCommands": []}

	_pressed_lanes[lane] = false
	if not _held_note_indices.has(lane):
		return {"released": true, "accepted": false, "reason": "no_held_note", "audioCommands": []}

	var note_index: int = int(_held_note_indices.get(lane))
	_held_note_indices.erase(lane)
	_longflare_lanes.erase(lane)

	var note := _notes[note_index]
	var hit_time := _tail_hit_time_for_note(note, now_ms)
	note["hitTime"] = hit_time
	_notes[note_index] = note

	var result := _apply_note_judgment(note_index, hit_time, now_ms)
	return {
		"released": true,
		"accepted": result != "miss",
		"hitTime": hit_time,
		"result": result,
		"audioCommands": _audio_commands_since(audio_start_index),
	}


func advance_to(now_ms: float, display_now_ms: float = -1.0,
		autosound_now_ms: float = -1.0, game_now_ms: float = -1.0,
		frame_delta_ms: float = -1.0) -> int:
	var render_now_ms := display_now_ms if display_now_ms >= 0.0 else now_ms
	var sound_now_ms := autosound_now_ms if autosound_now_ms >= 0.0 else now_ms
	var speed_now_ms := game_now_ms if game_now_ms >= 0.0 else now_ms
	var judged := 0
	_update_game_speed_state(speed_now_ms)
	_update_render_speed_state(speed_now_ms, frame_delta_ms)
	_advance_event_buffer(render_now_ms)
	_update_distance_state(render_now_ms, frame_delta_ms)
	_advance_bga_event(now_ms)
	_advance_auto_play(sound_now_ms)
	judged += _advance_note_autoplay(now_ms)
	_advance_note_autosound(sound_now_ms)
	for i in range(_notes.size()):
		if not _note_is_buffered(i):
			continue
		var note := _notes[i]
		if str(note.get("state", STATE_NOT_JUDGED)) == STATE_NOT_JUDGED:
			var hit_time := _hit_time_for_note(note, now_ms)
			if _missed_note(note, hit_time, now_ms):
				_apply_note_judgment(i, hit_time, now_ms, true)
				judged += 1
		elif str(note.get("state", "")) == STATE_HOLDING:
			var tail_hit_time := _tail_hit_time_for_note(note, now_ms)
			if _missed_note(note, tail_hit_time, now_ms):
				_apply_note_judgment(i, tail_hit_time, now_ms)
				var lane := int(note.get("lane", -1))
				_held_note_indices.erase(lane)
				_longflare_lanes.erase(lane)
				judged += 1
	_cleanup_to_kill_notes(render_now_ms)
	return judged


func held_note_count() -> int:
	return _held_note_indices.size()


func note_layer_empty() -> bool:
	for i in range(_notes.size()):
		if not _note_is_buffered(i):
			continue
		var note := _notes[i]
		if str(note.get("state", STATE_NOT_JUDGED)) != STATE_DEAD:
			return false
	return true


func event_buffer_empty() -> bool:
	return _buffer_event_index >= _buffer_events.size()


func result() -> Dictionary:
	return ResultModel.from_score(current_chart_id(), _score_state)


func _normalized_notes(raw_notes: Variant) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	if raw_notes is Array:
		for raw_note: Variant in raw_notes:
			if raw_note is Dictionary:
				var note: Dictionary = raw_note.duplicate(true)
				note["measure"] = int(note.get("measure", 0))
				note["state"] = STATE_NOT_JUDGED
				note["hitTime"] = 0.0
				note["samplePlayed"] = false
				note["autosoundConsumed"] = false
				normalized.append(note)

	normalized.sort_custom(_compare_notes)
	return normalized


func _notes_match_java_contract(raw_notes: Variant) -> bool:
	if not raw_notes is Array:
		return false

	for raw_note: Variant in raw_notes:
		if not raw_note is Dictionary:
			return false
		if not _note_matches_java_contract(raw_note):
			return false
		var kind := str(raw_note.get("kind", ""))
		if kind == "tap":
			if not _tap_note_matches_java_contract(raw_note):
				return false
			continue
		if kind != "holdStart":
			return false
		if not _hold_note_matches_java_contract(raw_note):
			return false
	return true


func _note_matches_java_contract(note: Dictionary) -> bool:
	var measure: Variant = note.get("measure")
	return _is_integer_like(measure) and int(measure) >= 0


func _tap_note_matches_java_contract(note: Dictionary) -> bool:
	return not note.has("endMs") and not note.has("endMeasure")


func _hold_note_matches_java_contract(note: Dictionary) -> bool:
	var start_ms: Variant = note.get("startMs")
	var end_ms: Variant = note.get("endMs")
	var end_measure: Variant = note.get("endMeasure")
	if not _is_non_negative_number(start_ms):
		return false
	if not _is_non_negative_number(end_ms):
		return false
	if float(end_ms) < float(start_ms):
		return false
	if not _is_integer_like(end_measure) or int(end_measure) < 0:
		return false
	return true


func _is_non_negative_number(value: Variant) -> bool:
	if not (value is int or value is float):
		return false
	return float(value) >= 0.0


func _is_integer_like(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return value == floor(value)
	return false


func _normalized_auto_play_events(raw_events: Variant) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	if raw_events is Array:
		for raw_event: Variant in raw_events:
			if raw_event is Dictionary:
				var event: Dictionary = raw_event.duplicate(true)
				event["played"] = false
				normalized.append(event)

	normalized.sort_custom(_compare_auto_play_events)
	return normalized


func _normalized_bga_events(raw_events: Variant) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	if raw_events is Array:
		for raw_event: Variant in raw_events:
			if raw_event is Dictionary:
				var event: Dictionary = raw_event.duplicate(true)
				event["startMs"] = float(event.get("startMs", event.get("timeMs", 0.0)))
				event["spriteId"] = int(event.get("spriteId", 0))
				normalized.append(event)

	normalized.sort_custom(_compare_timed_events)
	return normalized


func _normalized_timed_events(raw_events: Variant) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	if raw_events is Array:
		for raw_event: Variant in raw_events:
			if raw_event is Dictionary:
				var event: Dictionary = raw_event.duplicate(true)
				event["startMs"] = float(event.get("startMs", event.get("timeMs", 0.0)))
				normalized.append(event)
	normalized.sort_custom(_compare_timed_events)
	return normalized


func _normalized_buffer_events(raw_measures: Variant, raw_notes: Variant,
		raw_auto_play_events: Variant, raw_bga_events: Variant) -> Array[Dictionary]:
	var normalized: Array[Dictionary] = []
	if raw_measures is Array:
		for i in range(raw_measures.size()):
			var raw_measure: Variant = raw_measures[i]
			if raw_measure is Dictionary:
				var event: Dictionary = raw_measure.duplicate(true)
				event["startMs"] = float(event.get("startMs", event.get("timeMs", 0.0)))
				event["bufferKind"] = "measure"
				event["bufferIndex"] = i
				normalized.append(event)
	if raw_notes is Array:
		for i in range(raw_notes.size()):
			var raw_note: Variant = raw_notes[i]
			if raw_note is Dictionary:
				var event: Dictionary = raw_note.duplicate(true)
				event["startMs"] = float(event.get("startMs", event.get("timeMs", 0.0)))
				event["bufferKind"] = "note"
				event["bufferIndex"] = i
				normalized.append(event)
	for event: Dictionary in _normalized_timed_events(raw_auto_play_events):
		event["bufferKind"] = "autoPlay"
		normalized.append(event)
	for event: Dictionary in _normalized_timed_events(raw_bga_events):
		event["bufferKind"] = "bga"
		normalized.append(event)
	normalized.sort_custom(_compare_timed_events)
	return normalized


func _configure_distance() -> void:
	var visual_timing = _timing_from_chart("visualTiming")
	_timing = _timing_from_chart("judgmentTiming", visual_timing)
	_distance = NoteDistanceCalculator.new(visual_timing, JAVA_MEASURE_SIZE)
	if _speed_type == SPEED_TYPE_XR_SPEED:
		_distance.set_xr_speed_factors(_chart.get("xRSpeedFactors", []))


func _timing_from_chart(field_name: String, fallback_timing = null):
	var timing := TimingModel.new()
	var loaded := false
	var changes: Variant = _chart.get(field_name, [])
	if changes is Array:
		for raw_change: Variant in changes:
			if raw_change is Dictionary:
				timing.add_change(float(raw_change.get("timeMs", 0.0)), float(raw_change.get("bpm", 0.0)))
				loaded = true
	if not loaded and fallback_timing != null:
		return fallback_timing
	if not loaded:
		timing.add_change(0.0, float(_chart.get("bpm", 120.0)))
	timing.finish()
	return timing


func _compare_notes(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("startMs", 0.0)) < float(b.get("startMs", 0.0))


func _compare_auto_play_events(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("startMs", 0.0)) < float(b.get("startMs", 0.0))


func _compare_timed_events(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("startMs", 0.0)) < float(b.get("startMs", 0.0))


func _next_note_index_for_lane(lane: int) -> int:
	for i in range(_notes.size()):
		var note := _notes[i]
		if not _note_is_buffered(i):
			continue
		if int(note.get("lane", -1)) == lane and str(note.get("state", STATE_NOT_JUDGED)) == STATE_NOT_JUDGED:
			return i
	return -1


func _next_autoplay_note_index_for_lane(lane: int) -> int:
	for i in range(_notes.size()):
		var note := _notes[i]
		if not _note_is_buffered(i):
			continue
		if int(note.get("lane", -1)) != lane:
			continue
		var state := str(note.get("state", STATE_NOT_JUDGED))
		if state == STATE_NOT_JUDGED or state == STATE_HOLDING:
			return i
	return -1


func _hit_time_for_note(note: Dictionary, now_ms: float) -> float:
	return (float(note.get("startMs", 0.0)) - now_ms) / _effective_judgment_factor()


func _tail_hit_time_for_note(note: Dictionary, now_ms: float) -> float:
	var end_ms: Variant = note.get("endMs", null)
	if end_ms is int or end_ms is float:
		return (float(end_ms) - now_ms) / _effective_judgment_factor()
	return _hit_time_for_note(note, now_ms)


func _effective_judgment_factor() -> float:
	return max(_audio_pitch_scale, 0.0001)


func _apply_note_judgment(note_index: int, hit_time: float, now_ms: float,
		disable_autosound_on_miss: bool = false) -> String:
	var note := _notes[note_index]
	var result := _score_state.apply_judgment(_judge_note(note, hit_time, now_ms).to_lower())
	if result == "miss" and disable_autosound_on_miss:
		_disable_autosound = true
	if result == "miss" and bool(note.get("samplePlayed", false)):
		_emit_note_stop_command(note)
	_emit_judgment_render_event(note, result, now_ms)
	note["state"] = _state_after_judgment(note, result)
	note["hitTime"] = hit_time
	_notes[note_index] = note
	return result


func _state_after_judgment(note: Dictionary, result: String) -> String:
	if result == "miss" or str(note.get("kind", "")) == "holdStart":
		return STATE_TO_KILL
	return STATE_DEAD


func _emit_judgment_render_event(note: Dictionary, result: String, now_ms: float) -> void:
	_render_sequence += 1
	_last_judgment_event = {
		"sequence": _render_sequence,
		"result": result,
		"lane": int(note.get("lane", -1)),
		"startMs": now_ms,
	}
	if result == "cool" or result == "good":
		_render_sequence += 1
		_click_events.append({
			"sequence": _render_sequence,
			"lane": int(note.get("lane", -1)),
			"startMs": now_ms,
		})


func _active_events(events: Array[Dictionary], now_ms: float, duration_ms: float) -> Array[Dictionary]:
	var active: Array[Dictionary] = []
	for event: Dictionary in events:
		if _event_is_active(event, now_ms, duration_ms):
			active.append(event.duplicate(true))
	return active


func _active_longflares() -> Array[Dictionary]:
	var flares: Array[Dictionary] = []
	for raw_lane: Variant in _longflare_lanes.keys():
		var lane := int(raw_lane)
		var raw_flare: Variant = _longflare_lanes.get(lane, {})
		var flare: Dictionary = raw_flare if raw_flare is Dictionary else {"startMs": float(raw_flare)}
		var start_ms := float(flare.get("startMs", 0.0))
		if start_ms >= 0.0:
			flares.append({
				"lane": lane,
				"noteIndex": int(flare.get("noteIndex", -1)),
				"startMs": start_ms,
			})
	flares.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("lane", -1)) < int(b.get("lane", -1)))
	return flares


func _hidden_note_indices() -> Array[int]:
	var hidden: Array[int] = []
	for i in range(_notes.size()):
		if not _note_is_buffered(i) or str(_notes[i].get("state", STATE_NOT_JUDGED)) == STATE_DEAD:
			hidden.append(i)
	return hidden


func _hidden_measure_indices(now_ms: float) -> Array[int]:
	var hidden: Array[int] = []
	var measures: Variant = _chart.get("measures", [])
	if not measures is Array:
		return hidden
	for i in range(measures.size()):
		var raw_measure: Variant = measures[i]
		if not raw_measure is Dictionary:
			continue
		if not _measure_is_buffered(i) or float(raw_measure.get("startMs", raw_measure.get("timeMs", 0.0))) <= now_ms:
			hidden.append(i)
	return hidden


func _cleanup_to_kill_notes(now_ms: float) -> void:
	if _distance == null:
		return
	for i in range(_notes.size()):
		var note := _notes[i]
		if str(note.get("state", STATE_NOT_JUDGED)) != STATE_TO_KILL:
			continue
		if _cleanup_y_for_note(note, now_ms) >= JAVA_VIEWPORT_HEIGHT:
			note["state"] = STATE_DEAD
			_notes[i] = note


func _cleanup_y_for_note(note: Dictionary, now_ms: float) -> float:
	var target_ms := float(note.get("startMs", 0.0))
	var lane := int(note.get("lane", -1))
	if str(note.get("kind", "")) == "holdStart":
		var end_ms: Variant = note.get("endMs", null)
		if end_ms is int or end_ms is float:
			target_ms = float(end_ms)
		return JAVA_JUDGMENT_LINE - _distance_for(now_ms, target_ms, lane)
	return JAVA_JUDGMENT_LINE - _distance_for(now_ms, target_ms, lane) - JAVA_TAP_NOTE_HEIGHT


func _accept_note(note: Dictionary, hit_time: float, now_ms: float) -> bool:
	if _judgment_type == JUDGMENT_TYPE_TIME:
		return _judgment.accept_time(hit_time)
	return _judgment.accept_beat(_beat_hit_delta(note, hit_time, now_ms))


func _missed_note(note: Dictionary, hit_time: float, now_ms: float) -> bool:
	if _judgment_type == JUDGMENT_TYPE_TIME:
		return _judgment.missed_time(hit_time)
	return _judgment.missed_beat(_beat_hit_delta(note, hit_time, now_ms))


func _should_trigger_rejected_keysound(hit_time: float) -> bool:
	if not _is_vos_chart():
		return true
	return absf(hit_time) <= VOS_LIVE_TRIGGER_THRESHOLD


func _emit_last_sound_for_lane(lane: int) -> bool:
	if _is_vos_chart():
		return false
	var raw_note: Variant = _last_sound_by_lane.get(lane, {})
	if not raw_note is Dictionary:
		return false
	var note: Dictionary = raw_note
	if note.is_empty():
		return false
	_emit_audio_command(_sample_command(
			AUDIO_ACTION_PLAY_SAMPLE,
			AUDIO_SOURCE_NOTE,
			AUDIO_TRIGGER_EXTRASOUND,
			note))
	return true


func _is_vos_chart() -> bool:
	return str(_chart.get("format", "")) == "VOS"


func _judge_note(note: Dictionary, hit_time: float, now_ms: float) -> String:
	if _judgment_type == JUDGMENT_TYPE_TIME:
		return _judgment.judge_time(hit_time)
	return _judgment.judge_beat(_beat_hit_delta(note, hit_time, now_ms))


func _beat_hit_delta(note: Dictionary, hit_time: float, now_ms: float) -> float:
	if _timing == null:
		return hit_time
	var target_ms := _target_time_for_note(note)
	var hit_ms := target_ms - hit_time
	return (_timing.get_beat(target_ms) - _timing.get_beat(hit_ms)) / JAVA_BEAT_JUDGMENT_FACTOR


func _target_time_for_note(note: Dictionary) -> float:
	if str(note.get("state", STATE_NOT_JUDGED)) == STATE_HOLDING:
		var end_ms: Variant = note.get("endMs", null)
		if end_ms is int or end_ms is float:
			return float(end_ms)
	return float(note.get("startMs", 0.0))


func _normalized_judgment_type(value: Variant) -> String:
	var type := str(value).to_lower()
	if type == JUDGMENT_TYPE_TIME:
		return JUDGMENT_TYPE_TIME
	return JUDGMENT_TYPE_BEAT


func _normalized_rank(value: Variant) -> int:
	if value is int:
		return max(value, 0)
	if value is float and value == floor(value):
		return max(int(value), 0)
	return 0


func _normalized_speed_multiplier(value: Variant) -> float:
	if value is int or value is float:
		return max(float(value), 0.001)
	return JAVA_RENDER_SPEED


func _normalized_speed_type(value: Variant) -> String:
	if str(value) == SPEED_TYPE_XR_SPEED:
		return SPEED_TYPE_XR_SPEED
	if str(value) == SPEED_TYPE_REGUL_SPEED:
		return SPEED_TYPE_REGUL_SPEED
	if str(value) == SPEED_TYPE_W_SPEED:
		return SPEED_TYPE_W_SPEED
	return SPEED_TYPE_HI_SPEED


func _status_texts(now_ms: float) -> Array[String]:
	return [
		"%s: x%s" % [_java_speed_type_name(), _java_double_text(_target_render_speed)],
		"Current Measure: %d" % _current_measure(now_ms),
		"Game Speed: %+d" % _game_speed_pitch,
	]


func _java_double_text(value: float) -> String:
	var text := "%.12f" % value
	while text.ends_with("0") and not text.ends_with(".0"):
		text = text.substr(0, text.length() - 1)
	return text


func _java_speed_type_name() -> String:
	if _speed_type == SPEED_TYPE_XR_SPEED:
		return "xR-SPEED"
	if _speed_type == SPEED_TYPE_REGUL_SPEED:
		return "REGUL-SPEED"
	if _speed_type == SPEED_TYPE_W_SPEED:
		return "W-SPEED"
	return "HI-SPEED"


func _current_measure(now_ms: float) -> int:
	var measures: Variant = _chart.get("measures", [])
	if not measures is Array:
		return 0
	var count := 0
	for raw_measure: Variant in measures:
		if not raw_measure is Dictionary:
			continue
		if float(raw_measure.get("startMs", raw_measure.get("timeMs", 0.0))) <= now_ms:
			count += 1
	return count


func _advance_bga_event(now_ms: float) -> void:
	if _bga_event_index >= _bga_events.size():
		return
	var event := _bga_events[_bga_event_index]
	if float(event.get("startMs", 0.0)) > now_ms:
		return
	_current_bga_event_state = event.duplicate(true)
	_bga_event_index += 1


func _current_bga_event() -> Dictionary:
	return _current_bga_event_state.duplicate(true)


func _normalized_bool(value: Variant) -> bool:
	if value is bool:
		return value
	return false


func _normalized_volume(value: Variant) -> float:
	if value is int or value is float:
		return _clamped_volume(float(value))
	return 1.0


func _update_game_speed_state(now_ms: float) -> void:
	_game_speed_pitch = int(round(12.0 * log(_game_speed) / log(2.0)))
	_audio_pitch_scale = pow(2.0, float(_game_speed_pitch) / 12.0)
	if not _haste_enabled:
		return

	var current_measure := _current_measure(now_ms)
	if current_measure > _last_game_speed_update_measure:
		var measure_delta := current_measure - _last_game_speed_change_measure
		var increase := false
		if now_ms - _last_game_speed_change_time_ms >= HASTE_CHANGE_INTERVAL_MS * pow(min(_game_speed, 1.0), 4.0) and current_measure >= 6:
			if _is_power_of_two(measure_delta):
				increase = true
			if measure_delta >= 8:
				increase = true
			if _last_game_speed_change_measure == 0:
				increase = true
		if increase:
			_game_speed *= HASTE_SPEED_STEP
			_last_game_speed_change_measure = current_measure
			_last_game_speed_change_time_ms = now_ms
		_last_game_speed_update_measure = current_measure

	var life_limit: float = max(float(_score_state.life_limit), 1.0)
	var max_speed: float = min(2.0, max(0.5, 3.0 * float(_score_state.life) / life_limit))
	if _game_speed > max_speed:
		_game_speed = max_speed
	if _normalize_haste_speed and _distance != null:
		var target: float = 1.0 / _game_speed
		_distance.speed_factor += (target - _distance.speed_factor) * 0.1


func _is_power_of_two(value: int) -> bool:
	return value > 0 and (value & (value - 1)) == 0


func _update_render_speed_state(now_ms: float, frame_delta_ms: float = -1.0) -> void:
	var delta_ms: float = 0.0
	if frame_delta_ms >= 0.0:
		delta_ms = frame_delta_ms
	elif _has_speed_update_ms:
		delta_ms = max(now_ms - _last_speed_update_ms, 0.0)
	if _render_speed < _target_render_speed:
		_render_speed = min(_render_speed + SPEED_FACTOR * delta_ms, _target_render_speed)
	elif _render_speed > _target_render_speed:
		_render_speed = max(_render_speed - SPEED_FACTOR * delta_ms, _target_render_speed)
	_last_speed_update_ms = now_ms
	_has_speed_update_ms = true


func _update_distance_state(now_ms: float, frame_delta_ms: float = -1.0) -> void:
	if _speed_type != SPEED_TYPE_W_SPEED or _distance == null:
		return
	var delta_ms: float = 0.0
	if frame_delta_ms >= 0.0:
		delta_ms = frame_delta_ms
	elif _has_distance_update_ms:
		delta_ms = max(now_ms - _last_distance_update_ms, 0.0)
	_distance.update_w_speed(delta_ms, _render_speed)
	_last_distance_update_ms = now_ms
	_has_distance_update_ms = true


func _advance_event_buffer(now_ms: float) -> void:
	if _distance == null:
		_buffer_event_index = _buffer_events.size()
		return
	while _buffer_event_index < _buffer_events.size() and _can_buffer_next_event(now_ms):
		var event := _buffer_events[_buffer_event_index]
		_buffer_timer_ms = float(event.get("startMs", 0.0))
		_mark_event_buffered(event)
		_buffer_event_index += 1


func _can_buffer_next_event(now_ms: float) -> bool:
	return JAVA_JUDGMENT_LINE - _distance_for(now_ms, _buffer_timer_ms) > -10.0


func _mark_event_buffered(event: Dictionary) -> void:
	var index := int(event.get("bufferIndex", -1))
	if index < 0:
		return
	var kind := str(event.get("bufferKind", ""))
	if kind == "note":
		_buffered_note_indices[index] = true
	elif kind == "measure":
		_buffered_measure_indices[index] = true


func _note_is_buffered(index: int) -> bool:
	return bool(_buffered_note_indices.get(index, false))


func _measure_is_buffered(index: int) -> bool:
	return bool(_buffered_measure_indices.get(index, false))


func _distance_for(now_ms: float, target_ms: float, lane: int = -1) -> float:
	if _speed_type == SPEED_TYPE_XR_SPEED:
		return _distance.calculate_xr_speed(now_ms, target_ms, _render_speed, lane)
	if _speed_type == SPEED_TYPE_REGUL_SPEED:
		return _distance.calculate_regul_speed(now_ms, target_ms, _render_speed)
	if _speed_type == SPEED_TYPE_W_SPEED:
		return _distance.calculate_w_speed(now_ms, target_ms)
	return _distance.calculate_hi_speed(now_ms, target_ms, _render_speed)


func _event_is_active(event: Dictionary, now_ms: float, duration_ms: float) -> bool:
	if event.is_empty():
		return false
	var start_ms := float(event.get("startMs", 0.0))
	return now_ms - start_ms <= duration_ms


func _advance_auto_play(now_ms: float) -> void:
	for i in range(_auto_play_events.size()):
		var event := _auto_play_events[i]
		if bool(event.get("played", false)):
			continue
		if float(event.get("startMs", 0.0)) > now_ms:
			continue
		_emit_auto_play_command(event)
		event["played"] = true
		_auto_play_events[i] = event


func _advance_note_autoplay(now_ms: float) -> int:
	if not _autoplay_enabled:
		return 0

	var judged := 0
	for lane: int in _autoplay_lanes():
		var i := _next_autoplay_note_index_for_lane(lane)
		if i < 0:
			continue
		var note := _notes[i]
		var state := str(note.get("state", STATE_NOT_JUDGED))
		if state == STATE_NOT_JUDGED:
			var hit_time := _hit_time_for_note(note, now_ms)
			if hit_time > 0.0:
				continue
			_disable_autosound = false
			_emit_note_play_command(i, AUDIO_TRIGGER_KEYSOUND, true)
			var result := _apply_note_judgment(i, hit_time, now_ms)
			if str(note.get("kind", "")) == "holdStart" and result != "miss":
				_begin_autoplay_hold(i, now_ms)
			judged += 1
		elif state == STATE_HOLDING:
			var tail_hit_time := _tail_hit_time_for_note(note, now_ms)
			if tail_hit_time > 0.0:
				continue
			_end_autoplay_hold(note)
			_apply_note_judgment(i, tail_hit_time, now_ms)
			judged += 1
	return judged


func _autoplay_lanes() -> Array[int]:
	var lanes: Array[int] = []
	for note: Dictionary in _notes:
		var lane := int(note.get("lane", -1))
		if lane >= 0 and not lanes.has(lane):
			lanes.append(lane)
	lanes.sort()
	return lanes


func _advance_note_autosound(now_ms: float) -> void:
	if not _autosound_enabled:
		return

	for i in range(_notes.size()):
		if not _note_is_buffered(i):
			continue
		var note := _notes[i]
		if bool(note.get("samplePlayed", false)) or bool(note.get("autosoundConsumed", false)):
			continue
		var state := str(note.get("state", STATE_NOT_JUDGED))
		if state != STATE_NOT_JUDGED and state != STATE_HOLDING:
			continue
		if float(note.get("startMs", 0.0)) > now_ms:
			continue
		if _disable_autosound:
			note["autosoundConsumed"] = true
			_notes[i] = note
			continue
		_emit_note_play_command(i, AUDIO_TRIGGER_AUTOSOUND, true)


func _begin_autoplay_hold(note_index: int, now_ms: float) -> void:
	var note := _notes[note_index]
	var lane := int(note.get("lane", -1))
	note["state"] = STATE_HOLDING
	_notes[note_index] = note
	_pressed_lanes[lane] = true
	_held_note_indices[lane] = note_index
	_longflare_lanes[lane] = {
		"noteIndex": note_index,
		"startMs": now_ms,
	}


func _end_autoplay_hold(note: Dictionary) -> void:
	var lane := int(note.get("lane", -1))
	_pressed_lanes[lane] = false
	_held_note_indices.erase(lane)
	_longflare_lanes.erase(lane)


func _emit_note_play_command(note_index: int, trigger: String, mark_played: bool) -> Dictionary:
	var note := _notes[note_index]
	if mark_played and bool(note.get("samplePlayed", false)):
		return {}
	if mark_played:
		note["samplePlayed"] = true
		_notes[note_index] = note
	return _emit_audio_command(_sample_command(
			AUDIO_ACTION_PLAY_SAMPLE,
			AUDIO_SOURCE_NOTE,
			trigger,
			note))


func _emit_note_stop_command(note: Dictionary) -> Dictionary:
	return _emit_audio_command(_sample_command(
			AUDIO_ACTION_STOP_SAMPLE,
			AUDIO_SOURCE_NOTE,
			AUDIO_TRIGGER_MISSED,
			note))


func _emit_auto_play_command(event: Dictionary) -> Dictionary:
	return _emit_audio_command(_sample_command(
			AUDIO_ACTION_PLAY_SAMPLE,
			AUDIO_SOURCE_AUTO_PLAY,
			AUDIO_TRIGGER_AUTOSOUND,
			event))


func _sample_command(action: String, source: String, trigger: String, sample: Dictionary) -> Dictionary:
	var command := {
		"action": action,
		"source": source,
		"trigger": trigger,
		"sampleId": int(sample.get("sampleId", 0)),
		"volume": float(sample.get("volume", 1.0)),
		"pan": float(sample.get("pan", 0.0)),
	}
	if sample.has("id"):
		command["noteId"] = int(sample.get("id", 0))
	if sample.has("lane"):
		command["lane"] = int(sample.get("lane", -1))
	if sample.has("startMs"):
		command["startMs"] = float(sample.get("startMs", 0.0))
	return command


func _emit_audio_command(command: Dictionary) -> Dictionary:
	_audio_commands.append(command.duplicate(true))
	return command.duplicate(true)


func _clamped_volume(volume: float) -> float:
	return clampf(volume, VOLUME_MIN, VOLUME_MAX)


func _audio_commands_since(start_index: int) -> Array[Dictionary]:
	var commands: Array[Dictionary] = []
	for i in range(start_index, _audio_commands.size()):
		commands.append(_audio_commands[i].duplicate(true))
	return commands
