extends Camera3D
## Smooth follow camera at a fixed offset. No mouse look on purpose —
## this is a scaffold, not a showcase.

@export var offset := Vector3(0.0, 7.0, 10.0)
@export var look_at_height := 1.0
@export var smooth_speed := 5.0

var target: Node3D


func _process(delta: float) -> void:
	if target == null:
		return
	var desired := target.global_position + offset
	var t := clampf(smooth_speed * delta, 0.0, 1.0)
	global_position = global_position.lerp(desired, t)
	look_at(target.global_position + Vector3(0.0, look_at_height, 0.0), Vector3.UP)
