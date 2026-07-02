extends Control

const AppState = preload("res://scripts/app_state.gd")
const AudioManifestLoader = preload("res://scripts/audio_manifest_loader.gd")
const AudioPlayerPool = preload("res://scripts/audio_player_pool.gd")
const CatalogStore = preload("res://scripts/catalog_store.gd")
const ExporterClient = preload("res://scripts/exporter_client.gd")
const GameplayLoader = preload("res://scripts/gameplay_loader.gd")
const GameplayRuntime = preload("res://scripts/gameplay_runtime.gd")
const GameplayView = preload("res://scripts/gameplay_view.gd")
const InputMapStore = preload("res://scripts/input_map_store.gd")
const PartytimeServer = preload("res://scripts/partytime_server.gd")
const RenderEntityModel = preload("res://scripts/render_entity_model.gd")
const ResultModel = preload("res://scripts/result_model.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const SettingsI18n = preload("res://scripts/settings_i18n.gd")

const DEFAULT_KEY_BINDINGS: Array[String] = ["S", "D", "F", "Space", "J", "K", "L"]
const MISC_KEY_ACTIONS: Array[String] = [
	InputMapStore.ACTION_SPEED_UP,
	InputMapStore.ACTION_SPEED_DOWN,
	InputMapStore.ACTION_MAIN_VOLUME_UP,
	InputMapStore.ACTION_MAIN_VOLUME_DOWN,
	InputMapStore.ACTION_KEY_VOLUME_UP,
	InputMapStore.ACTION_KEY_VOLUME_DOWN,
	InputMapStore.ACTION_BGM_VOLUME_UP,
	InputMapStore.ACTION_BGM_VOLUME_DOWN,
]
const CHANNEL_MODIFIERS: Array[String] = ["None", "Mirror", "Shuffle", "Random"]
const SPEED_TYPES: Array[String] = ["HiSpeed", "xRSpeed", "WSpeed", "RegulSpeed"]
const VISIBILITY_MODIFIERS: Array[String] = ["None", "Hidden", "Sudden", "Dark"]
const JUDGMENT_TYPES: Array[String] = ["beat", "time"]
const AUTOSYNC_MODES: Array[String] = ["", "display", "audio"]
const JAVA_MIN_LOADING_SCREEN_MS: float = 300.0
const LOADING_AUDIO_PRELOADS_PER_FRAME: int = 1
const AUTOSYNC_MODE_LABEL_KEYS: Dictionary = {
	"": "settings.option.autosync.off",
	"display": "settings.option.autosync.display",
	"audio": "settings.option.autosync.audio",
}
const CHANNEL_MODIFIER_LABEL_KEYS: Dictionary = {
	"None": "settings.option.channel.none",
	"Mirror": "settings.option.channel.mirror",
	"Shuffle": "settings.option.channel.shuffle",
	"Random": "settings.option.channel.random",
}
const SPEED_TYPE_LABEL_KEYS: Dictionary = {
	"HiSpeed": "settings.option.speed.hispeed",
	"xRSpeed": "settings.option.speed.xrspeed",
	"WSpeed": "settings.option.speed.wspeed",
	"RegulSpeed": "settings.option.speed.regulspeed",
}
const VISIBILITY_MODIFIER_LABEL_KEYS: Dictionary = {
	"None": "settings.option.visibility.none",
	"Hidden": "settings.option.visibility.hidden",
	"Sudden": "settings.option.visibility.sudden",
	"Dark": "settings.option.visibility.dark",
}
const JUDGMENT_TYPE_LABEL_KEYS: Dictionary = {
	"beat": "settings.option.judgment.beat",
	"time": "settings.option.judgment.time",
}
const AUTOSYNC_MODE_VALUE_DESCRIPTION_KEYS: Dictionary = {
	"": "settings.option.autosync.off.description",
	"display": "settings.option.autosync.display.description",
	"audio": "settings.option.autosync.audio.description",
}
const CHANNEL_MODIFIER_VALUE_DESCRIPTION_KEYS: Dictionary = {
	"None": "settings.option.channel.none.description",
	"Mirror": "settings.option.channel.mirror.description",
	"Shuffle": "settings.option.channel.shuffle.description",
	"Random": "settings.option.channel.random.description",
}
const SPEED_TYPE_VALUE_DESCRIPTION_KEYS: Dictionary = {
	"HiSpeed": "settings.option.speed.hispeed.description",
	"xRSpeed": "settings.option.speed.xrspeed.description",
	"WSpeed": "settings.option.speed.wspeed.description",
	"RegulSpeed": "settings.option.speed.regulspeed.description",
}
const VISIBILITY_MODIFIER_VALUE_DESCRIPTION_KEYS: Dictionary = {
	"None": "settings.option.visibility.none.description",
	"Hidden": "settings.option.visibility.hidden.description",
	"Sudden": "settings.option.visibility.sudden.description",
	"Dark": "settings.option.visibility.dark.description",
}
const JUDGMENT_TYPE_VALUE_DESCRIPTION_KEYS: Dictionary = {
	"beat": "settings.option.judgment.beat.description",
	"time": "settings.option.judgment.time.description",
}
const MISC_KEY_DESCRIPTIONS: Dictionary = {
	InputMapStore.ACTION_SPEED_UP: "During gameplay, raises note scroll speed by 0.5.",
	InputMapStore.ACTION_SPEED_DOWN: "During gameplay, lowers note scroll speed by 0.5.",
	InputMapStore.ACTION_MAIN_VOLUME_UP: "During gameplay, raises master volume by 0.05.",
	InputMapStore.ACTION_MAIN_VOLUME_DOWN: "During gameplay, lowers master volume by 0.05.",
	InputMapStore.ACTION_KEY_VOLUME_UP: "During gameplay, raises keysound volume by 0.05.",
	InputMapStore.ACTION_KEY_VOLUME_DOWN: "During gameplay, lowers keysound volume by 0.05.",
	InputMapStore.ACTION_BGM_VOLUME_UP: "During gameplay, raises background music volume by 0.05.",
	InputMapStore.ACTION_BGM_VOLUME_DOWN: "During gameplay, lowers background music volume by 0.05.",
}
const DEFAULT_SETTINGS_PATH: String = "user://settings.cfg"
const DEFAULT_WINDOW_TITLE: String = "Open2Jam Rewrite"

var _built: bool = false
var _app_state = AppState.new()
var _song_entries: Array[Dictionary] = []
var _song_entries_directories: Array[String] = []
var _song_entries_from_settings: bool = false
var _song_catalog_error: String = ""
var _song_filter_text: String = ""
var _selected_entry: Dictionary = {}
var _last_result: Dictionary = {}
var _content: VBoxContainer = null
var _menu: HBoxContainer = null
var _title_label: Label = null
var _subtitle_label: Label = null
var _status_label: Label = null
var _loading_status_label: Label = null
var _start_button: Button = null
var _settings_button: Button = null
var _layout_buttons: Array[Button] = []
var _runtime: Node = null
var _gameplay_area: Control = null
var _gameplay_view: Control = null
var _exporter_client = ExporterClient.new()
var _settings_store = SettingsStore.new()
var _last_requested_window_mode: int = -1
var _last_requested_vsync_mode: int = -1
var _last_requested_window_title: String = ""
var _settings_path: String = DEFAULT_SETTINGS_PATH
var _loading_elapsed_ms: float = 0.0
var _loading_pending_gameplay: bool = false
var _gameplay_paused: bool = false
var _pause_menu: CanvasLayer = null
var _capturing_key_button: Button = null
var _capturing_key_previous_text: String = ""
var _loading_audio_pool: Node = null
var _selected_export_job: Variant = null
var _partytime_server = null


func _ready() -> void:
	build()


func _exit_tree() -> void:
	_wait_for_selected_export_job()
	_discard_loading_audio_pool()


func _process(delta: float) -> void:
	if _loading_pending_gameplay:
		_advance_loading(delta)
		return
	if _runtime == null or _gameplay_view == null:
		return
	if _gameplay_paused:
		return
	if _runtime.has_method("advance_to") and _runtime.has_method("elapsed_ms"):
		_runtime.advance_to(float(_runtime.elapsed_ms()) + delta * 1000.0)
		if _runtime == null or _gameplay_view == null:
			return

	var state: Dictionary = {}
	if _runtime.has_method("hud_state"):
		state = _runtime.hud_state()

	var view_time_ms := 0.0
	if _runtime.has_method("display_time_ms"):
		view_time_ms = float(_runtime.display_time_ms())
	elif state.has("displayTimeMs"):
		view_time_ms = float(state.get("displayTimeMs", 0.0))
	elif _runtime.has_method("elapsed_ms"):
		view_time_ms = float(_runtime.elapsed_ms())

	if _gameplay_view.has_method("update_frame") and not state.is_empty():
		_gameplay_view.update_frame(view_time_ms, state)
		return
	if _gameplay_view.has_method("update_hud_state") and not state.is_empty():
		_gameplay_view.update_hud_state(state)
	if _gameplay_view.has_method("update_time"):
		_gameplay_view.update_time(view_time_ms)


func _unhandled_input(event: InputEvent) -> void:
	if _app_state.current() != AppState.GAMEPLAY:
		return
	if not _is_escape_pressed(event):
		return
	if _gameplay_paused:
		_resume_gameplay()
	else:
		_pause_gameplay()
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _is_escape_pressed(event: InputEvent) -> bool:
	if event is InputEventKey and event.echo:
		return false
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		return true
	return event.is_action_pressed("ui_cancel")


func build() -> void:
	if _built:
		return
	_built = true
	_configure_exporter_from_environment()
	_load_settings_from_file()
	resized.connect(_on_resized)

	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.015, 0.018, 0.026, 1.0)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_content)

	_app_state.transition_to(AppState.MAIN_MENU)
	_show_main_menu()
	apply_layout_for_size(_layout_size())


func current_state() -> String:
	return _app_state.current()


func set_song_entries(entries: Array) -> void:
	_song_entries.clear()
	_song_entries_directories.clear()
	_song_entries_from_settings = false
	_song_catalog_error = ""
	for entry: Variant in entries:
		if entry is Dictionary:
			_song_entries.append(entry.duplicate(true))
	if _app_state.current() == AppState.SONG_SELECT:
		_show_song_select()


func set_exporter_client(exporter: Variant) -> void:
	_exporter_client = exporter


func configure_exporter(java_path: String, jar_path: String) -> void:
	_exporter_client.configure(java_path, jar_path)


func is_exporter_configured() -> bool:
	if _exporter_client == null or not _exporter_client.has_method("is_configured"):
		return false
	return _exporter_client.is_configured()


func set_settings_path(path: String) -> void:
	if not path.strip_edges().is_empty():
		_settings_path = path


func last_requested_window_mode() -> int:
	return _last_requested_window_mode


func last_requested_vsync_mode() -> int:
	return _last_requested_vsync_mode


func last_requested_window_title() -> String:
	return _last_requested_window_title


func complete_game(result: Dictionary) -> void:
	_last_result = result.duplicate(true)
	_apply_autosync_result(_last_result)
	if _app_state.current() == AppState.GAMEPLAY and _app_state.transition_to(AppState.RESULT):
		_show_result()


func _show_main_menu() -> void:
	_clear_content()
	_apply_window_title(DEFAULT_WINDOW_TITLE)

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.text = "Open2Jam"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.name = "Subtitle"
	_subtitle_label.text = "Godot runtime"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_subtitle_label)

	_menu = HBoxContainer.new()
	_menu.name = "Menu"
	_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(_menu)

	_start_button = Button.new()
	_start_button.name = "StartButton"
	_start_button.text = "Start"
	_start_button.pressed.connect(_on_start_pressed)
	_menu.add_child(_start_button)
	_layout_buttons.append(_start_button)

	_settings_button = Button.new()
	_settings_button.name = "SettingsButton"
	_settings_button.text = "Settings"
	_settings_button.pressed.connect(_on_settings_pressed)
	_menu.add_child(_settings_button)
	_layout_buttons.append(_settings_button)

	_status_label = Label.new()
	_status_label.name = "Status"
	_status_label.text = "Ready"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_status_label)

	apply_layout_for_size(_layout_size())


func apply_layout_for_size(viewport_size: Vector2) -> void:
	var short_edge: float = min(viewport_size.x, viewport_size.y)
	var long_edge: float = max(viewport_size.x, viewport_size.y)
	var content_margin: float = clamp(short_edge * 0.08, 48.0, 144.0)
	var vertical_margin: float = clamp(short_edge * 0.07, 40.0, 128.0)
	var title_size: int = int(round(clamp(short_edge * 0.075, 42.0, 104.0)))
	var subtitle_size: int = int(round(clamp(short_edge * 0.03, 18.0, 42.0)))
	var status_size: int = int(round(clamp(short_edge * 0.026, 16.0, 34.0)))
	var button_size := Vector2(
			clamp(long_edge * 0.14, 160.0, 360.0),
			clamp(short_edge * 0.075, 48.0, 96.0))
	var content_separation: int = int(round(clamp(short_edge * 0.035, 20.0, 56.0)))
	var menu_separation: int = int(round(clamp(long_edge * 0.018, 16.0, 48.0)))

	if _content != null:
		if (_app_state.current() == AppState.GAMEPLAY and _gameplay_view != null) \
				or (_app_state.current() == AppState.LOADING and _content_node_or_null("LoadingImage") != null):
			_content.offset_left = 0.0
			_content.offset_top = 0.0
			_content.offset_right = 0.0
			_content.offset_bottom = 0.0
			_content.add_theme_constant_override("separation", 0)
			_apply_gameplay_layout(viewport_size)
		else:
			_content.offset_left = content_margin
			_content.offset_top = vertical_margin
			_content.offset_right = -content_margin
			_content.offset_bottom = -vertical_margin
			_content.add_theme_constant_override("separation", content_separation)
	if _menu != null:
		_menu.add_theme_constant_override("separation", menu_separation)
	if _title_label != null:
		_title_label.add_theme_font_size_override("font_size", title_size)
	if _subtitle_label != null:
		_subtitle_label.add_theme_font_size_override("font_size", subtitle_size)
	if _status_label != null:
		_status_label.add_theme_font_size_override("font_size", status_size)
	if _loading_status_label != null:
		_loading_status_label.add_theme_font_size_override("font_size", status_size)
	if _pause_menu != null:
		_apply_pause_menu_layout(viewport_size)
	for button: Button in _layout_buttons:
		button.custom_minimum_size = button_size


func _on_start_pressed() -> void:
	_refresh_song_entries_from_settings(true)
	if _app_state.transition_to(AppState.SONG_SELECT):
		_show_song_select()


func _on_settings_pressed() -> void:
	if _app_state.transition_to(AppState.SETTINGS):
		_show_settings()


func _show_settings() -> void:
	_clear_content()
	_apply_window_title(DEFAULT_WINDOW_TITLE)
	_content.alignment = BoxContainer.ALIGNMENT_BEGIN

	_title_label = _label("Title", _settings_text("Settings"), HORIZONTAL_ALIGNMENT_CENTER)
	_content.add_child(_title_label)

	var help := _setting_description("SettingsHelp",
			"Game setup, audio, display, and controls.")
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(help)

	var scroll := ScrollContainer.new()
	scroll.name = "SettingsScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(scroll)

	var form := VBoxContainer.new()
	form.name = "SettingsForm"
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 16)
	scroll.add_child(form)

	_add_settings_section(form, "Language", "Language", "Settings page language. This affects Settings only and does not change gameplay.")
	var settings_language := OptionButton.new()
	settings_language.name = "SettingsLanguageOption"
	for language: String in SettingsI18n.supported_languages():
		settings_language.add_item(SettingsI18n.language_label(language))
	settings_language.select(_settings_language_index(_settings_store.settings_language()))
	settings_language.item_selected.connect(_on_settings_language_selected.bind(settings_language))
	_add_setting_row(form, "Settings language",
			"Changes labels and descriptions on this Settings page only.",
			settings_language)

	_add_settings_section(form, "Songs", "Song library", "Folders that contain VOS, OJN/OJM, osu!mania 7K, or exported song bundles.")
	var directory_selector := HBoxContainer.new()
	directory_selector.name = "SongDirectorySelector"
	directory_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	directory_selector.add_theme_constant_override("separation", 8)

	var directory_display := LineEdit.new()
	directory_display.name = "SongDirectoryDisplay"
	directory_display.placeholder_text = _settings_text("No folder selected")
	directory_display.text = _song_directories_text()
	directory_display.editable = false
	directory_display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	directory_selector.add_child(directory_display)

	var directory_browse := Button.new()
	directory_browse.name = "SongDirectoryBrowseButton"
	directory_browse.text = _settings_text("Browse...")
	directory_browse.custom_minimum_size = Vector2(116.0, 44.0)
	directory_browse.pressed.connect(_on_song_directory_browse_pressed)
	directory_selector.add_child(directory_browse)
	_add_setting_row(form, "Song directory", "Folder scanned when Start is pressed. Choose a directory with the browser so the path is stored exactly as selected.", directory_selector)

	var directory_dialog := FileDialog.new()
	directory_dialog.name = "SongDirectoryDialog"
	directory_dialog.title = _settings_text("Select song directory")
	directory_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	directory_dialog.access = FileDialog.ACCESS_FILESYSTEM
	directory_dialog.dir_selected.connect(_on_song_directory_selected)
	_content.add_child(directory_dialog)

	_add_settings_section(form, "Display", "Display", "Fullscreen behavior and screen mode.")
	var fullscreen := CheckBox.new()
	fullscreen.name = "FullscreenCheckBox"
	fullscreen.text = _settings_text("Use fullscreen mode")
	fullscreen.button_pressed = _settings_store.fullscreen_enabled()
	_add_setting_row(form, "Fullscreen", "When enabled, returning from Settings requests fullscreen mode for the game window.", fullscreen)

	var vsync := CheckBox.new()
	vsync.name = "VSyncCheckBox"
	vsync.text = _settings_text("Use VSync")
	vsync.button_pressed = _settings_store.vsync_enabled()
	_add_setting_row(form, "VSync", "Synchronizes frame presentation with the display refresh, matching Java's launch-time VSync option.", vsync)

	_add_settings_section(form, "Playback", "Playback assists", "Testing assists that can play charts without manual input.")
	var autoplay := CheckBox.new()
	autoplay.name = "AutoplayCheckBox"
	autoplay.text = _settings_text("Auto-hit lane notes")
	autoplay.button_pressed = _settings_store.autoplay_enabled()
	_add_setting_row(form, "Autoplay", "Automatically judges lane notes as hits. Use this for visual or audio checks, not normal play.", autoplay)

	var autosound := CheckBox.new()
	autosound.name = "AutoSoundCheckBox"
	autosound.text = _settings_text("Play keysounds automatically")
	autosound.button_pressed = _settings_store.autosound_enabled()
	_add_setting_row(form, "AutoSound", "Plays note keysounds at chart timing even without key presses. Disable it for manual keysound-only play.", autosound)

	var start_paused := CheckBox.new()
	start_paused.name = "StartPausedCheckBox"
	start_paused.text = _settings_text("Wait for first lane key")
	start_paused.button_pressed = _settings_store.start_paused_enabled()
	_add_setting_row(form, "Start paused", "Keeps chart time at zero until the first lane key is pressed.", start_paused)

	var local_matching_server := LineEdit.new()
	local_matching_server.name = "LocalMatchingServerInput"
	local_matching_server.placeholder_text = _settings_text("host:port")
	local_matching_server.text = _settings_store.local_matching_server()
	local_matching_server.clear_button_enabled = true
	_add_setting_row(form, "Local matching server",
			"Optional Java partytime host:port. When valid, gameplay waits for matching readiness instead of first-key start.",
			local_matching_server)

	var create_server := Button.new()
	create_server.name = "CreatePartytimeServerButton"
	create_server.text = _settings_text("Create server")
	create_server.custom_minimum_size = Vector2(144.0, 44.0)
	create_server.pressed.connect(_on_create_partytime_server_pressed)
	_add_setting_row(form, "Create server",
			"Starts a Java-compatible partytime server on the port from Local matching server, or 7273 when the field is empty.",
			create_server)

	_add_settings_section(form, "Timing", "Timing", "Millisecond offsets used to align input judgment, note drawing, and audio playback.")
	var audio_latency := SpinBox.new()
	audio_latency.name = "AudioLatencySpinBox"
	audio_latency.min_value = -60000.0
	audio_latency.max_value = 60000.0
	audio_latency.step = 0.001
	audio_latency.value = _settings_store.audio_latency_ms()
	_add_setting_row(form, "Audio latency", "Global audio and judgment offset in milliseconds. Positive values judge notes later; negative values judge earlier.", audio_latency)

	var display_latency := SpinBox.new()
	display_latency.name = "DisplayLatencySpinBox"
	display_latency.min_value = -60000.0
	display_latency.max_value = 60000.0
	display_latency.step = 0.001
	display_latency.value = _settings_store.display_latency_ms()
	_add_setting_row(form, "Display latency", "Visual offset in milliseconds applied after audio latency. Positive values draw notes later; negative values draw earlier.", display_latency)

	var autosync_mode := OptionButton.new()
	autosync_mode.name = "AutosyncModeOption"
	_populate_option_button(autosync_mode, AUTOSYNC_MODES,
			AUTOSYNC_MODE_LABEL_KEYS, _settings_store.autosync_mode())
	_add_option_setting_row(form, "Autosync mode",
			"Optional Java autosync mode. It updates one latency value from normal tap judgments while a chart is running.",
			autosync_mode,
			AUTOSYNC_MODE_VALUE_DESCRIPTION_KEYS)

	_add_settings_section(form, "Audio", "Audio", "Volume multipliers for master output, note keysounds, and background music.")
	var master_volume := SpinBox.new()
	master_volume.name = "MasterVolumeSpinBox"
	master_volume.min_value = 0.0
	master_volume.max_value = 1.0
	master_volume.step = 0.05
	master_volume.value = _settings_store.master_volume()
	_add_setting_row(form, "Master volume", "Master gain from 0.00 to 1.00 applied to every audio channel.", master_volume)

	var key_volume := SpinBox.new()
	key_volume.name = "KeyVolumeSpinBox"
	key_volume.min_value = 0.0
	key_volume.max_value = 1.0
	key_volume.step = 0.05
	key_volume.value = _settings_store.key_volume()
	_add_setting_row(form, "Key volume", "Keysound gain from 0.00 to 1.00 applied to note samples.", key_volume)

	var bgm_volume := SpinBox.new()
	bgm_volume.name = "BgmVolumeSpinBox"
	bgm_volume.min_value = 0.0
	bgm_volume.max_value = 1.0
	bgm_volume.step = 0.05
	bgm_volume.value = _settings_store.bgm_volume()
	_add_setting_row(form, "BGM volume", "Background music gain from 0.00 to 1.00 applied to BGM samples.", bgm_volume)

	_add_settings_section(form, "Modifiers", "Modifiers", "Optional gameplay rules that alter lanes, scroll distance, visibility, or judgment windows.")
	var haste_mode := CheckBox.new()
	haste_mode.name = "HasteModeCheckBox"
	haste_mode.text = _settings_text("Enable haste speed changes")
	haste_mode.button_pressed = _settings_store.haste_mode_enabled()
	_add_setting_row(form, "Haste mode", "Enables Java-style haste: chart speed and audio pitch change over time.", haste_mode)

	var haste_normalize := CheckBox.new()
	haste_normalize.name = "HasteNormalizeSpeedCheckBox"
	haste_normalize.text = _settings_text("Keep scroll distance stable")
	haste_normalize.button_pressed = _settings_store.haste_mode_normalize_speed()
	_add_setting_row(form, "Haste normalize speed", "Keeps note travel distance stable while haste changes pitch. Disable it to let scroll speed change with haste.", haste_normalize)

	var channel_modifier := OptionButton.new()
	channel_modifier.name = "ChannelModifierOption"
	_populate_option_button(channel_modifier, CHANNEL_MODIFIERS,
			CHANNEL_MODIFIER_LABEL_KEYS, _settings_store.channel_modifier())
	_add_option_setting_row(form, "Channel modifier",
			"Lane remap before play: None keeps lanes, Mirror reverses lanes, Shuffle picks one chart-wide map, Random changes by measure while preserving held lanes.",
			channel_modifier,
			CHANNEL_MODIFIER_VALUE_DESCRIPTION_KEYS)

	var speed_type := OptionButton.new()
	speed_type.name = "SpeedTypeOption"
	_populate_option_button(speed_type, SPEED_TYPES,
			SPEED_TYPE_LABEL_KEYS, _settings_store.speed_type())
	_add_option_setting_row(form, "Speed type",
			"Scroll math mode: HiSpeed follows BPM, xRSpeed varies each lane, WSpeed waves over time, RegulSpeed uses a fixed 150 BPM baseline.",
			speed_type,
			SPEED_TYPE_VALUE_DESCRIPTION_KEYS)

	var speed_multiplier := SpinBox.new()
	speed_multiplier.name = "SpeedMultiplierSpinBox"
	speed_multiplier.min_value = 0.5
	speed_multiplier.max_value = 10.0
	speed_multiplier.step = 0.5
	speed_multiplier.value = _settings_store.speed_multiplier()
	_add_setting_row(form, "Speed multiplier", "Base scroll multiplier from 0.5 to 10.0. Higher values move notes faster toward the judgment line.", speed_multiplier)

	var visibility_modifier := OptionButton.new()
	visibility_modifier.name = "VisibilityModifierOption"
	_populate_option_button(visibility_modifier, VISIBILITY_MODIFIERS,
			VISIBILITY_MODIFIER_LABEL_KEYS, _settings_store.visibility_modifier())
	_add_option_setting_row(form, "Visibility modifier",
			"Lane mask mode: Hidden covers lower lanes, Sudden covers upper lanes, Dark masks both ends, None leaves lanes visible.",
			visibility_modifier,
			VISIBILITY_MODIFIER_VALUE_DESCRIPTION_KEYS)

	var judgment_type := OptionButton.new()
	judgment_type.name = "JudgmentTypeOption"
	_populate_option_button(judgment_type, JUDGMENT_TYPES,
			JUDGMENT_TYPE_LABEL_KEYS, _settings_store.judgment_type())
	_add_option_setting_row(form, "Judgment type",
			"Judgment window mode: beat scales with BPM; time uses fixed millisecond windows.",
			judgment_type,
			JUDGMENT_TYPE_VALUE_DESCRIPTION_KEYS)

	_add_settings_section(form, "Input", "Input", "Keys used for the seven gameplay lanes and in-game adjustment hotkeys.")
	var key_bindings := GridContainer.new()
	key_bindings.name = "KeyBindings"
	key_bindings.columns = DEFAULT_KEY_BINDINGS.size()
	key_bindings.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for i in range(DEFAULT_KEY_BINDINGS.size()):
		var lane_description := _lane_key_description(i)
		var key_group := VBoxContainer.new()
		key_group.name = "KeyBinding%dGroup" % (i + 1)
		key_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key_group.add_theme_constant_override("separation", 4)
		key_group.add_child(_setting_caption("KeyBinding%dLabel" % (i + 1), _lane_key_label(i)))

		var key_input := _key_capture_button(
				"KeyBinding%d" % (i + 1),
				_key_binding_for_settings(i),
				lane_description,
				Vector2(96.0, 44.0))
		key_group.add_child(key_input)
		key_bindings.add_child(key_group)
	_add_setting_row(form, "Lane key bindings", "Seven lane inputs, left to right. Focus a key button, press Enter, then press one keyboard key to bind it.", key_bindings)

	var misc_key_bindings := GridContainer.new()
	misc_key_bindings.name = "MiscKeyBindings"
	misc_key_bindings.columns = 4
	misc_key_bindings.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for action: String in MISC_KEY_ACTIONS:
		var action_description := _misc_key_description(action)
		var action_group := VBoxContainer.new()
		action_group.name = "MiscKey_%sGroup" % action
		action_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_group.add_theme_constant_override("separation", 4)
		action_group.add_child(_setting_caption("MiscKey_%sLabel" % action, _misc_key_label(action)))

		var key_input := _key_capture_button(
				"MiscKey_%s" % action,
				_misc_key_binding_for_settings(action),
				action_description,
				Vector2(128.0, 44.0))
		action_group.add_child(key_input)
		misc_key_bindings.add_child(action_group)
	_add_setting_row(form, "Misc key bindings", "In-game adjustment hotkeys for speed and volume. Focus a key button, press Enter, then press one keyboard key to bind it.", misc_key_bindings)

	var back_button := _button("BackButton", _settings_text("Back"))
	back_button.pressed.connect(_on_settings_back_pressed)
	_content.add_child(back_button)

	apply_layout_for_size(_layout_size())


func _add_settings_section(parent: VBoxContainer, section_name: String, title_text: String, _description_text: String) -> void:
	var section := VBoxContainer.new()
	section.name = "SettingsSection%s" % section_name
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 3)

	var title := _setting_caption("SettingsSection%sTitle" % section_name, title_text)
	title.add_theme_font_size_override("font_size", 16)
	section.add_child(title)
	parent.add_child(section)


func _add_setting_row(parent: VBoxContainer, title_text: String, description_text: String, control: Control) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.name = "%sRow" % control.name
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 3)

	var title := Label.new()
	title.name = "%sLabel" % control.name
	title.text = _settings_text(title_text)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.modulate = Color(0.9, 0.93, 0.98, 1.0)
	title.add_theme_font_size_override("font_size", 15)
	row.add_child(title)

	if not description_text.strip_edges().is_empty():
		row.add_child(_setting_description("%sDescription" % control.name, description_text))

	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.tooltip_text = _settings_text(description_text)
	row.add_child(control)
	parent.add_child(row)
	return row


func _populate_option_button(
		control: OptionButton,
		values: Array[String],
		label_keys: Dictionary,
		selected_value: String) -> void:
	for value: String in values:
		control.add_item(_option_value_label(value, label_keys))
		control.set_item_metadata(control.get_item_count() - 1, value)
	var selected_index := values.find(selected_value)
	control.select(max(selected_index, 0))


func _option_value_label(value: String, label_keys: Dictionary) -> String:
	var key := str(label_keys.get(value, ""))
	return SettingsI18n.text(_settings_store.settings_language(), key, value)


func _add_option_setting_row(
		parent: VBoxContainer,
		title_text: String,
		description_text: String,
		control: OptionButton,
		value_descriptions: Dictionary) -> void:
	var row := _add_setting_row(parent, title_text, description_text, control)
	var value_description := _setting_description("%sValueDescription" % control.name,
			_option_value_description(control, value_descriptions))
	value_description.tooltip_text = value_description.text
	control.item_selected.connect(_on_option_value_selected.bind(control, value_description, value_descriptions))
	row.add_child(value_description)


func _on_option_value_selected(index: int, control: OptionButton, value_description: Label, value_descriptions: Dictionary) -> void:
	value_description.text = _option_value_description_at(control, index, value_descriptions)
	value_description.tooltip_text = value_description.text


func _on_settings_language_selected(index: int, _control: OptionButton) -> void:
	_save_settings_from_controls()
	_settings_store.set_settings_language(_settings_language_for_index(index))
	_save_settings_to_file()
	_show_settings()


func _settings_language_index(language: String) -> int:
	var index := SettingsI18n.supported_languages().find(language)
	return max(index, 0)


func _settings_language_for_index(index: int) -> String:
	var languages := SettingsI18n.supported_languages()
	if index < 0 or index >= languages.size():
		return SettingsI18n.DEFAULT_LANGUAGE
	return languages[index]


func _option_value_description(control: OptionButton, value_descriptions: Dictionary) -> String:
	return _option_value_description_at(control, control.selected, value_descriptions)


func _option_value_description_at(control: OptionButton, index: int, value_descriptions: Dictionary) -> String:
	if index < 0 or index >= control.get_item_count():
		return ""
	var value := _option_value_at(control, index)
	var key := str(value_descriptions.get(value, ""))
	return SettingsI18n.text(_settings_store.settings_language(), key, value)


func _option_value_at(control: OptionButton, index: int) -> String:
	if index < 0 or index >= control.get_item_count():
		return ""
	var metadata: Variant = control.get_item_metadata(index)
	if metadata == null:
		return control.get_item_text(index)
	return str(metadata)


func _selected_option_value(control: OptionButton) -> String:
	return _option_value_at(control, control.selected)


func _option_value_descriptions_text(control: OptionButton, value_descriptions: Dictionary) -> String:
	var descriptions: Array[String] = []
	for index in range(control.get_item_count()):
		descriptions.append(_option_value_description_at(control, index, value_descriptions))
	return "\n".join(descriptions)


func _setting_caption(node_name: String, text: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = _settings_text(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = Color(0.86, 0.9, 0.96, 1.0)
	label.add_theme_font_size_override("font_size", 14)
	return label


func _setting_description(node_name: String, text: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = _settings_text(text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = Color(0.52, 0.58, 0.66, 1.0)
	label.add_theme_font_size_override("font_size", 12)
	return label


func _lane_key_description(index: int) -> String:
	return _settings_format("settings.input.lane_description", [index + 1])


func _lane_key_label(index: int) -> String:
	return _settings_format("settings.input.lane_label", [index + 1])


func _lane_key_placeholder(index: int) -> String:
	return _settings_format("settings.input.lane_placeholder", [index + 1])


func _misc_key_label(action: String) -> String:
	match action:
		InputMapStore.ACTION_SPEED_UP:
			return _settings_text("Speed up")
		InputMapStore.ACTION_SPEED_DOWN:
			return _settings_text("Speed down")
		InputMapStore.ACTION_MAIN_VOLUME_UP:
			return _settings_text("Master volume up")
		InputMapStore.ACTION_MAIN_VOLUME_DOWN:
			return _settings_text("Master volume down")
		InputMapStore.ACTION_KEY_VOLUME_UP:
			return _settings_text("Key volume up")
		InputMapStore.ACTION_KEY_VOLUME_DOWN:
			return _settings_text("Key volume down")
		InputMapStore.ACTION_BGM_VOLUME_UP:
			return _settings_text("BGM volume up")
		InputMapStore.ACTION_BGM_VOLUME_DOWN:
			return _settings_text("BGM volume down")
		_:
			return action


func _misc_key_description(action: String) -> String:
	return _settings_text(str(MISC_KEY_DESCRIPTIONS.get(action, action)))


func _misc_key_placeholder(action: String) -> String:
	return _settings_format("settings.input.misc_placeholder", [_misc_key_label(action)])


func _settings_text(text: String) -> String:
	var key := SettingsI18n.key_for_english(text)
	if key.is_empty():
		return text
	return SettingsI18n.text(_settings_store.settings_language(), key, text)


func _settings_format(key: String, values: Array, fallback: String = "") -> String:
	return SettingsI18n.format(_settings_store.settings_language(), key, values, fallback)


func _on_song_directory_browse_pressed() -> void:
	var dialog: Node = _content_node_or_null("SongDirectoryDialog")
	if not dialog is FileDialog:
		return
	var file_dialog: FileDialog = dialog
	var directories := _settings_store.song_directories()
	if not directories.is_empty():
		file_dialog.current_dir = directories[0]
	if not file_dialog.is_inside_tree():
		file_dialog.visible = true
		return
	file_dialog.popup_centered_ratio(0.8)


func _on_song_directory_selected(directory: String) -> void:
	var selected_directory := directory.strip_edges()
	if selected_directory.is_empty():
		return
	var directories: Array[String] = [selected_directory]
	_settings_store.set_song_directories(directories)
	_song_filter_text = ""
	_selected_entry.clear()
	_song_entries_directories.clear()
	_song_entries_from_settings = false
	_save_settings_to_file()
	_refresh_song_directory_display()


func _refresh_song_directory_display() -> void:
	var display: Node = _content_node_or_null("SongDirectoryDisplay")
	if display is LineEdit:
		display.text = _song_directories_text()


func _on_create_partytime_server_pressed() -> void:
	var local_matching_server: Node = _content_node_or_null("LocalMatchingServerInput")
	var port := 7273
	if local_matching_server is LineEdit:
		var parsed_port := _partytime_server_port_from_text(local_matching_server.text)
		if parsed_port > 0:
			port = parsed_port
		local_matching_server.text = "localhost:%d" % port
		_settings_store.set_local_matching_server(local_matching_server.text)
		_save_settings_to_file()

	if _partytime_server != null and _partytime_server.has_method("stop"):
		_partytime_server.stop()
	_partytime_server = PartytimeServer.new()
	_partytime_server.start(port)


func _partytime_server_port_from_text(text: String) -> int:
	var value := text.strip_edges()
	if value.is_empty():
		return 0
	var parts := value.split(":")
	var port_text := value
	if parts.size() == 2:
		port_text = str(parts[1])
	if not port_text.is_valid_int():
		return 0
	return int(port_text)


func _show_song_select() -> void:
	_clear_content()
	_apply_window_title(DEFAULT_WINDOW_TITLE)
	_content.alignment = BoxContainer.ALIGNMENT_BEGIN

	_title_label = _label("Title", "Song Select", HORIZONTAL_ALIGNMENT_CENTER)
	_content.add_child(_title_label)

	var filter_input := LineEdit.new()
	filter_input.name = "SongFilterInput"
	filter_input.placeholder_text = "Filter songs"
	filter_input.text = _song_filter_text
	filter_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_input.text_changed.connect(_on_song_filter_changed)
	_content.add_child(filter_input)

	if not _song_catalog_error.is_empty():
		_status_label = _label("CatalogStatus", _song_catalog_error, HORIZONTAL_ALIGNMENT_CENTER)
		_status_label.add_theme_font_size_override("font_size", 14)
		_status_label.modulate = Color(0.94, 0.62, 0.36, 1.0)
		_content.add_child(_status_label)

	var scroll := ScrollContainer.new()
	scroll.name = "SongSelectScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(scroll)

	var song_list := VBoxContainer.new()
	song_list.name = "SongList"
	song_list.alignment = BoxContainer.ALIGNMENT_BEGIN
	song_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(song_list)

	_populate_song_list(song_list)

	var back_button := _button("BackButton", "Back")
	back_button.pressed.connect(_on_song_select_back_pressed)
	_content.add_child(back_button)

	apply_layout_for_size(_layout_size())


func _populate_song_list(song_list: VBoxContainer) -> void:
	for child in song_list.get_children():
		if child is Button:
			_layout_buttons.erase(child)
		song_list.remove_child(child)
		child.queue_free()

	var entries := _filtered_song_entries()
	if _song_entries.is_empty():
		var empty_label := _label("EmptySongList", "No songs", HORIZONTAL_ALIGNMENT_CENTER)
		song_list.add_child(empty_label)
	elif entries.is_empty():
		var empty_filter_label := _label("EmptySongList", "No matching songs", HORIZONTAL_ALIGNMENT_CENTER)
		song_list.add_child(empty_filter_label)
	else:
		for entry: Dictionary in entries:
			var safe_id := _safe_name(str(entry.get("id", "")))
			var song_button := _button("Song_%s" % safe_id,
					"%s - %s" % [str(entry.get("artist", "")), str(entry.get("title", ""))])
			song_button.pressed.connect(_on_song_selected.bind(entry.duplicate(true)))
			song_list.add_child(song_button)
			var metadata := _label("SongMeta_%s" % safe_id,
					_song_metadata_text(entry),
					HORIZONTAL_ALIGNMENT_CENTER)
			metadata.add_theme_font_size_override("font_size", 14)
			song_list.add_child(metadata)
			if _entry_is_selected(entry):
				var selected := _label("SongSelected_%s" % safe_id, "Selected", HORIZONTAL_ALIGNMENT_CENTER)
				selected.add_theme_font_size_override("font_size", 13)
				selected.modulate = Color(0.92, 0.78, 0.38, 1.0)
				song_list.add_child(selected)


func _on_song_filter_changed(text: String) -> void:
	_song_filter_text = text
	var song_list: Node = _content_node_or_null("SongList")
	if song_list is VBoxContainer:
		_populate_song_list(song_list)
		apply_layout_for_size(_layout_size())


func _filtered_song_entries() -> Array[Dictionary]:
	var query := _song_filter_text.strip_edges().to_lower()
	if query.is_empty():
		return _copy_song_entries(_song_entries)

	var filtered: Array[Dictionary] = []
	for entry: Dictionary in _song_entries:
		if _entry_matches_filter(entry, query):
			filtered.append(entry.duplicate(true))
	return filtered


func _entry_matches_filter(entry: Dictionary, query: String) -> bool:
	return str(entry.get("title", "")).to_lower().contains(query) \
			or str(entry.get("artist", "")).to_lower().contains(query) \
			or str(entry.get("sourcePath", "")).to_lower().contains(query)


func _copy_song_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	var copied: Array[Dictionary] = []
	for entry: Dictionary in entries:
		copied.append(entry.duplicate(true))
	return copied


func _show_gameplay() -> void:
	_clear_content()
	_loading_pending_gameplay = false
	_gameplay_paused = false

	var bundle := _load_selected_gameplay_bundle()
	if bundle.is_empty():
		_discard_loading_audio_pool()
		_title_label = _label("Title", str(_selected_entry.get("title", "Gameplay")), HORIZONTAL_ALIGNMENT_CENTER)
		_content.add_child(_title_label)
		_status_label = _label("Status", "Unable to load gameplay bundle", HORIZONTAL_ALIGNMENT_CENTER)
		_content.add_child(_status_label)
		var back_button := _button("BackButton", "Back")
		back_button.pressed.connect(_on_gameplay_back_pressed)
		_content.add_child(back_button)
		apply_layout_for_size(_layout_size())
		return

	_gameplay_area = Control.new()
	_gameplay_area.name = "GameplayArea"
	_gameplay_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gameplay_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(_gameplay_area)

	_gameplay_view = GameplayView.new()
	_gameplay_view.name = "GameplayView"
	if not _gameplay_view.load_metadata(bundle.get("renderMetadata", {})):
		_show_gameplay_load_error("Unable to load render metadata")
		return
	if not _gameplay_view.load_chart(bundle.get("chart", {})):
		_show_gameplay_load_error("Unable to load gameplay chart")
		return
	_gameplay_area.add_child(_gameplay_view)

	_runtime = GameplayRuntime.new()
	_runtime.name = "GameplayRuntime"
	_runtime.set_process(false)
	if _loading_audio_pool != null and _runtime.has_method("set_audio_pool"):
		_runtime.set_audio_pool(_loading_audio_pool)
		_loading_audio_pool = null
	_runtime.completed.connect(complete_game)
	add_child(_runtime)
	var key_bindings := _settings_store.key_bindings()
	if not key_bindings.is_empty() and not _runtime.set_key_bindings(key_bindings):
		_show_gameplay_load_error("Unable to apply key bindings")
		return
	if not _runtime.set_misc_key_bindings(_settings_store.misc_key_bindings()):
		_show_gameplay_load_error("Unable to apply misc key bindings")
		return
	if not _runtime.start(bundle.get("chart", {}), bundle.get("audioManifest", {})):
		_show_gameplay_load_error("Unable to start gameplay")
		return
	_apply_window_title(_java_gameplay_window_title(_selected_entry))
	if _runtime.has_method("hud_state") and _gameplay_view.has_method("update_hud_state"):
		_gameplay_view.update_hud_state(_runtime.hud_state())

	apply_layout_for_size(_layout_size())


func _pause_gameplay() -> void:
	if _runtime == null:
		return
	_set_gameplay_paused(true)
	_show_pause_menu()


func _resume_gameplay() -> void:
	_clear_pause_menu()
	_set_gameplay_paused(false)


func _set_gameplay_paused(paused: bool) -> void:
	_gameplay_paused = paused
	if _runtime != null and _runtime.has_method("set_paused"):
		_runtime.set_paused(paused)


func _show_pause_menu() -> void:
	_clear_pause_menu()

	_pause_menu = CanvasLayer.new()
	_pause_menu.name = "PauseMenu"
	_pause_menu.layer = 100
	add_child(_pause_menu)

	var overlay := Control.new()
	overlay.name = "Overlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_menu.add_child(overlay)

	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = Color(0.0, 0.0, 0.0, 0.68)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(scrim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(340.0, 0.0)
	center.add_child(panel)

	var actions := VBoxContainer.new()
	actions.name = "PauseActions"
	actions.add_theme_constant_override("separation", 10)
	panel.add_child(actions)

	var title := _label("PauseTitle", "Menu", HORIZONTAL_ALIGNMENT_CENTER)
	actions.add_child(title)
	actions.add_child(_pause_button("RetryButton", "Retry", _on_pause_retry_pressed))
	actions.add_child(_pause_button("SettingsButton", "Settings", _on_pause_settings_pressed))
	actions.add_child(_pause_button("SongSelectButton", "Song Select", _on_pause_song_select_pressed))

	_apply_pause_menu_layout(_layout_size())


func _apply_pause_menu_layout(viewport_size: Vector2) -> void:
	if _pause_menu == null:
		return
	var overlay := _pause_menu.get_node_or_null("Overlay")
	if overlay is Control:
		overlay.offset_left = 0.0
		overlay.offset_top = 0.0
		overlay.offset_right = 0.0
		overlay.offset_bottom = 0.0
	var panel := _pause_menu.get_node_or_null("Overlay/Center/Panel")
	if panel is Control:
		var short_edge: float = min(viewport_size.x, viewport_size.y)
		var panel_width: float = clamp(viewport_size.x * 0.34, 320.0, 460.0)
		panel.custom_minimum_size = Vector2(panel_width, 0.0)
		panel.add_theme_constant_override("margin_left", int(round(clamp(short_edge * 0.035, 20.0, 36.0))))
		panel.add_theme_constant_override("margin_top", int(round(clamp(short_edge * 0.035, 20.0, 36.0))))
		panel.add_theme_constant_override("margin_right", int(round(clamp(short_edge * 0.035, 20.0, 36.0))))
		panel.add_theme_constant_override("margin_bottom", int(round(clamp(short_edge * 0.035, 20.0, 36.0))))


func _pause_button(node_name: String, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(240.0, 44.0)
	button.pressed.connect(callback)
	return button


func _clear_pause_menu() -> void:
	if _pause_menu == null:
		return
	var parent := _pause_menu.get_parent()
	if parent != null:
		parent.remove_child(_pause_menu)
	_pause_menu.queue_free()
	_pause_menu = null


func _on_pause_retry_pressed() -> void:
	_clear_pause_menu()
	_set_gameplay_paused(false)
	if _app_state.transition_to(AppState.LOADING):
		_show_loading()


func _on_pause_song_select_pressed() -> void:
	_clear_pause_menu()
	_set_gameplay_paused(false)
	if _app_state.transition_to(AppState.SONG_SELECT):
		_show_song_select()


func _on_pause_settings_pressed() -> void:
	_clear_pause_menu()
	_gameplay_paused = false
	if _app_state.transition_to(AppState.SETTINGS):
		_show_settings()


func _show_result() -> void:
	_clear_content()
	_apply_window_title(DEFAULT_WINDOW_TITLE)

	_title_label = _label("Title", "Result", HORIZONTAL_ALIGNMENT_CENTER)
	_content.add_child(_title_label)

	_status_label = _label("Status", "Score %d" % int(_last_result.get("score", 0)), HORIZONTAL_ALIGNMENT_CENTER)
	_content.add_child(_status_label)

	var result_summary := _label("ResultSummary", _result_summary_text(_last_result), HORIZONTAL_ALIGNMENT_CENTER)
	_content.add_child(result_summary)

	var retry_button := _button("RetryButton", "Retry")
	retry_button.pressed.connect(_on_retry_pressed)
	_content.add_child(retry_button)

	var song_select_button := _button("SongSelectButton", "Song Select")
	song_select_button.pressed.connect(_on_result_song_select_pressed)
	_content.add_child(song_select_button)

	apply_layout_for_size(_layout_size())


func _on_settings_back_pressed() -> void:
	_save_settings_from_controls()
	_save_settings_to_file()
	if _app_state.transition_to(AppState.MAIN_MENU):
		_show_main_menu()


func _on_song_select_back_pressed() -> void:
	if _app_state.transition_to(AppState.MAIN_MENU):
		_show_main_menu()


func _on_song_selected(entry: Dictionary) -> void:
	_selected_entry = entry.duplicate(true)
	if _app_state.transition_to(AppState.LOADING):
		_show_loading()


func _on_gameplay_back_pressed() -> void:
	if _app_state.transition_to(AppState.SONG_SELECT):
		_show_song_select()


func _on_retry_pressed() -> void:
	if _app_state.transition_to(AppState.LOADING):
		_show_loading()


func _on_result_song_select_pressed() -> void:
	if _app_state.transition_to(AppState.SONG_SELECT):
		_show_song_select()


func _show_loading() -> void:
	_clear_content()
	_apply_window_title(DEFAULT_WINDOW_TITLE)
	_loading_elapsed_ms = 0.0
	_loading_pending_gameplay = true
	_discard_loading_audio_pool()
	_selected_export_job = null
	_content.alignment = BoxContainer.ALIGNMENT_CENTER

	var loading_layer := Control.new()
	loading_layer.name = "LoadingLayer"
	loading_layer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loading_layer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(loading_layer)

	var loading_image := TextureRect.new()
	loading_image.name = "LoadingImage"
	loading_image.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loading_image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	loading_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	loading_image.stretch_mode = TextureRect.STRETCH_SCALE
	loading_image.texture = _loading_texture()
	loading_layer.add_child(loading_image)

	_loading_status_label = _label("LoadingStatus", _loading_status_text(), HORIZONTAL_ALIGNMENT_CENTER)
	_loading_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loading_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_status_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_loading_status_label.offset_left = 32.0
	_loading_status_label.offset_top = -80.0
	_loading_status_label.offset_right = -32.0
	_loading_status_label.offset_bottom = -24.0
	_loading_status_label.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0, 1.0))
	_loading_status_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	_loading_status_label.add_theme_constant_override("outline_size", 5)
	loading_layer.add_child(_loading_status_label)
	apply_layout_for_size(_layout_size())


func _advance_loading(delta: float) -> void:
	_loading_elapsed_ms += max(delta, 0.0) * 1000.0
	var bundle_ready := _selected_bundle_paths_ready()
	if not bundle_ready:
		bundle_ready = _advance_selected_export()
	var audio_ready := false
	if bundle_ready:
		audio_ready = _advance_loading_audio_preload()
	_update_loading_status()
	if not _loading_pending_gameplay:
		return
	if _loading_elapsed_ms < JAVA_MIN_LOADING_SCREEN_MS:
		return
	if not bundle_ready:
		return
	if not audio_ready:
		return
	_loading_pending_gameplay = false
	_update_loading_status()
	if _app_state.transition_to(AppState.GAMEPLAY):
		_show_gameplay()


func _advance_selected_export() -> bool:
	if _selected_export_job == null:
		return _start_selected_export()
	if not _selected_export_job.has_method("is_done"):
		_show_loading_export_error("Unable to export selected chart")
		return false
	if not bool(_selected_export_job.is_done()):
		return false
	return _finish_selected_export()


func _start_selected_export() -> bool:
	var source_path := str(_selected_entry.get("sourcePath", "")).strip_edges()
	if source_path.is_empty():
		_show_loading_export_error("Unable to export selected chart")
		return false
	if _exporter_client == null:
		_show_loading_export_error("Unable to export selected chart")
		return false

	var out_dir := _selected_export_dir()
	if _exporter_client.has_method("export_selected_async"):
		_selected_export_job = _exporter_client.export_selected_async(source_path, out_dir, _selected_chart_index())
		if _selected_export_job == null:
			_show_loading_export_error("Unable to export selected chart")
			return false
		if _selected_export_job.has_method("is_done") and bool(_selected_export_job.is_done()):
			return _finish_selected_export()
		return false

	if not _exporter_client.has_method("export_selected"):
		_show_loading_export_error("Unable to export selected chart")
		return false

	var export_result: Dictionary = _exporter_client.export_selected(source_path, out_dir, _selected_chart_index())
	if not bool(export_result.get("ok", false)):
		_show_loading_export_error("Unable to export selected chart")
		return false
	_selected_entry["bundleDir"] = out_dir
	return _selected_bundle_paths_ready()


func _finish_selected_export() -> bool:
	if _selected_export_job == null or not _selected_export_job.has_method("take_result"):
		_show_loading_export_error("Unable to export selected chart")
		return false

	var result_variant: Variant = _selected_export_job.take_result()
	_selected_export_job = null
	if not (result_variant is Dictionary):
		_show_loading_export_error("Unable to export selected chart")
		return false

	var export_result: Dictionary = result_variant
	if not bool(export_result.get("ok", false)):
		_show_loading_export_error("Unable to export selected chart")
		return false

	_selected_entry["bundleDir"] = _selected_export_dir()
	if not _selected_bundle_paths_ready():
		_show_loading_export_error("Unable to load gameplay bundle")
		return false
	return true


func _show_loading_export_error(message: String) -> void:
	_loading_pending_gameplay = false
	_selected_export_job = null
	_discard_loading_audio_pool()
	if _app_state.transition_to(AppState.GAMEPLAY):
		_show_gameplay_load_error(message)


func _wait_for_selected_export_job() -> void:
	if _selected_export_job != null and _selected_export_job.has_method("wait_for_finish"):
		_selected_export_job.wait_for_finish()
	_selected_export_job = null


func _update_loading_status() -> void:
	if _loading_status_label == null:
		return
	_loading_status_label.text = _loading_status_text()


func _loading_status_text() -> String:
	if _selected_bundle_paths_ready():
		if _loading_audio_pool != null \
				and _loading_audio_pool.has_method("preload_sample_count") \
				and _loading_audio_pool.has_method("preload_pending_sample_count"):
			var total := int(_loading_audio_pool.preload_sample_count())
			var pending := int(_loading_audio_pool.preload_pending_sample_count())
			if total > 0 and pending > 0:
				return "Loading audio samples... %d/%d prepared" % [total - pending, total]
		return "Loading gameplay..."
	if _selected_export_job == null:
		return "Preparing selected chart..."

	var elapsed_seconds := int(floor(max(_loading_elapsed_ms - JAVA_MIN_LOADING_SCREEN_MS, 0.0) / 1000.0))
	var sample_count := _exported_audio_sample_count(_join_path(_selected_export_dir(), "audio"))
	if sample_count > 0:
		return "Exporting audio samples... %d rendered, %ds elapsed" % [sample_count, elapsed_seconds]
	if FileAccess.file_exists(_join_path(_selected_export_dir(), "gameplay.json")):
		return "Exporting audio samples... %ds elapsed" % elapsed_seconds
	return "Exporting selected chart... %ds elapsed" % elapsed_seconds


func _advance_loading_audio_preload() -> bool:
	if _loading_audio_pool == null:
		if not _start_loading_audio_preload():
			return false
	if not _loading_audio_pool.has_method("preload_pending_sample_count") \
			or not _loading_audio_pool.has_method("preload_next_sample"):
		return true

	if _loading_audio_pool.has_method("preload_next_sample_async"):
		for i in range(LOADING_AUDIO_PRELOADS_PER_FRAME):
			if not bool(_loading_audio_pool.preload_next_sample_async()):
				_show_loading_export_error("Unable to load audio samples")
				return false
			if _loading_audio_pool.has_method("preload_in_progress") \
					and bool(_loading_audio_pool.preload_in_progress()):
				break
			if int(_loading_audio_pool.preload_pending_sample_count()) <= 0:
				break
		if _loading_audio_pool.has_method("preload_in_progress") \
				and bool(_loading_audio_pool.preload_in_progress()):
			return false
		return int(_loading_audio_pool.preload_pending_sample_count()) <= 0

	var pending := int(_loading_audio_pool.preload_pending_sample_count())
	var preload_count: int = min(LOADING_AUDIO_PRELOADS_PER_FRAME, pending)
	for i in range(preload_count):
		if not bool(_loading_audio_pool.preload_next_sample()):
			_show_loading_export_error("Unable to load audio samples")
			return false
	return int(_loading_audio_pool.preload_pending_sample_count()) <= 0


func _start_loading_audio_preload() -> bool:
	var audio_manifest_path := _selected_bundle_path("audioManifestPath", "audio-manifest.json")
	if audio_manifest_path.is_empty():
		_show_loading_export_error("Unable to load audio manifest")
		return false

	var audio_loader = AudioManifestLoader.new()
	var audio_manifest: Dictionary = audio_loader.load_from_file(audio_manifest_path)
	if audio_manifest.is_empty():
		_show_loading_export_error("Unable to load audio manifest")
		return false

	_loading_audio_pool = AudioPlayerPool.new()
	_loading_audio_pool.name = "LoadingAudioPool"
	add_child(_loading_audio_pool)
	if not _loading_audio_pool.load_manifest(audio_manifest):
		_show_loading_export_error("Unable to load audio samples")
		return false
	return true


func _discard_loading_audio_pool() -> void:
	if _loading_audio_pool == null:
		return
	var parent := _loading_audio_pool.get_parent()
	if parent != null:
		parent.remove_child(_loading_audio_pool)
	_loading_audio_pool.queue_free()
	_loading_audio_pool = null


func _exported_audio_sample_count(audio_dir: String) -> int:
	var dir := DirAccess.open(audio_dir)
	if dir == null:
		return 0

	var count := 0
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.begins_with("sample-") and file_name.ends_with(".wav"):
			count += 1
		file_name = dir.get_next()
	dir.list_dir_end()
	return count


func _loading_texture() -> Texture2D:
	var path := ProjectSettings.globalize_path("res://../../src/resources/vos_loading.png")
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _label(name: String, text: String, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.name = name
	label.text = text
	label.horizontal_alignment = alignment
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _result_summary_text(result: Dictionary) -> String:
	var judgments: Dictionary = result.get("judgments", {})
	return "Accuracy %.2f%%\nMax Combo %d\nPerfect %d\nCool %d\nGood %d\nBad %d\nMiss %d" % [
		_result_accuracy(result, judgments),
		int(result.get("maxCombo", 0)),
		int(judgments.get("perfect", 0)),
		int(judgments.get("cool", 0)),
		int(judgments.get("good", 0)),
		int(judgments.get("bad", 0)),
		int(judgments.get("miss", 0)),
	]


func _result_accuracy(result: Dictionary, judgments: Dictionary) -> float:
	var raw_accuracy: Variant = result.get("accuracy", null)
	if raw_accuracy is int or raw_accuracy is float:
		return float(raw_accuracy)
	return ResultModel.accuracy_for_judgments(judgments)


func _song_metadata_text(entry: Dictionary) -> String:
	return "Level %s | BPM %s | Notes %d | Duration %s | Source %s" % [
		_song_level_text(entry),
		_song_bpm_text(entry),
		int(entry.get("noteCount", 0)),
		_duration_text(float(entry.get("durationMs", 0.0))),
		str(entry.get("sourcePath", "")),
	]


func _entry_is_selected(entry: Dictionary) -> bool:
	var entry_id := str(entry.get("id", "")).strip_edges()
	var selected_id := str(_selected_entry.get("id", "")).strip_edges()
	if not entry_id.is_empty() and not selected_id.is_empty():
		return entry_id == selected_id
	var entry_source := str(entry.get("sourcePath", "")).strip_edges()
	var selected_source := str(_selected_entry.get("sourcePath", "")).strip_edges()
	return not entry_source.is_empty() and entry_source == selected_source


func _song_level_text(entry: Dictionary) -> String:
	if not bool(entry.get("levelKnown", true)):
		return "?"
	return str(int(entry.get("level", 0)))


func _song_bpm_text(entry: Dictionary) -> String:
	var bpm := float(entry.get("bpm", 0.0))
	var rounded := int(round(bpm))
	if absf(bpm - float(rounded)) < 0.0001:
		return str(rounded)
	var text := "%.3f" % bpm
	while text.ends_with("0"):
		text = text.substr(0, text.length() - 1)
	if text.ends_with("."):
		text = text.substr(0, text.length() - 1)
	return text


func _duration_text(duration_ms: float) -> String:
	var total_seconds := int(round(max(duration_ms, 0.0) / 1000.0))
	var minutes := int(floor(float(total_seconds) / 60.0))
	var seconds := total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


func _button(name: String, text: String) -> Button:
	var button := Button.new()
	button.name = name
	button.text = text
	_layout_buttons.append(button)
	return button


func _key_capture_button(name: String, binding: String, tooltip: String, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.name = name
	button.text = _key_binding_display_name(binding)
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = minimum_size
	button.set_meta("binding_key", InputMapStore.normalized_key_name(binding))
	button.pressed.connect(_begin_key_capture.bind(button))
	button.gui_input.connect(_on_key_capture_gui_input.bind(button))
	return button


func _begin_key_capture(button: Button) -> void:
	if _capturing_key_button != null and _capturing_key_button != button:
		_finish_key_capture(false)
	_capturing_key_button = button
	_capturing_key_previous_text = button.text
	button.text = _settings_text("Press a key...")
	if button.is_inside_tree():
		button.grab_focus()


func _on_key_capture_gui_input(event: InputEvent, button: Button) -> void:
	if _capturing_key_button != button:
		return
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event
	if key_event.echo or not key_event.pressed:
		return
	if key_event.keycode == KEY_ESCAPE:
		_finish_key_capture(false)
		_mark_settings_input_handled()
		return
	if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
		_mark_settings_input_handled()
		return
	var key_name := InputMapStore.key_name_from_event(key_event)
	if key_name.is_empty():
		_mark_settings_input_handled()
		return
	button.set_meta("binding_key", key_name)
	button.text = _key_binding_display_name(key_name)
	_finish_key_capture(true)
	_save_settings_from_controls()
	_save_settings_to_file()
	_mark_settings_input_handled()


func _finish_key_capture(accepted: bool) -> void:
	if _capturing_key_button == null:
		return
	if not accepted:
		_capturing_key_button.text = _capturing_key_previous_text
	_capturing_key_button = null
	_capturing_key_previous_text = ""


func _mark_settings_input_handled() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _key_binding_display_name(binding: String) -> String:
	var normalized := InputMapStore.normalized_key_name(binding)
	if normalized.is_empty():
		return binding.strip_edges()
	return normalized


func _clear_content() -> void:
	_clear_gameplay_runtime()
	_finish_key_capture(false)
	_title_label = null
	_subtitle_label = null
	_status_label = null
	_loading_status_label = null
	_start_button = null
	_settings_button = null
	_menu = null
	_layout_buttons.clear()

	if _content == null:
		return
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


func _clear_gameplay_runtime() -> void:
	_clear_pause_menu()
	_gameplay_paused = false
	_gameplay_area = null
	_gameplay_view = null
	if _runtime == null:
		return
	if _runtime.has_method("stop"):
		_runtime.stop()
	remove_child(_runtime)
	_runtime.queue_free()
	_runtime = null


func _load_selected_gameplay_bundle() -> Dictionary:
	if not _selected_bundle_paths_ready():
		return {}

	var gameplay_path := _selected_bundle_path("gameplayPath", "gameplay.json")
	var audio_manifest_path := _selected_bundle_path("audioManifestPath", "audio-manifest.json")
	var render_metadata_path := _selected_bundle_path("renderMetadataPath", "render-metadata.json")
	if gameplay_path.is_empty() or audio_manifest_path.is_empty() or render_metadata_path.is_empty():
		return {}

	var gameplay_loader = GameplayLoader.new()
	var chart: Dictionary = gameplay_loader.load_from_file_with_overrides(gameplay_path, _gameplay_option_overrides())
	if chart.is_empty():
		return {}

	var audio_loader = AudioManifestLoader.new()
	var audio_manifest: Dictionary = audio_loader.load_from_file(audio_manifest_path)
	if audio_manifest.is_empty():
		return {}

	var render_model = RenderEntityModel.new()
	var render_metadata: Dictionary = render_model.load_from_file(render_metadata_path)
	if render_metadata.is_empty():
		return {}
	_apply_render_metadata_to_chart(chart, render_metadata)

	return {
		"chart": chart,
		"audioManifest": audio_manifest,
		"renderMetadata": render_metadata,
	}


func _apply_render_metadata_to_chart(chart: Dictionary, render_metadata: Dictionary) -> void:
	var status_text_templates: Variant = render_metadata.get("statusTextTemplates", {})
	if status_text_templates is Dictionary and not status_text_templates.is_empty():
		chart["statusTextTemplates"] = status_text_templates.duplicate(true)


func _selected_bundle_paths_ready() -> bool:
	var gameplay_path := _selected_bundle_path("gameplayPath", "gameplay.json")
	var audio_manifest_path := _selected_bundle_path("audioManifestPath", "audio-manifest.json")
	var render_metadata_path := _selected_bundle_path("renderMetadataPath", "render-metadata.json")
	return not gameplay_path.is_empty() \
			and not audio_manifest_path.is_empty() \
			and not render_metadata_path.is_empty() \
			and FileAccess.file_exists(gameplay_path) \
			and FileAccess.file_exists(audio_manifest_path) \
			and FileAccess.file_exists(render_metadata_path)


func _selected_chart_index() -> int:
	var raw_index: Variant = _selected_entry.get("chartIndex", -1)
	if raw_index is int:
		return int(raw_index)
	if raw_index is float:
		return int(raw_index)
	return -1


func _selected_export_dir() -> String:
	var id := _safe_name(str(_selected_entry.get("id", "selected")))
	if id.is_empty():
		id = "selected"
	return ProjectSettings.globalize_path("user://exports/%s" % id)


func _selected_bundle_path(field: String, bundle_file_name: String) -> String:
	var direct_path := str(_selected_entry.get(field, "")).strip_edges()
	if not direct_path.is_empty():
		return direct_path

	var bundle_dir := str(_selected_entry.get("bundleDir", "")).strip_edges()
	if bundle_dir.is_empty():
		bundle_dir = _selected_export_dir()
	return _join_path(bundle_dir, bundle_file_name)


func _join_path(directory: String, file_name: String) -> String:
	if directory.ends_with("/") or directory.ends_with("\\"):
		return "%s%s" % [directory, file_name]
	return "%s/%s" % [directory, file_name]


func _show_gameplay_load_error(message: String) -> void:
	_discard_loading_audio_pool()
	_clear_content()
	_apply_window_title(DEFAULT_WINDOW_TITLE)

	_title_label = _label("Title", str(_selected_entry.get("title", "Gameplay")), HORIZONTAL_ALIGNMENT_CENTER)
	_content.add_child(_title_label)

	_status_label = _label("Status", message, HORIZONTAL_ALIGNMENT_CENTER)
	_content.add_child(_status_label)

	var back_button := _button("BackButton", "Back")
	back_button.pressed.connect(_on_gameplay_back_pressed)
	_content.add_child(back_button)

	apply_layout_for_size(_layout_size())


func _configure_exporter_from_environment() -> void:
	if _exporter_client == null or not _exporter_client.has_method("configure"):
		return
	if _exporter_client.has_method("is_configured") and _exporter_client.is_configured():
		return
	if not _exporter_client.has_method("configure_default"):
		return
	_exporter_client.configure_default(ProjectSettings.globalize_path("res://../.."))


func _refresh_song_entries_from_settings(force_refresh: bool = false) -> void:
	_song_catalog_error = ""
	var directories := _settings_store.song_directories()
	_configure_exporter_from_environment()
	if directories.is_empty():
		if not _song_entries_from_settings and not _song_entries.is_empty():
			return
		_song_entries.clear()
		_song_entries_directories.clear()
		_song_entries_from_settings = true
		return
	if not force_refresh:
		if not _song_entries.is_empty() and _string_arrays_equal(directories, _song_entries_directories):
			return
	if _exporter_client == null or not _exporter_client.has_method("export_catalog"):
		_song_catalog_error = "Catalog exporter is unavailable. Run mise run package, then restart Godot."
		_song_entries.clear()
		_song_entries_directories = _copy_string_array(directories)
		_song_entries_from_settings = true
		return

	var next_entries: Array[Dictionary] = []
	var export_errors: Array[String] = []
	for i in range(directories.size()):
		var source_path := directories[i]
		var output_path := _catalog_export_path(i)
		var result: Dictionary = _exporter_client.export_catalog(source_path, output_path)
		if not bool(result.get("ok", false)):
			export_errors.append(_catalog_export_error_text(source_path, result))
			continue

		var catalog = CatalogStore.new()
		if catalog.load_from_file(output_path):
			for entry: Dictionary in catalog.entries():
				next_entries.append(entry.duplicate(true))
		else:
			export_errors.append("Catalog export produced an unreadable catalog for %s." % source_path)

	_song_entries = next_entries
	_song_entries_directories = _copy_string_array(directories)
	_song_entries_from_settings = true
	_song_catalog_error = "\n".join(export_errors)


func _catalog_export_error_text(source_path: String, result: Dictionary) -> String:
	var exit_code := int(result.get("exit_code", -1))
	var message := "Catalog export failed for %s (exit %d)" % [source_path, exit_code]
	var error_text := str(result.get("error", "")).strip_edges()
	if not error_text.is_empty():
		message += ": %s" % error_text
	var output_text := _catalog_output_text(result.get("output", []))
	if not output_text.is_empty():
		message += "\n%s" % output_text
	return message


func _catalog_output_text(output: Variant) -> String:
	var lines: Array[String] = []
	if output is Array:
		for item: Variant in output:
			var line := str(item).strip_edges()
			if not line.is_empty():
				lines.append(line)
			if lines.size() >= 3:
				break
	else:
		var line := str(output).strip_edges()
		if not line.is_empty():
			lines.append(line)
	return "\n".join(lines)


func _string_arrays_equal(left: Array[String], right: Array[String]) -> bool:
	if left.size() != right.size():
		return false
	for i in range(left.size()):
		if left[i] != right[i]:
			return false
	return true


func _copy_string_array(values: Array[String]) -> Array[String]:
	var copied: Array[String] = []
	for value: String in values:
		copied.append(value)
	return copied


func _catalog_export_path(index: int) -> String:
	return ProjectSettings.globalize_path("user://catalog/%s/catalog_%d.json" % [_catalog_export_scope(), index])


func _catalog_export_scope() -> String:
	var scope := _safe_name(_settings_path.strip_edges())
	if scope.is_empty():
		return "settings"
	return scope


func _content_node_or_null(node_name: String) -> Node:
	if _content == null:
		return null
	return _content.find_child(node_name, true, false)


func _save_settings_from_controls() -> void:
	var settings_language: Node = _content_node_or_null("SettingsLanguageOption")
	if settings_language is OptionButton:
		_settings_store.set_settings_language(_settings_language_for_index(settings_language.selected))

	var fullscreen: Node = _content_node_or_null("FullscreenCheckBox")
	if fullscreen is CheckBox:
		_settings_store.set_fullscreen_enabled(fullscreen.button_pressed)
		_apply_window_mode_from_settings()

	var vsync: Node = _content_node_or_null("VSyncCheckBox")
	if vsync is CheckBox:
		_settings_store.set_vsync_enabled(vsync.button_pressed)
		_apply_vsync_mode_from_settings()

	var autoplay: Node = _content_node_or_null("AutoplayCheckBox")
	if autoplay is CheckBox:
		_settings_store.set_autoplay_enabled(autoplay.button_pressed)

	var autosound: Node = _content_node_or_null("AutoSoundCheckBox")
	if autosound is CheckBox:
		_settings_store.set_autosound_enabled(autosound.button_pressed)

	var audio_latency: Node = _content_node_or_null("AudioLatencySpinBox")
	if audio_latency is SpinBox:
		_settings_store.set_audio_latency_ms(float(audio_latency.value))

	var display_latency: Node = _content_node_or_null("DisplayLatencySpinBox")
	if display_latency is SpinBox:
		_settings_store.set_display_latency_ms(float(display_latency.value))

	var autosync_mode: Node = _content_node_or_null("AutosyncModeOption")
	if autosync_mode is OptionButton:
		_settings_store.set_autosync_mode(_selected_option_value(autosync_mode))

	var master_volume: Node = _content_node_or_null("MasterVolumeSpinBox")
	if master_volume is SpinBox:
		_settings_store.set_master_volume(float(master_volume.value))

	var key_volume: Node = _content_node_or_null("KeyVolumeSpinBox")
	if key_volume is SpinBox:
		_settings_store.set_key_volume(float(key_volume.value))

	var bgm_volume: Node = _content_node_or_null("BgmVolumeSpinBox")
	if bgm_volume is SpinBox:
		_settings_store.set_bgm_volume(float(bgm_volume.value))

	var haste_mode: Node = _content_node_or_null("HasteModeCheckBox")
	if haste_mode is CheckBox:
		_settings_store.set_haste_mode_enabled(haste_mode.button_pressed)

	var haste_normalize: Node = _content_node_or_null("HasteNormalizeSpeedCheckBox")
	if haste_normalize is CheckBox:
		_settings_store.set_haste_mode_normalize_speed(haste_normalize.button_pressed)

	var start_paused: Node = _content_node_or_null("StartPausedCheckBox")
	if start_paused is CheckBox:
		_settings_store.set_start_paused_enabled(start_paused.button_pressed)

	var local_matching_server: Node = _content_node_or_null("LocalMatchingServerInput")
	if local_matching_server is LineEdit:
		_settings_store.set_local_matching_server(local_matching_server.text)

	var channel_modifier: Node = _content_node_or_null("ChannelModifierOption")
	if channel_modifier is OptionButton:
		_settings_store.set_channel_modifier(_selected_option_value(channel_modifier))

	var speed_type: Node = _content_node_or_null("SpeedTypeOption")
	if speed_type is OptionButton:
		_settings_store.set_speed_type(_selected_option_value(speed_type))

	var speed_multiplier: Node = _content_node_or_null("SpeedMultiplierSpinBox")
	if speed_multiplier is SpinBox:
		_settings_store.set_speed_multiplier(float(speed_multiplier.value))

	var visibility_modifier: Node = _content_node_or_null("VisibilityModifierOption")
	if visibility_modifier is OptionButton:
		_settings_store.set_visibility_modifier(_selected_option_value(visibility_modifier))

	var judgment_type: Node = _content_node_or_null("JudgmentTypeOption")
	if judgment_type is OptionButton:
		_settings_store.set_judgment_type(_selected_option_value(judgment_type))

	var bindings: Array[String] = []
	for i in range(DEFAULT_KEY_BINDINGS.size()):
		var key_input: Node = _content_node_or_null("KeyBinding%d" % (i + 1))
		if key_input != null:
			var key := _key_binding_from_control(key_input)
			if key.is_empty():
				return
			bindings.append(key)
	if bindings.size() == DEFAULT_KEY_BINDINGS.size():
		_settings_store.set_key_bindings(bindings)

	var misc_bindings := {}
	for action: String in MISC_KEY_ACTIONS:
		var key_input: Node = _content_node_or_null("MiscKey_%s" % action)
		if key_input != null:
			var key := _key_binding_from_control(key_input)
			if key.is_empty():
				return
			misc_bindings[action] = key
	if misc_bindings.size() == MISC_KEY_ACTIONS.size():
		_settings_store.set_misc_key_bindings(misc_bindings)


func _key_binding_from_control(control: Node) -> String:
	if control is Button:
		var text_key := InputMapStore.normalized_key_name(control.text)
		if not text_key.is_empty():
			return text_key
		if control.has_meta("binding_key"):
			return InputMapStore.normalized_key_name(str(control.get_meta("binding_key")))
		return ""
	if control is LineEdit:
		return InputMapStore.normalized_key_name(control.text)
	return ""


func _apply_window_mode_from_settings() -> void:
	var target_mode := DisplayServer.WINDOW_MODE_FULLSCREEN if _settings_store.fullscreen_enabled() else DisplayServer.WINDOW_MODE_WINDOWED
	_last_requested_window_mode = target_mode
	if DisplayServer.window_get_mode() != target_mode:
		DisplayServer.window_set_mode(target_mode)


func _apply_vsync_mode_from_settings() -> void:
	var target_mode := DisplayServer.VSYNC_ENABLED if _settings_store.vsync_enabled() else DisplayServer.VSYNC_DISABLED
	_last_requested_vsync_mode = target_mode
	DisplayServer.window_set_vsync_mode(target_mode)


func _apply_window_title(title: String) -> void:
	_last_requested_window_title = title
	DisplayServer.window_set_title(title)


func _java_gameplay_window_title(entry: Dictionary) -> String:
	return "%s - %s" % [
		str(entry.get("artist", "")),
		str(entry.get("title", "")),
	]


func _load_settings_from_file() -> void:
	if _settings_store.load_from_file(_settings_path):
		_apply_window_mode_from_settings()
		_apply_vsync_mode_from_settings()


func _save_settings_to_file() -> void:
	_settings_store.save_to_file(_settings_path)


func _apply_autosync_result(result: Dictionary) -> void:
	var mode := str(result.get("autosyncMode", ""))
	if mode == "display":
		_settings_store.set_display_latency_ms(float(result.get("displayLatencyMs", _settings_store.display_latency_ms())))
	elif mode == "audio":
		_settings_store.set_audio_latency_ms(float(result.get("audioLatencyMs", _settings_store.audio_latency_ms())))
	else:
		return
	_settings_store.set_autosync_mode("")
	_save_settings_to_file()


func _gameplay_option_overrides() -> Dictionary:
	var overrides := {
		"autoplay": _settings_store.autoplay_enabled(),
		"autosound": _settings_store.autosound_enabled(),
		"audioLatencyMs": _settings_store.audio_latency_ms(),
		"displayLatencyMs": _settings_store.display_latency_ms(),
		"autosyncMode": _settings_store.autosync_mode(),
		"masterVolume": _settings_store.master_volume(),
		"keyVolume": _settings_store.key_volume(),
		"bgmVolume": _settings_store.bgm_volume(),
		"hasteMode": _settings_store.haste_mode_enabled(),
		"hasteModeNormalizeSpeed": _settings_store.haste_mode_normalize_speed(),
		"manualStart": _settings_store.start_paused_enabled(),
		"localMatchingServer": _settings_store.local_matching_server(),
		"channelModifier": _settings_store.channel_modifier(),
		"speedType": _settings_store.speed_type(),
		"speedMultiplier": _settings_store.speed_multiplier(),
		"visibilityModifier": _settings_store.visibility_modifier(),
		"judgmentType": _settings_store.judgment_type(),
	}
	if _partytime_server != null:
		overrides["partytimeServerObject"] = _partytime_server
	return overrides


func _song_directories_text() -> String:
	var text := ""
	for path: String in _settings_store.song_directories():
		if not text.is_empty():
			text += ";"
		text += path
	return text


func _key_binding_for_settings(index: int) -> String:
	var bindings := _settings_store.key_bindings()
	if index >= 0 and index < bindings.size():
		return bindings[index]
	return DEFAULT_KEY_BINDINGS[index]


func _misc_key_binding_for_settings(action: String) -> String:
	var bindings := _settings_store.misc_key_bindings()
	return str(bindings.get(action, InputMapStore.DEFAULT_MISC_KEY_BINDINGS.get(action, "")))


func _safe_name(value: String) -> String:
	var result := value.replace(":", "_").replace("/", "_").replace("\\", "_").replace(" ", "_")
	if result.is_empty():
		return "unknown"
	return result


func _on_resized() -> void:
	apply_layout_for_size(_layout_size())


func _layout_size() -> Vector2:
	if is_inside_tree():
		return get_viewport_rect().size
	return Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 720)))


func _apply_gameplay_layout(viewport_size: Vector2) -> void:
	if _gameplay_area == null or _gameplay_view == null:
		return
	var base_size := _gameplay_view.custom_minimum_size
	if base_size.x <= 0.0 or base_size.y <= 0.0:
		return
	var target_size := Vector2(max(viewport_size.x, 1.0), max(viewport_size.y, 1.0))
	var scale_factor: float = min(target_size.x / base_size.x, target_size.y / base_size.y)
	var scaled_size := base_size * scale_factor
	_gameplay_area.custom_minimum_size = target_size
	_gameplay_area.size = target_size
	_gameplay_view.position = (target_size - scaled_size) * 0.5
	_gameplay_view.size = base_size
	_gameplay_view.scale = Vector2(scale_factor, scale_factor)
