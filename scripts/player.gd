class_name PlatformerPlayer
extends CharacterBody3D
## Simple platformer character. World-aligned movement; the follow camera
## sits at a fixed offset behind, so "forward" is always away from the camera.

@export var speed: float = 6.0
@export var jump_velocity: float = 7.5
@export var turn_speed: float = 10.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

## When false (start menu showing), the player still settles under gravity
## but ignores all movement input.
var controls_enabled := false


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if controls_enabled and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Vector2.ZERO
	if controls_enabled:
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input_dir.x, 0.0, input_dir.y)
	if direction.length() > 0.01:
		direction = direction.normalized()
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		var target_yaw := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 8.0 * delta)

	move_and_slide()
