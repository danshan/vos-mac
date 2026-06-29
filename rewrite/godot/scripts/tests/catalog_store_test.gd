extends SceneTree

const CatalogStore = preload("res://scripts/catalog_store.gd")

func _init() -> void:
	var store = CatalogStore.new()

	if not _expect_bool(store.load_from_file("res://test/fixtures/catalog.json"), true, "load fixture"):
		return
	if not _expect_int(store.count(), 1, "catalog count"):
		return
	if not _expect_int(store.filter("canon").size(), 1, "title filter count"):
		return
	if not _expect_int(store.filter("pachelbel").size(), 1, "artist filter count"):
		return
	if not _expect_int(store.filter("missing").size(), 0, "missing filter count"):
		return

	if not _expect_bool(store.load_from_file("res://test/fixtures/missing.json"), false, "missing file load"):
		return
	if not _expect_int(store.count(), 1, "count after missing file load"):
		return
	if not _expect_bool(store.load_from_file("res://test/fixtures/malformed_catalog.json"), false, "malformed file load"):
		return
	if not _expect_int(store.count(), 1, "count after malformed file load"):
		return

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
