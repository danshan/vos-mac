extends RefCounted

const STATUS_CREATING: String = "Creating server..."
const STATUS_STARTING: String = "Starting server..."
const READ_BUFFER_LIMIT: int = 65536
const SYNC_TIMES: int = 50
const PLAY_DELAY_MS: int = 5000

var _status: String = STATUS_CREATING
var _port: int = 0
var _server = null
var _connections: Array = []


class PartytimeConnection:
	extends RefCounted

	var _peer = null
	var _host: String = ""
	var _status: String = "Initializing..."
	var _read_buffer: String = ""
	var _closed: bool = false
	var _synchronized: bool = false
	var _waiting_for_time: bool = false
	var _sync_index: int = 1
	var _best_latency_ms: int = 0
	var _offset_ms: int = 0
	var _sent_at_epoch_ms: int = 0

	func start_with_peer(peer, host: String) -> void:
		_peer = peer
		_host = host
		_status = "Client accepted."
		_read_buffer = ""
		_closed = false
		_synchronized = false
		_waiting_for_time = false
		_sync_index = 1
		_best_latency_ms = 0
		_offset_ms = 0
		_sent_at_epoch_ms = 0

	func start_with_status(host: String, status: String) -> void:
		_peer = null
		_host = host
		_status = status
		_read_buffer = ""
		_closed = false
		_synchronized = true
		_waiting_for_time = false
		_sync_index = SYNC_TIMES
		_best_latency_ms = 0
		_offset_ms = 0
		_sent_at_epoch_ms = 0

	func poll() -> void:
		if _closed:
			return
		if _peer == null:
			return

		var poll_error: int = _peer.poll()
		if poll_error != OK:
			_fail("Read error.")
			return

		var peer_status: int = _peer.get_status()
		if peer_status == StreamPeerTCP.STATUS_ERROR:
			_fail("Read error.")
			return
		if peer_status == StreamPeerTCP.STATUS_NONE:
			close()
			return
		if peer_status != StreamPeerTCP.STATUS_CONNECTED:
			return

		_read_available_lines()
		if _closed or _synchronized:
			return
		if not _waiting_for_time:
			_send_sync_request()

	func host() -> String:
		return _host

	func status() -> String:
		return _status

	func is_closed() -> bool:
		return _closed

	func go(play_at_epoch_ms: int, player_count: int) -> void:
		if _closed:
			return
		_write_line("status:%s-PERSON PLAY" % _player_count_label(player_count))
		_write_line("play:%d" % (play_at_epoch_ms + _offset_ms))
		close()

	func close() -> void:
		if _closed:
			return
		_closed = true
		if _peer != null:
			_peer.disconnect_from_host()
		_peer = null

	func _send_sync_request() -> void:
		_set_status("Syncing:%d / %d" % [_sync_index, SYNC_TIMES])
		_write_line("time?")
		_write_line("status:Syncing%d / %d" % [_sync_index, SYNC_TIMES])
		_sent_at_epoch_ms = _current_epoch_ms()
		_waiting_for_time = true

	func _read_available_lines() -> void:
		var available: int = _peer.get_available_bytes()
		if available <= 0:
			return
		_read_buffer += _peer.get_utf8_string(available)
		if _read_buffer.length() > READ_BUFFER_LIMIT:
			_fail("Read error.")
			return

		while true:
			var newline_index: int = _read_buffer.find("\n")
			if newline_index < 0:
				return
			var line: String = _read_buffer.substr(0, newline_index)
			_read_buffer = _read_buffer.substr(newline_index + 1)
			_handle_line(line.strip_edges())
			if _closed or _synchronized:
				return

	func _handle_line(line: String) -> void:
		if not _waiting_for_time:
			return
		if not line.is_valid_int():
			_fail("Read error.")
			return

		var now_ms := _current_epoch_ms()
		var round_trip_ms: int = max(now_ms - _sent_at_epoch_ms, 0)
		var client_epoch_at_now: int = int(line) + round_trip_ms / 2
		if _sync_index == 1 or round_trip_ms < _best_latency_ms:
			_best_latency_ms = round_trip_ms
			_offset_ms = client_epoch_at_now - now_ms

		_sync_index += 1
		_waiting_for_time = false
		if _sync_index >= SYNC_TIMES:
			_write_line("synced")
			_write_line("status:Waiting for other players...")
			_synchronized = true
			_set_status("Client synchronized. Offset:%d" % _offset_ms)

	func _write_line(line: String) -> void:
		if _peer == null:
			return
		var error: int = _peer.put_data((line + "\n").to_utf8_buffer())
		if error != OK:
			_fail("Read error.")

	func _set_status(status: String) -> void:
		_status = status

	func _fail(status: String) -> void:
		_set_status(status)
		close()

	func _player_count_label(player_count: int) -> String:
		if player_count == 1:
			return "SINGLE"
		if player_count == 2:
			return "TWO"
		if player_count == 3:
			return "THREE"
		if player_count == 4:
			return "FOUR"
		return str(player_count)

	func _current_epoch_ms() -> int:
		return int(Time.get_unix_time_from_system() * 1000.0)


func start(port: int) -> void:
	stop()
	_port = port
	_status = STATUS_STARTING
	_server = TCPServer.new()
	var error: int = _server.listen(_port)
	if error != OK:
		_status = "Cannot start server:%s" % error
		_server = null
		return
	_status = "Listening on port%d" % _port


func start_with_state(status: String, raw_connections: Array) -> void:
	stop()
	_status = status
	for raw_connection: Variant in raw_connections:
		if not raw_connection is Dictionary:
			continue
		var connection := PartytimeConnection.new()
		connection.start_with_status(
				str(raw_connection.get("host", "")),
				str(raw_connection.get("status", "")))
		_connections.append(connection)


func add_peer_connection(host: String, peer) -> void:
	var connection := PartytimeConnection.new()
	connection.start_with_peer(peer, host)
	_connections.append(connection)


func poll() -> void:
	if _server != null:
		while _server.is_connection_available():
			var peer: Variant = _server.take_connection()
			add_peer_connection(_connected_host(peer), peer)

	for connection: PartytimeConnection in _connections.duplicate():
		connection.poll()
		if connection.is_closed():
			_connections.erase(connection)


func start_game(play_at_epoch_ms: int = -1) -> void:
	var playable_connections := _connections.duplicate()
	_connections.clear()
	var resolved_play_at := play_at_epoch_ms
	if resolved_play_at < 0:
		resolved_play_at = _current_epoch_ms() + PLAY_DELAY_MS
	for connection: PartytimeConnection in playable_connections:
		connection.go(resolved_play_at, playable_connections.size())


func stop() -> void:
	if _server != null:
		_server.stop()
	_server = null
	for connection: PartytimeConnection in _connections:
		connection.close()
	_connections.clear()


func status() -> String:
	return _status


func connections() -> Array:
	return _connections.duplicate()


func status_texts() -> Array:
	var texts: Array = ["Server: " + _status]
	for connection: PartytimeConnection in _connections:
		texts.append("%s: %s" % [connection.host(), connection.status()])
	return texts


func _connected_host(peer) -> String:
	if peer != null and peer.has_method("get_connected_host"):
		return str(peer.get_connected_host())
	return ""


func _current_epoch_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)
