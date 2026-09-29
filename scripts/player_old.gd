extends CharacterBody3D

@export_group("Flight Settings (Precision Physics)")
@export var engine_power: float = 72.0      
@export var air_drag: float = 0.09          
@export var max_dive_speed: float = 90.0    
@export var lift_power: float = 0.65         
## Aumentata a 12.0 per dare più inerzia a terra, rendendo l'accelerazione iniziale più lenta e pesante.
@export var plane_mass: float = 12.0 
@export var gravity_assist: float = 45.0
@export var sideslip_drag_factor: float = 50.0



@export_group("Flaps & Brakes (Heavy Impact)")
@export var airbrake_drag_multiplier: float = 5.0 
@export var flap_deploy_speed: float = 1.0   

@export_group("Maneuvering (Smooth & Reactive)")
@export var pitch_speed: float = 0.85        
@export var roll_speed: float = 0.8          
@export var yaw_speed: float = 0.5           
@export var turn_assist_strength: float = 0.2

# --- STATO INTERNO ACCESSIBILE DA ALTRI SCRIPT ---
var current_speed: float = 0.0
var target_speed: float = 0.0
var is_crashed: bool = false
var flap_deployment: float = 0.0 
var true_grip: float = 1.0
var is_airbrake_active: bool = false

# Stato dei Flap
var target_flap_level: float = 0.0

# ✨ AGGIUNGI QUESTA RIGA QUI SOTTO:
var current_inertia: float = 8.0

func _physics_process(delta: float) -> void:
	if is_crashed:
		return

	# --- 0. GESTIONE FLAP ---
	if Input.is_action_just_pressed("flaps_down"):
		target_flap_level = clamp(target_flap_level + 0.5, 0.0, 1.0)
	if Input.is_action_just_pressed("flaps_up"):
		target_flap_level = clamp(target_flap_level - 0.5, 0.0, 1.0)
		
	flap_deployment = move_toward(flap_deployment, target_flap_level, flap_deploy_speed * delta)

	# --- 1. DIREZIONI BASE ---
	var forward_dir = -global_transform.basis.z
	var up_dir = global_transform.basis.y

	# --- 2. MOTORE, ATTRITO E INERZIA ---
	var throttle_input = Input.get_axis("throttle_down", "throttle_up")
	target_speed += throttle_input * 0.4 * delta # Leggermente più lenta la risposta della manetta
	target_speed = clamp(target_speed, 0.0, 1.0)
	
	var thrust = target_speed * engine_power
	var effective_air_drag = air_drag + (flap_deployment * 0.12)
	
	if forward_dir.y > 0.0:
		effective_air_drag += forward_dir.y * 0.18 
		
	var drag_force = (current_speed * current_speed) * effective_air_drag
	
	is_airbrake_active = Input.is_action_pressed("airbrake")
	if is_airbrake_active:
		drag_force *= airbrake_drag_multiplier
		drag_force += 60.0
	
	# ✨ FIX RULLAGGIO LUNGO: Aumentato drasticamente l'attrito a terra legato alla velocità delle ruote. 
	# Più vai veloce a terra, più le ruote frenano. Questo impedisce all'aereo di schizzare via subito
	# e ti costringe a fare una corsa molto più lunga prima di poterti staccare!
	if is_on_floor(): 
		drag_force += 6.0 + (current_speed * 1.5)
	elif target_speed < 0.1: 
		drag_force += 3.0 
	
	var gravity_pull = -forward_dir.y * gravity_assist
	var net_acceleration = ((thrust - drag_force) / plane_mass) + gravity_pull
	
	current_speed += net_acceleration * delta
	current_speed = clamp(current_speed, 0.0, max_dive_speed)

	# --- 3. ROTAZIONI CONTROLLI ---
	_handle_rotation(delta)
	
	forward_dir = -global_transform.basis.z
	up_dir = global_transform.basis.y

	# --- 4. PORTANZA MATEMATICA FLUIDA ---
	var speed_ratio = current_speed / 25.0
	var throttle_ratio = target_speed 
	var lift_ratio = (speed_ratio * 0.85) + (throttle_ratio * 0.15)
	
	if velocity.length() > 1.0 and not is_on_floor():
		var vel_dir = velocity.normalized()
		var alignment = forward_dir.dot(vel_dir) 
		var slip_drag = (1.0 - max(0.0, alignment)) * sideslip_drag_factor * delta
		current_speed = max(0.0, current_speed - slip_drag)
		
	var target_velocity = forward_dir * current_speed
	var gravity_force = Vector3.DOWN * 9.8 * delta
	
	# ✨ FIX GROUND EFFECT SENZA SCATTI: Ridotto il bonus iniziale a terra a 0.1. 
	# Ora l'aereo non "salta" appena accenna ad alzarsi, ma si stacca in modo fluido e morbido.
	var angle_of_attack_bonus = 1.0
	if is_on_floor():
		var pitch_angle = clamp(forward_dir.y, 0.0, 0.22)
		angle_of_attack_bonus = 0.1 + (pitch_angle * 1.1) 
			
	var effective_lift_power = lift_power * (1.0 + (flap_deployment * 0.5))
	
	var lift_magnitude = 9.8 * lift_ratio * effective_lift_power * max(0.0, up_dir.y) * angle_of_attack_bonus
	var lift = up_dir * lift_magnitude * delta
	
	# --- 5. APPLICAZIONE VELOCITÀ E STALLO ---
	var grip_speed_required = 22.0 - (flap_deployment * 8.0) 
	var raw_grip = clamp(current_speed / grip_speed_required, 0.0, 1.0)
	true_grip = raw_grip * raw_grip * raw_grip 
	
	# Calcoliamo quale DOVREBBE essere l'inerzia ideale in questo frame
	var target_inertia = 8.0 if is_on_floor() else lerp(1.5, 4.0, true_grip)
	
	# ✨ IL FIX: Invece di saltare istantaneamente da 8 a 4, l'inerzia si muove in modo fluido.
	# Il valore 4.0 definisce la morbidezza della transizione (puoi alzarlo a 6.0 se vuoi un decollo ancora più lento).
	current_inertia = move_toward(current_inertia, target_inertia, delta * 4.0)
	
	# Applichiamo l'inerzia fluida al movimento dell'aereo
	velocity = velocity.lerp(target_velocity, delta * current_inertia)
	velocity += lift
	velocity += gravity_force

	# --- 6. FRENI A RUOTA ---
	if is_on_floor() and target_speed < 0.1:
		current_speed = lerp(current_speed, 0.0, delta * 4.0)

	# --- 7. MOVIMENTO E COLLISIONI ---
	move_and_slide()
	if is_on_wall() or is_on_ceiling():
		_crash("Hai colpito un ostacolo!")

func _handle_rotation(delta: float) -> void:
	var speed_factor = clamp((current_speed / 25.0) + 0.2, 0.0, 1.0)
	
	var p = Input.get_axis("pitch_down", "pitch_up") * pitch_speed
	var r = Input.get_axis("roll_right", "roll_left") * roll_speed
	var y = Input.get_axis("yaw_left", "yaw_right") * yaw_speed

	var torque_pull = target_speed * (1.0 - clamp(current_speed / 25.0, 0.0, 1.0))
	rotate_object_local(Vector3.FORWARD, 0.5 * torque_pull * delta)
	
	if is_on_floor():
		rotate_object_local(Vector3.UP, -y * speed_factor * delta)
		var current_roll = rotation.z
		rotation.z = lerp_angle(current_roll, 0.0, delta * 5.0)

		if p > 0: 
			var current_pitch_angle = -global_transform.basis.z.y 
			if current_pitch_angle < 0.22:
				rotate_object_local(Vector3.RIGHT, p * (speed_factor * 0.8) * delta)
		else:
			var current_pitch = rotation.x
			rotation.x = lerp_angle(current_pitch, 0.0, delta * 3.0)
	else:
		rotate_object_local(Vector3.RIGHT, p * speed_factor * delta)
		rotate_object_local(Vector3.FORWARD, -r * speed_factor * delta)
		rotate_object_local(Vector3.UP, -y * speed_factor * delta)
		
		var bank_angle = global_transform.basis.x.y 
		rotate_y(bank_angle * turn_assist_strength * speed_factor * delta)

func _crash(reason: String) -> void:
	is_crashed = true
	current_speed = 0.0
	target_speed = 0.0
	velocity = Vector3.ZERO
	print("CRASH: ", reason)
