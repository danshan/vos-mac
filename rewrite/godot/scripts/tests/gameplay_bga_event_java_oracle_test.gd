extends SceneTree

const AudioManifestLoader = preload("res://scripts/audio_manifest_loader.gd")
const GameplayRuntime = preload("res://scripts/gameplay_runtime.gd")


func _init() -> void:
	var oracle: Dictionary = _load_oracle()
	if oracle.is_empty():
		return

	var audio_manifest: Dictionary = _load_audio_manifest()
	if audio_manifest.is_empty():
		return

	var scenarios: Variant = oracle.get("scenarios")
	if not scenarios is Array:
		push_error("Expected BGA event oracle scenarios array.")
		quit(1)
		return

	for raw_scenario: Variant in scenarios:
		if not raw_scenario is Dictionary:
			push_error("Expected BGA event oracle scenario object.")
			quit(1)
			return
		if not _verify_scenario(oracle, audio_manifest, raw_scenario):
			return

	quit(0)


func _load_oracle() -> Dictionary:
	var path := "res://test/fixtures/bga-event-oracle.json"
	if not FileAccess.file_exists(path):
		push_error("Missing BGA event oracle fixture: %s" % path)
		quit(1)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Expected BGA event oracle root object.")
		quit(1)
		return {}

	var root: Dictionary = parsed
	if int(root.get("schemaVersion", 0)) != 1:
		push_error("Expected BGA event oracle schema version 1.")
		quit(1)
		return {}
	if str(root.get("source", "")) != "Render TimeEntity loop for BgaEntity":
		push_error("Expected BGA event oracle source Render TimeEntity loop for BgaEntity.")
		quit(1)
		return {}
	return root


func _load_audio_manifest() -> Dictionary:
	var loader = AudioManifestLoader.new()
	var audio_manifest: Dictionary = loader.load_from_file("res://test/fixtures/audio-manifest.json")
	if audio_manifest.is_empty():
		push_error("Missing audio manifest fixture for BGA event oracle test.")
		quit(1)
	return audio_manifest


func _verify_scenario(oracle: Dictionary, audio_manifest: Dictionary, scenario: Dictionary) -> bool:
	var runtime = GameplayRuntime.new()
	get_root().add_child(runtime)
	if not _expect_bool(runtime.start(_chart_from_oracle(oracle, scenario), audio_manifest), true,
			"%s runtime start" % scenario.get("name", "")):
		return false

	var frames: Variant = scenario.get("frames")
	if not frames is Array:
		push_error("Expected BGA event oracle frames array for %s." % scenario.get("name", ""))
		quit(1)
		return false

	for raw_frame: Variant in frames:
		if not raw_frame is Dictionary:
			push_error("Expected BGA event oracle frame object for %s." % scenario.get("name", ""))
			quit(1)
			return false
		if not _verify_frame(runtime, scenario, raw_frame):
			return false

	runtime.free()
	return true


func _chart_from_oracle(oracle: Dictionary, scenario: Dictionary) -> Dictionary:
	var bga_events: Array[Dictionary] = []
	bga_events.append({
		"startMs": float(oracle.get("eventTimeMs", 0.0)),
		"spriteId": _sprite_id_for_name("first"),
	})
	if str(scenario.get("name", "")) == "queued_same_frame":
		bga_events.append({
			"startMs": float(oracle.get("eventTimeMs", 0.0)),
			"spriteId": _sprite_id_for_name("second"),
		})

	return {
		"schemaVersion": 1,
		"chartId": "vos:bga-event-oracle:%s" % scenario.get("name", ""),
		"format": "VOS",
		"autosound": bool(scenario.get("autosound", false)),
		"audioLatencyMs": float(oracle.get("audioLatencyMs", 0.0)),
		"keys": 7,
		"bpm": 120.0,
		"durationMs": 3000,
		"notes": [],
		"measures": [],
		"autoPlayEvents": [],
		"bgaEvents": bga_events,
	}


func _verify_frame(runtime: Node, scenario: Dictionary, frame: Dictionary) -> bool:
	runtime.advance_to(float(frame.get("gameTimeMs", 0.0)))
	var state: Dictionary = runtime.hud_state()
	var label := "%s frame %.1f" % [scenario.get("name", ""), float(frame.get("gameTimeMs", 0.0))]
	if not _expect_int(int(state.get("judgmentTimeMs", -1)), int(round(float(frame.get("timeToJudgeMs", 0.0)))),
			"%s judgment time" % label):
		return false

	var expected_sprite := str(frame.get("currentSprite", ""))
	if expected_sprite == "base":
		return _expect_bool(state.has("currentBgaEvent"), false, "%s BGA event absent" % label)

	var event: Dictionary = state.get("currentBgaEvent", {})
	return _expect_int(int(event.get("spriteId", -1)), _sprite_id_for_name(expected_sprite),
			"%s BGA sprite" % label)


func _sprite_id_for_name(sprite_name: String) -> int:
	match sprite_name:
		"first":
			return 1
		"second":
			return 2
		_:
			return -1


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
