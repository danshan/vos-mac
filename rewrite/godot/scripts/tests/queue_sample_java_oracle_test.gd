extends SceneTree

const AudioPlayerPool = preload("res://scripts/audio_player_pool.gd")

const ORACLE_PATH := "res://test/fixtures/queue-sample-oracle.json"
const SAMPLE_PATH := "res://test/fixtures/sample.wav"
const MASTER_VOLUME := 0.5
const KEY_VOLUME := 0.25
const BGM_VOLUME := 0.75


func _init() -> void:
	var oracle: Dictionary = _load_json(ORACLE_PATH)
	if oracle.is_empty():
		_fail("Expected queue sample oracle fixture to load.")
		return
	if not _expect_string(str(oracle.get("source", "")), "Render.queueSample playback parameters", "oracle source"):
		return

	var pool = AudioPlayerPool.new()
	get_root().add_child(pool)
	if not _expect_bool(pool.load_manifest(_manifest_for_oracle(oracle)), true, "oracle manifest load"):
		return
	pool.set_volume_state(MASTER_VOLUME, KEY_VOLUME, BGM_VOLUME)

	for raw_case: Variant in oracle.get("cases", []):
		if not raw_case is Dictionary:
			_fail("Expected queue sample oracle case object.")
			return
		if not _verify_case(pool, raw_case):
			return

	pool.free()
	quit(0)


func _verify_case(pool: Node, oracle_case: Dictionary) -> bool:
	var before_count: int = pool.play_event_count()
	var expected_play_count := int(oracle_case.get("playCount", 0))
	var result: Dictionary = {"played": false}
	if int(oracle_case.get("sampleId", 0)) > 0:
		result = pool.apply_audio_command({
			"action": "playSample",
			"source": "autoPlay" if bool(oracle_case.get("bgm", false)) else "note",
			"trigger": "oracle",
			"sampleId": int(oracle_case.get("sampleId", 0)),
			"volume": float(oracle_case.get("sampleVolume", 0.0)),
			"pan": float(oracle_case.get("pan", 0.0)),
		})

	var name := str(oracle_case.get("name", ""))
	if not _expect_bool(bool(result.get("played", false)), bool(oracle_case.get("played", false)), "%s played" % name):
		return false
	if not _expect_int(pool.play_event_count() - before_count, expected_play_count, "%s play event delta" % name):
		return false
	if expected_play_count == 0:
		return true

	var expected_channel_volume := BGM_VOLUME if bool(oracle_case.get("bgm", false)) else KEY_VOLUME
	if not _expect_float(float(result.get("sampleVolume", -1.0)), float(oracle_case.get("playVolume", -1.0)), "%s play volume" % name):
		return false
	if not _expect_float(float(result.get("pan", 0.0)), float(oracle_case.get("playPan", 0.0)), "%s play pan" % name):
		return false
	if not _expect_float(float(result.get("channelVolume", -1.0)), expected_channel_volume, "%s channel volume" % name):
		return false
	var player: Node = pool.get_node(str(result.get("player", "")))
	if not _expect_bool(player is AudioStreamPlayer2D, true, "%s player type" % name):
		return false
	if not _expect_float(float(player.get_meta("pan", 0.0)), float(oracle_case.get("playPan", 0.0)), "%s player pan metadata" % name):
		return false
	if not _expect_float((player as AudioStreamPlayer2D).position.x, float(oracle_case.get("playPan", 0.0)), "%s player pan position" % name):
		return false
	return true


func _manifest_for_oracle(oracle: Dictionary) -> Dictionary:
	var assets: Array[Dictionary] = []
	for oracle_case: Variant in oracle.get("cases", []):
		if not oracle_case is Dictionary or not bool(oracle_case.get("played", false)):
			continue
		var sample_id := int(oracle_case.get("sampleId", 0))
		assets.append({
			"sampleId": sample_id,
			"fileName": "sample-%d.wav" % sample_id,
			"path": SAMPLE_PATH,
			"type": "wav",
			"role": "sample" if bool(oracle_case.get("bgm", false)) else "background",
			"preload": true,
		})
	return {
		"schemaVersion": 1,
		"format": "VOS",
		"chartId": "queue-sample-oracle",
		"assets": assets,
	}


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	return {}


func _expect_bool(actual: bool, expected: bool, label: String) -> bool:
	if actual != expected:
		_fail("Expected %s '%s', got '%s'." % [label, expected, actual])
		return false
	return true


func _expect_int(actual: int, expected: int, label: String) -> bool:
	if actual != expected:
		_fail("Expected %s '%s', got '%s'." % [label, expected, actual])
		return false
	return true


func _expect_string(actual: String, expected: String, label: String) -> bool:
	if actual != expected:
		_fail("Expected %s '%s', got '%s'." % [label, expected, actual])
		return false
	return true


func _expect_float(actual: float, expected: float, label: String) -> bool:
	if absf(actual - expected) > 0.0001:
		_fail("Expected %s '%s', got '%s'." % [label, expected, actual])
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
