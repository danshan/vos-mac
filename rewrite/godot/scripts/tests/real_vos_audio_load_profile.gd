extends SceneTree


func _init() -> void:
	var manifest_path := OS.get_environment("OPEN2JAM_AUDIO_MANIFEST").strip_edges()
	if manifest_path.is_empty():
		push_error("OPEN2JAM_AUDIO_MANIFEST is required.")
		quit(1)
		return
	if not FileAccess.file_exists(manifest_path):
		push_error("Audio manifest does not exist: %s" % manifest_path)
		quit(1)
		return

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if not parsed is Dictionary:
		push_error("Audio manifest is not a JSON object: %s" % manifest_path)
		quit(1)
		return

	var assets: Variant = parsed.get("assets", [])
	if not assets is Array:
		push_error("Audio manifest assets field is not an array.")
		quit(1)
		return

	var started := Time.get_ticks_msec()
	var failures: Array[Dictionary] = []
	var slow: Array[Dictionary] = []
	for i in range(assets.size()):
		var asset: Variant = assets[i]
		if not asset is Dictionary:
			failures.append({"index": i + 1, "reason": "invalid_asset"})
			continue
		var sample_id := int(asset.get("sampleId", 0))
		var path := str(asset.get("path", ""))
		var sample_started := Time.get_ticks_msec()
		var stream := AudioStreamWAV.load_from_file(path)
		var elapsed := Time.get_ticks_msec() - sample_started
		if stream == null:
			failures.append({
				"index": i + 1,
				"sampleId": sample_id,
				"path": path,
				"elapsedMs": elapsed,
				"reason": "load_failed",
			})
			continue
		if elapsed >= 100:
			slow.append({
				"index": i + 1,
				"sampleId": sample_id,
				"path": path,
				"elapsedMs": elapsed,
			})

	print(JSON.stringify({
		"manifest": manifest_path,
		"assetCount": assets.size(),
		"totalElapsedMs": Time.get_ticks_msec() - started,
		"slow": slow,
		"failures": failures,
	}))
	quit(0)
