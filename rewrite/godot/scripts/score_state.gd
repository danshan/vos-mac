extends RefCounted

var score: int = 0
var combo: int = 0
var max_combo: int = 0
var judgments: Dictionary = {
	"cool": 0,
	"good": 0,
	"bad": 0,
	"miss": 0,
}


func apply_judgment(name: String) -> void:
	judgments[name] = judgments.get(name, 0) + 1

	if name == "miss":
		combo = 0
		return

	combo += 1
	max_combo = max(max_combo, combo)
	score += _score_for_judgment(name)


func _score_for_judgment(name: String) -> int:
	if name == "cool":
		return 1000
	if name == "good":
		return 500
	return 100
