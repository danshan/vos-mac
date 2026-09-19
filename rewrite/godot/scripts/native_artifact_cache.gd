extends RefCounted

const Integrity = preload("res://scripts/native_bundle_integrity.gd")
const Loader = preload("res://scripts/native_bundle_loader.gd")


# Prepared bundles retain their declared producer identity. Raw formats acquire
# their source fingerprint from their importer before entering this boundary.
func lookup(root: String, request: Dictionary, cancel: Callable) -> Dictionary:
	if request.get("sourceKind") != "BUNDLE_V2":
		return {}
	var integrity = Integrity.new()
	var source: Dictionary = integrity.verify(request["sourcePath"], "", cancel)
	if source.is_empty() or source["chartId"] != request["chartId"]:
		return {}
	var path := root.path_join(str(source["bundleKey"]).trim_prefix("sha256:"))
	var cached: Dictionary = integrity.read_json(path.path_join("bundle.json"), 1048576, {}, cancel)
	var bundle: Dictionary = Loader.new().load_bundle(path, source["bundleKey"], cancel)
	if not bundle.is_empty():
		return {"bundle": bundle} if cached == source else {"conflict": true}
	return {"replaceKey": source["bundleKey"] if DirAccess.dir_exists_absolute(path) or FileAccess.file_exists(path) else ""}


# Called only by the active generation on the scene thread after both validators
# and final progress EOF. No callbacks or frame yields occur during publication.
func publish(root: String, staging: String, bundle: Dictionary, replace_key: String) -> Dictionary:
	var destination := root.path_join(str(bundle["bundleKey"]).trim_prefix("sha256:"))
	if DirAccess.make_dir_recursive_absolute(root) != OK:
		return {"ok": false, "error": {"code": "INTERNAL_ERROR", "message": "Unable to create artifact cache."}}
	var retired := ""
	if DirAccess.dir_exists_absolute(destination) or FileAccess.file_exists(destination):
		if replace_key != bundle["bundleKey"]:
			return {"ok": false, "error": {"code": "CACHE_CORRUPT", "message": "Artifact cache destination already exists."}}
		retired = destination + ".retired-" + staging.get_file()
		if DirAccess.dir_exists_absolute(retired) or FileAccess.file_exists(retired) or DirAccess.rename_absolute(destination, retired) != OK:
			return {"ok": false, "error": {"code": "INTERNAL_ERROR", "message": "Unable to quarantine corrupt artifact."}}
	if DirAccess.rename_absolute(staging, destination) != OK:
		if not retired.is_empty() and DirAccess.rename_absolute(retired, destination) != OK:
			return {"ok": false, "error": {"code": "INTERNAL_ERROR", "message": "Artifact publication failed; prior entry retained in quarantine."}}
		return {"ok": false, "error": {"code": "INTERNAL_ERROR", "message": "Unable to publish artifact cache."}}
	for asset: Dictionary in bundle["audio"]["assets"]:
		asset["path"] = destination.path_join(str(asset["path"]).trim_prefix(staging + "/"))
	return {"ok": true, "bundle": bundle}
