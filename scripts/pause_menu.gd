class_name PauseMenu
extends Control
## Pause overlay. Shown when the tree is paused; this node runs with
## PROCESS_MODE_ALWAYS (set in main.tscn) so its buttons and input keep
## working while everything else is frozen. Emits signals — the game root
## owns the actual pause state.

signal resume_requested
signal restart_requested


func _ready() -> void:
	%ResumeButton.pressed.connect(func() -> void: resume_requested.emit())
	%RestartButton.pressed.connect(func() -> void: restart_requested.emit())


func show_menu() -> void:
	visible = true
	%ResumeButton.grab_focus()


func hide_menu() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		resume_requested.emit()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		resume_requested.emit()
