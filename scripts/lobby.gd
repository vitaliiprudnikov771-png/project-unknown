extends Node3D

const PLAYER_SCRIPT := preload("res://scripts/voxel_player.gd")
const CONTROLS_SCRIPT := preload("res://scripts/mobile_controls.gd")

var status_label: Label
var network_label: Label
var server_address_input: LineEdit
var server_port_input: LineEdit
var local_player: CharacterBody3D
var remote_player_nodes: Dictionary = {}

func _ready() -> void:
	if not Session.is_authenticated or Session.current_user_id.is_empty():
		get_tree().change_scene_to_file("res://auth.tscn")
		return
	Network.connection_status_changed.connect(_on_network_status_changed)
	Network.roster_updated.connect(_on_roster_updated)
	Network.player_states_updated.connect(_on_player_states_updated)
	_build_environment()
	_build_world()
	_spawn_local_player()
	_build_interface()

func _build_environment() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#8cc9e8")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#c8e5ff")
	environment.ambient_light_energy = 0.7
	environment_node.environment = environment
	add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)

func _build_world() -> void:
	_add_box("LobbyFloor", Vector3(0, -0.55, 0), Vector3(54, 1, 54), Color("#536b72"), true)
	_add_box("SpawnPlatform", Vector3(0, 0.12, 0), Vector3(12, 0.35, 12), Color("#8b9da4"), true)
	_add_box("CentralCore", Vector3(0, 2.1, -8), Vector3(4.2, 4.2, 1.2), Color("#2563eb"), true)
	_add_box("CoreGlow", Vector3(0, 4.45, -8), Vector3(2.4, 0.25, 1.45), Color("#7dd3fc"), false)

	for i in range(12):
		var angle := TAU * float(i) / 12.0
		var ring_position := Vector3(cos(angle) * 9.0, 0.55, sin(angle) * 9.0)
		_add_box("RingBlock_%02d" % i, ring_position, Vector3(1.5, 1.1, 1.5), Color("#718b93"), true)

	for i in range(8):
		var x := -17.5 + float(i) * 5.0
		_add_box("EdgePillar_%02d" % i, Vector3(x, 1.0, -21), Vector3(2.0, 2.0, 2.0), Color("#607d8b"), true)
		_add_box("EdgePillarBack_%02d" % i, Vector3(x, 1.0, 21), Vector3(2.0, 2.0, 2.0), Color("#607d8b"), true)

	_add_box("ModeGateBlue", Vector3(-12, 2.0, -11), Vector3(4.0, 4.0, 1.0), Color("#2563eb"), true)
	_add_box("ModeGateGreen", Vector3(12, 2.0, -11), Vector3(4.0, 4.0, 1.0), Color("#16a34a"), true)
	_add_box("ModeGateGold", Vector3(0, 2.0, 13), Vector3(4.0, 4.0, 1.0), Color("#d97706"), true)

func _add_box(node_name: String, position_3d: Vector3, dimensions: Vector3, color: Color, solid: bool) -> void:
	var root: Node3D
	if solid:
		var body := StaticBody3D.new()
		body.name = node_name
		root = body
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = dimensions
		collision.shape = shape
		body.add_child(collision)
	else:
		var visual_root := Node3D.new()
		visual_root.name = node_name
		root = visual_root

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	mesh_instance.material_override = material
	root.add_child(mesh_instance)
	root.position = position_3d
	add_child(root)

func _spawn_local_player() -> void:
	var player := CharacterBody3D.new()
	player.name = "LocalPlayer"
	player.set_script(PLAYER_SCRIPT)
	player.position = Vector3(0, 1.2, 4.0)
	local_player = player
	add_child(player)

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 14)
	panel.custom_minimum_size = Vector2(260, 62)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var title := Label.new()
	title.text = "PROJECT UNKNOWN  •  LOBBY"
	title.add_theme_font_size_override("font_size", 17)
	box.add_child(title)
	status_label = Label.new()
	var profile: Dictionary = Session.current_profile
	var username := str(profile.get("username", "player"))
	var level := int(profile.get("level", 1))
	status_label.text = "@%s  •  Уровень %d  •  Монеты %d" % [username, level, int(profile.get("coins", 0))]
	status_label.add_theme_font_size_override("font_size", 11)
	box.add_child(status_label)
	network_label = Label.new()
	network_label.text = "Офлайн • сервер не подключён"
	network_label.add_theme_font_size_override("font_size", 11)
	box.add_child(network_label)
	server_address_input = LineEdit.new()
	server_address_input.placeholder_text = "IP или домен игрового сервера"
	server_address_input.custom_minimum_size = Vector2(240, 0)
	box.add_child(server_address_input)
	server_port_input = LineEdit.new()
	server_port_input.text = str(Network.DEFAULT_PORT)
	server_port_input.placeholder_text = "Порт"
	server_port_input.custom_minimum_size = Vector2(100, 0)
	box.add_child(server_port_input)
	var connect_button := Button.new()
	connect_button.text = "Подключиться"
	connect_button.pressed.connect(_connect_to_game_server)
	box.add_child(connect_button)

	var controls := Control.new()
	controls.set_script(CONTROLS_SCRIPT)
	layer.add_child(controls)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().change_scene_to_file("res://auth.tscn")

func _connect_to_game_server() -> void:
	var port := int(server_port_input.text)
	Network.connect_to_server(server_address_input.text, port)

func _on_network_status_changed(message: String, connected: bool) -> void:
	if is_instance_valid(network_label):
		network_label.text = message
		if connected:
			network_label.add_theme_color_override("font_color", Color("#34d399"))
		else:
			network_label.add_theme_color_override("font_color", Color("#fbbf24"))

func _on_roster_updated(players: Array) -> void:
	if is_instance_valid(network_label) and Network.is_connected_to_server():
		network_label.text = "Онлайн • игроков: %d" % players.size()

func _on_player_states_updated(states: Array) -> void:
	if not Network.is_connected_to_server():
		return
	var visible_peer_ids: Dictionary = {}
	for state_value in states:
		if typeof(state_value) != TYPE_DICTIONARY:
			continue
		var state: Dictionary = state_value
		var peer_id := int(state.get("peer_id", 0))
		var server_position: Vector3 = state.get("position", Vector3.ZERO)
		if peer_id <= 0:
			continue
		if peer_id == multiplayer.get_unique_id():
			if is_instance_valid(local_player):
				local_player.global_position = local_player.global_position.lerp(server_position, 0.18)
			continue
		visible_peer_ids[peer_id] = true
		if not remote_player_nodes.has(peer_id):
			remote_player_nodes[peer_id] = _create_remote_player(peer_id)
		var remote_player: Node3D = remote_player_nodes[peer_id]
		remote_player.global_position = remote_player.global_position.lerp(server_position, 0.35)
	for peer_id in remote_player_nodes.keys().duplicate():
		if not visible_peer_ids.has(peer_id):
			var stale_player: Node3D = remote_player_nodes[peer_id]
			stale_player.queue_free()
			remote_player_nodes.erase(peer_id)

func _create_remote_player(peer_id: int) -> Node3D:
	var remote_player := Node3D.new()
	remote_player.name = "RemotePlayer_%d" % peer_id
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.42
	body_mesh.height = 1.75
	body.mesh = body_mesh
	body.position.y = 0.9
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.from_hsv(fposmod(float(peer_id) * 0.173, 1.0), 0.62, 0.92)
	body.material_override = material
	remote_player.add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.62, 0.62, 0.62)
	head.mesh = head_mesh
	head.position.y = 1.95
	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = Color("#f1c7a5")
	head.material_override = head_material
	remote_player.add_child(head)
	add_child(remote_player)
	return remote_player
