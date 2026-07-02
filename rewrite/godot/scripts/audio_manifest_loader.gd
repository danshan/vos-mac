extends RefCounted

const REQUIRED_ASSET_FIELDS: Array[String] = [
	"sampleId",
	"fileName",
	"path",
	"type",
	"role",
]
const VALID_FORMATS: Array[String] = ["VOS", "OSU", "OJN"]


func load_from_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var content: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(content)
	if not parsed is Dictionary:
		return {}

	var manifest: Dictionary = parsed
	var normalized_manifest: Dictionary = _normalized_manifest(manifest)
	if normalized_manifest.is_empty():
		return {}

	return normalized_manifest


func _normalized_manifest(manifest: Dictionary) -> Dictionary:
	if manifest.get("schemaVersion") != 1:
		return {}
	if not VALID_FORMATS.has(manifest.get("format")):
		return {}

	var assets: Variant = manifest.get("assets")
	if not assets is Array:
		return {}

	var normalized_assets: Array[Dictionary] = []
	for asset: Variant in assets:
		if not asset is Dictionary:
			return {}

		var normalized_asset: Dictionary = _normalized_asset(asset)
		if normalized_asset.is_empty():
			return {}
		normalized_assets.append(normalized_asset)

	var normalized_manifest: Dictionary = manifest.duplicate(true)
	normalized_manifest["assets"] = normalized_assets
	return normalized_manifest


func _normalized_asset(asset: Dictionary) -> Dictionary:
	if not _has_fields(asset, REQUIRED_ASSET_FIELDS):
		return {}

	var sample_id: Variant = asset.get("sampleId")
	if not _is_positive_integer_like(sample_id):
		return {}

	var file_name: Variant = asset.get("fileName")
	if not _is_non_empty_string(file_name):
		return {}

	var asset_path: Variant = asset.get("path")
	if not _is_non_empty_string(asset_path):
		return {}
	if not FileAccess.file_exists(asset_path):
		return {}

	if asset.get("type") != "wav":
		return {}

	var role: Variant = asset.get("role")
	if not _is_non_empty_string(role):
		return {}

	var normalized_asset: Dictionary = asset.duplicate(true)
	normalized_asset["sampleId"] = int(sample_id)
	return normalized_asset


func _is_positive_integer_like(value: Variant) -> bool:
	if not _is_integer_like(value):
		return false
	return int(value) > 0


func _is_integer_like(value: Variant) -> bool:
	if value is int:
		return true
	if value is float:
		return value == floor(value)
	return false


func _is_non_empty_string(value: Variant) -> bool:
	if not value is String:
		return false
	return not value.strip_edges().is_empty()


func _has_fields(entry: Dictionary, fields: Array[String]) -> bool:
	for field: String in fields:
		if not entry.has(field):
			return false
	return true
