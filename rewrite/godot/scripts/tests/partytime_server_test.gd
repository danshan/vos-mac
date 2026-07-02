extends SceneTree

const PartytimeServer = preload("res://scripts/partytime_server.gd")

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
		status = StreamPeerTCP.STATUS_NONE


func _init() -> void:
	if not _test_state_status_texts_match_java_render_strings():
		return
	if not _test_server_connection_sync_and_single_player_start():
		return
	if not _test_player_count_labels():
		return
	quit(0)


func _test_state_status_texts_match_java_render_strings() -> bool:
	var server = PartytimeServer.new()
	server.start_with_state("Listening on port1234", [
		{"host": "127.0.0.1", "status": "Client synchronized. Offset:12"},
		{"host": "192.168.0.2", "status": "Syncing:1 / 50"},
	])
	var texts: Array = server.status_texts()
	if not _expect_int(texts.size(), 3, "state status text count"):
		return false
	if not _expect_string(str(texts[0]), "Server: Listening on port1234", "state server status"):
		return false
	if not _expect_string(str(texts[1]), "127.0.0.1: Client synchronized. Offset:12", "state first connection"):
		return false
	if not _expect_string(str(texts[2]), "192.168.0.2: Syncing:1 / 50", "state second connection"):
		return false
	return true


func _test_server_connection_sync_and_single_player_start() -> bool:
	var peer := FakePeer.new()
	var server = PartytimeServer.new()
	server.start_with_state("Listening on port7273", [])
	server.add_peer_connection("127.0.0.1", peer)

	for i in range(1, 50):
		server.poll()
		if not _expect_string(_read_peer_line(peer), "time?", "sync time query %d" % i):
			return false
		if not _expect_string(_read_peer_line(peer), "status:Syncing%d / 50" % i, "sync status %d" % i):
			return false
		_write_line(peer, str(_current_epoch_ms()))
		server.poll()

	if not _expect_string(_read_peer_line(peer), "synced", "synced marker"):
		return false
	if not _expect_string(_read_peer_line(peer), "status:Waiting for other players...", "waiting status"):
		return false

	var status_texts: Array = server.status_texts()
	if not _expect_int(status_texts.size(), 2, "synced status text count"):
		return false
	if not _expect_bool(str(status_texts[1]).begins_with("127.0.0.1: Client synchronized. Offset:"), true, "synced status text"):
		return false

	server.start_game(1000000)
	if not _expect_string(_read_peer_line(peer), "status:SINGLE-PERSON PLAY", "single player play status"):
		return false
	var play_line := _read_peer_line(peer)
	if not _expect_bool(play_line.begins_with("play:"), true, "single player play line"):
		return false
	if not _expect_bool(play_line.substr(5).is_valid_int(), true, "single player play time"):
		return false
	if not _expect_bool(peer.disconnected, true, "single player connection closes"):
		return false
	if not _expect_int(server.connections().size(), 0, "connections clear after start game"):
		return false
	return true


func _test_player_count_labels() -> bool:
	if not _expect_string(_play_status_for_count(2), "status:TWO-PERSON PLAY", "two player label"):
		return false
	if not _expect_string(_play_status_for_count(3), "status:THREE-PERSON PLAY", "three player label"):
		return false
	if not _expect_string(_play_status_for_count(4), "status:FOUR-PERSON PLAY", "four player label"):
		return false
	if not _expect_string(_play_status_for_count(5), "status:5-PERSON PLAY", "five player label"):
		return false
	return true


func _play_status_for_count(count: int) -> String:
	var server = PartytimeServer.new()
	server.start_with_state("Listening on port7273", [])
	var peers: Array[FakePeer] = []
	for i in range(count):
		var peer := FakePeer.new()
		peers.append(peer)
		server.add_peer_connection("127.0.0.%d" % (i + 1), peer)
	server.start_game(1000000)
	return _read_peer_line(peers[0])


func _write_line(peer: FakePeer, line: String) -> void:
	peer.incoming += line + "\n"


func _read_peer_line(peer: FakePeer) -> String:
	var newline_index := peer.outgoing.find("\n")
	if newline_index < 0:
		return ""
	var line := peer.outgoing.substr(0, newline_index).strip_edges()
	peer.outgoing = peer.outgoing.substr(newline_index + 1)
	return line


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
