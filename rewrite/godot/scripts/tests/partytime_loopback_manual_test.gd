extends SceneTree

const PartytimeClient = preload("res://scripts/partytime_client.gd")
const PartytimeServer = preload("res://scripts/partytime_server.gd")

const DEFAULT_PORT: int = 27273
const SYNC_POLL_LIMIT: int = 5000
const READY_POLL_LIMIT: int = 2000


func _init() -> void:
	if not _test_real_loopback_partytime_server_and_client():
		return
	quit(0)


func _test_real_loopback_partytime_server_and_client() -> bool:
	var port := _loopback_port()
	var server = PartytimeServer.new()
	server.start(port)
	if not _expect_string(server.status(), "Listening on port%d" % port, "server listen status"):
		return false

	var client = PartytimeClient.new()
	client.start("127.0.0.1", port, 0)

	if not _wait_for_server_sync(server, client):
		server.stop()
		client.disconnect_from_host()
		return _fail("server synchronized client")

	server.start_game(_current_epoch_ms())
	if not _wait_for_client_ready(server, client):
		server.stop()
		client.disconnect_from_host()
		return _fail("client ready after server start game")

	if not _expect_string(client.status(), "Game start!", "client game start status"):
		server.stop()
		client.disconnect_from_host()
		return false
	if not _expect_int(server.connections().size(), 0, "server clears connections after start game"):
		server.stop()
		client.disconnect_from_host()
		return false

	server.stop()
	client.disconnect_from_host()
	return true


func _wait_for_server_sync(server, client) -> bool:
	for _i in range(SYNC_POLL_LIMIT):
		server.poll()
		client.poll()
		var status_texts: Array = server.status_texts()
		if status_texts.size() > 1 and str(status_texts[1]).contains("Client synchronized. Offset:"):
			return true
		OS.delay_msec(1)
	return false


func _wait_for_client_ready(server, client) -> bool:
	for _i in range(READY_POLL_LIMIT):
		server.poll()
		client.poll()
		if client.is_ready():
			return true
		OS.delay_msec(1)
	return false


func _loopback_port() -> int:
	var raw_port := OS.get_environment("OPEN2JAM_PARTYTIME_LOOPBACK_PORT").strip_edges()
	if raw_port.is_valid_int():
		return int(raw_port)
	return DEFAULT_PORT


func _current_epoch_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)


func _expect_string(actual: String, expected: String, label: String) -> bool:
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


func _fail(label: String) -> bool:
	push_error("Expected %s." % label)
	quit(1)
	return false
