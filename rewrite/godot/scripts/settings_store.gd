extends RefCounted

var _song_directories: Array[String] = []
var _fullscreen_enabled: bool = false


func set_song_directories(paths: Array[String]) -> void:
	_song_directories = paths.duplicate()


func song_directories() -> Array[String]:
	return _song_directories.duplicate()


func set_fullscreen_enabled(enabled: bool) -> void:
	_fullscreen_enabled = enabled


func fullscreen_enabled() -> bool:
	return _fullscreen_enabled
