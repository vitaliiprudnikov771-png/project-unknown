extends Node2D

const PLAYER_SCENE_SCRIPT = preload("res://scripts/player.gd")
const JOYSTICK_SCRIPT = preload("res://scripts/joystick.gd")
const PORT := 24560
const WORLD_SIZE := Vector2(1800, 1200)

var players: Dictionary = {}
var local_peer_id := 1
var touch_vector := Vector2.ZERO
var status_label: Label
var ip_input: LineEdit
var network_status := "ОФФЛАЙН • ЛОКАЛЬНЫЙ ПРОТОТИП"
var net_sync_accumulator := 0.0

func _ready() -> void:
	_build_world()
	_build_ui()
	_spawn_player(1)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _process(delta: float) -> void:
	if multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		net_sync_accumulator += delta
		if net_sync_accumulator >= 0.05:
			net_sync_accumulator = 0.0
			var p: Node2D = players.get(local_peer_id)
			if p != null:
				if multiplayer.is_server():
					rpc("receive_position", local_peer_id, p.global_position)
				else:
					rpc_id(1, "submit_position", p.global_position)
	_update_ui_status()

func _build_world() -> void:
	var bg := ColorRect.new()
	bg.color = Color("151c28")
	bg.size = WORLD_SIZE
	bg.position = -WORLD_SIZE / 2.0
	bg.z_index = -100
	add_child(bg)
	for i in range(70):
		var dot := ColorRect.new()
		dot.color = Color("263447")
		dot.size = Vector2(3, 3)
		dot.position = Vector2(randf_range(-850, 850), randf_range(-550, 550))
		dot.z_index = -90
		add_child(dot)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var joystick = Control.new()	
	joystick.set_script(JOYSTICK_SCRIPT)
	joystick.vector_changed.connect(func(value: Vector2): touch_vector = value)
	layer.add_child(joystick)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 14)
	panel.custom_minimum_size = Vector2(330, 110)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "PROJECT UNKNOWN  /  TEST BUILD 0.1"
	title.add_theme_font_size_override("font_size", 17)
	box.add_child(title)
	status_label = Label.new()
	status_label.text = network_status
	box.add_child(status_label)
	var row := HBoxContainer.new()
	box.add_child(row)
	ip_input = LineEdit.new()
	ip_input.placeholder_text = "IP хоста в Wi-Fi сети"
	ip_input.text = "127.0.0.1"
	ip_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ip_input)
	var host_button := Button.new()
	host_button.text = "Создать"
	host_button.pressed.connect(_host_game)
	row.add_child(host_button)
	var join_button := Button.new()
	join_button.text = "Войти"
	join_button.pressed.connect(_join_game)
	row.add_child(join_button)
	var hint := Label.new()
	hint.text = "Для первого сетевого теста: оба устройства в одной Wi-Fi сети."
	hint.add_theme_font_size_override("font_size", 12)
	box.add_child(hint)

func _host_game() -> void:
	_close_peer()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 8)
	if err != OK:
		_set_status("ОШИБКА СОЗДАНИЯ СЕРВЕРА: %s" % error_string(err))
		return
	multiplayer.multiplayer_peer = peer
	local_peer_id = 1
	_set_status("ХОСТ • порт %d • ожидание игроков" % PORT)

func _join_game() -> void:
	_close_peer()
	var address := ip_input.text.strip_edges()
	if address.is_empty():
		_set_status("ВВЕДИ IP-АДРЕС ХОСТА")
		return
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, PORT)
	if err != OK:
		_set_status("ОШИБКА ПОДКЛЮЧЕНИЯ: %s" % error_string(err))
		return
	multiplayer.multiplayer_peer = peer
	_set_status("ПОДКЛЮЧЕНИЕ К %s..." % address)

func _close_peer() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	for id in players.keys():
		if id != 1:
			_remove_player(id)

func _on_connected_to_server() -> void:
	local_peer_id = multiplayer.get_unique_id()
	for id in players.keys():
		players[id].is_local = int(id) == local_peer_id
	_spawn_player(local_peer_id)
	rpc_id(1, "request_player_list")
	_set_status("ПОДКЛЮЧЕНО • игрок #%d" % local_peer_id)

func _on_connection_failed() -> void:
	_set_status("НЕ УДАЛОСЬ ПОДКЛЮЧИТЬСЯ")
	_close_peer()

func _on_server_disconnected() -> void:
	_set_status("СОЕДИНЕНИЕ СЕРВЕРОМ ПОТЕРЯНО")
	_close_peer()

func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		for existing_id in [1] + multiplayer.get_peers():
			rpc("register_player", int(existing_id))
		_set_status("ИГРОК #%d ПОДКЛЮЧИЛСЯ" % id)

func _on_peer_disconnected(id: int) -> void:
	_remove_player(id)
	_set_status("ИГРОК #%d ВЫШЕЛ" % id)

@rpc("any_peer", "reliable")
func request_player_list() -> void:
	if not multiplayer.is_server():
		return
	var requester := multiplayer.get_remote_sender_id()
	for id in [1] + multiplayer.get_peers():
		rpc_id(requester, "register_player", int(id))

@rpc("authority", "call_local", "reliable")
func register_player(id: int) -> void:
	_spawn_player(id)

@rpc("any_peer", "unreliable")
func submit_position(pos: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	rpc("receive_position", sender, pos)

@rpc("authority", "call_local", "unreliable")
func receive_position(id: int, pos: Vector2) -> void:
	if id == local_peer_id:
		return
	var p: Node2D = players.get(id)
	if p != null:
		p.global_position = pos

func _spawn_player(id: int) -> void:
	if players.has(id):
		return
	var player := Node2D.new()
	player.set_script(PLAYER_SCENE_SCRIPT)
	player.name = "Player_%d" % id
	player.peer_id = id
	player.is_local = id == local_peer_id
	player.position = Vector2((id % 4) * 55.0 - 80.0, 0)
	add_child(player)
	players[id] = player
	if id == local_peer_id:
		var camera := Camera2D.new()
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 7.0
		player.add_child(camera)
		camera.make_current()

func _remove_player(id: int) -> void:
	if players.has(id):
		players[id].queue_free()
		players.erase(id)

func get_local_input() -> Vector2:
	var keyboard := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	return keyboard if keyboard.length() > 0.1 else touch_vector

func _set_status(value: String) -> void:
	network_status = value
	_update_ui_status()

func _update_ui_status() -> void:
	if is_instance_valid(status_label):
		status_label.text = network_status
