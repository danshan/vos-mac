extends RefCounted

const BOOT := "boot"
const MAIN_MENU := "main_menu"
const SETTINGS := "settings"
const SONG_SELECT := "song_select"
const DIFFICULTY_SELECT := "difficulty_select"
const LOADING := "loading"
const GAMEPLAY := "gameplay"
const RESULT := "result"

const _ALLOWED_TRANSITIONS := {
	BOOT: [MAIN_MENU],
	MAIN_MENU: [SETTINGS, SONG_SELECT],
	SETTINGS: [MAIN_MENU],
	SONG_SELECT: [MAIN_MENU, DIFFICULTY_SELECT, LOADING],
	DIFFICULTY_SELECT: [SONG_SELECT, LOADING],
	LOADING: [GAMEPLAY, SONG_SELECT],
	GAMEPLAY: [RESULT, SONG_SELECT, LOADING, SETTINGS],
	RESULT: [LOADING, SONG_SELECT, MAIN_MENU],
}

var _current := BOOT


func current() -> String:
	return _current


func transition_to(next: String) -> bool:
	var allowed: Array = _ALLOWED_TRANSITIONS.get(_current, [])
	if allowed.has(next):
		_current = next
		return true
	return false
