extends CharacterBody3D

@export var speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var crouch_speed: float = 2.5
@export var jump_velocity: float = 7.0
@export var mouse_sensitivity: float = 0.002

# Physics
@export var gravity: float = 20.0
@export var friction: float = 5.0

var camera: Camera3D
var _yaw: float = 0.0
var _pitch: float = 0.0

# Movement states
var is_sprinting: bool = false
var is_crouching: bool = false
var is_climbing: bool = false

# Climbing detection
var climb_raycast: RayCast3D
var climb_direction: Vector3 = Vector3.ZERO

func _ready() -> void:
	camera = get_node_or_null("Camera3D")
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		camera.position = Vector3(0, 1.8, 0)
		add_child(camera)
	
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Setup climbing raycast for hill climbing
	climb_raycast = RayCast3D.new()
	climb_raycast.name = "ClimbRay"
	climb_raycast.enabled = true
	climb_raycast.target_position = Vector3(0, 2, 0)
	add_child(climb_raycast)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_pitch = clamp(_pitch, deg_to_rad(-85.0), deg_to_rad(85.0))
		
		rotation.y = _yaw
		camera.rotation.x = _pitch
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	var input_dir := Vector3.ZERO
	var transform_basis := global_transform.basis

	# Get input direction
	if Input.is_key_pressed(KEY_W):
		input_dir -= transform_basis.z
	if Input.is_key_pressed(KEY_S):
		input_dir += transform_basis.z
	if Input.is_key_pressed(KEY_A):
		input_dir -= transform_basis.x
	if Input.is_key_pressed(KEY_D):
		input_dir += transform_basis.x

	# Handle sprint and crouch
	is_sprinting = Input.is_key_pressed(KEY_SHIFT)
	is_crouching = Input.is_key_pressed(KEY_CTRL)
	
	var current_speed := speed
	if is_sprinting:
		current_speed = sprint_speed
	elif is_crouching:
		current_speed = crouch_speed

	# Apply climbing logic for hills
	var on_slope := _check_climb()
	if on_slope and not is_crouching:
		input_dir += climb_direction * 2.0

	# Normalize and apply movement
	if input_dir.length() > 0:
		input_dir = input_dir.normalized() * current_speed
		velocity.x = lerp(velocity.x, input_dir.x, friction * delta)
		velocity.z = lerp(velocity.z, input_dir.z, friction * delta)
	else:
		velocity.x = lerp(velocity.x, 0.0, friction * delta)
		velocity.z = lerp(velocity.z, 0.0, friction * delta)

	# Handle jumping
	if is_on_floor() and Input.is_key_pressed(KEY_SPACE):
		velocity.y = jump_velocity

	# Apply gravity
	velocity.y -= gravity * delta

	move_and_slide()

func _check_climb() -> bool:
	# Check forward direction
	climb_raycast.target_position = Vector3(0, 2, 0)
	climb_raycast.rotation_degrees = Vector3(0, _yaw, 0)
	
	if climb_raycast.is_colliding():
		var hit_normal := climb_raycast.get_collision_normal()
		if hit_normal.y > 0.3:  # Significant upward slope
			climb_direction = Vector3(hit_normal.x, 0, hit_normal.z).normalized()
			return true
	
	# Check backward direction
	climb_raycast.target_position = Vector3(0, 2, 0)
	climb_raycast.rotation_degrees = Vector3(0, _yaw + 180, 0)
	
	if climb_raycast.is_colliding():
		var hit_normal := climb_raycast.get_collision_normal()
		if hit_normal.y > 0.3:
			climb_direction = Vector3(hit_normal.x, 0, hit_normal.z).normalized()
			return true
	
	climb_direction = Vector3.ZERO
	return false
