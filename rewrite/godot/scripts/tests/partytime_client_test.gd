extends SceneTree

const PartytimeClient = preload("res://scripts/partytime_client.gd")

class FakePeer:
	extends RefCounted

	var incoming: String = ""
	var outgoing: String = ""
	var status: int = StreamPeerTCP.STATUS_CONNECTED
	var disconnected: bool = false

	func poll() -> int:
		return OK

	func get_status() -> int:
		return status

	func get_available_bytes() -> int:
		return incoming.to_utf8_buffer().size()

	func get_utf8_string(bytes: int) -> String:
		var data := incoming.to_utf8_buffer()
		var next_bytes: int = mini(bytes, data.size())
		var text: String = data.slice(0, next_bytes).get_string_from_utf8()
		incoming = data.slice(next_bytes).get_string_from_utf8()
		return text

	func put_data(data: PackedByteArray) -> int:
		outgoing += data.get_string_from_utf8()
		return OK

	func disconnect_from_host() -> void:
		disconnected = true


func _init() -> void:
	if not _test_client_protocol_reaches_game_start():
		return
	quit(0)


func _test_client_protocol_reaches_game_start() -> bool:
	var peer := FakePeer.new()
	var client = PartytimeClient.new()
	client.start_with_peer(peer, 0)
	if not _expect_string(client.status(), "Connected!", "connected status"):
		return false

	_write_line(peer, "status:Syncing1 / 50")
	client.poll()
	if not _expect_string(client.status(), "remote:Syncing1 / 50", "remote status"):
		return false

	_write_line(peer, "time?")
	var time_response := _wait_for_peer_line(peer, client)
	if not _expect_bool(time_response.is_valid_int(), true, "time response is integer"):
		return false

	_write_line(peer, "synced")
	client.poll()
	if not _expect_bool(client.is_ready(), false, "client waits for play"):
		return false

	_write_line(peer, "play:%d" % _current_epoch_ms())
	if not _wait_for_client_ready(client):
		return _fail("client ready")
	if not _expect_string(client.status(), "Game start!", "game start status"):
		return false

	return true


func _wait_for_peer_line(peer: FakePeer, client) -> String:
	var buffer := ""
	for _i in range(200):
		client.poll()
		if not peer.outgoing.is_empty():
			buffer += peer.outgoing
			peer.outgoing = ""
			var newline_index := buffer.find("\n")
			if newline_index >= 0:
				return buffer.substr(0, newline_index).strip_edges()
	return ""


func _wait_for_client_ready(client) -> bool:
	for _i in range(200):
		client.poll()
		if client.is_ready():
			return true
		OS.delay_msec(1)
	return false


func _write_line(peer: FakePeer, line: String) -> void:
	peer.incoming += line + "\n"


func _current_epoch_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


func _expect_bool(actual: bool, expected: bool, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true


func _expect_int(actual: int, expected: int, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true


func _expect_string(actual: String, expected: String, label: String) -> bool:
	if actual != expected:
		push_error("Expected %s '%s', got '%s'." % [label, expected, actual])
		quit(1)
		return false
	return true


func _fail(label: String) -> bool:
	push_error("Expected %s." % label)
	quit(1)
	return false
