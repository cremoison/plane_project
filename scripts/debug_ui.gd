extends Control

@export var p: CharacterBody3D # player

# func _onready() -> void:
# 	p = get_parent().get_node("Player") as CharacterBody3D

func _process(_delta: float) -> void:
	if not p:
		print("Player not found!")
		return

	var label = get_node("Label") as Label
	var info = "
	fps: %d\n
	position: %s\n
	velocity: %sm/s\n
	throttle: %d%%\n
	" % [Engine.get_frames_per_second(), p.global_position, p.velocity, int(p.current_throttle * 100.0)]
	
	
	label.text = info
