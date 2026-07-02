extends SceneTree

const AudioManifestLoader = preload("res://scripts/audio_manifest_loader.gd")

func _init() -> void:
	var loader = AudioManifestLoader.new()
	var manifest: Dictionary = loader.load_from_file("res://test/fixtures/audio-manifest.json")

	if not _expect_bool(manifest.is_empty(), false, "fixture load"):
		return
	if not _expect_string(manifest.get("chartId", ""), "vos:fixture", "chart id"):
		return
	if not _expect_string(manifest.get("format", ""), "VOS", "format"):
		return

	var assets: Array = manifest.get("assets", [])
	if not _expect_int(assets.size(), 2, "asset count"):
		return
	if not _expect_int(assets[0].get("sampleId", -1), 1, "first sample id"):
		return
	if not _expect_bool(assets[0].get("sampleId") is int, true, "first sample id type"):
		return
	if not _expect_string(assets[0].get("path", ""), "res://test/fixtures/sample.wav", "first asset path"):
		return
	if not _expect_bool(assets[0].get("preload", false), true, "preload preservation"):
		return
	if not _expect_int(assets[1].get("sampleId", -1), 2, "second sample id"):
		return

	var float_sample_manifest: Dictionary = _valid_manifest()
	float_sample_manifest["assets"][0]["sampleId"] = 3.0
	if not _expect_loaded(loader, float_sample_manifest, "float sample id"):
		return
	var normalized_manifest: Dictionary = loader.load_from_file(_manifest_path("float sample id"))
	var normalized_assets: Array = normalized_manifest.get("assets", [])
	if not _expect_int(normalized_assets[0].get("sampleId", -1), 3, "normalized float sample id"):
		return
	if not _expect_bool(normalized_assets[0].get("sampleId") is int, true, "normalized float sample id type"):
		return

	var minimal_manifest: Dictionary = _valid_manifest()
	minimal_manifest.erase("chartId")
	minimal_manifest["assets"][0].erase("preload")
	if not _expect_loaded(loader, minimal_manifest, "missing optional fields"):
		return
	var loaded_minimal: Dictionary = loader.load_from_file(_manifest_path("missing optional fields"))
	if not _expect_bool(loaded_minimal.has("chartId"), false, "optional chart id absent"):
		return
	var minimal_assets: Array = loaded_minimal.get("assets", [])
	if not _expect_bool(minimal_assets[0].has("preload"), false, "optional preload absent"):
		return

	var osu_manifest: Dictionary = _valid_manifest()
	osu_manifest["format"] = "OSU"
	osu_manifest["chartId"] = "osu:fixture"
	if not _expect_loaded(loader, osu_manifest, "osu manifest format"):
		return

	var ojn_manifest: Dictionary = _valid_manifest()
	ojn_manifest["format"] = "OJN"
	ojn_manifest["chartId"] = "ojn:fixture"
	if not _expect_loaded(loader, ojn_manifest, "ojn manifest format"):
		return

	var missing_manifest: Dictionary = loader.load_from_file("res://test/fixtures/missing_audio_manifest.json")
	if not _expect_bool(missing_manifest.is_empty(), true, "missing file result"):
		return

	if not _expect_rejected(loader, _manifest_with("schemaVersion", 2), "wrong schema"):
		return
	if not _expect_rejected(loader, _manifest_with("format", "O2J"), "wrong format"):
		return
	if not _expect_rejected(loader, _manifest_with_asset("sampleId", "1"), "string sample id"):
		return
	if not _expect_rejected(loader, _manifest_with_asset("sampleId", 0), "zero sample id"):
		return
	if not _expect_rejected(loader, _manifest_without_asset_field("fileName"), "missing file name"):
		return
	if not _expect_rejected(loader, _manifest_with_asset("path", ""), "empty path"):
		return
	if not _expect_rejected(loader, _manifest_with_asset("type", "ogg"), "non-wav type"):
		return
	if not _expect_rejected(loader, _manifest_without_asset_field("role"), "missing role"):
		return
	if not _expect_rejected(loader, _manifest_with_asset("path", "res://test/fixtures/missing.wav"), "nonexistent asset path"):
		return
	if not _expect_rejected(loader, _manifest_with("assets", null), "missing assets"):
		return
	if not _expect_rejected(loader, _manifest_with("assets", "samples"), "string assets"):
		return
	if not _expect_rejected(loader, _manifest_with("assets", ["sample"]), "string asset"):
		return
	if not _expect_non_dictionary_root(loader):
		return

	quit(0)


func _valid_manifest() -> Dictionary:
	return {
		"schemaVersion": 1,
		"format": "VOS",
		"chartId": "vos:fixture",
		"sourcePath": "fixture.vos",
		"assetDir": "audio",
		"assets": [
			{
				"sampleId": 1,
				"fileName": "sample.wav",
				"path": "res://test/fixtures/sample.wav",
				"type": "wav",
				"role": "keysound",
				"preload": true,
			},
			{
				"sampleId": 2,
				"fileName": "sample-copy.wav",
				"path": "res://test/fixtures/sample.wav",
				"type": "wav",
				"role": "background",
			},
		],
	}


func _manifest_with(field: String, value: Variant) -> Dictionary:
	var manifest: Dictionary = _valid_manifest()
	if value == null:
		manifest.erase(field)
	else:
		manifest[field] = value
	return manifest


func _manifest_with_asset(field: String, value: Variant) -> Dictionary:
	var manifest: Dictionary = _valid_manifest()
	manifest["assets"][0][field] = value
	return manifest


func _manifest_without_asset_field(field: String) -> Dictionary:
	var manifest: Dictionary = _valid_manifest()
	manifest["assets"][0].erase(field)
	return manifest


func _expect_loaded(loader: RefCounted, manifest: Dictionary, label: String) -> bool:
	var path: String = _manifest_path(label)
	if not _write_json(path, JSON.stringify(manifest)):
		return false

	var loaded: Dictionary = loader.load_from_file(path)
	return _expect_bool(loaded.is_empty(), false, label)


func _expect_rejected(loader: RefCounted, manifest: Dictionary, label: String) -> bool:
	var path: String = _manifest_path(label)
	if not _write_json(path, JSON.stringify(manifest)):
		return false

	var loaded: Dictionary = loader.load_from_file(path)
	return _expect_bool(loaded.is_empty(), true, label)


func _expect_non_dictionary_root(loader: RefCounted) -> bool:
	var path: String = _manifest_path("non dictionary")
	if not _write_json(path, JSON.stringify([])):
		return false

	var loaded: Dictionary = loader.load_from_file(path)
	return _expect_bool(loaded.is_empty(), true, "non-dictionary root")


func _manifest_path(label: String) -> String:
	return "%s/open2jam_%s_audio_manifest.json" % [OS.get_temp_dir(), label.replace(" ", "_")]


func _write_json(path: String, content: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write manifest fixture '%s'." % path)
		quit(1)
		return false

	file.store_string(content)
	return true


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
