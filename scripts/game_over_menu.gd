class_name GameOverMenu
extends Control
## Game-over overlay. Shown when the player falls below KILL_Y; this node
## runs with PROCESS_MODE_ALWAYS (set in main.tscn) so its buttons keep
## working while the tree is paused. Emits signals — the game root owns
## the actual state transitions.

signal retry_requested
signal main_menu_requested


func _ready() -> void:
	%RetryButton.pressed.connect(func() -> void: retry_requested.emit())
	%MainMenuButton.pressed.connect(func() -> void: main_menu_requested.emit())


func show_menu() -> void:
	visible = true
	%RetryButton.grab_focus()


func hide_menu() -> void:
	visible = false
