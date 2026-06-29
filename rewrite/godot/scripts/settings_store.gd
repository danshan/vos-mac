extends RefCounted

const CHANNEL_MOD_NONE: String = "None"
const CHANNEL_MODIFIERS: Array[String] = ["None", "Mirror", "Shuffle", "Random"]

var _song_directories: Array[String] = []
var _fullscreen_enabled: bool = false
var _key_bindings: Array[String] = []
var _channel_modifier: String = CHANNEL_MOD_NONE


func set_song_directories(paths: Array[String]) -> void:
	_song_directories = paths.duplicate()


func song_directories() -> Array[String]:
	return _song_directories.duplicate()


func set_fullscreen_enabled(enabled: bool) -> void:
	_fullscreen_enabled = enabled


func fullscreen_enabled() -> bool:
	return _fullscreen_enabled


func set_key_bindings(bindings: Array[String]) -> void:
	_key_bindings = bindings.duplicate()


func key_bindings() -> Array[String]:
	return _key_bindings.duplicate()


func set_channel_modifier(modifier: String) -> void:
	if CHANNEL_MODIFIERS.has(modifier):
		_channel_modifier = modifier
	else:
		_channel_modifier = CHANNEL_MOD_NONE


func channel_modifier() -> String:
	return _channel_modifier
