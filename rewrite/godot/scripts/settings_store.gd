extends RefCounted

const Wire = preload("res://scripts/native_json.gd")
const InputMapStore = preload("res://scripts/input_map_store.gd")
const SettingsI18n = preload("res://scripts/settings_i18n.gd")

const CHANNEL_MOD_NONE: String = "None"
const CHANNEL_MODIFIERS: Array[String] = ["None", "Mirror", "Shuffle", "Random"]
const SPEED_TYPE_DEFAULT: String = "HiSpeed"
const SPEED_TYPES: Array[String] = ["HiSpeed", "xRSpeed", "WSpeed", "RegulSpeed"]
const VISIBILITY_MOD_NONE: String = "None"
const VISIBILITY_MODIFIERS: Array[String] = ["None", "Hidden", "Sudden", "Dark"]
const JUDGMENT_TYPE_DEFAULT: String = "beat"
const JUDGMENT_TYPES: Array[String] = ["beat", "time"]
const AUTOSYNC_MODE_NONE: String = ""
const AUTOSYNC_MODE_DISPLAY: String = "display"
const AUTOSYNC_MODE_AUDIO: String = "audio"
const AUTOSYNC_MODES: Array[String] = [AUTOSYNC_MODE_NONE, AUTOSYNC_MODE_DISPLAY, AUTOSYNC_MODE_AUDIO]
const SETTINGS_LANGUAGE_EN: String = SettingsI18n.LANGUAGE_EN
const SETTINGS_LANGUAGE_ZH: String = SettingsI18n.LANGUAGE_ZH
const SETTINGS_LANGUAGES: Array[String] = SettingsI18n.LANGUAGE_ORDER

var _song_directories: Array[String] = []
var _library_root_ids: Dictionary = {}
var _library_identity_valid := true
var _settings_language: String = SETTINGS_LANGUAGE_EN
var _fullscreen_enabled: bool = false
var _vsync_enabled: bool = true
var _autoplay_enabled: bool = false
var _autosound_enabled: bool = false
var _audio_latency_ms: float = 0.0
var _display_latency_ms: float = 0.0
var _autosync_mode: String = AUTOSYNC_MODE_NONE
var _master_volume: float = 1.0
var _key_volume: float = 1.0
var _bgm_volume: float = 1.0
var _haste_mode_enabled: bool = false
var _haste_mode_normalize_speed: bool = true
var _start_paused_enabled: bool = false
var _key_bindings: Array[String] = []
var _misc_key_bindings: Dictionary = InputMapStore.DEFAULT_MISC_KEY_BINDINGS.duplicate(true)
var _channel_modifier: String = CHANNEL_MOD_NONE
var _speed_type: String = SPEED_TYPE_DEFAULT
var _speed_multiplier: float = 1.0
var _visibility_modifier: String = VISIBILITY_MOD_NONE
var _judgment_type: String = JUDGMENT_TYPE_DEFAULT


func set_song_directories(paths: Array[String]) -> void:
	_song_directories = paths.duplicate()
	for root: String in _library_root_ids.keys():
		if not paths.has(root):
			_library_root_ids.erase(root)


func persist_library_root_ids(settings_path: String) -> Dictionary:
	if not _ensure_library_root_ids() or not save_to_file(settings_path):
		return {}
	return _library_root_ids.duplicate()


func _ensure_library_root_ids() -> bool:
	if not _library_identity_valid:
		return false
	var next := {}
	var seen := {}
	for root: String in _song_directories:
		if not root.is_absolute_path() or next.has(root):
			return false
		var token: String = _library_root_ids.get(root, "")
		if token.is_empty():
			var bytes := Crypto.new().generate_random_bytes(32)
			if bytes.size() != 32:
				return false
			token = "library:" + Wire.sha256(bytes)
		if seen.has(token):
			return false
		seen[token] = true
		next[root] = token
	_library_root_ids = next
	return true


func song_directories() -> Array[String]:
	return _song_directories.duplicate()


func set_settings_language(language: String) -> void:
	if SettingsI18n.is_supported_language(language):
		_settings_language = language
	else:
		_settings_language = SETTINGS_LANGUAGE_EN


func settings_language() -> String:
	return _settings_language


func set_fullscreen_enabled(enabled: bool) -> void:
	_fullscreen_enabled = enabled


func fullscreen_enabled() -> bool:
	return _fullscreen_enabled


func set_vsync_enabled(enabled: bool) -> void:
	_vsync_enabled = enabled


func vsync_enabled() -> bool:
	return _vsync_enabled


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


func set_autosync_mode(mode: String) -> void:
	if AUTOSYNC_MODES.has(mode):
		_autosync_mode = mode
	else:
		_autosync_mode = AUTOSYNC_MODE_NONE


func autosync_mode() -> String:
	return _autosync_mode


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


func set_misc_key_bindings(bindings: Dictionary) -> bool:
	var next_bindings := _misc_key_bindings.duplicate(true)
	for action: Variant in bindings.keys():
		if not action is String:
			return false
		var action_name := str(action)
		if not InputMapStore.DEFAULT_MISC_KEY_BINDINGS.has(action_name):
			return false
		var binding: Variant = bindings[action]
		if not binding is String:
			return false
		var key := str(binding).strip_edges()
		if key.is_empty():
			return false
		next_bindings[action_name] = key

	_misc_key_bindings = next_bindings
	return true


func misc_key_bindings() -> Dictionary:
	return _misc_key_bindings.duplicate(true)


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
	if not _library_identity_valid or (not _library_root_ids.is_empty() and not _ensure_library_root_ids()):
		return false
	var config := ConfigFile.new()
	config.set_value("ui", "settings_language", _settings_language)
	config.set_value("songs", "directories", _song_directories)
	if not _library_root_ids.is_empty():
		config.set_value("songs", "root_ids", _library_root_ids)
	config.set_value("display", "fullscreen", _fullscreen_enabled)
	config.set_value("display", "vsync", _vsync_enabled)
	config.set_value("gameplay", "autoplay", _autoplay_enabled)
	config.set_value("gameplay", "autosound", _autosound_enabled)
	config.set_value("gameplay", "audio_latency_ms", _audio_latency_ms)
	config.set_value("gameplay", "display_latency_ms", _display_latency_ms)
	config.set_value("gameplay", "autosync_mode", _autosync_mode)
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
	config.set_value("input", "misc_key_bindings", _misc_key_bindings)
	var error := config.save(path)
	if error != OK:
		push_error("Unable to save settings to %s: %s" % [path, error])
	return error == OK


func load_from_file(path: String) -> bool:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return false

	set_settings_language(_string_value(config.get_value("ui", "settings_language", _settings_language), _settings_language))
	set_song_directories(_string_array_value(config.get_value("songs", "directories", song_directories()), song_directories()))
	_library_root_ids.clear()
	_library_identity_valid = true
	if config.has_section_key("songs", "root_ids"):
		var stored: Variant = config.get_value("songs", "root_ids")
		var seen := {}
		_library_identity_valid = stored is Dictionary and stored.size() == _song_directories.size()
		if _library_identity_valid:
			for root: Variant in stored:
				if not root is String or not _song_directories.has(root) or not Wire.identifier(stored[root], "library:sha256:") or seen.has(stored[root]):
					_library_identity_valid = false
					break
				seen[stored[root]] = true
		if _library_identity_valid:
			_library_root_ids = stored.duplicate()
	set_fullscreen_enabled(_bool_value(config.get_value("display", "fullscreen", _fullscreen_enabled), _fullscreen_enabled))
	set_vsync_enabled(_bool_value(config.get_value("display", "vsync", _vsync_enabled), _vsync_enabled))
	set_autoplay_enabled(_bool_value(config.get_value("gameplay", "autoplay", _autoplay_enabled), _autoplay_enabled))
	set_autosound_enabled(_bool_value(config.get_value("gameplay", "autosound", _autosound_enabled), _autosound_enabled))
	set_audio_latency_ms(_float_value(config.get_value("gameplay", "audio_latency_ms", _audio_latency_ms), _audio_latency_ms))
	set_display_latency_ms(_float_value(config.get_value("gameplay", "display_latency_ms", _display_latency_ms), _display_latency_ms))
	set_autosync_mode(_string_value(config.get_value("gameplay", "autosync_mode", _autosync_mode), _autosync_mode))
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
	set_misc_key_bindings(_string_dictionary_value(config.get_value("input", "misc_key_bindings", misc_key_bindings()), misc_key_bindings()))
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


func _string_dictionary_value(value: Variant, fallback: Dictionary) -> Dictionary:
	if not value is Dictionary:
		return fallback.duplicate(true)
	var result := {}
	for key: Variant in value.keys():
		result[str(key)] = str(value[key])
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
