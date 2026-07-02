extends SceneTree

const AppState = preload("res://scripts/app_state.gd")

func _init() -> void:
	var state = AppState.new()

	if not _expect_current(state, AppState.BOOT):
		return
	if not _expect_transition(state, AppState.GAMEPLAY, false):
		return
	if not _expect_current(state, AppState.BOOT):
		return

	if not _expect_transition(state, AppState.MAIN_MENU, true):
		return
	if not _expect_current(state, AppState.MAIN_MENU):
		return
	if not _expect_transition(state, AppState.SONG_SELECT, true):
		return
	if not _expect_current(state, AppState.SONG_SELECT):
		return
	if not _expect_transition(state, AppState.LOADING, true):
		return
	if not _expect_current(state, AppState.LOADING):
		return
	if not _expect_transition(state, AppState.GAMEPLAY, true):
		return
	if not _expect_current(state, AppState.GAMEPLAY):
		return
	if not _expect_transition(state, AppState.RESULT, true):
		return
	if not _expect_current(state, AppState.RESULT):
		return
	if not _expect_transition(state, AppState.SONG_SELECT, true):
		return
	if not _expect_current(state, AppState.SONG_SELECT):
		return

	var gameplay_settings_state = AppState.new()
	if not _expect_transition(gameplay_settings_state, AppState.MAIN_MENU, true):
		return
	if not _expect_transition(gameplay_settings_state, AppState.SONG_SELECT, true):
		return
	if not _expect_transition(gameplay_settings_state, AppState.LOADING, true):
		return
	if not _expect_transition(gameplay_settings_state, AppState.GAMEPLAY, true):
		return
	if not _expect_transition(gameplay_settings_state, AppState.SETTINGS, true):
		return
	if not _expect_current(gameplay_settings_state, AppState.SETTINGS):
		return
	if not _expect_transition(gameplay_settings_state, AppState.MAIN_MENU, true):
		return
	if not _expect_current(gameplay_settings_state, AppState.MAIN_MENU):
		return

	quit(0)


func _expect_current(state: Object, expected: String) -> bool:
	var actual: String = state.current()
	if actual != expected:
		push_error("Expected current state '%s', got '%s'." % [expected, actual])
		quit(1)
		return false
	return true


func _expect_transition(state: Object, next: String, expected: bool) -> bool:
	var actual: bool = state.transition_to(next)
	if actual != expected:
		push_error("Expected transition to '%s' to return '%s', got '%s'." % [next, expected, actual])
		quit(1)
		return false
	return true
