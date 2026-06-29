extends Control

const AppState = preload("res://scripts/app_state.gd")
const AudioManifestLoader = preload("res://scripts/audio_manifest_loader.gd")
const CatalogStore = preload("res://scripts/catalog_store.gd")
const ExporterClient = preload("res://scripts/exporter_client.gd")
const GameplayLoader = preload("res://scripts/gameplay_loader.gd")
const GameplayRuntime = preload("res://scripts/gameplay_runtime.gd")
const GameplayView = preload("res://scripts/gameplay_view.gd")
const RenderEntityModel = preload("res://scripts/render_entity_model.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const DEFAULT_KEY_BINDINGS: Array[String] = ["S", "D", "F", "Space", "J", "K", "L"]

var _built: bool = false
var _app_state = AppState.new()
var _song_entries: Array[Dictionary] = []
var _selected_entry: Dictionary = {}
var _last_result: Dictionary = {}
var _content: VBoxContainer = null
var _menu: HBoxContainer = null
var _title_label: Label = null
var _subtitle_label: Label = null
var _status_label: Label = null
var _start_button: Button = null
var _settings_button: Button = null
var _layout_buttons: Array[Button] = []
var _runtime: Node = null
var _gameplay_view: Control = null
var _exporter_client = ExporterClient.new()
var _settings_store = SettingsStore.new()


func _ready() -> void:
	build()


func _process(_delta: float) -> void:
	if _runtime == null or _gameplay_view == null:
		return
	if _runtime.has_method("elapsed_ms") and _gameplay_view.has_method("update_time"):
		_gameplay_view.update_time(_runtime.elapsed_ms())


func build() -> void:
	if _built:
		return
	_built = true
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
	for entry: Variant in entries:
		if entry is Dictionary:
			_song_entries.append(entry.duplicate(true))
	if _app_state.current() == AppState.SONG_SELECT:
		_show_song_select()


func set_exporter_client(exporter: Variant) -> void:
	_exporter_client = exporter


func configure_exporter(java_path: String, jar_path: String) -> void:
	_exporter_client.configure(java_path, jar_path)


func complete_game(result: Dictionary) -> void:
	_last_result = result.duplicate(true)
	if _app_state.current() == AppState.GAMEPLAY and _app_state.transition_to(AppState.RESULT):
		_show_result()


func _show_main_menu() -> void:
	_clear_content()

	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.text = "Open2Jam VOS"
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
	for button: Button in _layout_buttons:
		button.custom_minimum_size = button_size


func _on_start_pressed() -> void:
	_refresh_song_entries_from_settings()
	if _app_state.transition_to(AppState.SONG_SELECT):
		_show_song_select()


func _on_settings_pressed() -> void:
	if _app_state.transition_to(AppState.SETTINGS):
		_show_settings()


func _show_settings() -> void:
	_clear_content()

	_title_label = _label("Title", "Settings", HORIZONTAL_ALIGNMENT_CENTER)
	_content.add_child(_title_label)

	var directory_input := LineEdit.new()
	directory_input.name = "SongDirectoryInput"
	directory_input.placeholder_text = "Song directory"
	directory_input.text = _song_directories_text()
	_content.add_child(directory_input)

	var fullscreen := CheckBox.new()
	fullscreen.name = "FullscreenCheckBox"
	fullscreen.text = "Fullscreen"
	fullscreen.button_pressed = _settings_store.fullscreen_enabled()
	_content.add_child(fullscreen)

	var key_bindings := GridContainer.new()
	key_bindings.name = "KeyBindings"
	key_bindings.columns = DEFAULT_KEY_BINDINGS.size()
	_content.add_child(key_bindings)

	for i in range(DEFAULT_KEY_BINDINGS.size()):
		var key_input := LineEdit.new()
		key_input.name = "KeyBinding%d" % (i + 1)
		key_input.text = _key_binding_for_settings(i)
		key_input.custom_minimum_size = Vector2(96.0, 44.0)
		key_bindings.add_child(key_input)

	var back_button := _button("BackButton", "Back")
	back_button.pressed.connect(_on_settings_back_pressed)
	_content.add_child(back_button)

	apply_layout_for_size(_layout_size())


func _show_song_select() -> void:
	_clear_content()

	_title_label = _label("Title", "Song Select", HORIZONTAL_ALIGNMENT_CENTER)
	_content.add_child(_title_label)

	var song_list := VBoxContainer.new()
	song_list.name = "SongList"
	song_list.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(song_list)

	if _song_entries.is_empty():
		var empty_label := _label("EmptySongList", "No songs", HORIZONTAL_ALIGNMENT_CENTER)
		song_list.add_child(empty_label)
	else:
		for entry: Dictionary in _song_entries:
			var song_button := _button("Song_%s" % _safe_name(str(entry.get("id", ""))),
					"%s - %s" % [str(entry.get("artist", "")), str(entry.get("title", ""))])
			song_button.pressed.connect(_on_song_selected.bind(entry.duplicate(true)))
			song_list.add_child(song_button)

	var back_button := _button("BackButton", "Back")
	back_button.pressed.connect(_on_song_select_back_pressed)
	_content.add_child(back_button)

	apply_layout_for_size(_layout_size())


func _show_gameplay() -> void:
	_clear_content()

	_title_label = _label("Title", str(_selected_entry.get("title", "Gameplay")), HORIZONTAL_ALIGNMENT_CENTER)
	_content.add_child(_title_label)

	var bundle := _load_selected_gameplay_bundle()
	if bundle.is_empty():
		_status_label = _label("Status", "Unable to load gameplay bundle", HORIZONTAL_ALIGNMENT_CENTER)
		_content.add_child(_status_label)
		var back_button := _button("BackButton", "Back")
		back_button.pressed.connect(_on_gameplay_back_pressed)
		_content.add_child(back_button)
		apply_layout_for_size(_layout_size())
		return

	var gameplay_area := Control.new()
	gameplay_area.name = "GameplayArea"
	gameplay_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gameplay_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(gameplay_area)

	_gameplay_view = GameplayView.new()
	_gameplay_view.name = "GameplayView"
	_gameplay_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	if not _gameplay_view.load_metadata(bundle.get("renderMetadata", {})):
		_show_gameplay_load_error("Unable to load render metadata")
		return
	if not _gameplay_view.load_chart(bundle.get("chart", {})):
		_show_gameplay_load_error("Unable to load gameplay chart")
		return
	gameplay_area.add_child(_gameplay_view)

	_runtime = GameplayRuntime.new()
	_runtime.name = "GameplayRuntime"
	_runtime.completed.connect(complete_game)
	add_child(_runtime)
	var key_bindings := _settings_store.key_bindings()
	if not key_bindings.is_empty() and not _runtime.set_key_bindings(key_bindings):
		_show_gameplay_load_error("Unable to apply key bindings")
		return
	if not _runtime.start(bundle.get("chart", {}), bundle.get("audioManifest", {})):
		_show_gameplay_load_error("Unable to start gameplay")
		return

	_status_label = _label("Status", "Playing", HORIZONTAL_ALIGNMENT_CENTER)
	_content.add_child(_status_label)

	apply_layout_for_size(_layout_size())


func _show_result() -> void:
	_clear_content()

	_title_label = _label("Title", "Result", HORIZONTAL_ALIGNMENT_CENTER)
	_content.add_child(_title_label)

	_status_label = _label("Status", "Score %d" % int(_last_result.get("score", 0)), HORIZONTAL_ALIGNMENT_CENTER)
	_content.add_child(_status_label)

	var retry_button := _button("RetryButton", "Retry")
	retry_button.pressed.connect(_on_retry_pressed)
	_content.add_child(retry_button)

	var song_select_button := _button("SongSelectButton", "Song Select")
	song_select_button.pressed.connect(_on_result_song_select_pressed)
	_content.add_child(song_select_button)

	apply_layout_for_size(_layout_size())


func _on_settings_back_pressed() -> void:
	_save_settings_from_controls()
	if _app_state.transition_to(AppState.MAIN_MENU):
		_show_main_menu()


func _on_song_select_back_pressed() -> void:
	if _app_state.transition_to(AppState.MAIN_MENU):
		_show_main_menu()


func _on_song_selected(entry: Dictionary) -> void:
	_selected_entry = entry.duplicate(true)
	if _app_state.transition_to(AppState.LOADING) and _app_state.transition_to(AppState.GAMEPLAY):
		_show_gameplay()


func _on_gameplay_back_pressed() -> void:
	if _app_state.transition_to(AppState.SONG_SELECT):
		_show_song_select()


func _on_retry_pressed() -> void:
	if _app_state.transition_to(AppState.LOADING) and _app_state.transition_to(AppState.GAMEPLAY):
		_show_gameplay()


func _on_result_song_select_pressed() -> void:
	if _app_state.transition_to(AppState.SONG_SELECT):
		_show_song_select()


func _label(name: String, text: String, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.name = name
	label.text = text
	label.horizontal_alignment = alignment
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(name: String, text: String) -> Button:
	var button := Button.new()
	button.name = name
	button.text = text
	_layout_buttons.append(button)
	return button


func _clear_content() -> void:
	_clear_gameplay_runtime()
	_title_label = null
	_subtitle_label = null
	_status_label = null
	_start_button = null
	_settings_button = null
	_menu = null
	_layout_buttons.clear()

	if _content == null:
		return
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


func _clear_gameplay_runtime() -> void:
	_gameplay_view = null
	if _runtime == null:
		return
	if _runtime.has_method("stop"):
		_runtime.stop()
	remove_child(_runtime)
	_runtime.queue_free()
	_runtime = null


func _load_selected_gameplay_bundle() -> Dictionary:
	if not _ensure_selected_bundle_paths():
		return {}

	var gameplay_path := _selected_bundle_path("gameplayPath", "gameplay.json")
	var audio_manifest_path := _selected_bundle_path("audioManifestPath", "audio-manifest.json")
	var render_metadata_path := _selected_bundle_path("renderMetadataPath", "render-metadata.json")
	if gameplay_path.is_empty() or audio_manifest_path.is_empty() or render_metadata_path.is_empty():
		return {}

	var gameplay_loader = GameplayLoader.new()
	var chart: Dictionary = gameplay_loader.load_from_file(gameplay_path)
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

	return {
		"chart": chart,
		"audioManifest": audio_manifest,
		"renderMetadata": render_metadata,
	}


func _ensure_selected_bundle_paths() -> bool:
	if not _selected_bundle_path("gameplayPath", "gameplay.json").is_empty() \
			and not _selected_bundle_path("audioManifestPath", "audio-manifest.json").is_empty() \
			and not _selected_bundle_path("renderMetadataPath", "render-metadata.json").is_empty():
		return true

	var source_path := str(_selected_entry.get("sourcePath", "")).strip_edges()
	if source_path.is_empty():
		return false
	if _exporter_client == null or not _exporter_client.has_method("export_selected"):
		return false

	var out_dir := _selected_export_dir()
	var export_result: Dictionary = _exporter_client.export_selected(source_path, out_dir)
	if not bool(export_result.get("ok", false)):
		return false

	_selected_entry["bundleDir"] = out_dir
	return true


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
		return ""
	return _join_path(bundle_dir, bundle_file_name)


func _join_path(directory: String, file_name: String) -> String:
	if directory.ends_with("/") or directory.ends_with("\\"):
		return "%s%s" % [directory, file_name]
	return "%s/%s" % [directory, file_name]


func _show_gameplay_load_error(message: String) -> void:
	_clear_gameplay_runtime()
	if _status_label == null:
		_status_label = _label("Status", message, HORIZONTAL_ALIGNMENT_CENTER)
		_content.add_child(_status_label)
	else:
		_status_label.text = message


func _refresh_song_entries_from_settings() -> void:
	if not _song_entries.is_empty():
		return
	if _exporter_client == null or not _exporter_client.has_method("export_catalog"):
		return

	var next_entries: Array[Dictionary] = []
	var directories := _settings_store.song_directories()
	for i in range(directories.size()):
		var source_path := directories[i]
		var output_path := _catalog_export_path(i)
		var result: Dictionary = _exporter_client.export_catalog(source_path, output_path)
		if not bool(result.get("ok", false)):
			continue

		var catalog = CatalogStore.new()
		if catalog.load_from_file(output_path):
			for entry: Dictionary in catalog.entries():
				next_entries.append(entry.duplicate(true))

	if not next_entries.is_empty():
		_song_entries = next_entries


func _catalog_export_path(index: int) -> String:
	return ProjectSettings.globalize_path("user://catalog/catalog_%d.json" % index)


func _save_settings_from_controls() -> void:
	var directory_input: Node = _content.get_node_or_null("SongDirectoryInput")
	if directory_input is LineEdit:
		_settings_store.set_song_directories(_parse_song_directories(directory_input.text))

	var fullscreen: Node = _content.get_node_or_null("FullscreenCheckBox")
	if fullscreen is CheckBox:
		_settings_store.set_fullscreen_enabled(fullscreen.button_pressed)

	var bindings: Array[String] = []
	for i in range(DEFAULT_KEY_BINDINGS.size()):
		var key_input: Node = _content.get_node_or_null("KeyBindings/KeyBinding%d" % (i + 1))
		if key_input is LineEdit:
			var key: String = key_input.text.strip_edges()
			if key.is_empty():
				return
			bindings.append(key)
	if bindings.size() == DEFAULT_KEY_BINDINGS.size():
		_settings_store.set_key_bindings(bindings)


func _parse_song_directories(text: String) -> Array[String]:
	var directories: Array[String] = []
	for raw_path: String in text.split(";", false):
		var path := raw_path.strip_edges()
		if not path.is_empty():
			directories.append(path)
	return directories


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
