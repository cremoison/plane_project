extends Camera3D

@export var target_node: Node3D        # Nodo CameraTarget posizionato dietro l'aereo

@export_group("Dynamic Inseguimento")

@export var base_position_lag: float = 8.0 

@export var rotation_lag: float = 10 # also speed of rotation, lower = slower

func _ready() -> void:
	top_level = true

func _physics_process(delta: float) -> void:
	if not target_node:
		return

	# Recuperiamo l'aereo per leggerne la velocità fisica interna
	var aircraft = target_node.get_parent() as CharacterBody3D
	var current_lag = base_position_lag

	if aircraft and "current_speed" in aircraft:
		current_lag = base_position_lag + (aircraft.current_speed * 0.4)
	
	global_position = global_position.lerp(target_node.global_position, current_lag * delta)
	
	
	var current_basis = global_transform.basis.orthonormalized()
	var target_basis = target_node.global_transform.basis.orthonormalized()
	
	global_transform.basis = current_basis.slerp(target_basis, rotation_lag * delta).orthonormalized()