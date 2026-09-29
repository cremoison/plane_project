extends CharacterBody3D
# Volo arcade semplificato: l'aereo va sempre dove punta.
# Niente gravità, portanza, stallo, flap o ruote (per ora).

@export_group("fuel")
@export var fuel: float = 100.0
@export var fuel_consumption_rate: float = 1.0


@export_group("graphics")
@export var plane_mesh: Node3D
@export var propeller_mesh: Node3D
@export var mesh_lean_deg: float = 35.0

var is_crashed: bool = false

@export_group("traslation")
@export var mass: float = 1.0	# kg
@export var current_throttle: float = 0.5
@export var throttle_increment: float = 0.1
@export var drag_k: float = 0.06	# drag coefficient
@export var lift_k: float = 0.006	# lift coefficient
@export var lift_max : float = 15.0	# maximum lift force
@export var cruise_speed: float = 0

@export_group("rotation")
@export var k_pitch: float = 3
@export var k_yaw: float = 1
@export var k_roll: float = 4
@export var angular_damping: float = 2
@export var stall_speed: float = 2
@export var full_control_speed: float = 30

var omega: Vector3 = Vector3.ZERO	# angular velocity (rad/s)

const G: float = 9.82	# gravity acceleration

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING	# no gravity and there is no floor or ceiling
	cruise_speed =G/lift_k


func _physics_process(delta: float) -> void:
	
	_apply_rotation(delta)

	# translation forces

	# thrust
	# input
	if Input.is_action_pressed("throttle_up"):
		current_throttle = min(current_throttle + throttle_increment * delta, 1.0)
	elif Input.is_action_pressed("throttle_down"):
		current_throttle = max(current_throttle - throttle_increment * delta, 0.0)
	
	var thrust: Vector3 = -transform.basis.z * current_throttle * 100.
	
	# drag
	var drag: Vector3 = velocity * -drag_k * velocity.length_squared()

	# lift
	var forward_speed : float = max(velocity.dot(-transform.basis.z), 0.0)
	var lift_mag : float = clamp(lift_k * forward_speed * forward_speed, 0.0, lift_max)
	var lift: Vector3 = transform.basis.y * lift_mag

	# gravity
	var gravity: Vector3 = Vector3.DOWN * mass * G

	# accelerazione = (thrust + drag + lift + gravity) / mass
	var acceleration: Vector3 = (thrust + drag + lift + gravity) / mass
	velocity += acceleration * delta

	move_and_slide()

func _apply_rotation(delta: float) -> void:
	# input
	var input_pitch := Input.get_axis("pitch_down", "pitch_up")
	var input_yaw := Input.get_axis("yaw_right", "yaw_left")
	var input_roll := Input.get_axis("roll_left", "roll_right")

	var speed := velocity.length()
	var efficiency := smoothstep(stall_speed, full_control_speed, speed)
	efficiency = max(efficiency, 0.1)	# minimum control efficiency

	var u_right := transform.basis.x
	var u_up := transform.basis.y
	var u_forward := -transform.basis.z

	# angular velocity
	var alpha: Vector3 = (
		input_pitch * u_right * k_pitch +
		input_yaw * u_up * k_yaw +
		input_roll * u_forward * k_roll
	) * efficiency

	omega += alpha * delta
	omega *= 1.0-clamp(angular_damping * delta, 0.0, 1.0)

	# apply rotation
	var w: = omega.length()
	if w > 0.0001:
		var rot := Basis(omega / w, w * delta)
		transform.basis = (rot * transform.basis).orthonormalized()

func _crash(reason: String) -> void:
	is_crashed = true
	velocity = Vector3.ZERO
	print("CRASH: ", reason)