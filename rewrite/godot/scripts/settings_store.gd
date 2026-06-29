extends RefCounted

const CHANNEL_MOD_NONE: String = "None"
const CHANNEL_MODIFIERS: Array[String] = ["None", "Mirror", "Shuffle", "Random"]
const SPEED_TYPE_DEFAULT: String = "HiSpeed"
const SPEED_TYPES: Array[String] = ["HiSpeed", "xRSpeed", "WSpeed", "RegulSpeed"]
const VISIBILITY_MOD_NONE: String = "None"
const VISIBILITY_MODIFIERS: Array[String] = ["None", "Hidden", "Sudden", "Dark"]

var _song_directories: Array[String] = []
var _fullscreen_enabled: bool = false
var _key_bindings: Array[String] = []
var _channel_modifier: String = CHANNEL_MOD_NONE
var _speed_type: String = SPEED_TYPE_DEFAULT
var _speed_multiplier: float = 1.0
var _visibility_modifier: String = VISIBILITY_MOD_NONE


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


func set_speed_type(speed_type: String) -> void:
	if SPEED_TYPES.has(speed_type):
		_speed_type = speed_type
	else:
		_speed_type = SPEED_TYPE_DEFAULT


func speed_type() -> String:
	return _speed_type


func set_speed_multiplier(multiplier: float) -> void:
	_speed_multiplier = max(multiplier, 0.001)


func speed_multiplier() -> float:
	return _speed_multiplier


func set_visibility_modifier(modifier: String) -> void:
	if VISIBILITY_MODIFIERS.has(modifier):
		_visibility_modifier = modifier
	else:
		_visibility_modifier = VISIBILITY_MOD_NONE


func visibility_modifier() -> String:
	return _visibility_modifier
