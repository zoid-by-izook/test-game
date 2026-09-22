class_name PauseMenu
extends Control
## Pause overlay. Shown when the tree is paused; this node runs with
## PROCESS_MODE_ALWAYS (set in main.tscn) so its buttons and input keep
## working while everything else is frozen. Emits signals — the game root
## owns the actual pause state.

signal resume_requested
signal restart_requested

var _audio_menu: AudioMenu


func _ready() -> void:
	%ResumeButton.pressed.connect(func() -> void: resume_requested.emit())
	%RestartButton.pressed.connect(func() -> void: restart_requested.emit())
	%PauseAudioButton.pressed.connect(show_audio)
	_audio_menu = AudioMenu.new()
	_audio_menu.back_requested.connect(show_main)
	_audio_menu.visible = false
	%PauseCenter.add_child(_audio_menu)


func show_menu() -> void:
	visible = true
	show_main()


func show_main() -> void:
	_audio_menu.visible = false
	%VBox.visible = true
	%ResumeButton.grab_focus()


func show_audio() -> void:
	%VBox.visible = false
	_audio_menu.visible = true
	_audio_menu.refresh()


func hide_menu() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _audio_menu.visible:
		return  # AudioMenu handles ui_cancel itself.
	if event.is_action_pressed("ui_cancel"):
		resume_requested.emit()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		resume_requested.emit()
