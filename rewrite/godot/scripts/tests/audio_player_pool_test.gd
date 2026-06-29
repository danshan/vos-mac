extends SceneTree

const AudioManifestLoader = preload("res://scripts/audio_manifest_loader.gd")
const AudioPlayerPool = preload("res://scripts/audio_player_pool.gd")


func _init() -> void:
	var loader = AudioManifestLoader.new()
	var manifest: Dictionary = loader.load_from_file("res://test/fixtures/audio-manifest.json")
	if manifest.is_empty():
		push_error("Expected audio manifest fixture to load.")
		quit(1)
		return

	var pool = AudioPlayerPool.new()
	get_root().add_child(pool)

	if not _expect_bool(pool.load_manifest(manifest), true, "load manifest"):
		return
	if not _expect_int(pool.asset_count(), 2, "asset count"):
		return
	if not _expect_bool(pool.has_sample(1), true, "sample 1 exists"):
		return
	if not _expect_bool(pool.has_sample(99), false, "missing sample"):
		return

	var first_play: Dictionary = pool.play_sample(1)
	if not _expect_bool(first_play.get("played", false), true, "first play"):
		return
	if not _expect_int(first_play.get("sampleId", -1), 1, "first play sample id"):
		return
	if not _expect_string(first_play.get("role", ""), "keysound", "first play role"):
		return
	if not _expect_int(pool.play_event_count(), 1, "play event count"):
		return
	if not _expect_int(pool.get_child_count(), 1, "player node count"):
		return

	var missing_play: Dictionary = pool.play_sample(99)
	if not _expect_bool(missing_play.get("played", true), false, "missing play"):
		return
	if not _expect_int(pool.play_event_count(), 1, "missing does not add event"):
		return

	var stopped: int = pool.stop_all()
	if not _expect_int(stopped, 1, "stopped players"):
		return

	pool.free()
	quit(0)


func _expect_bool(actual: bool, expected: bool, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true


func _expect_int(actual: int, expected: int, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true


func _expect_string(actual: String, expected: String, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true
