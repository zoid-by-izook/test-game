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

## AnimationPlayer inside the imported Quaternius character model.
@onready var _anim: AnimationPlayer = $CharacterModel.find_child("AnimationPlayer")


var _was_on_floor := true

## Emote overlay: cosmetic only, never touches movement or physics.
## Keys 1-4 play the Quaternius Wave / Yes / No / Duck clips.
const EMOTE_ACTIONS: Array[String] = ["emote_1", "emote_2", "emote_3", "emote_4"]
const EMOTE_CLIPS: Array[String] = ["Wave", "Yes", "No", "Duck"]

## Currently playing emote clip; empty when no emote is active.
var _emote_clip := ""


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if controls_enabled and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		AudioManager.play_sfx("jump")

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
	if not _was_on_floor and is_on_floor():
		AudioManager.play_sfx("land")
	_was_on_floor = is_on_floor()
	_update_emote()
	_update_animation(input_dir)


## Starts an emote when keys 1-4 are pressed. Cosmetic only; the
## emote owns the AnimationPlayer until it finishes or is cancelled.
func _update_emote() -> void:
	if not controls_enabled:
		return
	for i in EMOTE_ACTIONS.size():
		if Input.is_action_just_pressed(EMOTE_ACTIONS[i]):
			_emote_clip = EMOTE_CLIPS[i]
			return


## Picks the character clip from the movement state. Guards on
## current_animation so clips aren't restarted every physics frame.
func _update_animation(input_dir: Vector2) -> void:
	# While an emote is active it owns the AnimationPlayer, so the movement
	# logic below never fights it. Any movement or jump input cancels the
	# emote instantly; a finished clip releases it back to movement.
	if _emote_clip != "":
		if input_dir.length() > 0.01 \
				or (controls_enabled and Input.is_action_just_pressed("jump")) \
				or not _anim.is_playing():
			_emote_clip = ""
		else:
			if _anim.current_animation != _emote_clip:
				_anim.play(_emote_clip)
			return
	var next_anim := "Idle"
	if not is_on_floor():
		next_anim = "Jump" if velocity.y > 1.0 else "Jump_Idle"
	elif input_dir.length() > 0.01:
		next_anim = "Run"
	if _anim.current_animation != next_anim:
		_anim.play(next_anim)
