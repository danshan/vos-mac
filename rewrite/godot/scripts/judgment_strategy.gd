extends RefCounted

const TIME_BAD_THRESHOLD: float = 173.0
const TIME_GOOD_THRESHOLD: float = 125.0
const TIME_COOL_THRESHOLD: float = 41.0

const BEAT_BAD_THRESHOLD: float = 0.8
const BEAT_GOOD_THRESHOLD: float = 0.5
const BEAT_COOL_THRESHOLD: float = 0.2

const COOL: String = "COOL"
const GOOD: String = "GOOD"
const BAD: String = "BAD"
const MISS: String = "MISS"


func accept_time(hit_time: float) -> bool:
	return hit_time <= TIME_BAD_THRESHOLD


func missed_time(hit_time: float) -> bool:
	return hit_time < -TIME_BAD_THRESHOLD


func judge_time(hit_time: float) -> String:
	var hit := absf(hit_time)
	if hit <= TIME_COOL_THRESHOLD:
		return COOL
	if hit <= TIME_GOOD_THRESHOLD:
		return GOOD
	if hit <= TIME_BAD_THRESHOLD:
		return BAD
	return MISS


func accept_beat(hit_delta: float) -> bool:
	return hit_delta <= BEAT_BAD_THRESHOLD


func missed_beat(hit_delta: float) -> bool:
	return hit_delta < -BEAT_BAD_THRESHOLD


func judge_beat(hit_delta: float) -> String:
	var hit := absf(hit_delta)
	if hit <= BEAT_COOL_THRESHOLD:
		return COOL
	if hit <= BEAT_GOOD_THRESHOLD:
		return GOOD
	if hit <= BEAT_BAD_THRESHOLD:
		return BAD
	return MISS
