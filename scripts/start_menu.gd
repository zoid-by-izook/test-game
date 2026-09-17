class_name StartMenu
extends Control
## Title screen overlay. Shown on boot; hidden once the player starts the
## game. Emits `start_requested` when the Start button is pressed — the
## game root also dismisses the menu on any key/mouse/touch via
## `_unhandled_input`, so this signal only covers the button itself.

signal start_requested


func _ready() -> void:
	%StartButton.pressed.connect(_on_start_button_pressed)
	%StartButton.grab_focus()


func show_menu() -> void:
	visible = true
	%StartButton.grab_focus()


func hide_menu() -> void:
	visible = false


func _on_start_button_pressed() -> void:
	start_requested.emit()
