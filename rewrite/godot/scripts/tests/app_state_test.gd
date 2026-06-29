extends SceneTree

const AppState = preload("res://scripts/app_state.gd")

func _init() -> void:
	var state = AppState.new()

	_expect_current(state, AppState.BOOT)
	state.transition_to(AppState.GAMEPLAY)
	_expect_current(state, AppState.BOOT)

	state.transition_to(AppState.MAIN_MENU)
	_expect_current(state, AppState.MAIN_MENU)
	state.transition_to(AppState.SONG_SELECT)
	_expect_current(state, AppState.SONG_SELECT)
	state.transition_to(AppState.LOADING)
	_expect_current(state, AppState.LOADING)
	state.transition_to(AppState.GAMEPLAY)
	_expect_current(state, AppState.GAMEPLAY)
	state.transition_to(AppState.RESULT)
	_expect_current(state, AppState.RESULT)
	state.transition_to(AppState.SONG_SELECT)
	_expect_current(state, AppState.SONG_SELECT)

	quit(0)


func _expect_current(state: Object, expected: String) -> void:
	var actual: String = state.current()
	if actual != expected:
		push_error("Expected current state '%s', got '%s'." % [expected, actual])
		quit(1)
