extends Node

signal connection_status_changed(message: String, connected: bool)
signal roster_updated(players: Array)
signal player_states_updated(states: Array)

const DEFAULT_PORT := 2456
const MAX_CLIENTS := 32
const PLAYER_SPEED := 6.2
const PLAYER_JUMP_VELOCITY := 7.0
const INPUT_TIMEOUT_MSEC := 250
const ISSUE_TICKET_PATH := "/functions/v1/issue-game-ticket"
const REDEEM_TICKET_PATH := "/functions/v1/redeem-game-ticket"
const AUTH_TIMEOUT_SECONDS := 12.0
const HTTP_TIMEOUT_SECONDS := 8.0

var peer: ENetMultiplayerPeer
var player_roster: Array = []
var last_error := ""
var is_dedicated_server := false
var connected_peers: Dictionary = {}
var server_players: Dictionary = {}
var server_bodies: Dictionary = {}
var verified_peer_identities: Dictionary = {}
var user_to_peer: Dictionary = {}
var ticket_http_requests: Dictionary = {}
var state_broadcast_timer := 0.0
var server_gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var supabase_url := ""
var supabase_public_key := ""
var game_server_shared_secret := ""
var game_ticket_http: HTTPRequest
var ticket_request_generation := 0
var is_ticket_request_pending := false
var pending_game_ticket := ""
var pending_server_address := ""
var pending_server_port := DEFAULT_PORT

func _ready() -> void:
	is_dedicated_server = OS.get_cmdline_user_args().has("--server")
	if is_dedicated_server:
		if not _load_server_configuration():
			push_error("PROJECT UNKNOWN server configuration is incomplete; refusing to listen.")
			get_tree().quit(1)
			return
		_start_dedicated_server()
		return

	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_authenticating.connect(_on_peer_authenticating)
	multiplayer.peer_authentication_failed.connect(_on_peer_authentication_failed)
	multiplayer.auth_callback = Callable(self, "_on_client_auth_payload")

func configure_identity_backend(url: String, publishable_key: String) -> void:
	supabase_url = url.strip_edges().trim_suffix("/")
	supabase_public_key = publishable_key.strip_edges()

func _load_server_configuration() -> bool:
	supabase_url = OS.get_environment("PROJECT_UNKNOWN_SUPABASE_URL").strip_edges().trim_suffix("/")
	supabase_public_key = OS.get_environment("PROJECT_UNKNOWN_SUPABASE_PUBLIC_KEY").strip_edges()
	game_server_shared_secret = OS.get_environment("PROJECT_UNKNOWN_GAME_SERVER_SHARED_SECRET")
	if not supabase_url.begins_with("https://"):
		push_error("PROJECT_UNKNOWN_SUPABASE_URL must be an HTTPS URL.")
		return false
	if supabase_public_key.is_empty():
		push_error("PROJECT_UNKNOWN_SUPABASE_PUBLIC_KEY is missing.")
		return false
	if game_server_shared_secret.length() < 32:
		push_error("PROJECT_UNKNOWN_GAME_SERVER_SHARED_SECRET must contain at least 32 characters.")
		return false
	return true

func _start_dedicated_server() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.peer_authentication_failed.connect(_on_peer_authentication_failed)
	peer = ENetMultiplayerPeer.new()
	var result := peer.create_server(DEFAULT_PORT, MAX_CLIENTS)
	if result != OK:
		push_error("PROJECT UNKNOWN server failed to start: " + error_string(result))
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	multiplayer.auth_timeout = AUTH_TIMEOUT_SECONDS
	multiplayer.auth_callback = Callable(self, "_on_server_auth_payload")
	_create_server_world()
	print("PROJECT UNKNOWN authenticated development server listening on UDP %d (max %d clients)" % [DEFAULT_PORT, MAX_CLIENTS])

func _create_server_world() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "ServerFloor"
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(256, 1, 256)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	add_child(floor_body)

func _physics_process(delta: float) -> void:
	if not is_dedicated_server:
		return
	var now_msec := Time.get_ticks_msec()
	for peer_id in server_players.keys():
		var body: CharacterBody3D = server_bodies.get(peer_id)
		if not is_instance_valid(body):
			continue
		var state: Dictionary = server_players[peer_id]
		var last_input_msec := int(state.get("last_input_msec", 0))
		if now_msec - last_input_msec > INPUT_TIMEOUT_MSEC:
			state["input"] = Vector2.ZERO
			state["jump"] = false
		var input_direction: Vector2 = state.get("input", Vector2.ZERO)
		body.velocity.x = input_direction.x * PLAYER_SPEED
		body.velocity.z = input_direction.y * PLAYER_SPEED
		if body.is_on_floor():
			if bool(state.get("jump", false)):
				body.velocity.y = PLAYER_JUMP_VELOCITY
				state["jump"] = false
		else:
			body.velocity.y -= server_gravity * delta
		body.move_and_slide()
		server_players[peer_id] = state
	state_broadcast_timer += delta
	if state_broadcast_timer >= 0.05:
		state_broadcast_timer = 0.0
		_broadcast_player_states()

func connect_to_server(address: String, port: int = DEFAULT_PORT) -> Error:
	if is_dedicated_server:
		return ERR_UNAVAILABLE
	if not Session.is_authenticated or Session.access_token.is_empty():
		last_error = "Сначала войди в аккаунт PROJECT UNKNOWN."
		connection_status_changed.emit(last_error, false)
		return FAILED
	if supabase_url.is_empty() or supabase_public_key.is_empty():
		last_error = "Сервис игровой авторизации не настроен."
		connection_status_changed.emit(last_error, false)
		return FAILED
	if is_ticket_request_pending:
		last_error = "Проверка аккаунта уже выполняется."
		connection_status_changed.emit(last_error, false)
		return ERR_BUSY

	var host := address.strip_edges()
	if host.is_empty() or port < 1 or port > 65535:
		last_error = "Укажи адрес и порт от 1 до 65535."
		connection_status_changed.emit(last_error, false)
		return ERR_INVALID_PARAMETER
	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		disconnect_from_server()

	pending_server_address = host
	pending_server_port = port
	pending_game_ticket = ""
	var request_error := _request_game_ticket()
	if request_error != OK:
		last_error = "Не удалось начать проверку аккаунта: " + error_string(request_error)
		connection_status_changed.emit(last_error, false)
		return request_error
	connection_status_changed.emit("Проверяю аккаунт перед подключением…", false)
	return OK

func _request_game_ticket() -> Error:
	if is_ticket_request_pending:
		return ERR_BUSY
	ticket_request_generation += 1
	var request_generation := ticket_request_generation
	var request := HTTPRequest.new()
	request.timeout = HTTP_TIMEOUT_SECONDS
	add_child(request)
	game_ticket_http = request
	request.request_completed.connect(_on_game_ticket_issue_completed.bind(request_generation, request))
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"apikey: " + supabase_public_key,
		"Authorization: Bearer " + Session.access_token,
		"Accept: application/json"
	])
	is_ticket_request_pending = true
	var request_error := request.request(
		supabase_url + ISSUE_TICKET_PATH,
		headers,
		HTTPClient.METHOD_POST,
		"{}"
	)
	if request_error != OK:
		is_ticket_request_pending = false
		game_ticket_http = null
		request.queue_free()
	return request_error

func _on_game_ticket_issue_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request_generation: int, request: HTTPRequest) -> void:
	if game_ticket_http != request or request_generation != ticket_request_generation:
		return
	game_ticket_http = null
	request.queue_free()
	if not is_ticket_request_pending:
		return
	is_ticket_request_pending = false
	if not Session.is_authenticated:
		pending_game_ticket = ""
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300 or typeof(parsed) != TYPE_DICTIONARY:
		last_error = "Не удалось получить временный игровой билет. Проверь соединение и повтори попытку."
		connection_status_changed.emit(last_error, false)
		return
	var ticket := str(parsed.get("ticket", ""))
	if not _is_ticket_format_valid(ticket):
		last_error = "Сервис авторизации вернул некорректный игровой билет."
		connection_status_changed.emit(last_error, false)
		return
	pending_game_ticket = ticket
	_start_enet_client()

func _start_enet_client() -> void:
	peer = ENetMultiplayerPeer.new()
	var result := peer.create_client(pending_server_address, pending_server_port)
	if result != OK:
		pending_game_ticket = ""
		last_error = "Не удалось создать подключение: " + error_string(result)
		connection_status_changed.emit(last_error, false)
		peer = null
		return
	multiplayer.auth_timeout = AUTH_TIMEOUT_SECONDS
	multiplayer.auth_callback = Callable(self, "_on_client_auth_payload")
	multiplayer.multiplayer_peer = peer
	connection_status_changed.emit("Подключение к %s:%d…" % [pending_server_address, pending_server_port], false)

func _on_peer_authenticating(peer_id: int) -> void:
	if is_dedicated_server:
		return
	if peer_id != 1 or pending_game_ticket.is_empty():
		multiplayer.disconnect_peer(peer_id)
		last_error = "Сервер не прошёл проверку игровой сессии."
		connection_status_changed.emit(last_error, false)
		return
	var send_error: int = multiplayer.send_auth(peer_id, pending_game_ticket.to_utf8_buffer())
	if send_error != OK:
		pending_game_ticket = ""
		multiplayer.disconnect_peer(peer_id)
		last_error = "Не удалось отправить игровой билет серверу."
		connection_status_changed.emit(last_error, false)
		return
	pending_game_ticket = ""
	var complete_error: int = multiplayer.complete_auth(peer_id)
	if complete_error != OK:
		multiplayer.disconnect_peer(peer_id)
		last_error = "Не удалось завершить локальную проверку соединения."
		connection_status_changed.emit(last_error, false)

func _on_client_auth_payload(_peer_id: int, _payload: PackedByteArray) -> void:
	# The server does not send client credentials. This callable enables the
	# built-in peer_authenticating signal; the client sends its one-time ticket.
	pass

func _on_server_auth_payload(peer_id: int, payload: PackedByteArray) -> void:
	if not is_dedicated_server or not multiplayer.get_authenticating_peers().has(peer_id):
		return
	var ticket := payload.get_string_from_utf8().strip_edges()
	if not _is_ticket_format_valid(ticket):
		multiplayer.disconnect_peer(peer_id)
		return
	_redeem_game_ticket(peer_id, ticket)

func _redeem_game_ticket(peer_id: int, ticket: String) -> void:
	if ticket_http_requests.has(peer_id) or game_server_shared_secret.is_empty():
		multiplayer.disconnect_peer(peer_id)
		return
	var request := HTTPRequest.new()
	request.timeout = HTTP_TIMEOUT_SECONDS
	add_child(request)
	ticket_http_requests[peer_id] = request
	request.request_completed.connect(_on_game_ticket_redeemed.bind(peer_id, request))
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"apikey: " + supabase_public_key,
		"x-game-server-secret: " + game_server_shared_secret,
		"Accept: application/json"
	])
	var request_error := request.request(
		supabase_url + REDEEM_TICKET_PATH,
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify({"ticket": ticket})
	)
	if request_error != OK:
		_cleanup_peer_auth(peer_id)
		multiplayer.disconnect_peer(peer_id)

func _on_game_ticket_redeemed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, peer_id: int, request: HTTPRequest) -> void:
	if ticket_http_requests.get(peer_id) != request:
		return
	ticket_http_requests.erase(peer_id)
	request.queue_free()
	if not multiplayer.get_authenticating_peers().has(peer_id):
		return
	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300 or typeof(parsed) != TYPE_DICTIONARY:
		multiplayer.disconnect_peer(peer_id)
		return

	var user_id := str(parsed.get("user_id", ""))
	if not _is_uuid_valid(user_id) or user_to_peer.has(user_id):
		multiplayer.disconnect_peer(peer_id)
		return
	var username := str(parsed.get("username", "player")).strip_edges().left(20)
	var display_name := str(parsed.get("display_name", username)).strip_edges().left(32)
	if username.is_empty():
		username = "player"
	if display_name.is_empty():
		display_name = username

	verified_peer_identities[peer_id] = {
		"user_id": user_id,
		"username": username,
		"display_name": display_name
	}
	user_to_peer[user_id] = peer_id
	var complete_error: int = multiplayer.complete_auth(peer_id)
	if complete_error != OK:
		_cleanup_peer_auth(peer_id)
		multiplayer.disconnect_peer(peer_id)

func _is_ticket_format_valid(ticket: String) -> bool:
	if ticket.length() != 64:
		return false
	var expression := RegEx.new()
	expression.compile("^[0-9a-f]{64}$")
	return expression.search(ticket) != null

func _is_uuid_valid(user_id: String) -> bool:
	var expression := RegEx.new()
	expression.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$")
	return expression.search(user_id) != null

func _cleanup_peer_auth(peer_id: int) -> void:
	if ticket_http_requests.has(peer_id):
		var request: HTTPRequest = ticket_http_requests[peer_id]
		ticket_http_requests.erase(peer_id)
		if is_instance_valid(request):
			request.cancel_request()
			request.queue_free()
	var identity: Dictionary = verified_peer_identities.get(peer_id, {})
	var user_id := str(identity.get("user_id", ""))
	if not user_id.is_empty() and int(user_to_peer.get(user_id, -1)) == peer_id:
		user_to_peer.erase(user_id)
	verified_peer_identities.erase(peer_id)

func _on_peer_authentication_failed(peer_id: int) -> void:
	_cleanup_peer_auth(peer_id)
	if not is_dedicated_server:
		pending_game_ticket = ""
		last_error = "Игровой сервер отклонил проверку аккаунта."
		connection_status_changed.emit(last_error, false)

func _on_peer_connected(peer_id: int) -> void:
	if not verified_peer_identities.has(peer_id):
		multiplayer.disconnect_peer(peer_id)
		return
	var identity: Dictionary = verified_peer_identities[peer_id]
	connected_peers[peer_id] = identity.duplicate(true)
	server_players[peer_id] = {"input": Vector2.ZERO, "jump": false, "last_input_msec": Time.get_ticks_msec()}
	var spawn_index := server_players.size() - 1
	var body := CharacterBody3D.new()
	body.name = "ServerPlayer_%d" % peer_id
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	body.add_child(collision)
	body.position = Vector3(float((spawn_index % 5) - 2) * 2.5, 1.0, 4.0 + float(spawn_index / 5) * 2.5)
	add_child(body)
	server_bodies[peer_id] = body
	_broadcast_roster()
	_broadcast_player_states()
	print("Authenticated player connected: %s (peer %d)" % [str(identity.get("username", "player")), peer_id])

func _on_peer_disconnected(peer_id: int) -> void:
	connected_peers.erase(peer_id)
	server_players.erase(peer_id)
	_cleanup_peer_auth(peer_id)
	var body: CharacterBody3D = server_bodies.get(peer_id)
	if is_instance_valid(body):
		body.queue_free()
	server_bodies.erase(peer_id)
	_broadcast_roster()
	_broadcast_player_states()

@rpc("any_peer", "call_remote", "reliable")
func request_roster() -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if sender_id <= 0 or not connected_peers.has(sender_id):
		return
	rpc_id(sender_id, "receive_roster", _build_roster())

func _sanitize_movement_direction(direction: Vector2) -> Vector2:
	if not is_finite(direction.x) or not is_finite(direction.y):
		return Vector2.ZERO
	return direction.limit_length(1.0)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_movement_input(direction: Vector2, jump_pressed: bool) -> void:
	if not is_dedicated_server:
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if not server_players.has(sender_id):
		return
	var now_msec := Time.get_ticks_msec()
	var state: Dictionary = server_players[sender_id]
	var last_input_msec := int(state.get("last_input_msec", 0))
	if now_msec - last_input_msec < 15:
		return
	state["input"] = _sanitize_movement_direction(direction)
	state["jump"] = jump_pressed
	state["last_input_msec"] = now_msec
	server_players[sender_id] = state

@rpc("authority", "call_remote", "reliable")
func receive_roster(players: Array) -> void:
	if is_dedicated_server:
		return
	player_roster = players.duplicate(true)
	roster_updated.emit(player_roster)

@rpc("authority", "call_remote", "unreliable_ordered")
func receive_player_states(states: Array) -> void:
	if not is_dedicated_server:
		player_states_updated.emit(states)

func _broadcast_player_states() -> void:
	if not is_dedicated_server or multiplayer.multiplayer_peer == null:
		return
	var states: Array = []
	for peer_id in server_bodies.keys():
		var body: CharacterBody3D = server_bodies[peer_id]
		if is_instance_valid(body):
			states.append({"peer_id": peer_id, "position": body.global_position})
	rpc("receive_player_states", states)

func _broadcast_roster() -> void:
	if not is_dedicated_server or multiplayer.multiplayer_peer == null:
		return
	rpc("receive_roster", _build_roster())

func _build_roster() -> Array:
	var roster: Array = []
	for peer_id in connected_peers.keys():
		var identity: Dictionary = connected_peers[peer_id]
		roster.append({
			"peer_id": peer_id,
			"username": str(identity.get("username", "player")),
			"display_name": str(identity.get("display_name", "player"))
		})
	return roster

func send_local_input(direction: Vector2, jump_pressed: bool) -> void:
	if not is_connected_to_server():
		return
	rpc_id(1, "submit_movement_input", direction.limit_length(1.0), jump_pressed)

func disconnect_from_server() -> void:
	if is_dedicated_server:
		return
	ticket_request_generation += 1
	var request_to_cancel := game_ticket_http
	game_ticket_http = null
	if is_ticket_request_pending and is_instance_valid(request_to_cancel):
		request_to_cancel.cancel_request()
		request_to_cancel.queue_free()
	is_ticket_request_pending = false
	pending_game_ticket = ""
	pending_server_address = ""
	pending_server_port = DEFAULT_PORT
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peer = null
	player_roster.clear()
	roster_updated.emit(player_roster)
	connection_status_changed.emit("Офлайн", false)

func is_connected_to_server() -> bool:
	return not is_dedicated_server and multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func _on_connected_to_server() -> void:
	last_error = ""
	connection_status_changed.emit("Подключено к игровому серверу", true)
	rpc_id(1, "request_roster")

func _on_connection_failed() -> void:
	pending_game_ticket = ""
	last_error = "Не удалось подключиться. Проверь адрес, порт и доступность сервера."
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peer = null
	connection_status_changed.emit(last_error, false)

func _on_server_disconnected() -> void:
	pending_game_ticket = ""
	peer = null
	player_roster.clear()
	roster_updated.emit(player_roster)
	connection_status_changed.emit("Соединение с сервером потеряно", false)
