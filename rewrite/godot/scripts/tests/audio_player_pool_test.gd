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
	if not _expect_bool(pool.has_method("preloaded_sample_count"), true, "preload counter method"):
		return
	if not _expect_int(pool.preloaded_sample_count(), 1, "preloaded sample count"):
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
	if not _expect_bool(pool.has_method("set_volume_state"), true, "volume state method"):
		return
	pool.set_volume_state(0.5, 0.25, 0.75)

	var note_play: Dictionary = pool.apply_audio_command({
		"action": "playSample",
		"source": "note",
		"trigger": "keysound",
		"sampleId": 1,
		"volume": 0.8,
		"noteId": 100,
	})
	if not _expect_bool(note_play.get("played", false), true, "note keysound command played"):
		return
	if not _expect_bool(note_play.get("registeredInstance", false), true, "note keysound registers instance"):
		return
	if not _expect_float(float(note_play.get("sampleVolume", -1.0)), 0.8, "note sample volume"):
		return
	if not _expect_float(float(note_play.get("masterVolume", -1.0)), 0.5, "note master volume"):
		return
	if not _expect_float(float(note_play.get("channelVolume", -1.0)), 0.25, "note channel volume"):
		return
	if not _expect_float(float(note_play.get("effectiveVolume", -1.0)), 0.1, "note effective volume"):
		return
	var note_player: Node = pool.get_node(str(note_play.get("player", "")))
	if not _expect_bool(note_player is AudioStreamPlayer, true, "note player node type"):
		return
	if not _expect_float(db_to_linear((note_player as AudioStreamPlayer).volume_db), 0.1, "note player initial db volume"):
		return
	pool.set_volume_state(0.4, 0.5, 0.75)
	if not _expect_float(db_to_linear((note_player as AudioStreamPlayer).volume_db), 0.16, "active note player volume update"):
		return
	pool.set_volume_state(0.5, 0.25, 0.75)

	var note_stop: Dictionary = pool.apply_audio_command({
		"action": "stopSample",
		"source": "note",
		"trigger": "missed",
		"sampleId": 1,
		"noteId": 100,
	})
	if not _expect_bool(note_stop.get("stopped", false), true, "note miss stops registered instance"):
		return

	var repeated_stop: Dictionary = pool.apply_audio_command({
		"action": "stopSample",
		"source": "note",
		"trigger": "missed",
		"sampleId": 1,
		"noteId": 100,
	})
	if not _expect_bool(repeated_stop.get("stopped", true), false, "note miss stop only once"):
		return

	var extra_play: Dictionary = pool.apply_audio_command({
		"action": "playSample",
		"source": "note",
		"trigger": "extrasound",
		"sampleId": 1,
		"noteId": 101,
	})
	if not _expect_bool(extra_play.get("played", false), true, "extrasound command played"):
		return
	if not _expect_bool(extra_play.get("registeredInstance", true), false, "extrasound does not register instance"):
		return

	var extra_stop: Dictionary = pool.apply_audio_command({
		"action": "stopSample",
		"source": "note",
		"trigger": "missed",
		"sampleId": 1,
		"noteId": 101,
	})
	if not _expect_bool(extra_stop.get("stopped", true), false, "extrasound miss has no registered instance"):
		return

	var batch_results: Array[Dictionary] = pool.apply_audio_commands([
		{"action": "playSample", "source": "autoPlay", "trigger": "autosound", "sampleId": 2, "volume": 0.8},
		{"action": "unknown", "sampleId": 2},
	])
	if not _expect_int(batch_results.size(), 2, "batch result count"):
		return
	if not _expect_bool(batch_results[0].get("played", false), true, "batch autoplay played"):
		return
	if not _expect_float(float(batch_results[0].get("sampleVolume", -1.0)), 0.8, "autoplay sample volume"):
		return
	if not _expect_float(float(batch_results[0].get("masterVolume", -1.0)), 0.5, "autoplay master volume"):
		return
	if not _expect_float(float(batch_results[0].get("channelVolume", -1.0)), 0.75, "autoplay channel volume"):
		return
	if not _expect_float(float(batch_results[0].get("effectiveVolume", -1.0)), 0.3, "autoplay effective volume"):
		return
	if not _expect_string(batch_results[1].get("reason", ""), "unknown_action", "unknown action reason"):
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


func _expect_float(actual: float, expected: float, label: String) -> bool:
	if absf(actual - expected) > 0.0001:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true
