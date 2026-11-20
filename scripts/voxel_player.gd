extends CharacterBody3D
class_name VoxelPlayer

const MOVE_SPEED := 6.2
const JUMP_VELOCITY := 7.0
const CAMERA_SENSITIVITY := 0.0045
const INPUT_SEND_INTERVAL := 0.05

var camera_pivot: Node3D
var camera: Camera3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var touch_look_active := false
var input_send_timer := 0.0
var jump_request_pending := false

func _ready() -> void:
	_build_character()
	_build_camera()
	floor_snap_length = 0.25

func _build_character() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)

	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.42
	body_mesh.height = 1.75
	body.mesh = body_mesh
	body.position.y = 0.9
	body.material_override = _material(Color("#3b82f6"))
	add_child(body)

	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.62, 0.62, 0.62)
	head.mesh = head_mesh
	head.position.y = 1.95
	head.material_override = _material(Color("#f1c7a5"))
	add_child(head)

func _build_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.position = Vector3(0, 1.45, 0)
	add_child(camera_pivot)
	camera = Camera3D.new()
	camera.position = Vector3(0, 1.2, 5.8)
	camera.rotation.x = deg_to_rad(-9.0)
	camera.current = true
	camera_pivot.add_child(camera)

func _physics_process(delta: float) -> void:
	var jump_pressed := is_on_floor() and Input.is_action_just_pressed("jump")
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif jump_pressed:
		velocity.y = JUMP_VELOCITY
		jump_request_pending = true

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward := -camera_pivot.global_basis.z
	var right := camera_pivot.global_basis.x
	var direction := (right * input_vector.x + forward * -input_vector.y).normalized()
	if direction.length_squared() > 0.001:
		velocity.x = direction.x * MOVE_SPEED
		velocity.z = direction.z * MOVE_SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, MOVE_SPEED * 7.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, MOVE_SPEED * 7.0 * delta)
	move_and_slide()
	input_send_timer += delta
	if input_send_timer >= INPUT_SEND_INTERVAL:
		Network.send_local_input(Vector2(direction.x, direction.z), jump_request_pending)
		jump_request_pending = false
		input_send_timer = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag and event.position.x > get_viewport().get_visible_rect().size.x * 0.42:
		camera_pivot.rotate_y(-event.relative.x * CAMERA_SENSITIVITY)
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x - event.relative.y * CAMERA_SENSITIVITY, deg_to_rad(-35), deg_to_rad(25))
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera_pivot.rotate_y(-event.relative.x * CAMERA_SENSITIVITY)
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x - event.relative.y * CAMERA_SENSITIVITY, deg_to_rad(-35), deg_to_rad(25))

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material
