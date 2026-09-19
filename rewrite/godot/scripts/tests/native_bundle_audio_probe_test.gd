extends SceneTree


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Expected one controlled bundle directory.")
		quit(1)
		return
	var stream := AudioStreamWAV.load_from_file(args[0].path_join("audio/tone.wav"))
	if stream == null:
		push_error("Native WAV failed to decode.")
		quit(1)
		return
	if absf(stream.get_length() - 0.25) > 0.000001 or stream.data.size() != 44100:
		push_error("Native WAV duration or decoded PCM length changed.")
		quit(1)
		return
	print("Native bundle WAV decoded by Godot: 0.25 seconds, 44100 PCM bytes.")
	quit(0)
