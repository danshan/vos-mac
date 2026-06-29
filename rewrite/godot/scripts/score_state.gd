extends RefCounted

const BASE_LIFE: int = 12000
const JAM_BAR_LIMIT: int = 50
const MAX_PILLS: int = 5

var score: int = 0
var combo: int = 0
var max_combo: int = 0
var rank: int = 0
var life_limit: int = 0
var life: int = 0
var jam_bar_limit: int = JAM_BAR_LIMIT
var jam_bar: int = 0
var jam_combo: int = 0
var consecutive_cools: int = 0
var pills: int = 0
var judgments: Dictionary = {}


func _init(initial_rank: int = 0) -> void:
	rank = initial_rank
	reset()


func reset() -> void:
	score = 0
	combo = 0
	max_combo = 0
	jam_bar = 0
	jam_combo = 0
	consecutive_cools = 0
	pills = 0
	life_limit = BASE_LIFE * _life_multiplier_for_rank(rank)
	life = life_limit
	judgments = {
		"cool": 0,
		"good": 0,
		"bad": 0,
		"miss": 0,
	}


func apply_judgment(name: String) -> String:
	var result := _handle_judgment(_normalize_judgment(name))
	judgments[result] = judgments.get(result, 0) + 1

	if _should_increase_combo(result):
		combo += 1
	else:
		combo = 0

	return result


func _handle_judgment(result: String) -> String:
	var score_value := 0

	match result:
		"cool":
			jam_bar = _add_with_limit(jam_bar, 2, jam_bar_limit)
			consecutive_cools += 1
			life = _add_with_limit(life, 48 if rank >= 2 else 96, life_limit)
			score_value = 200 + jam_combo * 10
		"good":
			jam_bar = _add_with_limit(jam_bar, 1, jam_bar_limit)
			consecutive_cools = 0
			score_value = 100
		"bad":
			if pills > 0:
				result = "good"
				jam_bar = _add_with_limit(jam_bar, 1, jam_bar_limit)
				pills -= 1
				score_value = 100
			else:
				jam_bar = 0
				jam_combo = 0
				life = _subtract_with_floor(life, 240)
				score_value = 4
			consecutive_cools = 0
		"miss":
			jam_bar = 0
			jam_combo = 0
			consecutive_cools = 0
			life = _subtract_with_floor(life, 1440)
			score_value = -10 if score >= 10 else -score
		_:
			push_error("Unknown judgment '%s'." % result)
			return result

	score += score_value

	if jam_bar >= jam_bar_limit:
		jam_bar = 0
		jam_combo += 1

	if consecutive_cools >= 15 and pills < MAX_PILLS:
		consecutive_cools -= 15
		pills += 1

	if max_combo < combo:
		max_combo += 1

	return result


func _should_increase_combo(result: String) -> bool:
	return result != "bad" and result != "miss"


func _normalize_judgment(name: String) -> String:
	return name.to_lower()


func _life_multiplier_for_rank(value: int) -> int:
	if value >= 2:
		return 4
	if value >= 1:
		return 3
	return 2


func _add_with_limit(value: int, amount: int, limit: int) -> int:
	return min(value + amount, limit)


func _subtract_with_floor(value: int, amount: int) -> int:
	return max(value - amount, 0)
