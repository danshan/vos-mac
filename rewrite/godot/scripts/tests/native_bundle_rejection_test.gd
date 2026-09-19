extends SceneTree

const BundleLoader = preload("res://scripts/native_bundle_loader.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		quit(1)
		return
	var directory := DirAccess.open(args[0])
	if directory == null:
		quit(1)
		return
	var count := 0
	for name: String in directory.get_directories():
		if not BundleLoader.new().load_bundle(args[0].path_join(name) + "/").is_empty():
			push_error("Invalid bundle accepted: " + name)
			quit(1)
			return
		count += 1
	if count < 15:
		push_error("Adversarial bundle matrix is incomplete.")
		quit(1)
		return
	print("Native invalid bundle matrix rejected: %d cases." % count)
	quit(0)
