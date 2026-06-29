extends RefCounted

const InputMapStore = preload("res://scripts/input_map_store.gd")
const JudgmentStrategy = preload("res://scripts/judgment_strategy.gd")
const ResultModel = preload("res://scripts/result_model.gd")
const ScoreState = preload("res://scripts/score_state.gd")

const STATE_NOT_JUDGED: String = "not_judged"
const STATE_DEAD: String = "dead"
const STATE_HOLDING: String = "holding"
const VOS_LIVE_TRIGGER_THRESHOLD: float = 280.0

var _chart: Dictionary = {}
var _notes: Array[Dictionary] = []
var _score_state = ScoreState.new()
var _input_map = InputMapStore.new()
var _judgment = JudgmentStrategy.new()
var _pressed_lanes: Dictionary = {}
var _held_note_indices: Dictionary = {}


func load_chart(chart: Dictionary) -> bool:
	if chart.is_empty():
		return false

	_chart = chart.duplicate(true)
	_score_state = ScoreState.new()
	_notes = _normalized_notes(_chart.get("notes", []))
	_pressed_lanes.clear()
	_held_note_indices.clear()
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


func press_lane(lane: int, now_ms: float) -> Dictionary:
	if lane < 0:
		return {"pressed": false, "accepted": false, "reason": "invalid_lane"}
	if bool(_pressed_lanes.get(lane, false)):
		return {"pressed": false, "accepted": false, "reason": "already_pressed"}

	_pressed_lanes[lane] = true

	var note_index := _next_note_index_for_lane(lane)
	if note_index < 0:
		return {"pressed": true, "accepted": false, "reason": "no_note", "rejectedKeysound": false}

	var note := _notes[note_index]
	var hit_time := _hit_time_for_note(note, now_ms)
	note["hitTime"] = hit_time
	_notes[note_index] = note

	if not _judgment.accept_time(hit_time):
		return {
			"pressed": true,
			"accepted": false,
			"hitTime": hit_time,
			"rejectedKeysound": absf(hit_time) <= VOS_LIVE_TRIGGER_THRESHOLD,
		}

	var result := _apply_note_judgment(note_index, hit_time)
	if str(note.get("kind", "")) == "holdStart" and result != "miss":
		note = _notes[note_index]
		note["state"] = STATE_HOLDING
		_notes[note_index] = note
		_held_note_indices[lane] = note_index

	return {
		"pressed": true,
		"accepted": true,
		"hitTime": hit_time,
		"result": result,
		"keysound": true,
		"rejectedKeysound": false,
	}


func release_lane(lane: int, now_ms: float) -> Dictionary:
	if lane < 0:
		return {"released": false, "accepted": false, "reason": "invalid_lane"}

	_pressed_lanes[lane] = false
	if not _held_note_indices.has(lane):
		return {"released": true, "accepted": false, "reason": "no_held_note"}

	var note_index: int = int(_held_note_indices.get(lane))
	_held_note_indices.erase(lane)

	var note := _notes[note_index]
	var hit_time := _tail_hit_time_for_note(note, now_ms)
	note["hitTime"] = hit_time
	_notes[note_index] = note

	var result := _apply_note_judgment(note_index, hit_time)
	return {
		"released": true,
		"accepted": result != "miss",
		"hitTime": hit_time,
		"result": result,
	}


func advance_to(now_ms: float) -> int:
	var judged := 0
	for i in range(_notes.size()):
		var note := _notes[i]
		if str(note.get("state", STATE_NOT_JUDGED)) == STATE_NOT_JUDGED:
			var hit_time := _hit_time_for_note(note, now_ms)
			if _judgment.missed_time(hit_time):
				_apply_note_judgment(i, hit_time)
				judged += 1
		elif str(note.get("state", "")) == STATE_HOLDING:
			var tail_hit_time := _tail_hit_time_for_note(note, now_ms)
			if _judgment.missed_time(tail_hit_time):
				_apply_note_judgment(i, tail_hit_time)
				_held_note_indices.erase(int(note.get("lane", -1)))
				judged += 1
	return judged


func held_note_count() -> int:
	return _held_note_indices.size()


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
				normalized.append(note)

	normalized.sort_custom(_compare_notes)
	return normalized


func _compare_notes(a: Dictionary, b: Dictionary) -> bool:
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


func _apply_note_judgment(note_index: int, hit_time: float) -> String:
	var note := _notes[note_index]
	var result := _score_state.apply_judgment(_judgment.judge_time(hit_time).to_lower())
	note["state"] = STATE_DEAD
	note["hitTime"] = hit_time
	_notes[note_index] = note
	return result
