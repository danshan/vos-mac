extends RefCounted

const STATUS_CONNECTING: String = "Connecting..."
const STATUS_CONNECTED: String = "Connected!"
const STATUS_GAME_START: String = "Game start!"
const STATUS_INTERRUPTED: String = "Interrupted!"
const READ_BUFFER_LIMIT: int = 65536

var _peer = null
var _host: String = ""
var _port: int = 0
var _own_latency_ms: int = 0
var _status: String = ""
var _ready: bool = false
var _connected: bool = false
var _phase: String = "sync"
var _read_buffer: String = ""
var _ready_at_epoch_ms: int = -1


func start(host: String, port: int, own_latency_ms: int) -> void:
	disconnect_from_host()
	_host = host
	_port = port
	_own_latency_ms = own_latency_ms
	_status = STATUS_CONNECTING
	_ready = false
	_connected = false
	_phase = "sync"
	_read_buffer = ""
	_ready_at_epoch_ms = -1
	_peer = StreamPeerTCP.new()
	var error: int = _peer.connect_to_host(_host, _port)
	if error != OK:
		_fail("IO Exception:%s" % error)


func start_with_peer(peer, own_latency_ms: int) -> void:
	disconnect_from_host()
	_host = ""
	_port = 0
	_own_latency_ms = own_latency_ms
	_status = STATUS_CONNECTED
	_ready = false
	_connected = true
	_phase = "sync"
	_read_buffer = ""
	_ready_at_epoch_ms = -1
	_peer = peer


func poll() -> void:
	if _ready:
		return
	if _peer == null:
		_ready = true
		return

	var poll_error: int = _peer.poll()
	if poll_error != OK:
		_fail("IO Exception:%s" % poll_error)
		return

	var peer_status: int = _peer.get_status()
	if peer_status == StreamPeerTCP.STATUS_CONNECTING:
		return
	if peer_status == StreamPeerTCP.STATUS_ERROR:
		_fail("IO Exception:connection failed")
		return
	if peer_status == StreamPeerTCP.STATUS_NONE:
		if _connected:
			_ready = true
		return
	if peer_status != StreamPeerTCP.STATUS_CONNECTED:
		return

	if not _connected:
		_connected = true
		_status = STATUS_CONNECTED

	_read_available_lines()
	if _ready_at_epoch_ms >= 0 and _current_epoch_ms() >= _ready_at_epoch_ms:
		_status = STATUS_GAME_START
		_ready = true
		disconnect_from_host()


func is_ready() -> bool:
	return _ready


func status() -> String:
	return _status


func disconnect_from_host() -> void:
	if _peer != null:
		_peer.disconnect_from_host()
	_peer = null


func _read_available_lines() -> void:
	var available: int = _peer.get_available_bytes()
	if available <= 0:
		return
	_read_buffer += _peer.get_utf8_string(available)
	if _read_buffer.length() > READ_BUFFER_LIMIT:
		_fail("IO Exception:read buffer overflow")
		return

	while true:
		var newline_index: int = _read_buffer.find("\n")
		if newline_index < 0:
			return
		var line: String = _read_buffer.substr(0, newline_index)
		_read_buffer = _read_buffer.substr(newline_index + 1)
		_handle_line(line.strip_edges())
		if _ready or _peer == null:
			return


func _handle_line(line: String) -> void:
	if line.begins_with("status:"):
		_status = "remote:" + line.substr(7)
		return

	if _phase == "sync":
		if line == "synced":
			_phase = "play"
		elif line == "time?":
			_write_line(str(_current_epoch_ms()))
	elif _phase == "play" and line.begins_with("play:"):
		var play_at: String = line.substr(5)
		if not play_at.is_valid_int():
			_fail("IO Exception:invalid play time")
			return
		_ready_at_epoch_ms = max(_current_epoch_ms(), int(play_at) - _own_latency_ms)


func _write_line(line: String) -> void:
	var error: int = _peer.put_data((line + "\n").to_utf8_buffer())
	if error != OK:
		_fail("IO Exception:%s" % error)


func _fail(next_status: String) -> void:
	_status = next_status
	_ready = true
	disconnect_from_host()


func _current_epoch_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)
