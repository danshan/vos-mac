extends RefCounted

const CHANNEL_MOD_NONE: String = "None"
const CHANNEL_MODIFIERS: Array[String] = ["None", "Mirror", "Shuffle", "Random"]
const SPEED_TYPE_DEFAULT: String = "HiSpeed"
const SPEED_TYPES: Array[String] = ["HiSpeed", "xRSpeed", "WSpeed", "RegulSpeed"]
const VISIBILITY_MOD_NONE: String = "None"
const VISIBILITY_MODIFIERS: Array[String] = ["None", "Hidden", "Sudden", "Dark"]
const JUDGMENT_TYPE_DEFAULT: String = "beat"
const JUDGMENT_TYPES: Array[String] = ["beat", "time"]

var _song_directories: Array[String] = []
var _fullscreen_enabled: bool = false
var _autoplay_enabled: bool = false
var _autosound_enabled: bool = false
var _audio_latency_ms: float = 0.0
var _display_latency_ms: float = 0.0
var _master_volume: float = 1.0
var _key_volume: float = 1.0
var _bgm_volume: float = 1.0
var _haste_mode_enabled: bool = false
var _haste_mode_normalize_speed: bool = true
var _start_paused_enabled: bool = false
var _key_bindings: Array[String] = []
var _channel_modifier: String = CHANNEL_MOD_NONE
var _speed_type: String = SPEED_TYPE_DEFAULT
var _speed_multiplier: float = 1.0
var _visibility_modifier: String = VISIBILITY_MOD_NONE
var _judgment_type: String = JUDGMENT_TYPE_DEFAULT


func set_song_directories(paths: Array[String]) -> void:
	_song_directories = paths.duplicate()


func song_directories() -> Array[String]:
	return _song_directories.duplicate()


func set_fullscreen_enabled(enabled: bool) -> void:
	_fullscreen_enabled = enabled


func fullscreen_enabled() -> bool:
	return _fullscreen_enabled


func set_autoplay_enabled(enabled: bool) -> void:
	_autoplay_enabled = enabled


func autoplay_enabled() -> bool:
	return _autoplay_enabled


func set_autosound_enabled(enabled: bool) -> void:
	_autosound_enabled = enabled


func autosound_enabled() -> bool:
	return _autosound_enabled


func set_audio_latency_ms(latency_ms: float) -> void:
	_audio_latency_ms = latency_ms


func audio_latency_ms() -> float:
	return _audio_latency_ms


func set_display_latency_ms(latency_ms: float) -> void:
	_display_latency_ms = latency_ms


func display_latency_ms() -> float:
	return _display_latency_ms


func set_master_volume(volume: float) -> void:
	_master_volume = _clamped_volume(volume)


func master_volume() -> float:
	return _master_volume


func set_key_volume(volume: float) -> void:
	_key_volume = _clamped_volume(volume)


func key_volume() -> float:
	return _key_volume


func set_bgm_volume(volume: float) -> void:
	_bgm_volume = _clamped_volume(volume)


func bgm_volume() -> float:
	return _bgm_volume


func set_haste_mode_enabled(enabled: bool) -> void:
	_haste_mode_enabled = enabled


func haste_mode_enabled() -> bool:
	return _haste_mode_enabled


func set_haste_mode_normalize_speed(enabled: bool) -> void:
	_haste_mode_normalize_speed = enabled


func haste_mode_normalize_speed() -> bool:
	return _haste_mode_normalize_speed


func set_start_paused_enabled(enabled: bool) -> void:
	_start_paused_enabled = enabled


func start_paused_enabled() -> bool:
	return _start_paused_enabled


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


func set_judgment_type(judgment_type: String) -> void:
	if JUDGMENT_TYPES.has(judgment_type):
		_judgment_type = judgment_type
	else:
		_judgment_type = JUDGMENT_TYPE_DEFAULT


func judgment_type() -> String:
	return _judgment_type


func save_to_file(path: String) -> bool:
	var config := ConfigFile.new()
	config.set_value("songs", "directories", _song_directories)
	config.set_value("display", "fullscreen", _fullscreen_enabled)
	config.set_value("gameplay", "autoplay", _autoplay_enabled)
	config.set_value("gameplay", "autosound", _autosound_enabled)
	config.set_value("gameplay", "audio_latency_ms", _audio_latency_ms)
	config.set_value("gameplay", "display_latency_ms", _display_latency_ms)
	config.set_value("gameplay", "master_volume", _master_volume)
	config.set_value("gameplay", "key_volume", _key_volume)
	config.set_value("gameplay", "bgm_volume", _bgm_volume)
	config.set_value("gameplay", "haste_mode", _haste_mode_enabled)
	config.set_value("gameplay", "haste_mode_normalize_speed", _haste_mode_normalize_speed)
	config.set_value("gameplay", "start_paused", _start_paused_enabled)
	config.set_value("gameplay", "channel_modifier", _channel_modifier)
	config.set_value("gameplay", "speed_type", _speed_type)
	config.set_value("gameplay", "speed_multiplier", _speed_multiplier)
	config.set_value("gameplay", "visibility_modifier", _visibility_modifier)
	config.set_value("gameplay", "judgment_type", _judgment_type)
	config.set_value("input", "key_bindings", _key_bindings)
	return config.save(path) == OK


func load_from_file(path: String) -> bool:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return false

	set_song_directories(_string_array_value(config.get_value("songs", "directories", song_directories()), song_directories()))
	set_fullscreen_enabled(_bool_value(config.get_value("display", "fullscreen", _fullscreen_enabled), _fullscreen_enabled))
	set_autoplay_enabled(_bool_value(config.get_value("gameplay", "autoplay", _autoplay_enabled), _autoplay_enabled))
	set_autosound_enabled(_bool_value(config.get_value("gameplay", "autosound", _autosound_enabled), _autosound_enabled))
	set_audio_latency_ms(_float_value(config.get_value("gameplay", "audio_latency_ms", _audio_latency_ms), _audio_latency_ms))
	set_display_latency_ms(_float_value(config.get_value("gameplay", "display_latency_ms", _display_latency_ms), _display_latency_ms))
	set_master_volume(_float_value(config.get_value("gameplay", "master_volume", _master_volume), _master_volume))
	set_key_volume(_float_value(config.get_value("gameplay", "key_volume", _key_volume), _key_volume))
	set_bgm_volume(_float_value(config.get_value("gameplay", "bgm_volume", _bgm_volume), _bgm_volume))
	set_haste_mode_enabled(_bool_value(config.get_value("gameplay", "haste_mode", _haste_mode_enabled), _haste_mode_enabled))
	set_haste_mode_normalize_speed(_bool_value(config.get_value("gameplay", "haste_mode_normalize_speed", _haste_mode_normalize_speed), _haste_mode_normalize_speed))
	set_start_paused_enabled(_bool_value(config.get_value("gameplay", "start_paused", _start_paused_enabled), _start_paused_enabled))
	set_channel_modifier(_string_value(config.get_value("gameplay", "channel_modifier", _channel_modifier), _channel_modifier))
	set_speed_type(_string_value(config.get_value("gameplay", "speed_type", _speed_type), _speed_type))
	set_speed_multiplier(_float_value(config.get_value("gameplay", "speed_multiplier", _speed_multiplier), _speed_multiplier))
	set_visibility_modifier(_string_value(config.get_value("gameplay", "visibility_modifier", _visibility_modifier), _visibility_modifier))
	set_judgment_type(_string_value(config.get_value("gameplay", "judgment_type", _judgment_type), _judgment_type))
	set_key_bindings(_string_array_value(config.get_value("input", "key_bindings", key_bindings()), key_bindings()))
	return true


func _clamped_volume(volume: float) -> float:
	return clampf(volume, 0.0, 1.0)


func _string_array_value(value: Variant, fallback: Array[String]) -> Array[String]:
	if not value is Array:
		return fallback.duplicate()
	var result: Array[String] = []
	for item: Variant in value:
		result.append(str(item))
	return result


func _bool_value(value: Variant, fallback: bool) -> bool:
	if value is bool:
		return value
	return fallback


func _float_value(value: Variant, fallback: float) -> float:
	if value is int or value is float:
		return float(value)
	return fallback


func _string_value(value: Variant, fallback: String) -> String:
	if value is String:
		return str(value)
	return fallback
