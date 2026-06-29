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

var _chart: Dictionary = {}
var _notes: Array[Dictionary] = []
var _auto_play_events: Array[Dictionary] = []
var _buffer_events: Array[Dictionary] = []
var _buffer_event_index: int = 0
var _buffer_timer_ms: float = 0.0
var _audio_commands: Array[Dictionary] = []
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
var _judgment_type: String = JUDGMENT_TYPE_BEAT


func load_chart(chart: Dictionary) -> bool:
	if chart.is_empty():
		return false

	_chart = chart.duplicate(true)
	_score_state = ScoreState.new()
	_notes = _normalized_notes(_chart.get("notes", []))
	_auto_play_events = _normalized_auto_play_events(_chart.get("autoPlayEvents", []))
	_buffer_events = _normalized_buffer_events(_chart.get("measures", []), _chart.get("autoPlayEvents", []))
	_buffer_event_index = 0
	_buffer_timer_ms = 0.0
	_judgment_type = _normalized_judgment_type(_chart.get("judgmentType", JUDGMENT_TYPE_BEAT))
	_configure_distance()
	_audio_commands.clear()
	_render_sequence = 0
	_last_judgment_event.clear()
	_click_events.clear()
	_pressed_lanes.clear()
	_held_note_indices.clear()
	_longflare_lanes.clear()
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


func drain_audio_commands() -> Array[Dictionary]:
	var drained: Array[Dictionary] = []
	for command: Dictionary in _audio_commands:
		drained.append(command.duplicate(true))
	_audio_commands.clear()
	return drained


func pressed_lanes() -> Array[int]:
	var lanes: Array[int] = []
	for raw_lane: Variant in _pressed_lanes.keys():
		var lane := int(raw_lane)
		if bool(_pressed_lanes.get(lane, false)):
			lanes.append(lane)
	lanes.sort()
	return lanes


func render_state(now_ms: float) -> Dictionary:
	var state := {
		"pills": _score_state.pills,
		"clickEvents": _active_events(_click_events, now_ms, CLICK_EVENT_DURATION_MS),
		"longFlares": _active_longflares(),
		"hiddenNotes": _hidden_note_indices(),
	}
	if _event_is_active(_last_judgment_event, now_ms, JUDGMENT_EVENT_DURATION_MS):
		state["judgmentEvent"] = _last_judgment_event.duplicate(true)
	return state


func press_lane(lane: int, now_ms: float) -> Dictionary:
	var audio_start_index := _audio_commands.size()
	if lane < 0:
		return {"pressed": false, "accepted": false, "reason": "invalid_lane", "audioCommands": []}
	if bool(_pressed_lanes.get(lane, false)):
		return {"pressed": false, "accepted": false, "reason": "already_pressed", "audioCommands": []}

	_pressed_lanes[lane] = true

	var note_index := _next_note_index_for_lane(lane)
	if note_index < 0:
		return {"pressed": true, "accepted": false, "reason": "no_note", "rejectedKeysound": false, "audioCommands": []}

	var note := _notes[note_index]
	var hit_time := _hit_time_for_note(note, now_ms)
	note["hitTime"] = hit_time
	_notes[note_index] = note

	if not _accept_note(note, hit_time, now_ms):
		var rejected_keysound := absf(hit_time) <= VOS_LIVE_TRIGGER_THRESHOLD
		if rejected_keysound:
			_emit_note_play_command(note_index, AUDIO_TRIGGER_EXTRASOUND, false)
		return {
			"pressed": true,
			"accepted": false,
			"hitTime": hit_time,
			"rejectedKeysound": rejected_keysound,
			"audioCommands": _audio_commands_since(audio_start_index),
		}

	var result := _apply_note_judgment(note_index, hit_time, now_ms)
	if result != "miss":
		_emit_note_play_command(note_index, AUDIO_TRIGGER_KEYSOUND, true)
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


func advance_to(now_ms: float) -> int:
	var judged := 0
	_advance_event_buffer(now_ms)
	_advance_auto_play(now_ms)
	for i in range(_notes.size()):
		var note := _notes[i]
		if str(note.get("state", STATE_NOT_JUDGED)) == STATE_NOT_JUDGED:
			var hit_time := _hit_time_for_note(note, now_ms)
			if _missed_note(note, hit_time, now_ms):
				_apply_note_judgment(i, hit_time, now_ms)
				judged += 1
		elif str(note.get("state", "")) == STATE_HOLDING:
			var tail_hit_time := _tail_hit_time_for_note(note, now_ms)
			if _missed_note(note, tail_hit_time, now_ms):
				_apply_note_judgment(i, tail_hit_time, now_ms)
				var lane := int(note.get("lane", -1))
				_held_note_indices.erase(lane)
				_longflare_lanes.erase(lane)
				judged += 1
	_cleanup_to_kill_notes(now_ms)
	return judged


func held_note_count() -> int:
	return _held_note_indices.size()


func note_layer_empty() -> bool:
	for note: Dictionary in _notes:
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
				note["state"] = STATE_NOT_JUDGED
				note["hitTime"] = 0.0
				note["samplePlayed"] = false
				normalized.append(note)

	normalized.sort_custom(_compare_notes)
	return normalized


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


func _normalized_buffer_events(raw_measures: Variant, raw_auto_play_events: Variant) -> Array[Dictionary]:
	var normalized := _normalized_timed_events(raw_measures)
	for event: Dictionary in _normalized_timed_events(raw_auto_play_events):
		normalized.append(event)
	normalized.sort_custom(_compare_timed_events)
	return normalized


func _configure_distance() -> void:
	var timing = TimingModel.new()
	var loaded := false
	var changes: Variant = _chart.get("visualTiming", [])
	if changes is Array:
		for raw_change: Variant in changes:
			if raw_change is Dictionary:
				timing.add_change(float(raw_change.get("timeMs", 0.0)), float(raw_change.get("bpm", 0.0)))
				loaded = true
	if not loaded:
		timing.add_change(0.0, float(_chart.get("bpm", 120.0)))
	timing.finish()
	_timing = timing
	_distance = NoteDistanceCalculator.new(timing, JAVA_MEASURE_SIZE)


func _compare_notes(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("startMs", 0.0)) < float(b.get("startMs", 0.0))


func _compare_auto_play_events(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("startMs", 0.0)) < float(b.get("startMs", 0.0))


func _compare_timed_events(a: Dictionary, b: Dictionary) -> bool:
	return float(a.get("startMs", 0.0)) < float(b.get("startMs", 0.0))


func _next_note_index_for_lane(lane: int) -> int:
	for i in range(_notes.size()):
		var note := _notes[i]
		if int(note.get("lane", -1)) == lane and str(note.get("state", STATE_NOT_JUDGED)) == STATE_NOT_JUDGED:
			return i
	return -1


func _hit_time_for_note(note: Dictionary, now_ms: float) -> float:
	return float(note.get("startMs", 0.0)) - now_ms


func _tail_hit_time_for_note(note: Dictionary, now_ms: float) -> float:
	var end_ms: Variant = note.get("endMs", null)
	if end_ms is int or end_ms is float:
		return float(end_ms) - now_ms
	return _hit_time_for_note(note, now_ms)


func _apply_note_judgment(note_index: int, hit_time: float, now_ms: float) -> String:
	var note := _notes[note_index]
	var result := _score_state.apply_judgment(_judge_note(note, hit_time, now_ms).to_lower())
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
		if str(_notes[i].get("state", STATE_NOT_JUDGED)) == STATE_DEAD:
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
	if str(note.get("kind", "")) == "holdStart":
		var end_ms: Variant = note.get("endMs", null)
		if end_ms is int or end_ms is float:
			target_ms = float(end_ms)
		return JAVA_JUDGMENT_LINE - _distance.calculate_hi_speed(now_ms, target_ms, JAVA_RENDER_SPEED)
	return JAVA_JUDGMENT_LINE - _distance.calculate_hi_speed(now_ms, target_ms, JAVA_RENDER_SPEED) - JAVA_TAP_NOTE_HEIGHT


func _accept_note(note: Dictionary, hit_time: float, now_ms: float) -> bool:
	if _judgment_type == JUDGMENT_TYPE_TIME:
		return _judgment.accept_time(hit_time)
	return _judgment.accept_beat(_beat_hit_delta(note, hit_time, now_ms))


func _missed_note(note: Dictionary, hit_time: float, now_ms: float) -> bool:
	if _judgment_type == JUDGMENT_TYPE_TIME:
		return _judgment.missed_time(hit_time)
	return _judgment.missed_beat(_beat_hit_delta(note, hit_time, now_ms))


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


func _advance_event_buffer(now_ms: float) -> void:
	if _distance == null:
		_buffer_event_index = _buffer_events.size()
		return
	while _buffer_event_index < _buffer_events.size() and _can_buffer_next_event(now_ms):
		var event := _buffer_events[_buffer_event_index]
		_buffer_timer_ms = float(event.get("startMs", 0.0))
		_buffer_event_index += 1


func _can_buffer_next_event(now_ms: float) -> bool:
	return JAVA_JUDGMENT_LINE - _distance.calculate_hi_speed(
			now_ms,
			_buffer_timer_ms,
			JAVA_RENDER_SPEED) > -10.0


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


func _audio_commands_since(start_index: int) -> Array[Dictionary]:
	var commands: Array[Dictionary] = []
	for i in range(start_index, _audio_commands.size()):
		commands.append(_audio_commands[i].duplicate(true))
	return commands
